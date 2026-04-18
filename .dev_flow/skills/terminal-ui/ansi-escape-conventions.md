# ANSI escape conventions (as used in lfm_scr)

| Purpose | Escape | Helper |
|---------|--------|--------|
| Enter alt-screen buffer | `\27[?1049h` | `enter_fullscreen` |
| Exit alt-screen buffer | `\27[?1049l` | `exit_fullscreen` |
| Hide cursor | `\27[?25l` | bundled with `enter_fullscreen` |
| Show cursor | `\27[?25h` | bundled with `exit_fullscreen` |
| Clear screen + home | `\27[2J\27[H` | `clear_screen` |
| Move cursor | `\27[<row>;<col>H` | `move_cursor` (1-indexed) |
| Set fg color | `\27[<30-37\|90-97>m` | `set_color` |
| Set bg color | `\27[<40-47\|100-107>m` | `set_bg_color` |
| Reset SGR | `\27[0m` | `reset_colors` |

**Gotchas:**
- Alt-screen buffer enter/exit **must** be paired — otherwise the user's shell loses its scrollback.
- `set_color` with a name not in the table resets (not an error) — pre-validate unknown names.
- SGR state persists across writes; always `reset_colors()` or explicitly set fg+bg before each colored segment if you need isolation.
- `\27[?25l` (cursor hide) survives alt-buffer exit on some terminals — show explicitly.

**Reference:** xterm control sequences — <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>
