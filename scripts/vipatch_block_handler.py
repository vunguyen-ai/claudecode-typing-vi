#!/usr/bin/env python3
"""Block replacement handler for Vietnamese IME patch.
v1.7.3: Block replacement with prefix condition preservation.
"""
import re
from typing import Optional, Tuple

DEL_CHAR = chr(127)  # 0x7F

def find_del_block(content: str, vars: dict) -> Optional[Tuple[int, int, str]]:
    """Find the entire DEL handling if-block boundaries for replacement.

    Actual pattern: if(!QA.backspace&&!QA.delete&&l.includes("\\x7f")){...}
    Returns: (start_pos, end_pos, prefix_condition) or None
    """
    input_var = vars["input"]

    # Pattern matches: if(PREFIX&&input.includes(DEL)){ - capture the prefix
    if_patterns = [
        rf'if\(([^{{]*?)&&{re.escape(input_var)}\.includes\("{DEL_CHAR}"\)\){{',
        rf'if\(([^{{]*?)&&{re.escape(input_var)}\.includes\("\\x7f"\)\){{'
    ]

    start_match = None
    prefix_cond = ""
    for pattern in if_patterns:
        start_match = re.search(pattern, content)
        if start_match:
            prefix_cond = start_match.group(1)  # Capture the prefix condition
            break

    if not start_match:
        return None

    start_pos = start_match.start()

    # Count braces to find matching closing brace
    pos = start_match.end()
    brace_count = 1

    while pos < len(content) and brace_count > 0:
        if content[pos] == '{':
            brace_count += 1
        elif content[pos] == '}':
            brace_count -= 1
        pos += 1

    if brace_count != 0:
        return None

    # Verify this is the DEL handling block
    block_content = content[start_pos:pos]
    if 'backspace()' not in block_content and 'deleteBackward()' not in block_content:
        return None

    return (start_pos, pos, prefix_cond)

def create_replacement_patch(vars: dict, prefix_cond: str = "") -> str:
    """Generate complete replacement block with stack-based algorithm.

    This replaces the ENTIRE original DEL handling block, ensuring:
    - Single state machine (no double processing)
    - Correct sequential DEL handling
    - Atomic operation
    - Preserves original prefix conditions (e.g., !QA.backspace&&!QA.delete)
    """
    inp, cur = vars["input"], vars["cur_state"]
    tfn, ofn = vars["text_fn"], vars["offset_fn"]

    # Build condition: prefix&&input.includes(DEL) or just input.includes(DEL)
    if prefix_cond:
        condition = f'{prefix_cond}&&{inp}.includes("{DEL_CHAR}")'
    else:
        condition = f'{inp}.includes("{DEL_CHAR}")'

    return (
        f'if({condition})'
        f'{{let _ns={cur},_sk=[];'
        f'for(const _c of {inp})'
        f'{{if(_c==="{DEL_CHAR}")'
        f'{{if(_sk.length>0)_sk.pop();else _ns=_ns.backspace()}}'
        f'else _sk.push(_c)}}'
        f'for(const _c of _sk)_ns=_ns.insert(_c);'
        f'if(!{cur}.equals(_ns))'
        f'{{if({cur}.text!==_ns.text){tfn}(_ns.text);'
        f'{ofn}(_ns.offset)}}return}}'
    )
