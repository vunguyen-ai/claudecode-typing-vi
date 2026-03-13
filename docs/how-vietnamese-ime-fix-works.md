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

### Challenge: Minified JavaScript

Claude Code ships as a single minified `cli.js` (~5MB). Variable names change between versions:

| Version | input var | state var | current state | text fn | offset fn |
|---------|-----------|-----------|---------------|---------|-----------|
| v2.1.6  | `n`       | `_A`      | `P`           | varies  | varies    |
| v2.1.12 | `l`       | `CA`      | `S`           | `Q`     | `T`       |

The patch must **dynamically discover** these names at patch time.

### Step 1: Find the DEL Handler

Locate `input.includes("\x7f")` in the minified code:

```python
# Search for literal DEL char or escaped version
pattern = f'includes\\("{DEL_CHAR}"\\)'
match = re.search(pattern, content)
```

### Step 2: Extract Variable Names

From the surrounding context (~1300 chars around the match), extract variable names using regex:

```python
# 1. Input variable: the one calling .includes()
#    Pattern: l.includes("\x7f")  →  input_var = "l"
m = re.search(rf'(\w+)\.includes\("{DEL_CHAR}"\)', ctx)
input_var = m.group(1)

# 2. Count and state variables from the let declaration
#    Pattern: let $A=(l.match(/\x7f/g)||[]).length,CA=S
m = re.search(
    rf'let (\$?\w+)=\({input_var}\.match\(...\)\|\|\[\]\)\.length,(\w+)=(\w+)',
    ctx
)
count_var, state_var, cur_state = m.groups()  # "$A", "CA", "S"

# 3. Update functions from the conditional update block
#    Pattern: if(S.text!==CA.text)Q(CA.text)  →  text_fn = "Q"
#    Pattern: T(CA.offset)                     →  offset_fn = "T"
```

### Step 3: Find Block Boundaries

The patch uses **Option B: full block replacement** — replacing the entire buggy DEL handler with the stack algorithm.

The actual code often has prefix conditions:

```javascript
if(!QA.backspace&&!QA.delete&&l.includes("\x7f")){...}
```

The block handler captures these prefix conditions and preserves them:

```python
# Match: if(PREFIX&&input.includes(DEL)){
pattern = rf'if\(([^{{]*?)&&{input_var}\.includes\("{DEL_CHAR}"\)\){{'
match = re.search(pattern, content)
prefix_cond = match.group(1)  # "!QA.backspace&&!QA.delete"
```

Then count braces to find the matching `}`:

```python
pos = match.end()
brace_count = 1
while brace_count > 0:
    if content[pos] == '{': brace_count += 1
    elif content[pos] == '}': brace_count -= 1
    pos += 1
```

### Step 4: Generate and Apply Patch

Build the replacement code using discovered variable names and preserved prefix conditions:

```python
# With vars: input="l", cur_state="S", text_fn="Q", offset_fn="T"
# With prefix: "!QA.backspace&&!QA.delete"

# Generated (minified):
# if(!QA.backspace&&!QA.delete&&l.includes("\x7f"))
# {let _ns=S,_sk=[];
#  for(const _c of l){if(_c==="\x7f"){if(_sk.length>0)_sk.pop();else _ns=_ns.backspace()}else _sk.push(_c)}
#  for(const _c of _sk)_ns=_ns.insert(_c);
#  if(!S.equals(_ns)){if(S.text!==_ns.text)Q(_ns.text);T(_ns.offset)}return}
```

The patch is applied by string splicing:

```python
new_content = content[:start_pos] + patch_code + content[end_pos:]
cli_js.write_text(new_content, 'utf-8')
```

### Patch Detection

To check if already patched, look for the distinctive variable names:

```python
def is_patched(content):
    return '_ns=' in content and '_sk=' in content
```

---

## 4. Architecture

### File Roles

