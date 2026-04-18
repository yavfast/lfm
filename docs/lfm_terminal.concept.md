# Embedded Shell Terminal  {#C_TRM}

> **Code:** C_TRM
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** [C_SCR](./lfm_scr.concept.md)
> **Used by:** [C_LFM](./lfm.concept.md)
> **Specification:** [SP_TRM](./lfm_terminal.sp.md)
> **Plan:** [lfm_terminal.plan.md](./lfm_terminal.plan.md)
>
> Embedded command-line widget rendered in the bottom band of the UI. Accepts keystrokes, executes commands via `io.popen`, persists history, and renders scrollable output.

## 1. Philosophy  {#C_TRM_01}

### 1.1. Core Principle  {#C_TRM_01_01}

Users frequently need shell actions while navigating files. Building a tiny in-process terminal widget (instead of suspending and `exec`-ing a real shell) avoids screen flicker and keeps the file panels visible.

### 1.2. Design Constraints  {#C_TRM_01_02}

- Single-line input at the bottom of the widget, multi-line output above.
- Command execution briefly returns the tty to cooked mode so sub-processes see normal behavior.
- One global widget state — only one terminal widget exists.

## 2. Domain Model  {#C_TRM_02}

### 2.1. Key Entities  {#C_TRM_02_01}

- **TerminalState** — module-level record (command, cursor, history, output, scroll offset, content height).
- **History** — list of previously executed command strings; navigable with `Ctrl+Up` / `Ctrl+Down`.

### 2.2. Data Flows  {#C_TRM_02_02}

```
keystroke ──► handle_input
             │
             ├── printable     ──► insert at cursor
             ├── cursor keys   ──► move cursor / scroll
             ├── history keys  ──► replace command
             └── enter         ──► io.popen → append to output → scroll to bottom

redraw ──► draw_terminal(start_row, width, height)
         ├── output lines (with horizontal truncation + view_offset)
         └── command line with cursor and horizontal scroll
```

## 3. Mechanisms  {#C_TRM_03}

### 3.1. Core Algorithm  {#C_TRM_03_01}

Command execution:
1. On `enter`, push command to history, reset history_pos.
2. `stty -raw echo` so the subprocess sees normal cooked tty.
3. `io.popen(command .. " 2>&1")` and slurp output.
4. Append `\n$ <cmd>\n<result>` to state.output.
5. `stty raw -echo` to return to raw mode.
6. Scroll to bottom.

### 3.2. Edge Cases  {#C_TRM_03_02}

- `io.popen` failure: silently drops the command.
- Output longer than widget height: scrolling capped at `get_max_scroll_offset()`.
- Horizontal overflow in command line: marker `←`/`→` indicate off-screen content.

## 4. Integration Points  {#C_TRM_04}

### 4.1. Dependencies  {#C_TRM_04_01}

- [C_SCR](./lfm_scr.concept.md) — all rendering.

### 4.2. API Surface  {#C_TRM_04_02}

- Render: `draw_terminal(start_row, width, height)`.
- Input: `handle_input(char)`, `handle_navigation_key(key)`.
- Predicates: `has_command`, `is_editing`.
- Scrolling: `scroll_output`, `get_max_scroll_offset`, `get_output_lines_count`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
