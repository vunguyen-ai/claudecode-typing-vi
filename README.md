# Vietnamese IME Fix for Claude Code CLI

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)

> Patch that fixes Vietnamese IME input in Claude Code CLI. Works with **Unikey**, **EVKey**, **OpenKey**, **GoTiengViet**.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vunguyen-ai/claudecode-typing-vi/main/install.sh | bash
```

**Restart Claude Code after patching** (`Ctrl+C`, then `claude`).

> **Windows users:** Run this in [Git Bash](https://git-scm.com/downloads) or [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install).

---

## Commands

| Command                  | Description                          |
|--------------------------|--------------------------------------|
| `claude-vipatch`         | Apply patch                          |
| `claude-vipatch status`  | Check patch status                   |
| `claude-vipatch restore` | Restore original (remove patch)      |
| `claude-update`          | Update Claude Code + auto re-patch   |

> After every Claude Code update, re-run `claude-vipatch` or use `claude-update`.

---

## The Problem

Vietnamese IMEs use a **backspace-then-replace** technique to transform characters (e.g. `a` → `á`). Claude Code's original handler applies all backspaces upfront, then fails to insert replacement characters — causing lost text.

| Before patch              | After patch               |
|---------------------------|---------------------------|
| Type "cộng hòa xã hội"   | Type "cộng hòa xã hội"   |
| → "ộng hòa ã hội" ❌      | → "cộng hòa xã hội" ✓    |

## The Fix

Replaces the entire DEL handling block in Claude Code's `cli.js` with a **stack-based algorithm**:

```javascript
let _ns = state, _sk = [];

for (const c of input) {
  if (c === "\x7f") {
    if (_sk.length > 0) _sk.pop();    // DEL consumes pending char
    else _ns = _ns.backspace();        // DEL affects existing state
  } else {
    _sk.push(c);                       // Normal char: push to stack
  }
}

for (const c of _sk) _ns = _ns.insert(c);  // Insert survivors
```

- Single-pass processing (no double handling)
- Sequential — DEL only affects the character immediately before it
- Stable under fast typing

---

## Troubleshooting

| Error                                | Solution                                                                                                              |
|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Vietnamese input still broken        | Restart Claude Code: `Ctrl+C`, then `claude`                                                                          |
| `claude-vipatch: command not found`  | Restart terminal or `source ~/.zshrc` / `source ~/.bashrc`                                                            |
| "Could not find Claude Code cli.js"  | Install via npm: `npm install -g @anthropic-ai/claude-code`                                                           |
| "Could not extract variables"        | Incompatible Claude Code version. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues) with `claude --version` |
| "Could not find DEL handling block"  | Claude Code structure changed. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues)               |
| "Patch already applied"              | Already patched. Check: `claude-vipatch status`                                                                       |

---

## Requirements

| Requirement    | Details                                              |
|----------------|------------------------------------------------------|
| **Python**     | 3.6+                                                 |
| **Bash**       | macOS/Linux (built-in), Windows ([Git Bash](https://git-scm.com/downloads) or [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)) |
| **Claude Code**| Installed via npm: `npm install -g @anthropic-ai/claude-code` |

---

## Uninstall

```bash
~/.claude/scripts/vipatch-uninstall.sh
```

Restores original `cli.js`, removes all scripts, cleans shell aliases, then self-deletes.

---

## Project Structure

```
claudecode-typing-vi/
├── install.sh                           # Installer
├── LICENSE
├── README.md
└── scripts/
    ├── vipatch.sh                       # Entry point
    ├── vipatch_core.py                  # Core patching logic
    ├── vipatch_block_handler.py         # Block replacement module
    ├── vipatch-update.sh                # Update Claude Code + re-patch
    └── vipatch-uninstall.sh             # Uninstaller (self-deleting)
```

---

## Credits

Original idea:
- [manhit96/claude-code-vietnamese-fix](https://github.com/manhit96/claude-code-vietnamese-fix)
- https://github.com/hangocduong/sua-loi-nhap-lieu-tieng-viet-claude-code-cli

## License

MIT — see [LICENSE](LICENSE).
