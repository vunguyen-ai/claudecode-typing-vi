#!/bin/bash
# Vietnamese IME Patch - Uninstaller
# Restores original binary, removes all vipatch scripts, cleans shell aliases

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Resolve HOME for Windows environments (Git Bash + WSL)
if [[ -z "$HOME" && -n "$USERPROFILE" ]]; then
    HOME=$(cygpath -u "$USERPROFILE" 2>/dev/null || echo "$USERPROFILE")
elif grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    _WIN_PROFILE=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
    if [[ -n "$_WIN_PROFILE" && "$_WIN_PROFILE" != *"%"* ]]; then
        HOME=$(wslpath -u "$_WIN_PROFILE" 2>/dev/null || echo "$_WIN_PROFILE")
    fi
fi

SCRIPT_DIR="$HOME/.claude/scripts"
SELF="$SCRIPT_DIR/vipatch-uninstall.sh"

echo ""
echo -e "${YELLOW}Uninstalling Vietnamese IME Patch...${NC}"
echo ""

# Step 1: Restore original binary
if [[ -f "$SCRIPT_DIR/vipatch.sh" ]]; then
    echo "Restoring original binary..."
    RESTORE_RESULT=$("$SCRIPT_DIR/vipatch.sh" restore 2>&1) || true
    echo "$RESTORE_RESULT"
else
    echo -e "${YELLOW}Patch script not found — skipping restore${NC}"
fi

# Step 2: Remove aliases from shell config
for CONFIG in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [[ -f "$CONFIG" ]] && grep -q "claude-vipatch\|vipatch" "$CONFIG" 2>/dev/null; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/# Vietnamese IME fix for Claude Code/d' "$CONFIG"
            sed -i '' '/claude-vipatch/d' "$CONFIG"
            sed -i '' '/vipatch-update/d' "$CONFIG"
        else
            sed -i '/# Vietnamese IME fix for Claude Code/d' "$CONFIG"
            sed -i '/claude-vipatch/d' "$CONFIG"
            sed -i '/vipatch-update/d' "$CONFIG"
        fi
        echo -e "${GREEN}Removed aliases from $CONFIG${NC}"
    fi
done

# Step 3: Remove all vipatch scripts (except self, deleted last)
echo "Removing scripts..."
for f in "$SCRIPT_DIR"/vipatch*; do
    [[ "$f" == "$SELF" ]] && continue
    rm -f "$f"
done

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
echo -e "Restart your terminal to apply changes."
echo ""

# Step 4: Self-delete (OS keeps handle open until process exits)
rm -f "$SELF"
