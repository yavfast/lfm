# Implementation Plan: Display Options  {#PL_DSP}

> **Code:** PL_DSP
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_DSP](./display_options.concept.md)
> **Specification:** [SP_DSP](./display_options.sp.md)
> **Depends on plans:** [PL_LFM](./lfm.plan.md), [PL_OPS](./file_operations.plan.md) (reuses `lfm_prompt`), [PL_SYS](./lfm_sys.plan.md)

## Goal

Ship the Area C MVP: per-panel sort modes and hidden-files toggle, reached through a single, extensible F9 menu.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UX entry point | Single F9 menu, two-level | Portable across terminals, extensible, discoverable |
| Menu impl | New `lfm_prompt.menu` primitive | Reusable for future menus |
| Sort impl | Closure built in `lfm.lua` | No new module warranted; comparator is ~15 LOC |
| Hidden filter | Post-fetch Lua filter on the items list | `get_directory_items` stays unchanged; one boolean, zero shell forks for sort |
| Per-panel state | Three fields on existing `Panel` record | Aligns with `selected` field added in PL_OPS |
| Persistence | None this slice | Separate roadmap item (R-NAV-03) |
| F9 key decode | Add `\27[20~` → `"options"` to `lfm_sys.get_key` | Standard VT sequence |
| Ext parsing | `name:match("%.([^.]+)$")` | Handles `.hidden` (no ext), `a.tar.gz` (ext = "gz"), `README` (no ext) |
| Arrow glyphs | UTF-8 `↑` / `↓` | All modern terminals render these; not a functional hazard if not rendered |

## Progress

- [x] Phase 1 — `lfm_prompt.menu` primitive
- [x] Phase 2 — F9 key decoder
- [x] Phase 3 — Panel state additions (`sort_by`, `sort_desc`, `show_hidden`)
- [x] Phase 4 — Sort comparator + hidden filter helpers
- [x] Phase 5 — `open_dir` / `refresh_panels` use new helpers
- [x] Phase 6 — F9 dispatch + two-level menu flow
- [x] Phase 7 — Hints bar update
- [x] Phase 8 — Smoke test
- [x] Phase 9 — Docs / index / roadmap propagation

## Phases

### Phase 1 — `lfm_prompt.menu(label, items, layout) -> key | nil`

**Implements:** [SP_DSP_02_01](./display_options.sp.md#SP_DSP_02_01)

Build the render string `label .. "  " .. table.concat per-item  .. "  Esc=cancel"`, truncate with `~` when overflowing `layout.cols` (use `lfm_str.pad_string` for width-aware truncation). Input loop uses `lfm_sys.get_key()`; a single char matching any item's key returns that key. `"escape"` → return nil. Everything else ignored.

### Phase 2 — F9 decoder

**Implements:** [SP_DSP_03_01](./display_options.sp.md#SP_DSP_03_01)

In `lfm_sys.get_key`, extend the `next2 == "2"` branch with a `next3 == "0"` arm: expect `"~"` → return `"options"`. The existing `"1"` → F10 and bare `"~"` → Insert arms remain untouched.

### Phase 3 — Panel fields

**Implements:** [SP_DSP_01_01](./display_options.sp.md#SP_DSP_01_01)

Extend `new_panel()` in `lfm.lua` with `sort_by = "name"`, `sort_desc = false`, `show_hidden = false`.

### Phase 4 — Sort comparator + hidden filter

**Implements:** [SP_DSP_02_02](./display_options.sp.md#SP_DSP_02_02), [SP_DSP_02_03](./display_options.sp.md#SP_DSP_02_03)

Two module-local helpers:

    local function sort_comparator(mode, desc) -> function(a, b)
    local function filter_hidden(items, show_hidden) -> items

Replace the existing `sort_items` local with a call to `table.sort(items, sort_comparator(panel.sort_by, panel.sort_desc))`.

### Phase 5 — `open_dir` / `refresh_panels`

**Implements:** [SP_DSP_02_04](./display_options.sp.md#SP_DSP_02_04), [SP_DSP_02_05](./display_options.sp.md#SP_DSP_02_05)

`open_dir(panel, target_path, prev_dir)` now:

1. Fetch via `lfm_files.get_directory_items`.
2. `filter_hidden(items, panel.show_hidden)`.
3. `table.sort(items, sort_comparator(panel.sort_by, panel.sort_desc))`.
4. Restore cursor by name as before.

No other call sites of sort logic remain.

### Phase 6 — F9 menu dispatch

**Implements:** [SP_DSP_03_02](./display_options.sp.md#SP_DSP_03_02), [SP_DSP_03_03](./display_options.sp.md#SP_DSP_03_03), [SP_DSP_06_04](./display_options.sp.md#SP_DSP_06_04)

Add `elseif key == "options" then` arm. Implementation in a new helper `handle_display_menu(panel)`:

    local function handle_display_menu(panel)
        while true do
            local items = {
                { key = "1", text = "Sort: " .. sort_label(panel) },
                { key = "2", text = "Hidden: " .. (panel.show_hidden and "on" or "off") },
            }
            local ch = lfm_prompt.menu("Display Options:", items, prompt_layout())
            if ch == nil then return end
            if ch == "1" then
                if not handle_sort_menu(panel) then
                    -- Esc from sub-menu; loop to show parent again.
                else return end
            elseif ch == "2" then
                panel.show_hidden = not panel.show_hidden
                refresh_panels()
                return
            end
        end
    end

`handle_sort_menu(panel) -> boolean` returns `true` if an action was taken (menu closes), `false` on Esc (parent menu re-opens).

In-place re-sort for sort actions: just `table.sort(panel.items, sort_comparator(...))`. Cursor index may become stale if the item at that index moved; preserve by name.

### Phase 7 — Hints bar

**Implements:** [SP_DSP_04_01](./display_options.sp.md#SP_DSP_04_01)

Edit the single `draw_text_colored("gray", ...)` line in `draw_hints` to include `F9:Opts` before `F10:Quit`.

### Phase 8 — Smoke test

Fixture `/tmp/lfm_dsp_test`:

- regular files with varying sizes, extensions, mtimes
- a `.hidden` dotfile
- one subdir

Flow:

1. Launch LFM; verify default sort is name asc, hidden off.
2. F9 → 1 → size → verify size-desc... wait, first press should be asc. Verify first-press-asc, second-press-desc.
3. F9 → 1 → r → flip; verify flipped.
4. F9 → 2 → hidden appears.
5. F9 → 2 → hidden disappears.
6. Tab to panel2 → verify its sort is unaffected.
7. Per-panel: navigate into a subdir → settings persist.
8. Esc in sub-menu → parent menu re-opens.
9. Esc in parent menu → closes cleanly.
10. F10 → exit.

### Phase 9 — Propagation

1. Update [docs/_index.md](./_index.md): add cross-cutting row for Display Options.
2. Mark R-DISP-01 and R-DISP-02 as done in [PL_RMP](./roadmap.plan.md); annotate R-DISP-03 (filter) as still proposed; leave R-DISP-04 (git status) but note it is explicitly deferred per user's IoT directive (no git on device).
3. Update [.dev_flow/active_context.md](../.dev_flow/active_context.md).

## Backlog (out-of-scope of this plan)

- Filter by glob mask (C3 / R-DISP-03) — need a pattern prompt + state field.
- Remember last sort via `~/.lfm/state` — part of R-NAV-03.
- Multi-key sort (e.g. "ext, then size") — YAGNI.
- "Sort" hotkey outside the menu for power users — only if menu proves too slow.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft — 9 phases. |
