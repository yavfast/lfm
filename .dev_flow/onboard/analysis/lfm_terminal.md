# Analysis: lfm_terminal

**Layer:** 1 | **File:** [lfm_terminal.lua](../../../lfm_terminal.lua) | **Depends on:** lfm_scr

## Purpose

Embedded command-line widget rendered in the bottom band of the UI. Accepts keystrokes, executes commands via `io.popen`, renders command history and scrollable output.

## Internal state (module-local, single instance)

```
terminal_state = {
  command        : string,   -- current input line
  output         : string,   -- accumulated multi-command output
  cursor_pos     : integer,  -- 1-indexed within command
  history        : string[], -- past commands
  history_pos    : integer,  -- cursor into history; #history+1 = "blank line"
  view_offset    : integer,  -- rows scrolled up from bottom of output
  content_height : integer,  -- set each frame from draw_terminal height-1
}
```

## Public contracts

| Function | Purpose |
|----------|---------|
| `draw_terminal(start_row, width, height)` | Render the widget in rows `start_row..start_row+height-1` spanning `width` columns. Last row is the input line. Sets `content_height = height - 1`. |
| `handle_input(char)` | Process one symbolic key or printable byte; updates state, executes command on `enter`. |
| `scroll_output(direction)` | `"up"` / `"down"` / `"bottom"` — moves `view_offset` within `[0, max_offset]`. |
| `has_command()` | `command ~= ""` |
| `is_editing()` | Input has content or history is active |
| `handle_navigation_key(key)` | Attempt to consume cursor/scroll keys; returns `true` if consumed. Also handles pageup/pagedown for scrolling output. |
| `get_output_lines_count()` | Number of lines in `output`. |
| `get_max_scroll_offset()` | `max(0, total_lines - content_height)` |

## Command execution

On `enter`:
1. Append to history; reset `history_pos` to `#history + 1`.
2. `stty -raw echo` (exit raw mode so the command sees a normal tty).
3. `io.popen(command .. " 2>&1")`; read full output.
4. Append `"\n$ <command>\n<result>"` to `output`; clear `command`, reset cursor.
5. `scroll_output("bottom")`.
6. `stty raw -echo` (back to raw).

## Rendering rules

- Output region: `content_height = height - 1` rows, each truncated to `width` bytes with `...` if longer.
- Input line: `$ ` prompt then the command, with a 1-character cursor drawn via inverted gray/black background.
- If command exceeds visible width (`width - 2`): horizontal scroll; left scroll marker `←`, right marker `→`.
- Always clears unused columns with spaces — no residue from previous frame.

## Invariants

- `content_height` is set by `draw_terminal` **before** any call to `get_max_scroll_offset`. Callers outside the draw path must call `draw_terminal` at least once, or scroll math uses stale values.
- Truncation uses byte length (`#line`), not Unicode width — acceptable because terminal output is typically ASCII.

## Error handling

- `io.popen` failing silently drops the command (no output appended).
- Unknown symbolic keys are ignored.
