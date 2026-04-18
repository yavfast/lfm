# Implementation Plan: File Viewer  {#PL_VIW}

> **Code:** PL_VIW
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_VIW](./lfm_view.concept.md)
> **Specification:** [SP_VIW](./lfm_view.sp.md)
> **Depends on plans:** [PL_FIL](./lfm_files.plan.md), [PL_SCR](./lfm_scr.plan.md), [PL_SYS](./lfm_sys.plan.md)
> **Used by plans:** [PL_LFM](./lfm.plan.md)
>
> Fully implemented in [lfm_view.lua](../lfm_view.lua).

## Goal

Provide a blocking F3-pager for text files that preserves the main UI via the alternate screen buffer.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| File I/O | `io.open` + `read("*a")` | Simplest path; fine for source files |
| Line splitting | `gmatch("[^\r\n]*\r?\n?")` | Handles CRLF and LF |
| Screen takeover | `enter_fullscreen` / `exit_fullscreen` | Preserves main screen state |
| Horizontal scroll step | 10 columns | Matches common pager defaults |

## Progress

- [x] Phase 1 — Load file
- [x] Phase 2 — Render loop + keybindings

## Phases

### Phase 1 — Load file (`lfm_view.lua`) [DONE]

**Implements:** first half of [SP_VIW_02_01](./lfm_view.sp.md#SP_VIW_02_01)

Open, read, split lines, enter fullscreen.

### Phase 2 — Render loop and keybindings [DONE]

**Implements:** second half of [SP_VIW_02_01](./lfm_view.sp.md#SP_VIW_02_01)

Clamped viewport updates for every key; redraw on each iteration.

## Backlog

- [ ] Stream-read for files larger than available RAM.
- [ ] Add `/` search.
- [ ] Highlight line numbers or file mime type in header.
- [ ] Content-type sniff — refuse to render binary files.

## Completed (after onboard)

- [x] Replaced byte-based `#line` truncation with `lfm_str.pad_string`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
