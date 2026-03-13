# Technical Details

## Vietnamese IME Behavior

Vietnamese Input Method Editors (IMEs) like OpenKey, EVKey, Unikey use a technique called "backspace-then-replace" to transform characters:

1. User types `a`
2. User adds tone mark (e.g., press `s` for sắc)
3. IME sends: `BACKSPACE` + `á`
4. Result: `a` is deleted, `á` is inserted

The BACKSPACE is sent as DEL character (0x7F / `\x7f`).

## The Bug in Claude Code

Claude Code's input handler (`cli.js`) processes DEL characters but has a bug:

```javascript
// Simplified original code
if(input.includes("\x7f")){
  let count = (input.match(/\x7f/g)||[]).length;
  let state = currentState;

  // Process each DEL - delete one char
  for(let i=0; i<count; i++) state = state.backspace();

  // Update display
  if(!currentState.equals(state)){
    updateText(state.text);
    updateOffset(state.offset);
  }

  // BUG: Early return! Remaining chars in input are lost!
  return;
}
```

When input is `a<DEL>á`, the code:
1. Counts 1 DEL char
2. Deletes 1 char (the `a`)
3. Returns early - the `á` is never processed!

## The Fix

Insert code after backspace processing to re-insert remaining characters:

```javascript
if(input.includes("\x7f")){
  let count = (input.match(/\x7f/g)||[]).length;
  let state = currentState;

  for(let i=0; i<count; i++) state = state.backspace();

  if(!currentState.equals(state)){
    updateText(state.text);
    updateOffset(state.offset);
  }

  // === FIX START ===
  let cleanInput = input.replace(/\x7f/g, "");  // Remove DEL chars
  if(cleanInput.length > 0){
    for(const char of cleanInput) state = state.insert(char);
    if(!currentState.equals(state)){
      if(currentState.text !== state.text) updateText(state.text);
      updateOffset(state.offset);
    }
  }
  // === FIX END ===

  return;
}
```

## Dynamic Variable Extraction

Since `cli.js` is minified, variable names change between versions:

| Version | input | state | curState | textFn | offsetFn |
|---------|-------|-------|----------|--------|----------|
| 2.1.6   | n     | _A    | P        | varies | varies   |
| 2.1.12  | l     | CA    | S        | Q      | T        |

The script uses regex patterns to extract these dynamically:

### Step 1: Find DEL handling block

```python
pattern = f'includes\\("{DEL_CHAR}"\\)'
match = re.search(pattern, content)
```

### Step 2: Extract input variable

```python
# Pattern: input.includes("\x7f")
m = re.search(rf'(\w+)\.includes\("{DEL_CHAR}"\)', context)
input_var = m.group(1)  # "l"
```

### Step 3: Extract state variables

```python
# Pattern: let count=(input.match(...)).length,state=curState
m = re.search(
    rf'let (\$?\w+)=\({input_var}\.match\(/[^/]+/g\)\|\|\[\]\)\.length,(\w+)=(\w+)',
    context
)
count_var = m.group(1)   # "$A"
state_var = m.group(2)   # "CA"
cur_state = m.group(3)   # "S"
```

### Step 4: Extract update functions

```python
# Pattern: textFn(state.text) and offsetFn(state.offset)
text_m = re.search(rf'(\w+)\({state_var}\.text\)', context)
offset_m = re.search(rf'(\w+)\({state_var}\.offset\)', context)
text_fn = text_m.group(1)    # "Q"
offset_fn = offset_m.group(1) # "T"
```

### Step 5: Find insertion point

```python
# Pattern: offsetFn(state.offset)} - end of if block
pattern = rf'{offset_fn}\({state_var}\.offset\)\}}'
for m in re.finditer(pattern, content):
    if 'backspace()' in surrounding_context:
        insertion_point = m.end()
```

## Generated Patch Code

For v2.1.12:

```javascript
let _vn=l.replace(/\x7f/g,"");if(_vn.length>0){for(const _c of _vn)CA=CA.insert(_c);if(!S.equals(CA)){if(S.text!==CA.text)Q(CA.text);T(CA.offset)}}
```

Formatted:
```javascript
let _vn = l.replace(/\x7f/g, "");
if (_vn.length > 0) {
  for (const _c of _vn) CA = CA.insert(_c);
  if (!S.equals(CA)) {
    if (S.text !== CA.text) Q(CA.text);
    T(CA.offset);
  }
}
```

## Version Compatibility

The script handles variations:

1. **Literal vs Escaped DEL**: Some versions use literal `\x7f`, others use escaped
2. **Variable prefixes**: Some vars start with `$` (like `$A`)
3. **Method names**: `.backspace()` vs `.deleteBackward()`

## Backup Strategy

Before patching:
```python
backup = cli_js.with_suffix(f'.backup.{timestamp}')
shutil.copy(cli_js, backup)
```

Restore finds latest backup:
```python
backups = sorted(cli_js.parent.glob('cli.js.backup.*'), reverse=True)
shutil.copy(backups[0], cli_js)
```

## Testing the Patch

1. Check syntax is valid:
   ```bash
   claude --version  # Should show version without errors
   ```

2. Check patch is detected:
   ```bash
   claude-vipatch status  # Should show "PATCHED"
   ```

3. Test Vietnamese input:
   - Open Claude terminal
   - Type Vietnamese with tone marks
   - Verify characters display correctly
