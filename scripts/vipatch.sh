#!/bin/bash
# Claude Code Vietnamese IME Patch - Entry point
# Usage: claude-vipatch [patch|restore|status]
# Patches the native Claude Code binary directly.

# Resolve HOME for Windows environments (Git Bash + WSL)
if [[ -z "$HOME" && -n "$USERPROFILE" ]]; then
    # Git Bash: PowerShell doesn't export $HOME, fall back to $USERPROFILE
    HOME=$(cygpath -u "$USERPROFILE" 2>/dev/null || echo "$USERPROFILE")
elif grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    # WSL: Claude Code is a Windows app, resolve Windows home via cmd.exe
    _WIN_PROFILE=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
    if [[ -n "$_WIN_PROFILE" && "$_WIN_PROFILE" != *"%"* ]]; then
        HOME=$(wslpath -u "$_WIN_PROFILE" 2>/dev/null || echo "$_WIN_PROFILE")
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/vipatch_core.py"

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "Error: Core script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Find the native Claude Code binary — supports CLAUDE_BIN override
find_claude_binary() {
    local bin_path

    # Check PATH first
    if command -v claude &>/dev/null; then
        bin_path=$(which claude)
        # Resolve symlinks
        if [[ -L "$bin_path" ]]; then
            bin_path=$(python3 -c "import os; print(os.path.realpath('$bin_path'))" 2>/dev/null || echo "$bin_path")
        fi
        [[ -f "$bin_path" ]] && echo "$bin_path" && return 0
    fi

    # Native install paths
    for path in "$HOME/.local/bin/claude" \
                "$HOME/.local/bin/claude.exe" \
                "/usr/local/bin/claude"; do
        [[ -f "$path" ]] && echo "$path" && return 0
    done

    # WSL fallback: use Windows PATH via cmd.exe
    if command -v cmd.exe &>/dev/null; then
        local win_bin
        win_bin=$(cmd.exe /c "where claude" 2>/dev/null | tr -d '\r' | head -1)
        if [[ -n "$win_bin" ]]; then
            local unix_bin
            unix_bin=$(wslpath -u "$win_bin" 2>/dev/null || echo "$win_bin")
            [[ -f "$unix_bin" ]] && echo "$unix_bin" && return 0
        fi
    fi

    return 1
}

if [[ -n "$CLAUDE_BIN" && -f "$CLAUDE_BIN" ]]; then
    : # Use CLAUDE_BIN override from environment
else
    CLAUDE_BIN=$(find_claude_binary)
fi
if [[ -z "$CLAUDE_BIN" ]]; then
    echo "Error: Could not find Claude Code binary."
    echo "  Checked (HOME=$HOME):"
    echo "    - claude in \$PATH: $(command -v claude 2>/dev/null || echo 'not found')"
    echo "    - $HOME/.local/bin/claude(.exe): not found"
    echo "    - /usr/local/bin/claude: not found"
    echo ""
    echo "  Manual override: CLAUDE_BIN=/path/to/claude $0 $*"
    echo "  Install: https://docs.anthropic.com/en/docs/claude-code/overview"
    exit 1
fi

ACTION="${1:-patch}"
RESULT=$(python3 "$PYTHON_SCRIPT" "$CLAUDE_BIN" "$ACTION")
EXIT_CODE=$?
echo "$RESULT"

# Show restart reminder for patch/restore actions
if [[ $EXIT_CODE -eq 0 && ("$ACTION" == "patch" || "$ACTION" == "restore" || "$ACTION" == "fix" || "$ACTION" == "apply") ]]; then
    if echo "$RESULT" | grep -q "successfully\|applied\|Restored"; then
        echo ""
        echo -e "\033[1;33m  Restart Claude Code to apply changes!\033[0m"
        echo -e "\033[1;33m  Press Ctrl+C to exit, then run: claude\033[0m"
    fi
fi

exit $EXIT_CODE
