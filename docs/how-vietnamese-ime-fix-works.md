# Vietnamese IME Fix for Claude Code — Technical Deep Dive

> How Vietnamese input methods break Claude Code, how the stack-based algorithm fixes it, and how the patch applies itself to minified JavaScript.

---

## 1. The Problem: Why Vietnamese Input Breaks

### How Vietnamese IMEs Work

Vietnamese Input Method Editors (Unikey, EVKey, OpenKey, GoTiengViet) use a **backspace-then-replace** technique to compose diacritics:

```
User types: a
User adds tone (press 's' for sắc):
  IME sends: BACKSPACE + á
Terminal sees: a → DEL → á
Result: a is replaced by á
```

The BACKSPACE is sent as **DEL character** (Unicode `0x7F` / `\x7f`) — not the keyboard's Backspace key, but an in-band control character embedded in the input stream.

This is fundamental to how Vietnamese typing works. Every tone mark, every vowel modification triggers this DEL-then-replace cycle. A single word like "tiếng" may involve multiple cycles as the IME refines each vowel.

### The Bug in Claude Code

Claude Code's terminal input handler in `cli.js` has a DEL processing block. Simplified:

```javascript
if (input.includes("\x7f")) {
  let count = (input.match(/\x7f/g) || []).length;
  let state = currentState;

  // Delete one character per DEL
  for (let i = 0; i < count; i++)
    state = state.backspace();

  // Update display
  if (currentState.text !== state.text) updateText(state.text);
  updateOffset(state.offset);

  return;  // <-- Early return! Remaining chars are LOST
}
```

**The root cause**: The code counts ALL DEL characters, applies ALL backspaces upfront, then **returns early** — discarding any non-DEL characters in the same input chunk.

### Why This Fails

Consider typing "cộ" (the IME sends `o` then `DEL` + `ộ`):

```
Input stream: "o\x7fộ"
State before: "c"

Original handler:
  1. Count DELs = 1
  2. Apply 1 backspace → state goes from "c" to ""
  3. Return early — 'o' and 'ộ' are never processed
  Result: "" (lost everything!)
```

The handler deletes from the **existing state** (the editor text), not from the **pending input**. The DEL was meant to remove the `o` that the IME just sent — not the `c` that was already in the editor.

**Visual impact**: Users type "cộng hòa xã hội" but see "ộng hòa ã hội" — characters vanish unpredictably.

---

## 2. The Fix: Stack-Based Algorithm

### Core Idea

Instead of counting DELs and batch-deleting, process each character **sequentially** using a stack to track pending input:

```javascript
let _ns = currentState, _sk = [];

for (const c of input) {
  if (c === "\x7f") {
    if (_sk.length > 0) _sk.pop();   // DEL cancels pending input char
    else _ns = _ns.backspace();       // DEL affects existing state
  } else {
    _sk.push(c);                      // Normal char: push to stack
  }
}

for (const c of _sk) _ns = _ns.insert(c);  // Insert survivors
```

### Why This Works

The stack creates a **separation of concerns**:
- `_sk` (stack) holds characters that haven't been committed yet
- `_ns` (new state) represents the committed editor state
- DEL first tries to cancel a pending character; only if the stack is empty does it touch the editor state

### Trace: Typing "cộ"

```
Input: "o\x7fộ"    State: "c"    Stack: []

Step 1: char = 'o'
  → Not DEL, push to stack
  Stack: ['o']    State: "c"

Step 2: char = DEL
  → Stack not empty, pop 'o'
  Stack: []       State: "c"

Step 3: char = 'ộ'
  → Not DEL, push to stack
  Stack: ['ộ']    State: "c"

Insert loop: insert 'ộ' into state
  State: "cộ" ✓
```

The DEL correctly removed the pending `o` (the character the IME wanted to replace), leaving the existing `c` untouched.

### Edge Cases

| Scenario | Input | Initial State | Stack Trace | Result |
|----------|-------|---------------|-------------|--------|
| Simple tone | `a\x7fá` | `""` | a→DEL(pop a)→á | `"á"` |
| Mid-word | `o\x7fộ` | `"c"` | o→DEL(pop o)→ộ | `"cộ"` |
| Multiple DELs | `abc\x7f\x7f\x7fx` | `""` | abc→DEL(pop c)→DEL(pop b)→DEL(pop a)→x | `"x"` |
| DEL with empty stack | `\x7fa` | `"x"` | DEL(backspace x)→a | `"a"` |
| DEL on empty everything | `\x7fa` | `""` | DEL(backspace noop)→a | `"a"` |
| Rapid IME corrections | `o\x7fộ\x7fõ` | `"c"` | o→DEL→ộ→DEL→õ | `"cõ"` |

All cases produce correct results. The algorithm is mathematically sound: it preserves the **positional relationship** between DEL and the character it targets.

