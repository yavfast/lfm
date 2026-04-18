# Analysis: lfm_view

**Layer:** 2 | **File:** [lfm_view.lua](../../../lfm_view.lua) | **Depends on:** lfm_files, lfm_scr, lfm_sys

## Purpose

Read-only pager invoked on F3. Renders a file's contents in an alternate screen buffer with vertical and horizontal scrolling.

## Public contract

| Function | Inputs | Output |
|----------|--------|--------|
| `view_file(path, view_width, view_height)` | path to file, terminal dimensions | — (blocking until user quits with `q` or ESC) |

## Flow

1. `io.open(path, "r")` — return early if it fails.
2. `read("*a")`; split into lines via `gmatch("[^\r\n]*\r?\n?")`, stripping trailing CR/LF.
3. Take over terminal: `lfm_sys.init_terminal()` → `lfm_scr.enter_fullscreen()` → `clear_screen()`.
4. Draw header (path + `=` separator), footer (position `[start-end/total]` + hint bar).
5. Render loop:
   - Clear `max_lines = view_height - 4` rows (2 header, 2 footer).
   - For each visible line: horizontal-slice by `current_col`, truncate to `view_width - 3` + `...` if overflowing.
   - Read a key via `lfm_sys.get_key()`.
6. Handled keys: `up`, `down`, `pageup`, `pagedown`, `home`, `end`, `left`, `right` (±10 cols), `q`, `escape`.
7. On exit: `exit_fullscreen` → `restore_terminal`.

## Invariants

- `view_height >= 5` (else `max_lines <= 0` and nothing renders usefully).
- `current_line` clamped to `[1, max(1, #lines - max_lines + 1)]` on down/pagedown/end.
- `current_col` clamped to `>= 0` on left; unbounded on right (lines shorter than scroll appear blank).

## Error handling

- Unreadable file → silent return, caller never enters view mode.
- Binary / non-text content is rendered byte-for-byte, which may corrupt the terminal — no content-type check.
