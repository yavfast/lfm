# Implementation Plan: Screen Primitives  {#PL_SCR}

> **Code:** PL_SCR
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_SCR](./lfm_scr.concept.md)
> **Specification:** [SP_SCR](./lfm_scr.sp.md)
> **Depends on plans:** none
> **Used by plans:** [PL_TRM](./lfm_terminal.plan.md), [PL_VIW](./lfm_view.plan.md), [PL_LFM](./lfm.plan.md)
>
> Fully implemented in [lfm_scr.lua](../lfm_scr.lua).

## Goal

Provide ANSI-based cursor, color, and alt-screen primitives consumed by every other rendering module.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering mechanism | Raw ANSI escapes via `io.write` | No terminfo dependency; works on any VT100-compatible terminal |
| Color vocabulary | Named table (not numeric SGR) | Readable call sites |
| Unknown-name behavior | Silently reset | No runtime errors in rendering hot path |

## Progress

- [x] Phase 1 — Screen control (alt-buffer, clear, cursor)
- [x] Phase 2 — Color tables and SGR helpers
- [x] Phase 3 — Composite draw helpers

## Phases

### Phase 1 — Screen control (`lfm_scr.lua`) [DONE]

**Implements:** [SP_SCR_02_01](./lfm_scr.sp.md#SP_SCR_02_01), [SP_SCR_02_02](./lfm_scr.sp.md#SP_SCR_02_02), [SP_SCR_02_03](./lfm_scr.sp.md#SP_SCR_02_03)

`enter_fullscreen`, `exit_fullscreen`, `clear_screen`, `move_cursor`.

### Phase 2 — Color tables and SGR helpers [DONE]

**Implements:** [SP_SCR_02_04](./lfm_scr.sp.md#SP_SCR_02_04)

Foreground + background color tables, `set_color`, `set_bg_color`, `reset_colors`.

### Phase 3 — Composite draw helpers [DONE]

**Implements:** [SP_SCR_02_05](./lfm_scr.sp.md#SP_SCR_02_05)

`draw_text`, `draw_text_xy`, `draw_text_colored`, `draw_text_with_bg`.

## Backlog

- [ ] `draw_text_colored` does not reset afterwards; colors leak. Consider adding `draw_text_colored_reset` or making the reset the default.
- [ ] Add terminfo-based detection (via `tput colors`) to gracefully degrade on mono/16-color terminals.
- [ ] Expose `bright_black` and remaining bright backgrounds that are currently missing from the table.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