---

## 3. The Patching Approach

### Challenge: Native Binary with Embedded JavaScript

Claude Code ships as a **native binary** (~239MB on Windows) with JavaScript embedded inside. This is likely a Node.js Single Executable Application (SEA) — a self-contained executable that bundles Node.js and the application code together.

The JavaScript is stored as raw ASCII/UTF-8 text within the binary. Variable names in the minified code change between versions:

| Version | input var | state var | current state | text fn | offset fn |
|---------|-----------|-----------|---------------|---------|-----------|
| v2.1.12 | `l`       | `CA`      | `S`           | `Q`     | `T`       |
| v2.1.75 | `s`       | `LH`      | `y`           | `A`     | `h`       |

The patch must **dynamically discover** these names at patch time.

### Step 1: Find the DEL Handler in the Binary

Search for the byte pattern `.includes("\x7F")` in the binary data. In the binary, the DEL escape `\x7F` is stored as 4 ASCII bytes: `5c 78 37 46`.

```python
# Search for includes pattern in binary bytes
markers = [
    b'.includes("\\x7F")',   # uppercase (common in native builds)
    b'.includes("\\x7f")',   # lowercase
    b'.includes("\x7f")',    # literal DEL byte (npm builds)
]
for marker in markers:
    pos = data.find(marker)
    if pos >= 0: break
```

### Step 2: Extract Variable Names

Extract a ~1500 byte context window around the match, decode as ASCII, and apply regex patterns:

```python
# 1. Input variable: X.includes(...)  →  input_var = "s"
# 2. Count/state from: let HH=(s.match(...)).length,LH=y
# 3. Update fns from: if(y.text!==LH.text)A(LH.text);h(LH.offset)
```

### Step 3: Find Block Boundaries

The code often has prefix conditions:

```javascript
if(!o.backspace&&!o.delete&&s.includes("\x7F")){...}
```

The block handler finds the `if(` start, captures the prefix condition, then counts braces to find the matching `}`:

```python
# Search backwards from includes() to find if(
pre = data[inc_pos - 100:inc_pos]
if_pos = pre.rfind(b'if(')

# Count braces to find block end
depth = 1
while depth > 0:
    if data[pos] == ord('{'): depth += 1
    elif data[pos] == ord('}'): depth -= 1
    pos += 1
```

### Step 4: Generate Replacement (Exact Byte Count)

**Critical constraint**: the replacement must be the **exact same byte count** as the original block. We can't add or remove bytes from a binary without corrupting it.

The replacement uses aggressively minified variable names (`n`, `k`, `c` instead of `_ns`, `_sk`, `_c`) and ternary operators to fit:

```javascript
// Original: 237 bytes (v2.1.75 example)
if(!o.backspace&&!o.delete&&s.includes("\x7F")){
  let HH=(s.match(/\x7f/g)||[]).length,LH=y;
  for(let NH=0;NH<HH;NH++)LH=LH.deleteTokenBefore()??LH.backspace();
  if(!y.equals(LH)){if(y.text!==LH.text)A(LH.text);h(LH.offset)}
  mUH(),pUH();return}

// Replacement: 209 bytes + 28 bytes padding = 237 bytes
if(!o.backspace&&!o.delete&&s.includes("\x7F")){
  let n=y,k=[];
  for(let c of s)c==="\x7F"?k.length?k.pop():n=n.backspace():k.push(c);
  for(let c of k)n=n.insert(c);
  y.equals(n)||(A(n.text),h(n.offset));
  mUH(),pUH();return}                           // padded with spaces
```

The patch is applied by byte-level replacement:

```python
patched = bytearray(data)
patched[start:end] = replacement_bytes  # exact same length
binary_path.write_bytes(bytes(patched))
```

### Code Signing (macOS)

On macOS, the binary is code-signed. Patching breaks the signature. The tool handles this:

```bash
codesign --remove-signature ./claude    # Strip before patching
# ... apply patch ...
codesign --force --deep -s - ./claude   # Ad-hoc re-sign after
```

Apple Silicon requires all binaries to be signed (even ad-hoc), so this step is mandatory on ARM64 Macs.

### Patch Detection

Check for distinctive byte markers unique to the patch:

```python
def is_patched(data: bytes) -> bool:
    return (b'let n=y,k=[]' in data
            and b'k.pop():n=n.backspace()' in data
            and b'n=n.insert(c)' in data)
```

---

## 4. Architecture

### File Roles

```
install.sh                    Installer (local or curl|bash)
scripts/
  vipatch.sh                  Entry point — finds claude binary, dispatches to Python
  vipatch_core.py             Orchestrator — binary read/write, backup, codesign
  vipatch_block_handler.py    Block operations — find boundaries, generate replacement bytes
  vipatch-update.sh           Re-apply patch after Claude Code auto-updates
  vipatch-uninstall.sh        Self-deleting uninstaller
```

