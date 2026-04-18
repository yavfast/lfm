# Onboard Report

**Date:** 2026-04-18
**Project:** LFM (Lua File Manager)
**Mode:** Bottom-up reverse-engineering from existing code.

## Summary

| Metric | Count |
|--------|-------|
| Source files analyzed | 7 |
| Total Lua lines | 1341 |
| Layers identified | 4 (0..3) |
| Concepts generated | 7 |
| Specs generated | 7 |
| Plans generated | 7 (all status: `completed`) |
| Rules categories | 5 (naming, structure, architecture, error-handling, style) |
| Rules total | 13 (4 must, 7 should, 2 prefer) |
| Skills domains | 2 (terminal-ui, unicode) |
| Skills files | 4 |
| Issues flagged | 9 (see issues.md) |

## Layer map

```
Layer 0 : lfm_sys, lfm_scr, lfm_str       (no project deps)
Layer 1 : lfm_files -> lfm_sys
          lfm_terminal -> lfm_scr
Layer 2 : lfm_view -> lfm_files, lfm_scr, lfm_sys
Layer 3 : lfm (entry) -> all of the above
```

No circular dependencies. No external libraries — only Lua stdlib plus POSIX tools (`stty`, `stat`, `free`, `realpath`, `vi`).

## Deliverables

### Documentation pipeline

- [docs/_index.md](../../docs/_index.md) — module index.
- [docs/lfm*.concept.md](../../docs/) — one concept per module (7 files, `Status: active`).
- [docs/lfm*.sp.md](../../docs/) — one spec per module (7 files, `Status: active`).
- [docs/lfm*.plan.md](../../docs/) — one plan per module (7 files, `Status: completed`). Each lists a **Backlog** section capturing TODO-class findings.

### Project standards

- [.dev_flow/rules/](../rules/) — 5 category files + `_index.yaml`.
  - Highlights: `architecture.layer_direction` (must), `architecture.no_external_deps` (must), `error_handling.tty_restore` (must), `style.ansi_via_lfm_scr` (must).
- [.dev_flow/skills/](../skills/) — 2 domains with 4 skill files:
  - `terminal-ui/`: ansi-escape-conventions, raw-mode-lifecycle, key-decoding.
  - `unicode/`: utf8-width-computation.

### Onboard workspace (this directory)

- `state.yaml`, `queue.yaml` — progress tracking.
- `project_structure.md`, `dependency_graph.md`, `layers.md` — structural maps.
- `analysis/*.md` — per-module raw analysis (7 files).
- `issues.md` — items for manual attention.
- `report.md` — this file.

## Items requiring manual attention

See [issues.md](./issues.md) for the full list. Key items:

- **Shell-injection via unescaped paths** ([lfm_files.lua:14, 48](../../lfm_files.lua)). Would bite on paths containing `"`, `$`, backticks.
- **Refresh crash** on selected-item not found ([lfm.lua:416-419](../../lfm.lua)).
- **No pcall around main loop** — a crash leaves raw mode active, breaks the user's shell.
- **Stale comment** at [lfm.lua:24](../../lfm.lua) (says 20% but value is 30%).
- **Byte-based truncation** in [lfm_view.lua](../../lfm_view.lua), [lfm_terminal.lua](../../lfm_terminal.lua) bypasses `lfm_str` — mostly ASCII content, but inconsistent with rules.

## Suggested next steps

1. Review [docs/_index.md](../../docs/_index.md) and the `Backlog` section of each plan to pick the highest-value improvement.
2. Consider running `/dev-flow fix` against the shell-injection and refresh-crash items — both are narrow, well-defined bugs.
3. Consider promoting the "wrap main in `pcall` + unconditional tty restore" backlog item to a concept-level change (touches [C_LFM](../../docs/lfm.concept.md)).
4. After any iteration, the `.dev_flow/onboard/` workspace may be archived or deleted — it is no longer needed once you trust the generated docs.

## Validation checklist

- [x] All 7 modules have concept + spec + plan.
- [x] Cross-references (`Depends on`, `Used by`) consistent across docs.
- [x] All plans marked `completed` (code already exists).
- [x] `.dev_flow/rules/_index.yaml` valid YAML with at least one category file per entry.
- [x] `.dev_flow/skills/_index.yaml` valid YAML with at least one domain.
- [x] No conflicts or contradictions between generated concepts.
- [ ] **Manual review pending:** user verification of concept philosophies + rule severities.
