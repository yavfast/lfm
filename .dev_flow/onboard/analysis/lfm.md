# Analysis: lfm (entry point)

**Layer:** 3 | **File:** [lfm.lua](../../../lfm.lua) | **Depends on:** lfm_sys, lfm_files, lfm_scr, lfm_view, lfm_str, lfm_terminal

## Purpose

Program entry point. Owns global UI state (two panels + embedded terminal), runs the redraw/input loop, and routes key events to panel, viewer, editor, or terminal.

## Screen layout

Vertical bands from top:

```
row 1            : header (title + RAM info)
row 2            : path bar (two panels, active highlighted)
rows 3..M        : panel rows (two side-by-side file lists)
row M            : status / position footer ([idx/total]= padding)
rows M+1..T      : embedded terminal band (height = 30% of total, min 5)
rows T+1..T+2    : hints (F3/F4/Ctrl+R/Tab/F10)
```

Screen widths: `usable = total - 3` (three vertical separators `|`), split evenly between panels.

## Module-level state

- `screen_layout` — computed per-frame from current terminal size.
- `panel_info` — template copied into `panel1` and `panel2` at startup.
- `screen_info` — full terminal width/height.
- `active_panel` — `1` or `2`.

Each panel record: `{ current_dir, absolute_path, selected_item, scroll_offset, items, view_width, view_height }`.

## Flow

1. `main()` — clears screen, loads panel1+panel2 at `"."`, sorts items, enters raw mode, loops:
   - `display_file_manager()` — recomputes layout, redraws header/panels/footer/terminal/hints.
   - `lfm_sys.get_key()` — block for next key.
   - Dispatch:
     - `quit` → break.
     - If terminal has command text OR `handle_navigation_key` does not consume → try `lfm_terminal.handle_navigation_key` → else `lfm_terminal.handle_input`.
2. On exit → `lfm_sys.restore_terminal()`.

## Sort order

Panel items sorted by:
1. `".."` first, always.
2. Directories before files.
3. Case-insensitive name.

## Navigation key handling (`handle_navigation_key`)

- `up` / `down` — move selection.
- `pageup` / `pagedown` / `home` / `end` — jump selection.
- `tab` — flip active panel.
- `enter` — if selected is a readable directory, `open_dir(...)`. Parent-navigation (`..`) preserves previous child-directory position.
- `view` (F3) — restore tty, call `lfm_view.view_file` on a readable file, re-enter raw mode.
- `edit` (F4) — restore tty, `os.execute("vi " .. path)`, re-enter raw mode.
- `refresh` (Ctrl+R) — reload both panels, restoring position by previously-selected name.

## Invariants

- At least one item always present per panel (at minimum the synthetic `..`, except at `/`).
- Raw mode is restored around any external program (vi, viewer) — panic safety is **not** guaranteed (no `pcall`).
- Panel widths/heights are recomputed every frame — windows can be resized live.

## Error handling

- Selecting an unreadable directory silently does nothing.
- Editing an unwritable file silently does nothing.
- No pcall around the main loop — any unhandled error leaves the terminal in raw mode.
