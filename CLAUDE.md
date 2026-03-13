# Claude Code Vietnamese IME Fix

## Project Overview
This project patches the native Claude Code binary to fix Vietnamese IME input issues.
It works by replacing the DEL handling block in the embedded JavaScript with a stack-based algorithm.

## Important Notes

- Patches the **native binary** directly (not npm cli.js)
- On macOS: strips and re-applies code signature (ad-hoc) during patching

## Commands

```bash
~/.claude/scripts/vipatch.sh patch      # Apply patch
~/.claude/scripts/vipatch.sh status     # Check status
~/.claude/scripts/vipatch.sh restore    # Restore original
~/.claude/scripts/vipatch-update.sh     # Re-apply patch after updates
~/.claude/scripts/vipatch-uninstall.sh  # Full uninstall
```

## File Structure
- `scripts/vipatch.sh` - Entry point (finds claude binary, dispatches to Python)
- `scripts/vipatch_core.py` - Core binary patching logic
- `scripts/vipatch_block_handler.py` - Block detection & replacement module
- `scripts/vipatch-update.sh` - Re-apply patch after updates
- `scripts/vipatch-uninstall.sh` - Self-deleting uninstaller
- `install.sh` - Installation script
