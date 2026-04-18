# Implementation Plan: Quick Navigation  {#PL_NAV}

> **Code:** PL_NAV
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_NAV](./quick_nav.concept.md)
> **Specification:** [SP_NAV](./quick_nav.sp.md)
> **Depends on plans:** [PL_SYS](./lfm_sys.plan.md), [PL_LFM](./lfm.plan.md)

## Goal

Add Alt+letter first-char jump so in-list navigation doesn't require printable-character hotkeys. Delivered as part of the same commit that cleans up `*` and `=` panel bindings.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Key sequence | `\27<letter>` detected in `get_key` after `read_with_timeout` | Terminal-standard Alt encoding; no new infrastructure |
| Match scope | First character of `name` (case-insensitive), skipping `..` and dotfiles | Matches FAR ergonomics for the common use case |
| Repeat handling | Cursor starts scan at `selected_item + 1` with wrap | No buffer state, no timeout, stateless per keystroke |
| Main-loop gate | Force panel routing for `alt_*` keys | Alt keys never belong to the shell command line |

## Phases

- [x] Phase 1 — decoder extension in `lfm_sys.get_key`.
- [x] Phase 2 — `handle_alt_letter(panel, letter)` helper in `lfm.lua`.
- [x] Phase 3 — dispatch arm + main-loop override.
- [x] Phase 4 — live smoke test.
- [x] Phase 5 — docs + roadmap propagation.

## Backlog (future)

- Incremental multi-char search (R-NAV-01) — prefix buffer with short timeout.
- Alt+digit → quick bookmarks.
- Visual indicator when a jump occurred (brief flash).

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial delivery. |
