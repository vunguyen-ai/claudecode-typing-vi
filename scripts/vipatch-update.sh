#!/bin/bash
# Wrapper script: Updates Claude Code and auto-patches Vietnamese IME
# Usage: claude-update

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find patch script - check both local dir and installed location
if [[ -f "$SCRIPT_DIR/vipatch.sh" ]]; then
    PATCH_SCRIPT="$SCRIPT_DIR/vipatch.sh"
elif [[ -f "$HOME/.claude/scripts/vipatch.sh" ]]; then
    PATCH_SCRIPT="$HOME/.claude/scripts/vipatch.sh"
else
    echo "Error: vipatch.sh not found"
    exit 1
fi

echo "Updating Claude Code..."
npm update -g @anthropic-ai/claude-code

echo ""
echo "Applying Vietnamese IME patch..."
"$PATCH_SCRIPT" patch

echo ""
echo "Done! Claude Code updated and patched."
