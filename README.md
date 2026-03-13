# Vietnamese IME Fix for Claude Code CLI

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)

> Patch that fixes Vietnamese IME input in Claude Code CLI. Works with **Unikey**, **EVKey**, **OpenKey**, **GoTiengViet**.

---

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/vunguyen-ai/claudecode-typing-vi/main/install.sh | bash
```

### Windows (PowerShell as Admin)

```powershell
irm https://raw.githubusercontent.com/vunguyen-ai/claudecode-typing-vi/main/install.ps1 | iex
```

**Restart Claude Code after patching** (`Ctrl+C`, then `claude`).

---

## Commands

| Command                  | Description                          |
|--------------------------|--------------------------------------|
| `claude-vi-patch`        | Apply patch                          |
| `claude-vi-patch status` | Check patch status                   |
| `claude-vi-patch restore`| Restore original (remove patch)      |
| `claude-update`          | Update Claude Code + auto re-patch   |

> After every Claude Code update, re-run `claude-vi-patch` or use `claude-update`.

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
| `claude-vi-patch: command not found` | Restart terminal or `source ~/.zshrc` / `source ~/.bashrc`                                                            |
| "Could not find Claude Code cli.js"  | Install via npm: `npm install -g @anthropic-ai/claude-code`                                                           |
| "Could not extract variables"        | Incompatible Claude Code version. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues) with `claude --version` |
| "Could not find DEL handling block"  | Claude Code structure changed. [Open issue](https://github.com/vunguyen-ai/claudecode-typing-vi/issues)               |
| "Patch already applied"              | Already patched. Check: `claude-vi-patch status`                                                                      |

---

## Requirements

| Requirement    | Details                                              |
|----------------|------------------------------------------------------|
| **Python**     | 3.6+                                                 |
| **Claude Code**| Installed via npm: `npm install -g @anthropic-ai/claude-code` |
| **OS**         | Windows, macOS, or Linux                             |

---

## Project Structure

```
claudecode-typing-vi/
├── install.sh                           # Installer (macOS/Linux)
├── install.ps1                          # Installer (Windows)
├── LICENSE
├── README.md
└── scripts/
    ├── vi-patch.sh                      # Entry point (Bash)
    ├── vi-patch.ps1                     # Entry point (PowerShell)
    ├── vi_patch_core.py                 # Core patching logic
    ├── vi_patch_block_handler.py        # Block replacement module
    ├── vi-patch-update.sh               # Update + patch (Bash)
    └── vi-patch-update.ps1              # Update + patch (PowerShell)
```

---

## Uninstall

### macOS / Linux

```bash
# 1. Restore original cli.js
claude-vi-patch restore

# 2. Remove all scripts (all prefixed with vi-patch / vi_patch)
rm -f ~/.claude/scripts/vi-patch* ~/.claude/scripts/vi_patch*

# 3. Remove aliases from ~/.zshrc or ~/.bashrc — delete these lines:
#    # Vietnamese IME fix for Claude Code
#    alias claude-vi-patch="$HOME/.claude/scripts/vi-patch.sh"
#    alias claude-update="$HOME/.claude/scripts/vi-patch-update.sh"
```

### Windows (PowerShell)

```powershell
# 1. Restore original cli.js
claude-vi-patch restore

# 2. Remove all scripts (all prefixed with vi-patch / vi_patch)
Remove-Item "$env:USERPROFILE\.claude\scripts\vi-patch*" -Force
Remove-Item "$env:USERPROFILE\.claude\scripts\vi_patch*" -Force

# 3. Edit PowerShell profile — remove claude-vi-patch and claude-update functions
notepad $PROFILE.CurrentUserAllHosts
```

---

## Credits

Original idea: 
- [manhit96/claude-code-vietnamese-fix](https://github.com/manhit96/claude-code-vietnamese-fix)  
- https://github.com/hangocduong/sua-loi-nhap-lieu-tieng-viet-claude-code-cli  


## License

MIT — see [LICENSE](LICENSE).
