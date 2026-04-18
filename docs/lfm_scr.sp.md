# Screen Primitives — Specification  {#SP_SCR}

> **Code:** SP_SCR
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_SCR](./lfm_scr.concept.md)
> **Depends on specs:** none
> **Used by specs:** [SP_TRM](./lfm_terminal.sp.md), [SP_VIW](./lfm_view.sp.md), [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_scr.plan.md](./lfm_scr.plan.md)
>
> Contracts for ANSI-based rendering helpers.

## 01. Data Structures  {#SP_SCR_01}

### 01_01. ColorName  {#SP_SCR_01_01}

Fixed string vocabulary accepted by `set_color` / `set_bg_color` / `draw_text_colored` / `draw_text_with_bg`.

Foreground names: `reset, black, red, green, blue, yellow, white, gray, silver, bright_red, bright_green, bright_yellow, bright_blue, bright_white`.

Background names: `black, red, green, yellow, blue, white, gray`.

Invariants:
- Unknown names resolve to SGR `0` (reset). Do not rely on this for intentional reset — use `reset_colors`.

## 02. Contracts  {#SP_SCR_02}

### 02_01. enter_fullscreen / exit_fullscreen  {#SP_SCR_02_01}

| | enter_fullscreen | exit_fullscreen |
|-|------------------|-----------------|
| Emits | `\27[?1049h` + `\27[?25l` | `\27[?25h` + `\27[?1049l` |
| Effect | Alt-buffer on, cursor hidden | Cursor shown, alt-buffer off |
| Flushes | yes | yes |

### 02_02. clear_screen  {#SP_SCR_02_02}

Emits `\27[2J\27[H`. Clears visible area and homes cursor.

### 02_03. move_cursor(row, col)  {#SP_SCR_02_03}

Input: row ≥ 1, col ≥ 1 (integers). Emits `\27[<row>;<col>H`. No bounds check.

### 02_04. set_color / set_bg_color / reset_colors  {#SP_SCR_02_04}

- `set_color(name)` → SGR fg. Unknown name → reset (`0`).
- `set_bg_color(name)` → SGR bg. Unknown name → reset (`0`).
- `reset_colors()` → `\27[0m`.

### 02_05. draw_text / draw_text_xy / draw_text_colored / draw_text_with_bg  {#SP_SCR_02_05}

| Function | Effect |
|----------|--------|
| `draw_text(text)` | raw `io.write(text)` |
| `draw_text_xy(r, c, text)` | `move_cursor(r, c)` + `draw_text(text)` |
| `draw_text_colored(color, text)` | `set_color(color)` + `draw_text(text)` — does NOT reset |
| `draw_text_with_bg(fg, bg, text)` | `set_color(fg)` + `set_bg_color(bg)` + `draw_text(text)` + `reset_colors()` |

## 03. Validation Rules  {#SP_SCR_03}

### 03_01. Input Validation  {#SP_SCR_03_01}

- `move_cursor` expects positive integers; zero or negative causes malformed escape but does not raise.
- Color tables are the only source of truth — add names there before using them.

## 04. State Transitions  {#SP_SCR_04}

### 04_01. Alt-screen Buffer  {#SP_SCR_04_01}

    [primary] --enter_fullscreen()--> [alternate]
    [alternate] --exit_fullscreen()--> [primary]

| From | To | Side effects |
|------|----|-------------|
| primary | alternate | hide cursor, switch buffer |
| alternate | primary | show cursor, switch buffer |

## 05. Verification Criteria  {#SP_SCR_05}

### 05_01. Functional Expectations  {#SP_SCR_05_01}

| Contract | Scenario | Input | Expected outcome |
|----------|----------|-------|------------------|
| move_cursor | (5, 10) | — | emits `\27[5;10H` |
| set_color | `"red"` | — | emits `\27[31m` |
| set_color | unknown | `"magenta"` | emits `\27[0m` |
| draw_text_with_bg | fg+bg+text | — | emits fg + bg + text + reset |

### 05_02. Invariant Checks  {#SP_SCR_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| No raw `\27[` outside `lfm_scr` | `grep -n "\\\\27\\["` returns only `lfm_scr.lua` |
| Enter/exit pairing | Every `enter_fullscreen` in callers has a corresponding `exit_fullscreen` |

### 05_03. Integration Scenarios  {#SP_SCR_05_03}

| Scenario | Preconditions | Steps | Expected result |
|----------|--------------|-------|-----------------|
| Viewer enter/exit | `lfm_view.view_file` called | enter_fullscreen → render → user quits → exit_fullscreen | Main screen intact after viewer exits |

### 05_04. Edge Cases and Boundaries  {#SP_SCR_05_04}

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Zero-length text | `""` | No visible effect |
| Nested colors | `set_color("red")` then `set_color("blue")` | Second color wins, no reset needed |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
