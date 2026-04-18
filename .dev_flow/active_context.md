# Dev-Flow Active Context

> **Last updated:** 2026-04-18
> **Session:** Platform-constraint formalization + feature-roadmap capture.

## Current Work Item

| Field | Value |
|-------|-------|
| **Document** | C_PLT (Platform Constraints), SP_PLT, PL_RMP (Roadmap) |
| **Pipeline phase** | `concept` + `spec` + `plan` (all freshly drafted) |
| **Status** | `draft` — awaiting user review and commit approval |
| **Traceable IDs** | C_PLT, SP_PLT, PL_RMP |

## Current Task

Captured the IoT / BusyBox / plain-Lua platform target as a first-class architectural constraint (concept + spec), filed the brainstormed feature backlog as a roadmap filtered against that constraint, and strengthened the architecture rules with two new `must` entries (`busybox_flag_subset`, `memory_and_fork_budgets`).

## Progress State

- [x] Platform-constraint concept: [platform_constraints.concept.md](../docs/platform_constraints.concept.md) — `C_PLT` (scope, forbidden deps, BusyBox vs GNU divergences, compatibility-probe policy).
- [x] Platform-constraint spec: [platform_constraints.sp.md](../docs/platform_constraints.sp.md) — `SP_PLT` (baseline runtime, allowed applet/flag catalog, probe contract, memory/fork budgets).
- [x] Feature roadmap: [roadmap.plan.md](../docs/roadmap.plan.md) — `PL_RMP` (29 backlog items across 8 areas, each with IoT-feasibility rating and priority).
- [x] Rules: [architecture.md](./rules/architecture.md) — reworded `no_external_deps` to reference `C_PLT`; added `busybox_flag_subset` and `memory_and_fork_budgets` (both `must`).
- [x] Rules index: [_index.yaml](./rules/_index.yaml) — new rule entries.
- [x] Docs index: [_index.md](../docs/_index.md) — cross-cutting section added with pointer to `C_PLT`.
- [ ] **Next:** user review of the three new docs and the rules diff; on approval, commit with message referencing `[C_PLT]` / `[SP_PLT]` / `[PL_RMP]`.

## Blocking Issues

None. All content is additive — no existing docs were invalidated. `no_external_deps` was narrowed (GNU → BusyBox-compatible) but the intent is unchanged, so existing code continues to conform.

## Relevant Context

| Type | Name / Path | Note |
|------|-------------|------|
| Concept | [C_PLT](../docs/platform_constraints.concept.md) | New — project-wide architectural constraint |
| Spec | [SP_PLT](../docs/platform_constraints.sp.md) | New — allowed applet catalog, probe protocol, budgets |
| Plan | [PL_RMP](../docs/roadmap.plan.md) | New — feature roadmap keyed to IoT feasibility |
| Rule | [architecture.busybox_flag_subset] | New `must` — tracks BusyBox flag compatibility |
| Rule | [architecture.memory_and_fork_budgets] | New `must` — codifies 0-forks-per-keystroke, ring-buffer caps |

## Recommended follow-ups (next phases)

1. Promote `R-PLAT-01` (capability probe module) via `/dev-flow concept lfm_platform` — it unblocks `R-PLAT-02` and future probe-dependent features.
2. Promote `R-OPS-02` + `R-OPS-01` (multi-select + file ops) — biggest UX gap vs. MC.
3. Address `R-PERF-07` (per-keystroke `stty` toggling) — cheap IoT win.

## Recent Changes

| File | Change |
|------|--------|
| [docs/platform_constraints.concept.md](../docs/platform_constraints.concept.md) | New — C_PLT concept. |
| [docs/platform_constraints.sp.md](../docs/platform_constraints.sp.md) | New — SP_PLT specification. |
| [docs/roadmap.plan.md](../docs/roadmap.plan.md) | New — PL_RMP roadmap. |
| [docs/_index.md](../docs/_index.md) | Added cross-cutting section pointing to C_PLT / PL_RMP. |
| [.dev_flow/rules/architecture.md](./rules/architecture.md) | Reworded `no_external_deps`; added `busybox_flag_subset`, `memory_and_fork_budgets`. |
| [.dev_flow/rules/_index.yaml](./rules/_index.yaml) | Two new rule entries. |

---

*This file is maintained automatically by dev-flow commands.
Edit manually only when auto-update is not possible.*
