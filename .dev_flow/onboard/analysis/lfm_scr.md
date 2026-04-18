# Analysis: lfm_scr

**Layer:** 0 | **File:** [lfm_scr.lua](../../../lfm_scr.lua) | **Depends on:** none

## Purpose

ANSI escape sequence primitives: cursor movement, foreground/background color, alternate screen buffer.

## Public contracts

| Function | Emits / effect |
|----------|---------------|
| `enter_fullscreen()` | `\27[?1049h` + `\27[?25l` (alt buffer on, cursor hide) |
| `exit_fullscreen()` | `\27[?25h` + `\27[?1049l` (cursor show, alt buffer off) |
| `clear_screen()` | `\27[2J\27[H` |
| `move_cursor(row, col)` | `\27[<row>;<col>H` — 1-indexed |
| `set_color(name)` | SGR fg; unknown name → reset (`0`) |
| `set_bg_color(name)` | SGR bg; unknown name → reset |
| `reset_colors()` | SGR 0 |
| `draw_text(text)` | raw `io.write` |
| `draw_text_xy(row, col, text)` | `move_cursor` + `draw_text` |
| `draw_text_colored(color, text)` | `set_color` + `draw_text` |
| `draw_text_with_bg(fg, bg, text)` | set fg + set bg + write + reset |

## Color tables

- Foreground: `reset, black, red, green, blue, yellow, white, gray, silver, bright_red, bright_green, bright_yellow, bright_blue, bright_white`.
- Background: `black, red, green, yellow, blue, white, gray`.

## Invariants

- Every write is un-buffered (`io.write`) — callers must `io.flush()` at frame end.
- Cursor coordinates are 1-indexed (terminal convention).
- Only `draw_text_with_bg` resets colors after drawing; `draw_text_colored` does not — color leaks into following writes unless caller resets.
