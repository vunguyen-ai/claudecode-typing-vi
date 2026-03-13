#!/bin/bash
# Claude Code Vietnamese IME Patch - Entry point
# Usage: claude-vipatch [patch|restore|status]
# Patches the native Claude Code binary directly.

# Resolve HOME on Windows: PowerShell doesn't export $HOME, fall back to $USERPROFILE
if [[ -z "$HOME" && -n "$USERPROFILE" ]]; then
    HOME=$(cygpath -u "$USERPROFILE" 2>/dev/null || echo "$USERPROFILE")
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
