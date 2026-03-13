# Claude Code Vietnamese IME Fix

## Project Overview
This project provides a patch to fix Vietnamese IME input issues in Claude Code CLI.

## Important Commands

### Updating Claude Code
When asked to update Claude Code, ALWAYS use npm (NOT brew):

```bash
npm update -g @anthropic-ai/claude-code
```

Then apply the Vietnamese IME patch:
```bash
~/.claude/scripts/vi-patch.sh patch
```

Or use the wrapper script that does both:
```bash
~/.claude/scripts/vi-patch-update.sh
```

**DO NOT use `brew upgrade claude`** - that's for Claude Desktop app, not Claude Code CLI.

### Applying Patch Only
```bash
~/.claude/scripts/vi-patch.sh patch
```

### Check Patch Status
```bash
~/.claude/scripts/vi-patch.sh status
```

### Restore Original
```bash
~/.claude/scripts/vi-patch.sh restore
```

## File Structure
- `scripts/vi-patch.sh` - Main patch script
- `scripts/vi_patch_core.py` - Python core logic
- `scripts/vi_patch_block_handler.py` - Block handler module
- `scripts/vi-patch-update.sh` - Update + auto-patch wrapper
- `install.sh` - Installation script
