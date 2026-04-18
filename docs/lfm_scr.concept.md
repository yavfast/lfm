# Screen Primitives  {#C_SCR}

> **Code:** C_SCR
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** none
> **Used by:** [C_TRM](./lfm_terminal.concept.md), [C_VIW](./lfm_view.concept.md), [C_LFM](./lfm.concept.md)
> **Specification:** [SP_SCR](./lfm_scr.sp.md)
> **Plan:** [lfm_scr.plan.md](./lfm_scr.plan.md)
>
> ANSI escape-sequence primitives: cursor movement, SGR color, alternate screen buffer. Every raw `\27[...` in the codebase lives here.

## 1. Philosophy  {#C_SCR_01}

### 1.1. Core Principle  {#C_SCR_01_01}

Centralize all terminal-rendering primitives so higher layers never need to know VT100 escape codes. Makes it feasible in the future to swap in `ncurses`/`tput` without touching the draw code.

### 1.2. Design Constraints  {#C_SCR_01_02}

- No I/O buffering control — caller handles `io.flush`.
- No state tracking — helpers are stateless wrappers around `io.write`.
- Named color tables (not numeric codes) exposed to callers; unknown names silently reset rather than error.

## 2. Domain Model  {#C_SCR_02}

### 2.1. Key Entities  {#C_SCR_02_01}

- **Color name** — key into the fg/bg table, mapping to an SGR code string.
- **Cursor position** — 1-indexed `(row, col)` used by `move_cursor`.
- **Alt-screen buffer** — toggled by enter/exit fullscreen.

### 2.2. Data Flows  {#C_SCR_02_02}

Caller → `draw_text_colored(color, text)` → emits `\27[<code>m<text>` via `io.write`.

## 3. Mechanisms  {#C_SCR_03}

### 3.1. Core Algorithm  {#C_SCR_03_01}

Each helper is a pure transform from arguments to ANSI bytes. No conditionals beyond color-table lookup with `0` (reset) fallback.

### 3.2. Edge Cases  {#C_SCR_03_02}

- Unknown color names fall through to SGR `0` — reset. Spotting misspellings requires reading output, not stack traces.
- Zero-length strings: `draw_text("")` is a no-op but still flushes pending escape state into the stream.

## 4. Integration Points  {#C_SCR_04}

### 4.1. Dependencies  {#C_SCR_04_01}

None.

### 4.2. API Surface  {#C_SCR_04_02}

- Screen: `enter_fullscreen`, `exit_fullscreen`, `clear_screen`, `move_cursor`.
- Text: `draw_text`, `draw_text_xy`, `draw_text_colored`, `draw_text_with_bg`.
- Colors: `set_color`, `set_bg_color`, `reset_colors`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
