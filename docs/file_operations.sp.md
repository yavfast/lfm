# Specification: File Operations  {#SP_OPS}

> **Code:** SP_OPS
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_OPS](./file_operations.concept.md)
> **Plan:** [PL_OPS](./file_operations.plan.md)
> **Depends on specifications:** [SP_PLT](./platform_constraints.sp.md), [SP_SYS](./lfm_sys.sp.md), [SP_FIL](./lfm_files.sp.md), [SP_SCR](./lfm_scr.sp.md), [SP_STR](./lfm_str.sp.md), [SP_LFM](./lfm.sp.md)

## 1. Data Structures  {#SP_OPS_01}

### 1.1. Panel.selected  {#SP_OPS_01_01}

New field on the `Panel` record (see [SP_LFM_01](./lfm.sp.md)):

| Field | Type | Semantics |
|-------|------|-----------|
| `selected` | `table<string, true>` | Set keyed by item `name`. `[name] = true` means selected. Absent key = not selected. |

**Invariants:**

- `selected[".."]` MUST never be `true` (the entry is filtered at toggle and at op time).
- On `open_dir`, `selected` is reset to `{}`.
- After a completed batch op (`copy` / `move` / `remove`), `selected` is reset to `{}` in the acting panel.

### 1.2. OpResult  {#SP_OPS_01_02}

Returned by every `lfm_ops` function:

| Field | Type | Semantics |
|-------|------|-----------|
| `ok` | `boolean` | `true` when the shell command returned exit 0 (or stdout was empty on Lua 5.1 without exit-code plumbing). |
| `error_line` | `string?` | First non-empty line of captured stdout+stderr when `ok == false`; `nil` otherwise. |

### 1.3. PromptResult  {#SP_OPS_01_03}

Returned by `lfm_prompt.prompt_text`:

| Value | Meaning |
|-------|---------|
| `string` (possibly empty) | User pressed Enter. Caller decides whether empty = cancel. |
| `nil` | User pressed Escape (explicit cancel). |

Returned by `lfm_prompt.confirm`:

| Value | Meaning |
|-------|---------|
| `true` | User pressed `y` or `Y`. |
| `false` | User pressed any other key, including Enter, Escape, `n`, `N`. |

## 2. Module Contracts  {#SP_OPS_02}

### 2.1. `lfm_ops.copy(targets, dest) -> OpResult`  {#SP_OPS_02_01}

- **`targets`**: non-empty array of absolute or relative paths (strings).
- **`dest`**: string path — existing directory (batch copy) OR non-existent destination name (single-source copy and rename).
- **Shell form**: `cp -r -f -- <targets…> <dest>` with every argument shell-quoted.
- **Errors:** empty `targets` → `{ ok=false, error_line="no source" }` without forking. Non-existent source → shell returns stderr → propagated.

### 2.2. `lfm_ops.move(targets, dest) -> OpResult`  {#SP_OPS_02_02}

- Same signature and semantics as copy.
- **Shell form**: `mv -f -- <targets…> <dest>`.
- **Note on rename:** when `#targets == 1` and `dest` is a single basename with no directory prefix, `mv` effectively renames — no special handling in Lua.

### 2.3. `lfm_ops.remove(targets) -> OpResult`  {#SP_OPS_02_03}

- **`targets`**: non-empty array of path strings.
- **Shell form**: `rm -rf -- <targets…>`.
- **Safety invariant**: `..` MUST be filtered from the caller's target set BEFORE calling this function. `lfm_ops.remove` does not re-check for `..` — this is the caller's responsibility (enforced at dispatch in [lfm.lua handle_navigation_key](../lfm.lua)).

### 2.4. `lfm_ops.mkdir(path) -> OpResult`  {#SP_OPS_02_04}

- **`path`**: string — absolute or relative directory path.
- **Shell form**: `mkdir -p -- <path>`.
- Empty or whitespace-only `path` returns `{ ok=false, error_line="empty name" }` without forking.

### 2.5. `lfm_prompt.prompt_text(label, initial, layout) -> PromptResult`  {#SP_OPS_02_05}

- **`label`**: short prompt text (e.g., `"Copy to:"`) drawn on the hints row.
- **`initial`**: pre-filled editable content; cursor starts at end.
- **`layout`**: `{ row = <int>, cols = <int> }` describing where to draw (usually the hints row coordinates).
- **Keys handled**: printable → insert; `backspace` → delete-left; `left`/`right`/`home`/`end` → cursor motion; `enter` → commit (returns string); `escape` → cancel (returns `nil`).
- **Tty mode assumption**: terminal is already in raw mode (set by `lfm_sys.init_terminal`); the prompt does not toggle tty state.

### 2.6. `lfm_prompt.confirm(label, layout) -> boolean`  {#SP_OPS_02_06}

- **`label`**: displayed prompt, e.g. `"Delete 3 item(s)? [y/N]"`.
- **Keys handled**: `y` or `Y` → returns `true`; any other key → `false`.
- **Tty mode assumption**: same as prompt_text.

### 2.7. `lfm_prompt.show_error(message, layout)`  {#SP_OPS_02_07}

- **`message`**: short string, drawn in red on the hints row.
- **Key handled**: any key dismisses.
- **Use**: called after an `OpResult` with `ok=false` to surface `error_line` before returning to normal dispatch.

## 3. Key Dispatch Extensions  {#SP_OPS_03}

### 3.1. New `get_key` tokens  {#SP_OPS_03_01}

