#!/usr/bin/env python3
"""Claude Code Vietnamese IME Patch - Core logic.
v2.0.0: Native binary patching support.
Patches the embedded JavaScript inside Claude Code's native binary.
Original fix: https://github.com/manhit96/claude-code-vietnamese-fix
"""
import os
import re
import sys
import shutil
import platform
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

# Import block handler
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))
import vipatch_block_handler as block_handler


def get_version_from_binary(binary_path: Path) -> str:
    """Get Claude Code version by running the binary."""
    try:
        result = subprocess.run(
            [str(binary_path), '--version'],
            capture_output=True, text=True, timeout=10
        )
        return result.stdout.strip().split('\n')[0] if result.returncode == 0 else 'unknown'
    except Exception:
        return 'unknown'


def is_patched(data: bytes) -> bool:
    """Check if binary is already patched by looking for patch markers."""
    return (
        b'let n=y,k=[]' in data
        and b'k.pop():n=n.backspace()' in data
        and b'n=n.insert(c)' in data
    )


def handle_codesign(binary_path: Path, action: str) -> None:
    """Handle macOS code signing for binary patching.

    Args:
        action: 'strip' to remove signature, 'resign' to ad-hoc sign
    """
    if platform.system() != 'Darwin':
        return

    try:
        if action == 'strip':
            subprocess.run(
                ['codesign', '--remove-signature', str(binary_path)],
                capture_output=True, timeout=30
            )
            print('Stripped macOS code signature')
        elif action == 'resign':
            subprocess.run(
                ['codesign', '--force', '--deep', '-s', '-', str(binary_path)],
                capture_output=True, timeout=30
            )
            print('Applied ad-hoc code signature')
    except FileNotFoundError:
        print('Warning: codesign not found (not macOS?)')
    except Exception as e:
        print(f'Warning: codesign {action} failed: {e}')


def patch(binary_path: Path) -> bool:
    """Patch the native Claude Code binary."""
    version = get_version_from_binary(binary_path)
    print(f'Claude Code {version} at: {binary_path}')

    data = binary_path.read_bytes()

    if is_patched(data):
        print('Patch already applied!')
        return True

    # Find DEL block and extract variables
    result = block_handler.find_del_block(data)
    if not result:
        print('Error: Could not find DEL handling block.')
        print('Claude Code version may be incompatible.')
        return False

    start_pos, end_pos, vars_dict = result
    original_size = end_pos - start_pos
    print(f'Found DEL block: {original_size} bytes at offset {start_pos}')
    print(f'Variables: {vars_dict}')

    # Extract post-handler calls (e.g., mUH(),pUH())
    suffix = block_handler.extract_suffix_calls(data, start_pos, end_pos)
    if suffix:
        print(f'Post-handler calls: {suffix}')

    # Generate replacement
    replacement = block_handler.create_replacement_with_suffix(
        vars_dict, original_size, suffix
    )
    if not replacement:
        print('Error: Replacement patch too large to fit.')
        return False

    assert len(replacement) == original_size, \
        f'Size mismatch: {len(replacement)} != {original_size}'

    # Backup
    backup = binary_path.with_suffix(
        binary_path.suffix + f'.backup.{datetime.now():%Y%m%d_%H%M%S}'
    )
    shutil.copy2(binary_path, backup)
    print(f'Backup: {backup}')

    # Strip macOS code signature before patching
    handle_codesign(binary_path, 'strip')

    # Apply patch via temp file (atomic write where possible)
    patched = bytearray(data)
    patched[start_pos:end_pos] = replacement
    tmp = binary_path.with_suffix(binary_path.suffix + '.tmp')
    try:
        tmp.write_bytes(bytes(patched))
        tmp.replace(binary_path)
    except OSError:
        # Fallback: direct write (Windows may lock files)
        binary_path.write_bytes(bytes(patched))
        if tmp.exists():
            tmp.unlink()

    # Preserve executable permission
    binary_path.chmod(binary_path.stat().st_mode | 0o755)

    # Re-sign on macOS
    handle_codesign(binary_path, 'resign')

    # Verify
    verify_data = binary_path.read_bytes()
    if not is_patched(verify_data):
        print('Error: Patch verification failed! Restoring backup...')
        shutil.copy2(backup, binary_path)
        return False

    print('Patch applied successfully! (v2.0.0)')
    return True


def restore(binary_path: Path) -> bool:
    """Restore from the most recent backup."""
    suffix = binary_path.suffix  # .exe on Windows, empty on Unix
    pattern = f'{binary_path.name}.backup.*'
    backups = sorted(binary_path.parent.glob(pattern), reverse=True)

    if not backups:
        # Try without the extension prefix
        stem_pattern = f'{binary_path.stem}.backup.*'
        backups = sorted(binary_path.parent.glob(stem_pattern), reverse=True)

    if not backups:
        print('No backup found')
        return False

    shutil.copy2(backups[0], binary_path)
    binary_path.chmod(binary_path.stat().st_mode | 0o755)

    # Re-sign on macOS after restore
    handle_codesign(binary_path, 'resign')

    print(f'Restored from: {backups[0]}')
    return True


def status(binary_path: Path) -> bool:
    """Check patch status."""
    version = get_version_from_binary(binary_path)
    data = binary_path.read_bytes()
    patched = is_patched(data)
    print(f'Claude Code {version}: {"PATCHED" if patched else "NOT PATCHED"}')
    return patched


def main():
    if len(sys.argv) < 2:
        print('Usage: vipatch_core.py <claude-binary> [patch|restore|status]')
        sys.exit(1)

    binary_path = Path(sys.argv[1])
    action = sys.argv[2] if len(sys.argv) > 2 else 'patch'

    # On Windows, `which claude` may return path without .exe
    if not binary_path.exists() and binary_path.with_suffix('.exe').exists():
        binary_path = binary_path.with_suffix('.exe')

    if not binary_path.exists():
        print(f'Error: File not found: {binary_path}')
        sys.exit(1)

    actions = {
        'patch': patch, 'fix': patch, 'apply': patch,
        'restore': restore, 'unpatch': restore, 'remove': restore,
        'status': status, 'check': status,
    }

    if action not in actions:
        print(f'Unknown action: {action}')
        sys.exit(1)

    sys.exit(0 if actions[action](binary_path) else 1)


if __name__ == '__main__':
    main()
