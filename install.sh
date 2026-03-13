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

# Check Claude Code
if ! command -v claude &>/dev/null; then
    log_error "Claude Code not found"
    echo "    Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi
CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1)
log_success "Claude Code found: $CLAUDE_VERSION"

# Create target directory
mkdir -p "$TARGET_DIR"
log_info "Target: $TARGET_DIR"

# Determine script source (local repo or remote)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/vipatch.sh" ]]; then
    # Local installation from cloned repo
    log_info "Installing from local repo..."
    cp "$SCRIPT_DIR/scripts/vipatch.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch_core.py" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch_block_handler.py" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch-update.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/scripts/vipatch-uninstall.sh" "$TARGET_DIR/"
else
    # Remote installation via curl
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
PATCH_RESULT=$("$TARGET_DIR/vipatch.sh" patch 2>&1)
echo "$PATCH_RESULT"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓ CÀI ĐẶT THÀNH CÔNG!                                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  ⚠️  QUAN TRỌNG: Thoát và khởi động lại Claude Code          ║"
echo "║     để bản vá có hiệu lực!                                   ║"
echo "║                                                              ║"
echo "║  Nhấn Ctrl+C để thoát phiên hiện tại, sau đó chạy: claude    ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}Lệnh khả dụng (sau khi restart terminal hoặc chạy 'source $SHELL_CONFIG'):${NC}"
echo ""
echo "  claude-vipatch        Áp dụng bản vá"
echo "  claude-vipatch status Kiểm tra trạng thái"
echo "  claude-update          Cập nhật Claude + tự động vá"
echo ""