### Data Flow

```
vipatch.sh
  │
  ├─ find_claude_binary()    Locate native binary via PATH or known install paths
  │
  └─ python3 vipatch_core.py <binary> <action>
       │
       ├─ patch:
       │    ├─ read binary as bytes
       │    ├─ is_patched() → already done? exit
       │    ├─ block_handler.find_del_block() → (start, end, vars_dict)
       │    ├─ block_handler.extract_suffix_calls() → post-handler functions
       │    ├─ backup binary file
       │    ├─ codesign --remove-signature (macOS)
       │    ├─ block_handler.create_replacement_with_suffix() → padded bytes
       │    ├─ byte-level replacement + write
       │    ├─ codesign --force -s - (macOS)
       │    └─ verify patch markers present
       │
       ├─ restore:
       │    └─ find latest .backup.* file → copy over binary
       │
       └─ status:
            └─ is_patched() → print PATCHED or NOT PATCHED
```

### Why Block Replacement (Option B)

Earlier versions (v1.6) used **Option A: insert after** — keeping the original buggy code and appending a second handler that redid the work correctly. This worked but had issues:

| Concern | Option A (insert after) | Option B (block replace) |
|---------|------------------------|--------------------------|
| Processing cycles | Two (original + patch) | One |
| UI updates | Two (may flicker) | One |
| State complexity | Two state machines | One |
| Reasoning difficulty | Must understand interaction | Self-contained |
| Risk of state desync | Possible | None |
| Invasiveness | Low (append only) | Higher (full replacement) |

Option B was adopted in v1.7 as the superior production approach.

---

## 5. What Could Be Improved

### Robustness

- **Backup cleanup**: Each patch creates a timestamped backup (~239MB). After many Claude Code updates, backups accumulate quickly. Could keep only the last N backups.
- **Post-patch verification**: After patching, the tool verifies byte markers but doesn't run `claude --version` to confirm the binary still works. A smoke test would catch corrupted patches.
- **Atomic write**: The tool writes to a temp file then renames (atomic on most filesystems), but fallback direct write on Windows could corrupt if interrupted.

### Code Signing

- **macOS Gatekeeper**: Ad-hoc re-signing works for execution, but the binary loses its original notarization. macOS may show "unidentified developer" warnings.
- **Windows SmartScreen**: Broken Authenticode signature could trigger SmartScreen warnings on first run after patching. In practice, this hasn't been observed as a blocker.
- **Auto-update re-signs**: When Claude Code auto-updates, it replaces the binary with a fresh signed copy — removing the patch. Users must re-apply after every update.

### Cross-Platform

- **Untested on macOS/Linux native binaries**: The binary patching approach was verified on Windows PE32+. macOS (Mach-O) and Linux (ELF) binaries should work identically since the embedded JavaScript is format-agnostic, but this needs testing.
- **Variable name stability**: If a Claude Code update changes the minified variable names significantly (making replacement longer than original), the patch would fail to fit. Aggressive minification of the replacement mitigates this.

### Testing

- **No automated tests**: The regex patterns and replacement logic could be tested against extracted JavaScript snippets. Even basic `pytest` coverage for `find_del_block()` and `create_replacement_with_suffix()` would catch regressions.
- **Version matrix**: No CI testing across Claude Code versions. A collection of DEL handler snippets from different versions could serve as a test corpus.

### Architecture

- **Regex fragility**: The variable extraction relies on specific minification patterns. A major change in Claude Code's bundler could break all patterns.
- **Byte-count constraint**: The replacement must be <= original size. If future versions have much shorter DEL blocks or the algorithm needs more code, this becomes a hard limit. Current headroom is ~28 bytes.
- **No auto-patch on update**: Claude Code auto-updates replace the binary, removing the patch. A filesystem watcher or scheduled task could re-apply automatically.

---

## 6. Key Takeaways

1. **Vietnamese IME sends DEL+replacement as a single input chunk** — any handler that processes DELs without considering their position relative to other characters in the same chunk will break.

2. **The stack algorithm is the correct abstraction** — it naturally models "DEL cancels the most recent pending character" which is exactly what IME backspace-then-replace semantics require.

3. **Native binaries can be patched** — Node.js SEA executables embed JavaScript as searchable text. Binary patching (exact byte-count replacement with padding) works without decompilation, though it breaks code signatures that must be re-applied.

4. **Patching minified JavaScript requires dynamic variable extraction** — hardcoded names break on every version update. Regex-based extraction from structural patterns (`.includes()`, `.match()`, `.backspace()`) is fragile but workable.

5. **Block replacement > append** — replacing the entire buggy block eliminates double-processing, state desync risks, and UI flicker. The tradeoff is more complex boundary detection, but the result is cleaner and more maintainable.
