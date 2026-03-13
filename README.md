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
| `claude-update`          | Re-apply patch after updates         |

> After Claude Code auto-updates, re-run `claude-vipatch` or use `claude-update`.

---

## The Problem

Vietnamese IMEs use a **backspace-then-replace** technique to transform characters (e.g. `a` → `á`). Claude Code's original handler applies all backspaces upfront, then fails to insert replacement characters — causing lost text.

| Before patch              | After patch               |
|---------------------------|---------------------------|
| Type "cộng hòa xã hội"   | Type "cộng hòa xã hội"   |
| → "ộng hòa ã hội" ❌      | → "cộng hòa xã hội" ✓    |

## The Fix

Replaces the entire DEL handling block inside Claude Code's binary with a **stack-based algorithm**:

```javascript
let n = state, k = [];

for (const c of input) {
  if (c === "\x7f") {
    if (k.length > 0) k.pop();     // DEL consumes pending char
    else n = n.backspace();          // DEL affects existing state
  } else {
    k.push(c);                       // Normal char: push to stack
  }
}

for (const c of k) n = n.insert(c);  // Insert survivors
```

- Single-pass processing (no double handling)
- Sequential — DEL only affects the character immediately before it
- Stable under fast typing

---

## How It Works

Claude Code ships as a **native binary** with JavaScript embedded inside. This tool:

1. Finds the Claude Code binary (`~/.local/bin/claude`)
2. Locates the DEL handling block in the embedded JavaScript
3. Replaces it with the stack-based algorithm (exact same byte count)
4. On macOS: strips and re-applies code signature (ad-hoc)

See [`docs/how-vietnamese-ime-fix-works.md`](docs/how-vietnamese-ime-fix-works.md) for technical details.

---

## Troubleshooting

| Error                                | Solution                                                                                                              |
|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Vietnamese input still broken        | Restart Claude Code: `Ctrl+C`, then `claude`                                                                          |
| `claude-vipatch: command not found`  | Restart terminal or `source ~/.zshrc` / `source ~/.bashrc`                                                            |
| "Could not find Claude Code binary"  | Install Claude Code: https://docs.anthropic.com/en/docs/claude-code/overview                                          |
| "Could not find DEL handling block"  | Claude Code version may be incompatible. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues) with `claude --version` |
| "Replacement patch too large"        | Variable names changed significantly. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues)        |
| "Patch already applied"              | Already patched. Check: `claude-vipatch status`                                                                       |

---

## Requirements

| Requirement    | Details                                              |
|----------------|------------------------------------------------------|
| **Python**     | 3.6+                                                 |
| **Bash**       | macOS/Linux (built-in), Windows ([Git Bash](https://git-scm.com/downloads) or [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)) |
| **Claude Code**| Native install (https://docs.anthropic.com/en/docs/claude-code/overview) |

---

## Uninstall

```bash
~/.claude/scripts/vipatch-uninstall.sh
```

Restores original binary, removes all scripts, cleans shell aliases, then self-deletes.

---

## Project Structure

```
claudecode-typing-vi/
├── install.sh                           # Installer
├── LICENSE
├── README.md
└── scripts/
    ├── vipatch.sh                       # Entry point
    ├── vipatch_core.py                  # Core binary patching logic
    ├── vipatch_block_handler.py         # Block detection & replacement
    ├── vipatch-update.sh                # Re-apply patch after updates
    └── vipatch-uninstall.sh             # Uninstaller (self-deleting)
```

---

## Credits

Original idea (npm version only — patched `cli.js` text file):
- [manhit96/claude-code-vietnamese-fix](https://github.com/manhit96/claude-code-vietnamese-fix)
- https://github.com/hangocduong/sua-loi-nhap-lieu-tieng-viet-claude-code-cli

This project (v2.0+) extends the approach to **native binary patching** — replacing the DEL handler directly inside the compiled executable.

## License

MIT — see [LICENSE](LICENSE).
