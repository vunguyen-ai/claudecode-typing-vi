#!/usr/bin/env python3
"""Block replacement handler for Vietnamese IME patch.
v2.0.0: Native binary patching support.
Finds and replaces the DEL handling block in Claude Code's embedded JavaScript.
"""
import re
from typing import Optional, Tuple

# DEL escape as it appears in the binary (literal ASCII chars: \x7F)
DEL_ESCAPED_UPPER = r'\x7F'
DEL_ESCAPED_LOWER = r'\x7f'


def find_del_block(data: bytes) -> Optional[Tuple[int, int, dict]]:
    """Find the DEL handling block in binary data.

    Searches for the pattern:
      if(!prefix&&input.includes("\\x7F")){...backspace()...return}

    Returns: (start_pos, end_pos, vars_dict) or None
    """
    # Search for the includes("\x7F") pattern in ASCII
    # Binary stores it as: 2e 69 6e 63 6c 75 64 65 73 28 22 5c 78 37 46 22 29
    markers = [
        b'.includes("\\x7F")',
        b'.includes("\\x7f")',
        b'.includes("\x7f")',   # literal DEL byte (npm installs)
    ]

    inc_pos = -1
    for marker in markers:
        inc_pos = data.find(marker)
        if inc_pos >= 0:
            break

    if inc_pos < 0:
        return None

    # Extract context window (1500 bytes around the match)
    ctx_start = max(0, inc_pos - 500)
    ctx_end = min(len(data), inc_pos + 1000)
    ctx_bytes = data[ctx_start:ctx_end]
    ctx = ctx_bytes.decode('ascii', errors='replace')
    ctx_offset = inc_pos - ctx_start  # offset of includes() within context

    # Find input variable: X.includes(...)
    inc_in_ctx = ctx[ctx_offset - 20:ctx_offset + 30]
    m = re.search(r'(\w+)\.includes\(', inc_in_ctx)
    if not m:
        return None
    input_var = m.group(1)

    # Find the if( block start in the binary
    # Pattern: if(PREFIX&&input.includes(...)){
    search_back = data[max(0, inc_pos - 100):inc_pos]
    if_pos = search_back.rfind(b'if(')
    if if_pos < 0:
        return None
    block_start = max(0, inc_pos - 100) + if_pos

    # Extract prefix condition (between 'if(' and 'input.includes')
    prefix_bytes = data[block_start + 3:inc_pos]
    # Remove trailing '&&' and the input var
    prefix_text = prefix_bytes.decode('ascii', errors='replace')
    prefix_match = re.match(r'(.+?)&&' + re.escape(input_var) + r'$', prefix_text)
    prefix_cond = prefix_match.group(1) if prefix_match else ''

    # Find the opening brace of the if block
    brace_pos = data.find(b'{', inc_pos)
    if brace_pos < 0:
        return None

    # Count braces to find matching close
    pos = brace_pos + 1
    depth = 1
    while pos < len(data) and depth > 0:
        if data[pos:pos + 1] == b'{':
            depth += 1
        elif data[pos:pos + 1] == b'}':
            depth -= 1
        pos += 1
    block_end = pos

    if depth != 0:
        return None

    # Verify this is the DEL handler (must contain backspace)
    block_data = data[block_start:block_end]
    if b'backspace()' not in block_data:
        return None

    # Extract remaining variables from context
    vars_dict = _extract_vars_from_context(ctx, input_var, ctx_offset)
    if not vars_dict:
        return None

    vars_dict['prefix_cond'] = prefix_cond
    return (block_start, block_end, vars_dict)


def _extract_vars_from_context(ctx: str, input_var: str, ctx_offset: int) -> Optional[dict]:
    """Extract variable names from the context around the DEL handler."""
    # Patterns work with both escaped (\x7F) and literal DEL
    del_pat = r'(?:\\x7[fF]|\x7f)'

    # Count and state: let HH=(input.match(/\x7f/g)||[]).length,LH=y
    count_state = re.search(
        rf'let (\$?\w+)=\({re.escape(input_var)}\.match\(/[^/]+/g\)\|\|\[\]\)\.length,(\w+)=(\w+)',
        ctx
    )
    if not count_state:
        return None

    count_var, state_var, cur_state = count_state.groups()

    # Find update functions from the conditional:
    # if(!curState.equals(stateVar)){if(curState.text!==stateVar.text)textFn(stateVar.text);offsetFn(stateVar.offset)}
    text_fn_match = re.search(
        rf'if\({re.escape(cur_state)}\.text!==({re.escape(state_var)})\.text\)(\w+)\(\1\.text\)',
        ctx
    )
    if not text_fn_match:
        text_fn_match = re.search(rf'(\w+)\({re.escape(state_var)}\.text\)', ctx)

    offset_fn_match = re.search(rf'(\w+)\({re.escape(state_var)}\.offset\)', ctx)

    if not text_fn_match or not offset_fn_match:
        return None

    text_fn = text_fn_match.group(2) if text_fn_match.lastindex >= 2 else text_fn_match.group(1)
    offset_fn = offset_fn_match.group(1)

    return {
        'input': input_var,
        'state': state_var,
        'cur_state': cur_state,
        'text_fn': text_fn,
        'offset_fn': offset_fn,
        'count': count_var,
    }