| Token | Escape sequence | When fired |
|-------|-----------------|------------|
| `"copy"` | `\27[15~` (F5) | Always |
| `"move"` | `\27[17~` (F6) | Always |
| `"mkdir"` | `\27[18~` (F7) | Always |
| `"delete_key"` | `\27[19~` (F8) OR `\27[3~` (Delete key) | Always |
| `"insert"` | `\27[2~` | Always |
| `"swap_panels"` | `\21` (Ctrl+U, ASCII 21) | Always |

**Collision note:** Ctrl+U at `\21` is NOT currently mapped elsewhere; `lfm_terminal.handle_input` receives unrecognized printables, so prior behavior was "insert `\21` into command line" — which is a non-functional NAK byte. Replacing that edge case with a panel-level "swap panels" is acceptable.

### 3.2. Printable-shortcut dispatch  {#SP_OPS_03_02}

`*` and `=` remain unchanged in `get_key` (return the character itself). In `handle_navigation_key`, new arms:

- `key == "*"` → invert_select (if panel non-empty). Returns `true` → caller does NOT pass to terminal.
- `key == "="` → sync_panels. Returns `true`.

These trigger ONLY when the terminal widget has no command text (existing dispatch chain rule in `lfm.lua`).

## 4. Selection Rendering  {#SP_OPS_04}

### 4.1. Color rule  {#SP_OPS_04_01}

In `draw_panel_row`:

| Selected? | Active + cursor? | Result |
|-----------|------------------|--------|
| no | no | existing color rules |
| no | yes | existing (gray background + normal color) |
| **yes** | no | **yellow foreground**, black background |
| **yes** | yes | **yellow foreground**, gray background |

No change to the leading prefix glyph (`/`, `*`, ` `, ` `).

### 4.2. Footer counter  {#SP_OPS_04_02}

`draw_footer` extends the panel's position marker from `[idx/total]` to `[idx/total,N]` when `N = #selected > 0`. When `N == 0`, unchanged.

## 5. Error Cases  {#SP_OPS_05}

| Scenario | Behavior |
|----------|----------|
| Selection + cursor both empty (directory empty except `..`) | Ops refuse silently (no prompt) |
| Copy/move with dest path unresolvable | Shell returns stderr → displayed via `show_error` |
| Mkdir with existing directory name | `mkdir -p` exits 0 → treated as success (idempotent) |
| Mkdir with existing **file** at that path | `mkdir -p` fails → stderr displayed |
| Delete of `..` explicitly targeted | Filtered at dispatch — `..` cannot be in `selected` per invariant |
| Prompt canceled with Esc | Op aborted, panels not refreshed, selection preserved |
| User types path that shell-quote cannot handle (e.g., binary bytes) | `shell_quote` handles any byte string; no unreachable failure |
| Shell command hangs (unlikely on local FS) | Blocks indefinitely — acceptable per [C_OPS_01_02](./file_operations.concept.md#C_OPS_01_02). No timeout. |

## 6. Integration Scenarios  {#SP_OPS_06}

### 6.1. Scenario: copy a file from panel1 to panel2  {#SP_OPS_06_01}

1. User cursor on `foo.txt` in panel1 (active). No multi-selection.
2. Presses F5.
3. Dispatch computes `targets = { absolute_path .. "/foo.txt" }`, `default_dest = panel2.absolute_path`.
4. `lfm_prompt.prompt_text("Copy to:", default_dest, layout)` → user presses Enter.
5. `lfm_ops.copy(targets, default_dest)` runs `cp -r -f -- '…/foo.txt' '…/panel2'`.
6. `OpResult.ok == true` → refresh both panels preserving cursor by name.

### 6.2. Scenario: delete 3 selected items  {#SP_OPS_06_02}

1. User Insert-toggles 3 items. Selection set has 3 entries.
2. Presses F8.
3. `lfm_prompt.confirm("Delete 3 item(s)? [y/N]", layout)` → user presses `y`.
4. `lfm_ops.remove(targets)` runs `rm -rf -- a b c`.
5. Success → clear panel.selected → refresh panels.

### 6.3. Scenario: rename a file  {#SP_OPS_06_03}

1. Cursor on `old.txt`, no selection.
2. F6 → prompt `"Move to:"` prefilled with `"<panel2-dir>/old.txt"` — user edits to `"new.txt"` (bare basename).
3. `lfm_ops.move({ ".../old.txt" }, "new.txt")` → `mv` interprets as rename in CWD.
4. Actually — **wait** — for the rename case the default pre-fill is the inactive panel's path; user has to erase more. Acceptable trade-off for simplicity. If ergonomics demand it, future enhancement: special-case F6 single-item to pre-fill with the filename only.

### 6.4. Scenario: cancel mid-prompt  {#SP_OPS_06_04}

1. F5 → prompt opens.
2. User presses Escape.
3. `prompt_text` returns `nil`.
4. Caller: no shell exec, no panel refresh, selection preserved.

## 7. Verification Criteria  {#SP_OPS_07}

### 7.1. Unit-testable (pure Lua)  {#SP_OPS_07_01}

- `lfm_ops` command-string construction — mock `io.popen` and assert the exact string built.
- `Panel.selected` invariants — toggle `..` must be a no-op; directory-change clears set.
- Prompt input handling — simulate a keystroke stream, assert returned string/value.

### 7.2. Live-verifiable via agent-tui  {#SP_OPS_07_02}

- Launch in `/tmp/lfm_test` sandbox, create files with `touch`/`mkdir`, drive through each flow.
- Verify: file created/deleted on disk after each op; selection cleared after batch ops; cursor landing restored when panel refreshes; Esc aborts without side effects.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft derived from [C_OPS](./file_operations.concept.md). |
