# Implementation Plan: Embedded Shell Terminal  {#PL_TRM}

> **Code:** PL_TRM
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_TRM](./lfm_terminal.concept.md)
> **Specification:** [SP_TRM](./lfm_terminal.sp.md)
> **Depends on plans:** [PL_SCR](./lfm_scr.plan.md)
> **Used by plans:** [PL_LFM](./lfm.plan.md)
>
> Fully implemented in [lfm_terminal.lua](../lfm_terminal.lua).

## Goal

Provide an embedded command-line widget that can be drawn in the bottom band of the file manager, with a keystroke API compatible with the global dispatch loop.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Command execution | `io.popen(cmd .. " 2>&1")` | Captures both streams; no PTY complexity |
| Tty mode around exec | Toggle to cooked, then back to raw | Subprocesses see a sane tty (colors, line editing) |
| Cursor rendering | Inverted gray/black glyph | Avoids `\27[?25h` flashes inside widget |
| Horizontal overflow markers | `←` / `→` | Single-cell glyphs; no extra width budget |

## Progress

- [x] Phase 1 — State model
- [x] Phase 2 — Rendering (`draw_terminal`)
- [x] Phase 3 — Input handling
- [x] Phase 4 — Command execution
- [x] Phase 5 — Scrolling integration

## Phases

### Phase 1 — State model (`lfm_terminal.lua`) [DONE]

**Implements:** [SP_TRM_01_01](./lfm_terminal.sp.md#SP_TRM_01_01)

Single module-local `terminal_state` record.

### Phase 2 — Rendering [DONE]

**Implements:** [SP_TRM_02_01](./lfm_terminal.sp.md#SP_TRM_02_01)

Draw output window + input line with cursor. Horizontal scroll on overflow.

### Phase 3 — Input handling [DONE]

**Implements:** [SP_TRM_02_02](./lfm_terminal.sp.md#SP_TRM_02_02), [SP_TRM_02_05](./lfm_terminal.sp.md#SP_TRM_02_05)

Cursor movement, history navigation, printable insert, backspace, scroll passthrough.

### Phase 4 — Command execution [DONE]

**Implements:** [SP_TRM_04_02](./lfm_terminal.sp.md#SP_TRM_04_02)

`enter` → mode switch → `io.popen` → append to output → mode switch back.

### Phase 5 — Scrolling integration [DONE]

**Implements:** [SP_TRM_02_03](./lfm_terminal.sp.md#SP_TRM_02_03), [SP_TRM_02_06](./lfm_terminal.sp.md#SP_TRM_02_06)

`scroll_output`, `get_output_lines_count`, `get_max_scroll_offset`.

## Backlog

- [ ] Persist history across sessions (`~/.lfm_history`).
- [ ] Support word-wise motion (`Ctrl+Left` / `Ctrl+Right`).
- [ ] Truncate `output` above a size cap to avoid unbounded memory growth.
- [ ] Stream long-running command output incrementally instead of slurping everything.
- [ ] Command-line horizontal scroll still uses byte-length (`#command_display`) — replace with width-accurate computation.
- [ ] Signal handling — Ctrl+C during a long command is ignored (program receives it).

## Completed (after onboard)

- [x] Output-window rendering uses `lfm_str.pad_string` — no more byte-based truncation of command output lines.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
