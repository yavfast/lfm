# Architectural Rules

## [architecture.layer_direction] (must)

Dependencies flow strictly inward. Higher-layer modules may require lower-layer modules; the reverse is forbidden.

```
Layer 3: lfm (entry)
Layer 2: lfm_view
Layer 1: lfm_files, lfm_terminal
Layer 0: lfm_sys, lfm_scr, lfm_str
```

**Why:** Keeps the dependency graph acyclic so onboarding, tests, and future refactors can work layer-by-layer.

**How to apply:** Before adding a `require` in an existing module, check [.dev_flow/onboard/layers.md](../onboard/layers.md). If the new dependency would cross upward, extract the shared code into a new Layer 0 module instead.

**Example:** [lfm_files.lua:5](../../lfm_files.lua#L5) depends only on `lfm_sys` (Layer 0 → Layer 1). It never requires `lfm_scr` or `lfm_view`.

## [architecture.no_external_deps] (must)

Only Lua standard library + POSIX shell utilities reachable through `$PATH` (`stty`, `free`, `stat`, `realpath`, `vi`, user commands). No LuaRocks, no FFI.

**Why:** The program must run on any Linux with Lua installed — no build step, no vendoring.

**How to apply:** If a feature truly needs a binding (e.g., `lfs`, `luaposix`), discuss before adding. Prefer a `io.popen` over bringing a dependency.

## [architecture.shell_lang_c] (should)

Shell commands run through `io.popen` must be prefixed with `LANG=C ` so numeric and tabular output parses deterministically.

**Why:** `stat`, `free`, `stty` localize their output in non-English locales; `LANG=C` keeps formats stable.

**How to apply:** Either go through [lfm_sys.exec_command_output](../../lfm_sys.lua#L4) (which already prefixes) or add `LANG=C ` manually at the call site.

**Example:** [lfm_files.lua:48](../../lfm_files.lua#L48) — `io.popen('LANG=C stat -c ...')`.

## [architecture.global_state_via_module_locals] (prefer)

UI state (panels, active panel, screen layout) lives as `local` variables at module scope. Do not use Lua globals (`_G`), do not pollute the global environment.

**Why:** Globals make testing impossible and hide the data flow between functions.

**How to apply:** Prefer module-level locals; pass them to helpers explicitly rather than relying on upvalues.
