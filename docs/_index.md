# LFM Documentation Index

Dev-flow documentation for the **Lua File Manager** — a terminal two-panel file manager with embedded shell, viewer, and editor integration.

All docs were produced by the [onboard procedure](../.dev_flow/onboard/) from the existing codebase.

## Cross-cutting documents

| Document | Concept | Spec | Plan |
|----------|---------|------|------|
| **Platform constraints** — IoT/BusyBox/plain-Lua target | [C_PLT](./platform_constraints.concept.md) | [SP_PLT](./platform_constraints.sp.md) | — |
| **Feature roadmap** — backlog of candidate features with IoT feasibility | — | — | [PL_RMP](./roadmap.plan.md) |
| **File operations** — Area A: copy/move/delete/mkdir, multi-select, panel sync | [C_OPS](./file_operations.concept.md) | [SP_OPS](./file_operations.sp.md) | [PL_OPS](./file_operations.plan.md) |

> **Read [C_PLT](./platform_constraints.concept.md) before designing any new feature** — it bounds what's acceptable (no LuaRocks, no FFI, BusyBox-compatible shell flags only).

## Modules by dependency layer

### Layer 0 — foundation (no project deps)

| Module | Concept | Spec | Plan |
|--------|---------|------|------|
| `lfm_sys` — shell, tty, key decoding | [C_SYS](./lfm_sys.concept.md) | [SP_SYS](./lfm_sys.sp.md) | [PL_SYS](./lfm_sys.plan.md) |
| `lfm_scr` — ANSI rendering primitives | [C_SCR](./lfm_scr.concept.md) | [SP_SCR](./lfm_scr.sp.md) | [PL_SCR](./lfm_scr.plan.md) |
| `lfm_str` — UTF-8 width and padding | [C_STR](./lfm_str.concept.md) | [SP_STR](./lfm_str.sp.md) | [PL_STR](./lfm_str.plan.md) |

### Layer 1

| Module | Concept | Spec | Plan |
|--------|---------|------|------|
| `lfm_files` — directory listing, permissions | [C_FIL](./lfm_files.concept.md) | [SP_FIL](./lfm_files.sp.md) | [PL_FIL](./lfm_files.plan.md) |
| `lfm_terminal` — embedded shell widget | [C_TRM](./lfm_terminal.concept.md) | [SP_TRM](./lfm_terminal.sp.md) | [PL_TRM](./lfm_terminal.plan.md) |
| `lfm_prompt` — modal input / confirm / error overlay | (see [C_OPS](./file_operations.concept.md)) | (see [SP_OPS](./file_operations.sp.md)) | (see [PL_OPS](./file_operations.plan.md)) |
| `lfm_ops` — cp / mv / rm / mkdir shell wrappers | (see [C_OPS](./file_operations.concept.md)) | (see [SP_OPS](./file_operations.sp.md)) | (see [PL_OPS](./file_operations.plan.md)) |

### Layer 2

| Module | Concept | Spec | Plan |
|--------|---------|------|------|
| `lfm_view` — F3 text pager | [C_VIW](./lfm_view.concept.md) | [SP_VIW](./lfm_view.sp.md) | [PL_VIW](./lfm_view.plan.md) |

### Layer 3 — entry point

| Module | Concept | Spec | Plan |
|--------|---------|------|------|
| `lfm` — main loop & two-panel UI | [C_LFM](./lfm.concept.md) | [SP_LFM](./lfm.sp.md) | [PL_LFM](./lfm.plan.md) |

## Project standards

- Coding rules: [.dev_flow/rules/](../.dev_flow/rules/_index.yaml)
- Project skills (terminal UI, Unicode): [.dev_flow/skills/](../.dev_flow/skills/_index.yaml)
- Onboard report: [.dev_flow/onboard/report.md](../.dev_flow/onboard/report.md)
- Onboard issues / manual-attention items: [.dev_flow/onboard/issues.md](../.dev_flow/onboard/issues.md)
