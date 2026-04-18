# Implementation Plan: File Operations  {#PL_OPS}

> **Code:** PL_OPS
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_OPS](./file_operations.concept.md)
> **Specification:** [SP_OPS](./file_operations.sp.md)
> **Depends on plans:** [PL_SYS](./lfm_sys.plan.md), [PL_FIL](./lfm_files.plan.md), [PL_SCR](./lfm_scr.plan.md), [PL_STR](./lfm_str.plan.md), [PL_LFM](./lfm.plan.md)

## Goal

Deliver Area A (MC-parity file operations + multi-select + panel sync/swap) as the minimum viable destructive-ops slice, using BusyBox-compatible shell-outs and a small reusable prompt widget.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Copy/move/delete impl | Shell-out via `cp -r -f` / `mv -f` / `rm -rf` | BusyBox-core, single fork per batch, atomic per-file semantics for free |
| Mkdir impl | `mkdir -p --` | Creates parents, idempotent on existing dir |
| Prompt UX | Single-line overlay on hints row | Reuses existing render cycle; no new modal frame |
| Prompt impl | New module `lfm_prompt.lua` (Layer 1) | Reusable for future NAV-01 search, NAV-05 path entry |
| Ops impl | New module `lfm_ops.lua` (Layer 1) | Keeps `lfm.lua` dispatch thin |
| Conflict UI | None — `-f` force-overwrites after user confirms path | Per [C_OPS_01_02](./file_operations.concept.md#C_OPS_01_02), IoT simplicity wins |
| Progress UI | None — blocking with optional `Working…` overlay | Local ops complete in ms on IoT; progress plumbing not warranted |
| Multi-select state | `panel.selected = {}` keyed by name | Survives cursor motion; cleared on `open_dir` and after batch ops |
| Selection color | Existing `yellow` from `lfm_scr` | No new color primitive needed |
| Key decode for F5-F8 / Insert | Extend existing escape-sequence decoder in `lfm_sys.get_key` | Adds ~20 LOC; no new decoder abstraction |
| Ctrl+U = swap panels | Raw `\21` byte recognized in `get_key` | Previously fell through to terminal as NAK; collision-free |

## Progress

- [x] Phase 1 — `lfm_prompt.lua` (foundation for user input)
- [x] Phase 2 — `lfm_ops.lua` (shell-out wrappers)
- [x] Phase 3 — Key-decoder extension in `lfm_sys.get_key`
- [x] Phase 4 — Multi-select state + rendering in `lfm.lua` (A2)
- [x] Phase 5 — Panel sync / swap dispatch (A3)
- [x] Phase 6 — F5 / F6 / F7 / F8 wiring (A1)
- [x] Phase 7 — Smoke test sandbox via agent-tui
- [x] Phase 8 — Active context + docs index update

## Phases

### Phase 1 — `lfm_prompt.lua`

**Implements:** [SP_OPS_02_05](./file_operations.sp.md#SP_OPS_02_05), [SP_OPS_02_06](./file_operations.sp.md#SP_OPS_02_06), [SP_OPS_02_07](./file_operations.sp.md#SP_OPS_02_07)

1. `prompt_text(label, initial, layout)` — synchronous input loop. Draws `"<label> <buffer>█"` at `layout.row`/`layout.col` truncated to `layout.cols`. Handles printable/backspace/home/end/left/right/enter/escape.
2. `confirm(label, layout)` — single-char read; returns `true` only on `y`/`Y`.
3. `show_error(message, layout)` — red text on hints row; blocks on any key.
4. All three call `lfm_scr` for drawing, `lfm_sys.get_key` for input, `lfm_str.get_string_width` for Unicode-aware layout.

### Phase 2 — `lfm_ops.lua`

**Implements:** [SP_OPS_02_01](./file_operations.sp.md#SP_OPS_02_01)…[SP_OPS_02_04](./file_operations.sp.md#SP_OPS_02_04)

Thin wrappers; each builds a shell-quoted argument list and dispatches via `lfm_sys.exec_command_output` (stderr redirected in-command, not via the helper).

One helper `M._run(cmd)` does:

```lua
local handle = io.popen(cmd .. " 2>&1", "r")
if not handle then return { ok = false, error_line = "popen failed" } end
local out = handle:read("*a") or ""
local ok, _, code = handle:close()
if ok == nil then ok = (out == "") end  -- Lua 5.1 fallback
if ok then return { ok = true } end
local first = out:match("([^\n]+)") or "error"
return { ok = false, error_line = first }
```

Each op function validates inputs, builds cmd string, calls `_run`.

### Phase 3 — `lfm_sys.get_key` extension

**Implements:** [SP_OPS_03_01](./file_operations.sp.md#SP_OPS_03_01)

Refactor the existing `next2 == "1"` branch to recognize digit-only paths (`15`, `17`, `18`, `19`) followed by `~`. Add `next2 == "2"` plain `~` branch (Insert, existing path already handles `21~` for F10). Add `next2 == "3"` plain `~` branch (Delete key = alias for F8). Add top-level `key == "\21"` → `swap_panels`.

### Phase 4 — Multi-select (A2)

**Implements:** [SP_OPS_01_01](./file_operations.sp.md#SP_OPS_01_01), [SP_OPS_03_02](./file_operations.sp.md#SP_OPS_03_02) (`*`), [SP_OPS_04](./file_operations.sp.md#SP_OPS_04)

1. Add `selected = {}` to the `panel_info` template in `lfm.lua`.
2. New dispatch arms:
   - `key == "insert"`: toggle `selected[cursor.name]` if `cursor.name ~= ".."`, advance cursor.
   - `key == "*"`: iterate items, flip `selected[name]` for every non-`..` item.
3. `open_dir`: reset `selected = {}`.
4. `draw_panel_row`: if `panel.selected[item.name]`, override foreground color to yellow.
5. `draw_footer`: when `count_selected(panel) > 0`, suffix `,N` in the position marker.

### Phase 5 — Panel sync / swap (A3)

**Implements:** [SP_OPS_03_02](./file_operations.sp.md#SP_OPS_03_02) (`=`), [SP_OPS_03_01](./file_operations.sp.md#SP_OPS_03_01) (`swap_panels`)

1. `key == "="`: `open_dir(inactive, active.current_dir)` — selection of inactive is cleared by open_dir per invariant; active unchanged.
2. `key == "swap_panels"`: swap references `panel1` and `panel2`. Simplest Lua form:

   ```lua
   local tmp = {}
   for k, v in pairs(panel1) do tmp[k] = v end
   for k, v in pairs(panel2) do panel1[k] = v end
   for k, v in pairs(tmp) do panel2[k] = v end
   ```

   `active_panel` index also flips so the visually-active panel stays visually-active after the swap.

### Phase 6 — F5 / F6 / F7 / F8 (A1)

**Implements:** [SP_OPS_06](./file_operations.sp.md#SP_OPS_06), [SP_OPS_05](./file_operations.sp.md#SP_OPS_05)

New helper in `lfm.lua`:

```lua
local function resolve_targets(panel)
    local out = {}
    -- prefer multi-selection
    for name, _ in pairs(panel.selected or {}) do
        if name ~= ".." then
            local item = find_item_by_name(panel.items, name)
            if item then out[#out + 1] = item.path end
        end
    end
    if #out == 0 then
        local item = panel.items[panel.selected_item]
        if item and item.name ~= ".." then out[#out + 1] = item.path end
    end
    return out
end
```

Key arms:

- `key == "copy"` → targets → prompt "Copy to:" pre-filled with inactive panel path → `lfm_ops.copy` → refresh both.
- `key == "move"` → same with `lfm_ops.move`.
- `key == "mkdir"` → prompt "New directory:" → `lfm_ops.mkdir(active.dir .. "/" .. name)` → refresh active.
- `key == "delete_key"` → confirm `"Delete N item(s)? [y/N]"` → `lfm_ops.remove` → refresh both.

After every success, clear `panel.selected`.

Prompt layout: `{ row = hint_row + 1, col = 1, cols = screen_info.view_width }` where `hint_row = screen_layout.terminal_start_row + screen_layout.terminal_height`. After prompt returns, call `display_file_manager()` once to repaint.

### Phase 7 — Smoke test

Agent-tui session in a sandbox `/tmp/lfm_ops_test`:

1. Pre-create `a.txt`, `b.txt`, `sub/`.
2. Launch LFM; navigate into sandbox.
3. F7 → `newdir` → verify `newdir/` appears.
4. Insert on `a.txt`, Insert on `b.txt`, F5 → accept default (other panel) → verify copies.
5. `*` on panel → verify selection inverts.
6. F8 on a selected item → `y` → verify removal.
7. F6 on a single item → edit target path → verify move/rename.
8. `=` → verify inactive panel shows active's path.
9. Ctrl+U → verify panels swapped.
10. F10 → clean exit; verify no stray processes, tty restored.

### Phase 8 — Docs/index update

1. Add `lfm_prompt`, `lfm_ops` to [docs/_index.md](./_index.md) under Layer 1.
2. Mark R-OPS-01/02/03 in [PL_RMP](./roadmap.plan.md) as status=done.
3. Update [.dev_flow/active_context.md](../.dev_flow/active_context.md) with Phase outcomes.
4. If implementation surfaced any recurring pattern not yet in `.dev_flow/rules/` — auto-add per dev-flow protocol.

## Backlog (out-of-scope of this plan)

- Glob-mask selection (`+` / `-`) — promote R-OPS from P2 if needed.
- Per-file conflict resolution (overwrite / skip / all) — needs expanded prompt.
- Progress indicator for long batch ops — needs streaming popen, see [PL_TRM backlog](./lfm_terminal.plan.md#backlog).
- Pre-fill F6 single-item prompt with bare filename for smoother rename.
- Symlink creation, chmod, chown.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft — 8 phases, blocking shell-out design. |
