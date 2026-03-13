#!/bin/bash
# Claude Code Vietnamese IME Patch - Entry point
# Usage: claude-vipatch [patch|restore|status]
# Requires: vipatch_core.py

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/vipatch_core.py"

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "Error: Core script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Find cli.js
find_cli_js() {
    local claude_path
    if command -v claude &>/dev/null; then
        claude_path=$(which claude)
        [[ -L "$claude_path" ]] && claude_path=$(readlink -f "$claude_path" 2>/dev/null || echo "")
        [[ -f "$claude_path" ]] && head -1 "$claude_path" | grep -q "node" && echo "$claude_path" && return 0
    fi

    for path in "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
                "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
                "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"; do
        [[ -f "$path" ]] && echo "$path" && return 0
    done
    return 1
}

CLI_JS=$(find_cli_js)
if [[ -z "$CLI_JS" ]]; then
    echo "Error: Could not find Claude Code cli.js"
    exit 1
fi

ACTION="${1:-patch}"
RESULT=$(python3 "$PYTHON_SCRIPT" "$CLI_JS" "$ACTION")
EXIT_CODE=$?
echo "$RESULT"

# Show restart reminder for patch/restore actions
if [[ $EXIT_CODE -eq 0 && ("$ACTION" == "patch" || "$ACTION" == "restore" || "$ACTION" == "fix" || "$ACTION" == "apply") ]]; then
    if echo "$RESULT" | grep -q "successfully\|applied"; then
        echo ""
        echo -e "\033[1;33m⚠️  Khởi động lại Claude Code để áp dụng thay đổi!\033[0m"
        echo -e "\033[1;33m   Nhấn Ctrl+C thoát, sau đó chạy: claude\033[0m"
    fi
fi

exit $EXIT_CODE
