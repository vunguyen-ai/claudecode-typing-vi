#!/usr/bin/env python3
"""Claude Code Vietnamese IME Patch - Core logic.
v1.7.3: Block replacement with prefix condition preservation.
Original fix: https://github.com/manhit96/claude-code-vietnamese-fix
"""
import re
import sys
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict

# Import block handler for v1.7+ replacement strategy
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))
import vipatch_block_handler as block_handler

DEL_CHAR = chr(127)  # 0x7F

def get_version(content: str) -> str:
    m = re.search(r'Version: ([\d.]+)', content)
    return m.group(1) if m else "unknown"

def is_patched(content: str) -> bool:
    # v1.7+: _ns/_sk with stack algorithm
    return '_ns=' in content and '_sk=' in content

def extract_variables(content: str) -> Optional[Dict]:
    """Extract variable names dynamically from minified code."""
    # Search for includes with literal DEL or escaped
    pattern = f'includes\\("{DEL_CHAR}"\\)'
    match = re.search(pattern, content)
    if not match:
        pattern = r'includes\("\\x7f"\)'
        match = re.search(pattern, content)
    if not match:
        return None

    start = max(0, match.start() - 500)
    end = min(len(content), match.end() + 800)
    ctx = content[start:end]

    # v2.1.12 pattern: l.includes("\x7f"){let $A=(l.match(...).length,CA=S;for(..._A<$A;_A++)CA=CA.backspace()
    # Extract: input_var.includes -> input_var=l, then find state vars

    # Find input variable (the one calling .includes)
    incl_pattern = rf'(\w+)\.includes\("{DEL_CHAR}"\)'
    m = re.search(incl_pattern, ctx)
    if not m:
        m = re.search(r'(\w+)\.includes\("\\x7f"\)', ctx)
    if not m:
        return None
    input_var = m.group(1)

    # Find pattern: let count=(input.match(/\x7f/g)||[]).length,state=curState
    # v2.1.12: let $A=(l.match(/\x7f/g)||[]).length,CA=S
    # Note: variable names may start with $ (like $A)
    count_state_pattern = rf'let (\$?\w+)=\({re.escape(input_var)}\.match\(/[^/]+/g\)\|\|\[\]\)\.length,(\w+)=(\w+)'
    m2 = re.search(count_state_pattern, ctx)
    if not m2:
        return None
    count_var, state_var, cur_state = m2.groups()

    # Find update functions by looking at the pattern: if(curState.text!==state.text)textFn(state.text);offsetFn(state.offset)
    text_pattern = rf'if\({re.escape(cur_state)}\.text!==({re.escape(state_var)})\.text\)(\w+)\(\1\.text\)'
    text_m = re.search(text_pattern, ctx)
    if not text_m:
        # Try simpler pattern
        text_m = re.search(rf'(\w+)\({re.escape(state_var)}\.text\)', ctx)

    offset_pattern = rf'(\w+)\({re.escape(state_var)}\.offset\)'
    offset_m = re.search(offset_pattern, ctx)

    if not text_m or not offset_m:
        return None

    text_fn = text_m.group(2) if text_m.lastindex >= 2 else text_m.group(1)
    offset_fn = offset_m.group(1)

    return {
        'input': input_var, 'state': state_var, 'cur_state': cur_state,
        'text_fn': text_fn, 'offset_fn': offset_fn, 'count': count_var
    }


def patch(cli_js: Path) -> bool:
    content = cli_js.read_text('utf-8')
    version = get_version(content)
    print(f"Claude Code v{version} at: {cli_js}")

    if is_patched(content):
        print("Patch already applied!")
        return True

    vars = extract_variables(content)
    if not vars:
        print("Error: Could not extract variables. Version may be incompatible.")
        return False
    print(f"Found vars: {vars}")

    # Find and replace entire DEL block
    block_result = block_handler.find_del_block(content, vars)
    if not block_result:
        print("Error: Could not find DEL handling block.")
        return False

    start_pos, end_pos, prefix_cond = block_result
    print(f"Found DEL block: {end_pos - start_pos} bytes")
    if prefix_cond:
        print(f"Prefix condition: {prefix_cond}")

    # Backup
    backup = cli_js.with_suffix(f'.backup.{datetime.now():%Y%m%d_%H%M%S}')
    shutil.copy(cli_js, backup)
    print(f"Backup: {backup}")

    # Replace entire block with correct implementation
    patch_code = block_handler.create_replacement_patch(vars, prefix_cond)
    new_content = content[:start_pos] + patch_code + content[end_pos:]
    cli_js.write_text(new_content, 'utf-8')
    print("Patch applied successfully! (v1.7.3)")
    return True

def restore(cli_js: Path) -> bool:
    # Try both naming patterns
    backups = sorted(cli_js.parent.glob(f'{cli_js.name}.backup.*'), reverse=True)
    if not backups:
        backups = sorted(cli_js.parent.glob(f'{cli_js.stem}.backup.*'), reverse=True)
    if not backups:
        print("No backup found")
        return False
    shutil.copy(backups[0], cli_js)
    print(f"Restored from: {backups[0]}")
    return True

def status(cli_js: Path) -> bool:
    content = cli_js.read_text('utf-8')
    version = get_version(content)
    patched = is_patched(content)
    print(f"Claude Code v{version}: {'PATCHED' if patched else 'NOT PATCHED'}")
    return patched

def main():
    if len(sys.argv) < 2:
        print("Usage: patch-core.py <cli.js> [patch|restore|status]")
        sys.exit(1)

    cli_js = Path(sys.argv[1])
    action = sys.argv[2] if len(sys.argv) > 2 else 'patch'

    if not cli_js.exists():
        print(f"Error: File not found: {cli_js}")
        sys.exit(1)

    actions = {
        'patch': patch, 'fix': patch, 'apply': patch,
        'restore': restore, 'unpatch': restore, 'remove': restore,
        'status': status, 'check': status
    }

    if action not in actions:
        print(f"Unknown action: {action}")
        sys.exit(1)

    sys.exit(0 if actions[action](cli_js) else 1)

if __name__ == '__main__':
    main()
