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
~/.claude/scripts/vipatch.sh patch
```

Or use the wrapper script that does both:
```bash
~/.claude/scripts/vipatch-update.sh
```

**DO NOT use `brew upgrade claude`** - that's for Claude Desktop app, not Claude Code CLI.

### Applying Patch Only
```bash
~/.claude/scripts/vipatch.sh patch
```

### Check Patch Status
```bash
~/.claude/scripts/vipatch.sh status
```

### Restore Original
```bash
~/.claude/scripts/vipatch.sh restore
```

## File Structure
- `scripts/vipatch.sh` - Main patch script
- `scripts/vipatch_core.py` - Python core logic
- `scripts/vipatch_block_handler.py` - Block handler module
- `scripts/vipatch-update.sh` - Update + auto-patch wrapper
- `install.sh` - Installation script
