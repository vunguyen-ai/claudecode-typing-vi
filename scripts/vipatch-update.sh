#!/bin/bash
# Re-applies Vietnamese IME patch after Claude Code updates.
# Native installs auto-update, so this just re-patches.
# Usage: claude-update

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find patch script
if [[ -f "$SCRIPT_DIR/vipatch.sh" ]]; then
    PATCH_SCRIPT="$SCRIPT_DIR/vipatch.sh"
elif [[ -f "$HOME/.claude/scripts/vipatch.sh" ]]; then
    PATCH_SCRIPT="$HOME/.claude/scripts/vipatch.sh"
else
    echo "Error: vipatch.sh not found"
    exit 1
fi

echo "Re-applying Vietnamese IME patch..."
echo "(Native Claude Code auto-updates; this re-patches after an update.)"
echo ""
"$PATCH_SCRIPT" patch

echo ""
echo "Done! Restart Claude Code to apply."
