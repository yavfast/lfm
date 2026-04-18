# Implementation Plan: File Manager Entry Point  {#PL_LFM}

> **Code:** PL_LFM
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_LFM](./lfm.concept.md)
> **Specification:** [SP_LFM](./lfm.sp.md)
> **Depends on plans:** [PL_SYS](./lfm_sys.plan.md), [PL_FIL](./lfm_files.plan.md), [PL_SCR](./lfm_scr.plan.md), [PL_VIW](./lfm_view.plan.md), [PL_STR](./lfm_str.plan.md), [PL_TRM](./lfm_terminal.plan.md)
> **Used by plans:** —
>
> Fully implemented in [lfm.lua](../lfm.lua).

## Goal

Ship a runnable two-panel file manager with embedded shell terminal, viewer (F3), editor (F4), and refresh (Ctrl+R).

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Layout | Fixed panel split + 30% bottom terminal | MC-like UX, familiar |
| Redraw strategy | Full redraw per keystroke | Simple; acceptable performance at tty sizes |
| Editor integration | `os.execute("vi ...")` | No editor bindings to maintain |
| Terminal widget | Embedded via `lfm_terminal` | Preserves panel visibility; no process suspension |
| Panel state | Module-local globals | No inter-panel abstraction needed yet |
| Global cwd | Both panels start at `"."` | Sensible default; no config file |

## Progress

- [x] Phase 1 — Layout computation
- [x] Phase 2 — Panel rendering
- [x] Phase 3 — Header / footer / hints
- [x] Phase 4 — Sort order
- [x] Phase 5 — Directory navigation
- [x] Phase 6 — Input dispatch
- [x] Phase 7 — Viewer / editor integration
- [x] Phase 8 — Refresh
- [x] Phase 9 — Main loop

## Phases

### Phase 1 — Layout computation (`lfm.lua`) [DONE]

**Implements:** [SP_LFM_01_02](./lfm.sp.md#SP_LFM_01_02)

`display_file_manager` recomputes `screen_info` and `screen_layout` every frame.

### Phase 2 — Panel rendering [DONE]

**Implements:** [SP_LFM_01_01](./lfm.sp.md#SP_LFM_01_01)

`draw_panel_row` formats each row with icon (`/`, `*`, ` `, red space for unreadable), name, size, date via `lfm_str.pad_string`.

### Phase 3 — Header / footer / hints [DONE]

`draw_header`, `draw_footer`, `draw_hints` — title bar + RAM, path bars with active highlighted, `[idx/total]` position strips, hint line.

### Phase 4 — Sort order [DONE]

**Implements:** [SP_LFM_01_03](./lfm.sp.md#SP_LFM_01_03), [SP_LFM_02_01](./lfm.sp.md#SP_LFM_02_01)

Case-insensitive, `..` first, directories before files.

### Phase 5 — Directory navigation [DONE]

**Implements:** [SP_LFM_02_03](./lfm.sp.md#SP_LFM_02_03)

`open_dir` + `handle_enter_key`. Parent navigation restores previous-child highlight.

### Phase 6 — Input dispatch [DONE]

**Implements:** [SP_LFM_02_04](./lfm.sp.md#SP_LFM_02_04)

`handle_navigation_key`, cooperative dispatch with terminal widget (see [C_LFM_03_01](./lfm.concept.md#C_LFM_03_01)).

### Phase 7 — Viewer / editor integration [DONE]

F3 → `restore_terminal` → `lfm_view.view_file` → `init_terminal`. F4 → `restore_terminal` → `os.execute("vi ...")` → `init_terminal`.

### Phase 8 — Refresh [DONE]

Ctrl+R reloads both panels, restoring cursor by previously-selected name.

### Phase 9 — Main loop [DONE]

**Implements:** [SP_LFM_02_05](./lfm.sp.md#SP_LFM_02_05)

`main()` — init panels, enter raw mode, dispatch loop until `quit`, restore raw mode.

## Backlog

- [ ] Replace global panel state with an explicit `Panel` module.
- [ ] Per-panel persistent directory state (`~/.lfm_state`).
- [ ] Handle `SIGWINCH` for immediate resize redraw instead of next-key redraw.
- [ ] Bookmarks / jumps (`Ctrl+\` or similar).
- [ ] Basic file operations (copy, move, delete) behind additional hotkeys.
- [ ] Configurable keybindings via `~/.lfmrc` or similar.

## Completed (after onboard)

- [x] Wrap main in `xpcall` + unconditional `exit_fullscreen`/`restore_terminal` on error.
- [x] Fix refresh nil-deref — guard against empty/out-of-range selection.
- [x] Stale 20% comment corrected to 30%.
- [x] F4 edit invocation uses `shell_quote` on path before handing to `vi`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
| 2026-04-18 | Applied post-onboard fixes: xpcall wrap, refresh nil-guard, stale comment, vi path escape. |
