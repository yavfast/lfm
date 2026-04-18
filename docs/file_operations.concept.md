# File Operations — MC-style Copy / Move / Delete / Mkdir + Multi-select  {#C_OPS}

> **Code:** C_OPS
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Depends on:** [C_PLT](./platform_constraints.concept.md), [C_LFM](./lfm.concept.md), [C_SYS](./lfm_sys.concept.md), [C_FIL](./lfm_files.concept.md), [C_SCR](./lfm_scr.concept.md), [C_STR](./lfm_str.concept.md)
> **Used by:** —
> **Specification:** [SP_OPS](./file_operations.sp.md)
> **Plan:** [PL_OPS](./file_operations.plan.md)
>
> Area A from the feature roadmap: destructive file-system operations (copy, move, rename, delete, mkdir), multi-selection, and panel path sync/swap — the set of interactions that promotes LFM from a read-only browser to an MC-parity file manager.

## 1. Philosophy  {#C_OPS_01}

### 1.1. Core Principle  {#C_OPS_01_01}

Shell-out over re-implementation. On IoT hosts we trust BusyBox `cp -r -f`, `mv -f`, `rm -rf`, `mkdir -p` — they are bit-compatible with GNU coreutils for the flag subset we use, well-tested, and deliver atomic semantics we would not get from Lua-level traversal. A single `fork+exec` per batch is cheaper than a Lua loop with per-file `io.open` — aligned with the fork-budget discipline in [SP_PLT_04_02](./platform_constraints.sp.md#SP_PLT_04_02).

### 1.2. Design Constraints  {#C_OPS_01_02}

- **Blocking execution**, no progress bar. On IoT hosts typical operations finish in milliseconds; a spinner would steal complexity budget for zero visible benefit. Long operations (unlikely) manifest as a "Working…" status line.
- **One up-front confirmation or prompt** per operation — no per-file interactive loops (interactive `cp -i` / `rm -i` break raw-mode TUI). Overwrite is `-f`-forced once the user confirms intent; we do not attempt granular conflict resolution.
- **No undo.** Destructive ops are destructive. We add confirmation for `rm`; the rest is editable-target-path prompts that the user can cancel with Esc.
- **Fail-soft**: if the shell command returns a non-zero exit, display the first line of stderr in the status area, leave LFM state intact, refresh both panels.
- **Zero external deps**: `cp`, `mv`, `rm`, `mkdir` are BusyBox-core applets (see [SP_PLT_02_02](./platform_constraints.sp.md#SP_PLT_02_02)). No new runtime dependency.

### 1.3. Scope boundary  {#C_OPS_01_03}

**IN SCOPE:**

- **A1** — F5 copy, F6 move/rename, F7 mkdir, F8/Delete delete.
- **A2** — Insert toggles multi-select.
- **A3** — `Ctrl+U` swaps both panels' state. Copying the active panel's path to the inactive panel is exposed via the F9 "Options" menu (see [C_DSP](./display_options.concept.md)), not as a direct hotkey.

**OUT OF SCOPE** (future promotion from roadmap):

- `+` / `-` glob-mask selection (Roadmap P2).
- Per-file conflict resolution UI (overwrite/skip/all).
- Progress indicator for long copies (Roadmap P2 — R-PERF-04 covers the streaming primitive if ever needed).
- Undo / trash can.
- Symlink creation (`Ctrl+S`), hardlink, chmod / chown — out of scope for this slice.

## 2. Domain Model  {#C_OPS_02}

### 2.1. Key Entities  {#C_OPS_02_01}

- **Selection set** — `panel.selected = { [name]=true, … }`. New per-panel field. `..` can never be selected. Cleared on directory change and after any completed batch op.
- **Target set** — resolved at op time from: selection if non-empty, else the item under the cursor. `..` is filtered out even if somehow in the set.
- **Prompt widget** — a transient modal overlay on the hints row. Three flavors: text-input (returns entered string or nil on Esc), yes/no confirm (returns bool), message (blocks until any key).
- **Op result** — `{ ok = bool, error_line = string? }`. Single error line at most — we do not aggregate multi-file failures because the shell sees the batch as one exec.

### 2.2. Data Flows  {#C_OPS_02_02}

```
F5 (copy)
  targets = selection or [cursor_item]
  default = inactive_panel.absolute_path
  dest = prompt_text("Copy to:", default)              // nil => cancel
  if dest: result = lfm_ops.copy(targets, dest)        // cp -r -f -- …
           show_message_if_error(result)
           refresh_both_panels_preserving_cursor()

F6 (move/rename)
  same as F5 but: mv -f -- …

F7 (mkdir)
  name = prompt_text("New directory name:", "")
  if name: result = lfm_ops.mkdir(active_panel.dir .. "/" .. name)
           show_message_if_error(result)
           refresh_active_panel()

F8 / Delete
  targets = selection or [cursor_item]
  if confirm("Delete " .. #targets .. " item(s)? [y/N]"):
    result = lfm_ops.remove(targets)                   // rm -rf -- …
    show_message_if_error(result)
    refresh_both_panels()

Insert
  toggle selection of cursor item → cursor down

Ctrl+U
  swap panel1 and panel2 (paths, selections, cursor, scroll)
```

## 3. Mechanisms  {#C_OPS_03}

### 3.1. Core Algorithm — blocking shell dispatch  {#C_OPS_03_01}

Each op function in `lfm_ops.lua`:

1. Build shell command from quoted arguments (each via `lfm_sys.shell_quote`).
2. Append `2>&1` to capture stderr.
3. `io.popen(cmd, "r")` → read all output.
4. `handle:close()` returns exit status (Lua 5.2+) or `nil` (5.1 — fall back to parsing output emptiness as success signal).
5. Return `{ ok, error_line }` where `error_line` is the first non-empty line of output on failure.

Because `cp -r -f` / `mv -f` / `rm -rf` suppress interactive prompts, the shell call completes without stdin interaction.

### 3.2. Prompt widget  {#C_OPS_03_02}

Implemented as `lfm_prompt.lua` — a small synchronous helper that:

1. Draws over the **hints row** (bottom of screen) using `lfm_scr` primitives.
2. Runs its own read loop via `lfm_sys.get_key()`.
3. Handles: printable insertion, `backspace`, `left`/`right`/`home`/`end` cursor motion, `enter` (commit), `escape` (cancel).
4. Unicode-aware via `lfm_str.get_string_width` for visible width and cursor position.
5. Returns control to the main loop when the user commits or cancels.

No re-entrant draw of the full file manager during prompt — the overlay is additive. A single `display_file_manager()` call re-paints the full screen after the prompt completes.

### 3.3. Key decoding additions  {#C_OPS_03_03}

Extend `lfm_sys.get_key` to recognize:

| Input bytes | Token |
|-------------|-------|
| `\27[15~` | `copy` (F5) |
| `\27[17~` | `move` (F6) |
| `\27[18~` | `mkdir` (F7) |
| `\27[19~` | `delete_key` (F8) |
| `\27[2~` | `insert` |
| `\27[3~` | `delete_key` (aliased to F8) |
| `\21` (Ctrl+U) | `swap_panels` |
| `*` (printable) | `invert_select` — intercepted at dispatch, NOT in decoder |
| `=` (printable) | `sync_panels` — intercepted at dispatch, NOT in decoder |

`*` and `=` remain raw printables out of `get_key` — the dispatch layer in `lfm.lua` elevates them to panel shortcuts when the terminal widget input is empty.

### 3.4. Selection rendering  {#C_OPS_03_04}

Selected items draw with yellow foreground instead of the usual color. When selected + cursor + active panel simultaneously: cursor style wins (gray background), yellow foreground remains. When selected without cursor: yellow foreground, black background.

No new color enum in `lfm_scr` — `yellow` already exists.

### 3.5. Edge Cases  {#C_OPS_03_05}

- **Empty selection + cursor on `..`** — ops refuse (no-op, silent); nothing to act on.
- **Copy/move destination is the same as source** — `cp` / `mv` handle this (no-op or error "same file"); we report the stderr.
- **Rename via F6** — user edits the default path to a local basename (no `/`). Shell `mv` handles identically.
- **Mkdir with parent missing** — `mkdir -p` creates parents. Safe by default.
- **Delete root-ish paths** — confirm dialog protects against `rm -rf /`. No extra guard: if the user explicitly confirms deleting cursor-on-`..`, we still filter `..` out of targets.
- **Permission denied** — shell returns stderr, we display the first line. No privilege escalation attempted.
- **Path traversal attack via prompt** — paths pass through `shell_quote`, so nothing typed into the prompt can escape the argument boundary.

## 4. Integration Points  {#C_OPS_04}

### 4.1. Dependencies  {#C_OPS_04_01}

- **`lfm_sys`** — `shell_quote`, `exec_command_output`, `get_key`, `get_terminal_size`, init/restore tty.
- **`lfm_scr`** — cursor movement, colored text, clear line (for overlay).
- **`lfm_str`** — display-width for prompt input rendering.
- **`lfm_files`** — `check_permissions` for pre-op guards, `get_directory_items` for refresh.

### 4.2. New Modules  {#C_OPS_04_02}

- **`lfm_prompt.lua`** (Layer 1) — the modal input widget.
- **`lfm_ops.lua`** (Layer 1) — the shell-out op functions.

### 4.3. Modified Modules  {#C_OPS_04_03}

- **`lfm.lua`** — new key dispatch arms, `Panel` gains `selected`-set field, selection rendering in `draw_panel_row`.
- **`lfm_sys.lua`** — `get_key` extended with F5/F6/F7/F8/Insert/Delete/Ctrl+U.

## 5. Non-Goals  {#C_OPS_05}

- **Not a replacement for `cp` / `mv` error semantics** — LFM only reports them; we do not add our own recovery logic.
- **Not a concurrent-op scheduler** — exactly one op runs at a time, UI blocks until it completes.
- **Not a confirmation gauntlet** — only `rm` confirms. `cp` / `mv` use editable-target prompts; `mkdir` just asks for a name.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft — captures Area A from [PL_RMP](./roadmap.plan.md) at priority P0. |
| 2026-04-18 | Removed printable-character hotkeys `*` (invert selection) and `=` (sync paths). `*` dropped entirely; sync relocated to the F9 menu (see [C_DSP](./display_options.concept.md)). Rationale: printable keys conflict with terminal-widget command input. |