def create_replacement_patch(vars_dict: dict, original_size: int) -> Optional[bytes]:
    """Generate replacement bytes for the DEL block, padded to exact size.

    The replacement uses a stack-based algorithm that correctly handles
    Vietnamese IME backspace-then-replace sequences.
    """
    inp = vars_dict['input']
    cur = vars_dict['cur_state']
    tfn = vars_dict['text_fn']
    ofn = vars_dict['offset_fn']
    prefix = vars_dict.get('prefix_cond', '')

    # Build condition with prefix
    if prefix:
        cond = f'{prefix}&&{inp}.includes("\\x7F")'
    else:
        cond = f'{inp}.includes("\\x7F")'

    # Stack-based replacement (minified)
    # Uses single-char vars for size: n=state, k=stack, c=char
    patch = (
        f'if({cond})'
        f'{{let n={cur},k=[];'
        f'for(let c of {inp})'
        f'c==="\\x7F"?k.length?k.pop():n=n.backspace():k.push(c);'
        f'for(let c of k)n=n.insert(c);'
        f'y.equals(n)||(A(n.text),h(n.offset));'
        # Discover and preserve post-handler function calls
    )

    # Check if there are post-handler calls (like mUH(),pUH()) in the original
    # We'll add them via the caller if needed
    # For now, generate without post-calls and let caller add them
    # Actually, we need to detect these from the original block

    # Simpler: generate the full replacement with known post-handler pattern
    # The post-handler calls are version-specific, so we extract them
    patch_with_return = patch + 'return}'

    patch_bytes = patch_with_return.encode('ascii')

    if len(patch_bytes) > original_size:
        return None  # Can't fit

    # Pad with spaces
    return patch_bytes + b' ' * (original_size - len(patch_bytes))


def create_replacement_with_suffix(vars_dict: dict, original_size: int, suffix_calls: str) -> Optional[bytes]:
    """Generate replacement with preserved post-handler function calls.

    Args:
        vars_dict: Extracted variable names
        original_size: Must match exactly
        suffix_calls: Post-handler calls like 'mUH(),pUH()' extracted from original
    """
    inp = vars_dict['input']
    cur = vars_dict['cur_state']
    tfn = vars_dict['text_fn']
    ofn = vars_dict['offset_fn']
    prefix = vars_dict.get('prefix_cond', '')

    if prefix:
        cond = f'{prefix}&&{inp}.includes("\\x7F")'
    else:
        cond = f'{inp}.includes("\\x7F")'

    patch = (
        f'if({cond})'
        f'{{let n={cur},k=[];'
        f'for(let c of {inp})'
        f'c==="\\x7F"?k.length?k.pop():n=n.backspace():k.push(c);'
        f'for(let c of k)n=n.insert(c);'
        f'{cur}.equals(n)||({tfn}(n.text),{ofn}(n.offset));'
    )

    if suffix_calls:
        patch += f'{suffix_calls};'

    patch += 'return}'

    patch_bytes = patch.encode('ascii')

    if len(patch_bytes) > original_size:
        return None

    return patch_bytes + b' ' * (original_size - len(patch_bytes))


def extract_suffix_calls(data: bytes, block_start: int, block_end: int) -> str:
    """Extract post-handler function calls from the original block.

    Looks for function calls between the last '}' of the state update
    and 'return}' at the end.
    """
    block = data[block_start:block_end].decode('ascii', errors='replace')

    # Pattern: ...offset)}SUFFIX_CALLS;return}
    m = re.search(r'\.offset\)}(.+?);?return}$', block)
    if m:
        suffix = m.group(1).strip(';').strip()
        if suffix and not suffix.startswith('return'):
            return suffix

    return ''