```
install.sh                    Installer (local or curl|bash)
scripts/
  vipatch.sh                  Entry point — finds cli.js, dispatches to Python
  vipatch_core.py             Orchestrator — extract vars, backup, patch/restore/status
  vipatch_block_handler.py    Block operations — find boundaries, generate replacement
  vipatch-update.sh           npm update + auto re-patch
  vipatch-uninstall.sh        Self-deleting uninstaller
```

### Data Flow

```
vipatch.sh
  │
  ├─ find_cli_js()          Locate cli.js via `which claude` or known paths
  │
  └─ python3 vipatch_core.py <cli.js> <action>
       │
       ├─ patch:
       │    ├─ read cli.js content
       │    ├─ is_patched() → already done? exit
       │    ├─ extract_variables() → {input, state, cur_state, text_fn, offset_fn}
       │    ├─ block_handler.find_del_block() → (start, end, prefix_condition)
       │    ├─ backup original file
       │    ├─ block_handler.create_replacement_patch() → patched code string
       │    └─ splice and write
       │
       ├─ restore:
       │    └─ find latest .backup.* file → copy over cli.js
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

- **Atomic file write**: Currently `write_text()` directly — if interrupted mid-write, `cli.js` corrupts. Should write to temp file then `rename()` (atomic on most filesystems).
- **Stronger patch detection**: `_ns=` and `_sk=` are short strings that could theoretically appear elsewhere in minified code. A more distinctive pattern like `_ns=` + `_sk=[]` + `_sk.pop()` would reduce false positives.
- **Backup cleanup**: Each patch creates a timestamped backup. After many Claude Code updates, backups accumulate. Could keep only the last N backups.

### Cross-Platform

- **Windows npm paths**: The fallback path list in `vipatch.sh` doesn't include `$APPDATA/npm/node_modules/...` for Git Bash users.
- **macOS `readlink -f`**: BSD `readlink` doesn't support `-f`. Current code has a Python fallback, but could be more explicit.

### Testing

- **No automated tests**: The regex patterns and algorithm could be tested against mock cli.js snippets. Even basic `pytest` coverage for `extract_variables()` and `find_del_block()` would catch regressions when updating patterns for new Claude Code versions.
- **Version matrix**: No CI testing against multiple Claude Code versions. A collection of anonymized cli.js snippets (just the DEL handler region) could serve as a test corpus.

### Architecture

- **Regex fragility**: The variable extraction relies on specific minification patterns. A major change in Claude Code's bundler (e.g., switching from one minifier to another) could break all patterns. A more resilient approach might use AST parsing of the relevant code region, though this adds significant complexity.
- **No rollback verification**: After patching, the tool doesn't verify that `claude --version` still works. A post-patch syntax check (even `node -c cli.js`) would catch malformed patches before the user discovers a broken CLI.
- **Single-file module**: `vipatch_core.py` and `vipatch_block_handler.py` could potentially be merged into one file since they're always used together, simplifying deployment.

### User Experience

- **Mixed language output**: The installer shows Vietnamese banners but the README is English. Consistent language (or a language detection/flag) would improve clarity.
- **Silent failure on install**: If patching fails during `install.sh`, the `|| true` guard prevents abort but the error could be more prominent.
- **No auto-patch on Claude update**: Users must manually re-run `claude-vipatch` after every `npm update`. A post-install hook or watcher could automate this, though npm doesn't natively support post-global-install hooks.

---

## 6. Key Takeaways

1. **Vietnamese IME sends DEL+replacement as a single input chunk** — any handler that processes DELs without considering their position relative to other characters in the same chunk will break.

2. **The stack algorithm is the correct abstraction** — it naturally models "DEL cancels the most recent pending character" which is exactly what IME backspace-then-replace semantics require.

3. **Patching minified JavaScript requires dynamic variable extraction** — hardcoded names break on every version update. Regex-based extraction from structural patterns (`.includes()`, `.match()`, `.backspace()`) is fragile but workable.

4. **Block replacement > append** — replacing the entire buggy block eliminates double-processing, state desync risks, and UI flicker. The tradeoff is more complex boundary detection, but the result is cleaner and more maintainable.
