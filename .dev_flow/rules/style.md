# Style Rules

## [style.ansi_via_lfm_scr] (must)

All ANSI escape sequences go through helpers in [lfm_scr.lua](../../lfm_scr.lua). Do not write raw `\27[...` in other modules.

**Why:** Centralizes escape-sequence handling; any future terminfo-based rendering change stays in one module.

**How to apply:** If you need an SGR code not yet exposed, add it to `lfm_scr` first.

**Example:** [lfm_view.lua](../../lfm_view.lua) uses `lfm_scr.move_cursor`, `draw_text_colored`, `clear_screen` — never writes raw escapes.

## [style.flush_at_frame_end] (should)

`io.write` is unbuffered line-wise; call `io.flush()` once at the end of a rendered frame, not between draws.

**Why:** Flushing mid-frame causes visible tearing and cursor flicker.

**How to apply:** The frame's final call (e.g., after the last `draw_text_colored` in `view_file`'s render loop) should be followed by `io.flush()`. Do not add `flush` calls inside helpers.

**Example:** [lfm_view.lua:77](../../lfm_view.lua#L77) — `io.flush()` after all hints are drawn.

## [style.unicode_via_lfm_str] (should)

For column alignment, width budgeting, and truncation, use `lfm_str.get_string_width` / `lfm_str.pad_string`. Do not use `#s` (byte length) for display width.

**Why:** `#s` counts UTF-8 bytes, not display cells — CJK or emoji filenames would misalign.

**How to apply:** When formatting rows (panel listings, footers), compute column widths using `lfm_str` helpers.

**Example:** [lfm.lua:221-225](../../lfm.lua#L221-L225) uses `lfm_str.pad_string` for name/size/date columns.

**Known debt:** [lfm_terminal.lua:40-42](../../lfm_terminal.lua#L40-L42) and [lfm_view.lua:62-64](../../lfm_view.lua#L62-L64) still use `#line` — acceptable today (terminal output / source code is mostly ASCII), but new code should not follow this pattern.

## [style.indentation_4_spaces] (prefer)

Indent with 4 spaces. No tabs.

**Why:** Every existing file uses 4-space indents; mixing tabs breaks column alignment in the TUI viewer.
