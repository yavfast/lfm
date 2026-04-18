# Implementation Plan: System Primitives  {#PL_SYS}

> **Code:** PL_SYS
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_SYS](./lfm_sys.concept.md)
> **Specification:** [SP_SYS](./lfm_sys.sp.md)
> **Depends on plans:** none
> **Used by plans:** [PL_FIL](./lfm_files.plan.md), [PL_VIW](./lfm_view.plan.md), [PL_LFM](./lfm.plan.md)
>
> The `lfm_sys` module is fully implemented in [lfm_sys.lua](../lfm_sys.lua).

## Goal

Provide a single entry point for all shell-out, terminal geometry, and raw-input decoding needed by the rest of the program.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shell-out mechanism | `io.popen` | Stdlib; no binding required |
| Locale | `LANG=C` prefix | Deterministic parsing of `stat`, `free`, `stty` |
| Raw input | `stty raw -echo` via `os.execute` | Portable Unix; no FFI |
| ESC disambiguation | `stty -icanon min 0 time 1` toggle | Short (~100ms) non-blocking read window |
| Fallback strategy | Typed defaults (24×80, "N/A") | Never crash UI loop |

## Progress

- [x] Phase 1 — Shell execution wrapper
- [x] Phase 2 — Terminal geometry & RAM info
- [x] Phase 3 — Tty mode management
- [x] Phase 4 — Key decoding
- [x] Phase 5 — `shell_quote` helper

## Phases

### Phase 1 — Shell execution wrapper (`lfm_sys.lua`) [DONE]

**Implements:** [SP_SYS_02_01](./lfm_sys.sp.md#SP_SYS_02_01)

Exposes `exec_command_output(command)` that prepends `LANG=C` and returns captured stdout.

### Phase 2 — Terminal geometry & RAM info [DONE]

**Implements:** [SP_SYS_02_02](./lfm_sys.sp.md#SP_SYS_02_02), [SP_SYS_02_03](./lfm_sys.sp.md#SP_SYS_02_03), [SP_SYS_02_04](./lfm_sys.sp.md#SP_SYS_02_04)

- `get_terminal_size` parses `stty size`.
- `format_size` promotes through KMGT units.
- `get_ram_info` parses `free` `Mem:` line, formats with `format_size`.

### Phase 3 — Tty mode management [DONE]

**Implements:** [SP_SYS_02_05](./lfm_sys.sp.md#SP_SYS_02_05), [SP_SYS_04_01](./lfm_sys.sp.md#SP_SYS_04_01)

`init_terminal` / `restore_terminal`.

### Phase 4 — Key decoding [DONE]

**Implements:** [SP_SYS_02_06](./lfm_sys.sp.md#SP_SYS_02_06)

`get_key` plus internal `read_with_timeout`. Escape-sequence decision tree covers arrows, paging, home/end, Ctrl-modified arrows, F3, F4, F10.

### Phase 5 — `shell_quote` helper [DONE]

**Implements:** [SP_SYS_02_00](./lfm_sys.sp.md#SP_SYS_02_00)

POSIX single-quote wrapping with `'\''` escape for any embedded single quotes. Used by every `io.popen` / `os.execute` call site in `lfm_files` and `lfm.lua`.

## Backlog

- [ ] Wrap the main loop in `pcall` + unconditional `restore_terminal` so a crash does not leave raw mode active.
- [ ] Recognize additional terminal variants (`\27[1~` Home, `\27[4~` End) for broader terminal support.
- [ ] Add F1/F2/F5-F9/F11-F12 decoding.
- [ ] Consider `luaposix` (opt-in) to replace the `stty -icanon` toggle with a proper `termios` poll.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
| 2026-04-18 | Added Phase 5 for `shell_quote`. |
