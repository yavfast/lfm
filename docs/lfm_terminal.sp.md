# Embedded Shell Terminal — Specification  {#SP_TRM}

> **Code:** SP_TRM
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_TRM](./lfm_terminal.concept.md)
> **Depends on specs:** [SP_SCR](./lfm_scr.sp.md)
> **Used by specs:** [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_terminal.plan.md](./lfm_terminal.plan.md)

## 01. Data Structures  {#SP_TRM_01}

### 01_01. TerminalState  {#SP_TRM_01_01}

Single module-local table.

Fields:
| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| command | string | `""` | — | Current input line |
| output | string | `""` | may contain `\n` | Accumulated output |
| cursor_pos | integer | 1 | `1 ≤ cursor_pos ≤ #command + 1` | 1-indexed cursor into command |
| history | string[] | `{}` | — | Completed commands |
| history_pos | integer | 0 | `1 ≤ history_pos ≤ #history + 1` when navigating | `#history + 1` = "after end" |
| view_offset | integer | 0 | `0 ≤ view_offset ≤ max_offset` | Lines scrolled above bottom |
| content_height | integer | 0 | set by `draw_terminal` | Visible output rows |

Invariants:
- `cursor_pos` ≤ `#command + 1`.
- `view_offset` ≤ `get_max_scroll_offset()`.

## 02. Contracts  {#SP_TRM_02}

### 02_01. draw_terminal(start_row, width, height)  {#SP_TRM_02_01}

Input:
| Parameter | Type | Constraints |
|-----------|------|-------------|
| start_row | integer ≥ 1 | Top row of widget |
| width | integer ≥ 3 | Widget width (must fit `"$ "` + ≥ 1 char) |
| height | integer ≥ 2 | Widget height (≥ 1 output line + input line) |

Output: —. Side effects: writes ANSI via `lfm_scr`; sets `content_height = height - 1`.

Layout:
- Rows `start_row .. start_row + height - 2`: output lines, truncated to `width` bytes, scroll-windowed by `view_offset`.
- Row `start_row + height - 1`: `"$ "` + command (with horizontal scroll + cursor).

### 02_02. handle_input(char)  {#SP_TRM_02_02}

Input: a symbolic key name (see [SP_SYS_01_01](./lfm_sys.sp.md#SP_SYS_01_01)) or a printable byte.

Transitions:
| Key | Effect |
|-----|--------|
| `enter` | Push to history; execute via `io.popen`; append output; clear command |
| `ctrl_up` | Previous history entry replaces command |
| `ctrl_down` | Next history entry, or blank when past end |
| `ctrl_shift_up` / `ctrl_shift_down` | scroll output |
| `left` / `right` | move cursor within command |
| `home` / `end` | cursor to start/end of command |
| `pageup` / `pagedown` | scroll output |
| `\127` / `\b` | backspace (delete left of cursor) |
| printable (single byte ≥ `" "`) | insert at cursor |

### 02_03. scroll_output(direction)  {#SP_TRM_02_03}

Direction ∈ `"up"`, `"down"`, `"bottom"`. Adjusts `view_offset` within `[0, max_offset]`.

### 02_04. has_command / is_editing  {#SP_TRM_02_04}

| Function | Returns |
|----------|---------|
| `has_command()` | `state.command ~= ""` |
| `is_editing()` | `state.command ~= "" or state.history_pos > 0` |

### 02_05. handle_navigation_key(key)  {#SP_TRM_02_05}

Tries to consume cursor/scroll keys (`left`, `right`, `home`, `end`, `pageup`, `pagedown`).

Returns: boolean — `true` if consumed.

Special gate: returns `false` immediately if `not is_editing() and view_offset == 0 and output == ""`. Lets `lfm.lua` fall back to panel navigation when the terminal widget is idle.

### 02_06. get_output_lines_count / get_max_scroll_offset  {#SP_TRM_02_06}

- `get_output_lines_count()` — count of `\n`-separated segments in `output`; 0 if empty.
- `get_max_scroll_offset()` — `max(0, total_lines - content_height)`.

## 03. Validation Rules  {#SP_TRM_03}

### 03_01. Input Validation  {#SP_TRM_03_01}

- `draw_terminal` must be called at least once before `get_max_scroll_offset` (otherwise `content_height == 0`).
- `content_height` is authoritative — only `draw_terminal` writes it.

## 04. State Transitions  {#SP_TRM_04}

### 04_01. History Navigation  {#SP_TRM_04_01}

    [idle: history_pos = #history + 1]
       │ ctrl_up
       ▼
    [browsing: history_pos in [1..#history]]
       │ ctrl_down past end
       ▼
    [idle, blank command]

### 04_02. Command Execution  {#SP_TRM_04_02}

    [editing] --enter--> [executing: raw mode off, io.popen]
                 │
                 ▼
              [idle: command cleared, output appended, scrolled to bottom, raw mode on]

## 05. Verification Criteria  {#SP_TRM_05}

### 05_01. Functional Expectations  {#SP_TRM_05_01}

| Contract | Scenario | Input | Expected |
|----------|----------|-------|----------|
| handle_input | printable insert | `"a"` when command empty | command = `"a"`, cursor = 2 |
| handle_input | backspace | `"\127"` with cursor > 1 | deletes char left of cursor |
| handle_input | enter empty | `"enter"` with command `""` | no-op |
| handle_input | enter with command | `"enter"` with `"ls"` | history grows, output grows, command cleared |
| scroll_output | past top | `"up"` with offset = max | offset unchanged |
| scroll_output | past bottom | `"down"` with offset = 0 | offset unchanged |

### 05_02. Invariant Checks  {#SP_TRM_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Raw-mode restored post-execute | After `handle_input("enter")`, `stty -a` shows `raw` again |
| view_offset clamped | Fuzz scroll_output calls; offset stays in range |

### 05_03. Integration Scenarios  {#SP_TRM_05_03}

| Scenario | Preconditions | Steps | Expected |
|----------|---------------|-------|----------|
| Shared arrow-key dispatch | UI idle, terminal idle | Press `left` | Panel navigation wins (handle_navigation_key returns false) |
| Shared arrow-key dispatch | Command typed | Press `left` | Terminal cursor moves left |

### 05_04. Edge Cases  {#SP_TRM_05_04}

| Case | Input | Expected |
|------|-------|----------|
| Long command | > width-2 chars | Horizontal scroll with `←`/`→` markers |
| Empty history | `"ctrl_up"` with no history | no-op |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
