#!/bin/bash
# Claude Code Vietnamese IME Fix - Installer
# https://github.com/vunguyen-ai/claudecode-typing-vi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

REPO_URL="https://raw.githubusercontent.com/vunguyen-ai/claudecode-typing-vi/main"

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

TARGET_DIR="$HOME/.claude/scripts"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Claude Code Vietnamese IME Fix          ║"
echo "║  Bản vá bộ gõ tiếng Việt                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    log_error "Python 3 is required but not installed"
    exit 1
fi
log_success "Python 3 found"

# Check Claude Code (native install) — supports CLAUDE_BIN override
if [[ -n "$CLAUDE_BIN" && -f "$CLAUDE_BIN" ]]; then
    log_info "Using CLAUDE_BIN override: $CLAUDE_BIN"
else
    CLAUDE_BIN=""
    if command -v claude &>/dev/null; then
        CLAUDE_BIN=$(which claude)
    elif [[ -f "$HOME/.local/bin/claude" ]]; then
        CLAUDE_BIN="$HOME/.local/bin/claude"
    elif [[ -f "$HOME/.local/bin/claude.exe" ]]; then
        CLAUDE_BIN="$HOME/.local/bin/claude.exe"
    fi
    # WSL fallback: use Windows PATH via cmd.exe
    if [[ -z "$CLAUDE_BIN" ]] && command -v cmd.exe &>/dev/null; then
        _WIN_BIN=$(cmd.exe /c "where claude" 2>/dev/null | tr -d '\r' | head -1)
        if [[ -n "$_WIN_BIN" ]]; then
            CLAUDE_BIN=$(wslpath -u "$_WIN_BIN" 2>/dev/null || echo "$_WIN_BIN")
        fi
    fi
fi

if [[ -z "$CLAUDE_BIN" ]]; then
    log_error "Claude Code not found"
    echo "    Checked (HOME=$HOME):"
    echo "      - claude in \$PATH: $(command -v claude 2>/dev/null || echo 'not found')"
    echo "      - $HOME/.local/bin/claude(.exe): not found"
    if command -v cmd.exe &>/dev/null; then
        echo "      - cmd.exe where claude: $(cmd.exe /c 'where claude' 2>/dev/null | tr -d '\r' | head -1 || echo 'not found')"
    fi
    echo ""
    echo "    If Claude Code IS installed, find it and retry:"
    echo "      CLAUDE_BIN=/path/to/claude bash install.sh"
    echo ""
    echo "    If not installed: https://docs.anthropic.com/en/docs/claude-code/overview"
    exit 1
fi
CLAUDE_VERSION=$("$CLAUDE_BIN" --version 2>/dev/null | head -1) || CLAUDE_VERSION="unknown"
log_success "Claude Code found: $CLAUDE_VERSION"
log_info "Binary: $CLAUDE_BIN"

# Create target directory
mkdir -p "$TARGET_DIR"
log_info "Target: $TARGET_DIR"

# Determine script source (local repo or remote)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/vipatch.sh" ]]; then
    log_info "Installing from local repo..."
    cp "$SCRIPT_DIR/scripts/vipatch.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch_core.py" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch_block_handler.py" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch-update.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch-uninstall.sh" "$TARGET_DIR/"
else
    log_info "Downloading scripts from GitHub..."
    curl -fsSL "$REPO_URL/scripts/vipatch.sh" -o "$TARGET_DIR/vipatch.sh"
    curl -fsSL "$REPO_URL/scripts/vipatch_core.py" -o "$TARGET_DIR/vipatch_core.py"
    curl -fsSL "$REPO_URL/scripts/vipatch_block_handler.py" -o "$TARGET_DIR/vipatch_block_handler.py"
    curl -fsSL "$REPO_URL/scripts/vipatch-update.sh" -o "$TARGET_DIR/vipatch-update.sh"
    curl -fsSL "$REPO_URL/scripts/vipatch-uninstall.sh" -o "$TARGET_DIR/vipatch-uninstall.sh"
fi

# Make executable
chmod +x "$TARGET_DIR/vipatch.sh"
chmod +x "$TARGET_DIR/vipatch_core.py"
chmod +x "$TARGET_DIR/vipatch-update.sh"
chmod +x "$TARGET_DIR/vipatch-uninstall.sh"
log_success "Scripts installed"

# Detect shell config
SHELL_CONFIG=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

# Add aliases
if [[ -n "$SHELL_CONFIG" ]]; then
    ALIAS_LINE1='alias claude-vipatch="$HOME/.claude/scripts/vipatch.sh"'
    ALIAS_LINE2='alias claude-update="$HOME/.claude/scripts/vipatch-update.sh"'

    if ! grep -q "claude-vipatch" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Vietnamese IME fix for Claude Code" >> "$SHELL_CONFIG"
        echo "$ALIAS_LINE1" >> "$SHELL_CONFIG"
        echo "$ALIAS_LINE2" >> "$SHELL_CONFIG"
        log_success "Aliases added to $SHELL_CONFIG"
    else
        log_info "Aliases already exist"
    fi
else
    log_warn "Could not detect shell config. Add manually:"
    echo '  alias claude-vipatch="$HOME/.claude/scripts/vipatch.sh"'
    echo '  alias claude-update="$HOME/.claude/scripts/vipatch-update.sh"'
fi

# Apply patch
echo ""
log_info "Applying patch..."
PATCH_RESULT=$("$TARGET_DIR/vipatch.sh" patch 2>&1) || true
echo "$PATCH_RESULT"

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${YELLOW}Restart Claude Code to apply: Ctrl+C, then run: claude${NC}"
echo ""
echo "Commands (after restarting terminal):"
echo "  claude-vipatch         Apply patch"
echo "  claude-vipatch status  Check patch status"
echo "  claude-vipatch restore Restore original"
echo "  claude-update          Re-apply patch after updates"
echo ""
