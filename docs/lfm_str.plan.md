# Implementation Plan: String Width & Padding  {#PL_STR}

> **Code:** PL_STR
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_STR](./lfm_str.concept.md)
> **Specification:** [SP_STR](./lfm_str.sp.md)
> **Depends on plans:** none
> **Used by plans:** [PL_LFM](./lfm.plan.md)
>
> Fully implemented in [lfm_str.lua](../lfm_str.lua).

## Goal

Provide accurate width and padding for UTF-8 strings so panel columns align regardless of locale.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Width algorithm | Inline East Asian Width ranges | No external data tables, no dependencies |
| Truncation marker | `"~"` | Single-byte, visually distinct |
| 4-byte sequences | Unconditional width 2 | Simpler than per-emoji classification; good enough for filenames |

## Progress

- [x] Phase 1 — `get_string_width`
- [x] Phase 2 — `pad_string`

## Phases

### Phase 1 — `get_string_width` (`lfm_str.lua`) [DONE]

**Implements:** [SP_STR_02_01](./lfm_str.sp.md#SP_STR_02_01)

Byte-walk with inline EAW range checks.

### Phase 2 — `pad_string` [DONE]

**Implements:** [SP_STR_02_02](./lfm_str.sp.md#SP_STR_02_02)

Space-pad or truncate + `"~"`.

## Backlog

- [ ] Truncation loop counts characters, not cells — fix to be width-accurate for strings of wide characters.
- [ ] Add `truncate_string(str, width)` as a standalone helper (currently baked into pad).
- [ ] Handle combining marks (Unicode mark category) as width 0.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
