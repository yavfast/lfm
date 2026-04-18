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

Only Lua standard library + **BusyBox-compatible** shell utilities reachable through `$PATH` (`stty`, `free`, `stat`, `realpath`, `readlink`, `vi`, `cp`, `mv`, `rm`, `mkdir`, `tar`, `cat`, user commands). No LuaRocks, no FFI, no Lua C modules (`luafilesystem`, `luaposix`, etc.).

**Why:** The primary deployment target is IoT devices (OpenWrt, Alpine, buildroot) with **BusyBox** userland and a **stock Lua 5.1** interpreter — no LuaRocks, no C-extension packaging. See [C_PLT](../../docs/platform_constraints.concept.md) for the full platform-constraint rationale.

**How to apply:** If a feature truly needs a binding (e.g., `lfs`, `luaposix`), discuss before adding — the default answer is "no, work around it or scope the feature differently". Prefer a single `io.popen` + a BusyBox applet over bringing a dependency. When the only option is a C module, the feature becomes **optional** (loaded via `pcall(require, …)`) and LFM must run with full core functionality when the module is absent.

## [architecture.busybox_flag_subset] (must)

Shell commands must only use flags that are supported by **both BusyBox 1.24+ and GNU coreutils**. GNU-only flags (e.g. `stat --format=%w` for birth time, `readlink -z`, `find -printf`, `sort -z`, `sed -z`) are forbidden in the default code path — they may appear only behind a capability probe with a graceful fallback.

**Why:** LFM runs on IoT hosts where BusyBox is the only userland. GNU-only flags silently produce wrong output or a non-zero exit — we've already hit one such bug (`stat --printf` missing on BusyBox < 1.24). See [SP_PLT_02_02](../../docs/platform_constraints.sp.md#SP_PLT_02_02) for the allowed-applet catalog and [SP_PLT_03](../../docs/platform_constraints.sp.md#SP_PLT_03) for the probe contract.

**How to apply:**
1. Before adding a new shell invocation, check the allowed flags table in [SP_PLT_02_02](../../docs/platform_constraints.sp.md#SP_PLT_02_02).
2. If the flag is not in the table, look it up in the BusyBox applet docs (`busybox --help <applet>`).
3. If the flag is GNU-only, add a capability probe per [SP_PLT_03](../../docs/platform_constraints.sp.md#SP_PLT_03) and provide a BusyBox-compatible fallback.
4. No `bash`-isms in shell-out strings: stick to POSIX `sh` syntax (works in `ash`, `dash`, `hush`, `bash`).

## [architecture.memory_and_fork_budgets] (must)

LFM's long-running in-memory structures must have explicit size caps, and per-keystroke code paths must not fork a subprocess.

**Why:** IoT RAM budgets are 16–128 MB total; an unbounded terminal output buffer or a stat-per-keystroke loop wrecks the device. See [SP_PLT_04](../../docs/platform_constraints.sp.md#SP_PLT_04) for the numeric budgets.

**How to apply:**
- Panel navigation (↑/↓/PgUp/PgDn/Home/End): **0 forks** — pure in-memory only.
- Terminal output buffer: ≤ 2 000 lines (ring buffer).
- Command history: ≤ 500 entries.
- Viewer: refuse files > 16 MB.
- Any new cache must have an explicit invalidation trigger (mtime, explicit refresh, directory change).

## [architecture.shell_lang_c] (should)

Shell commands run through `io.popen` must be prefixed with `LANG=C ` so numeric and tabular output parses deterministically.

**Why:** `stat`, `free`, `stty` localize their output in non-English locales; `LANG=C` keeps formats stable.

**How to apply:** Either go through [lfm_sys.exec_command_output](../../lfm_sys.lua#L4) (which already prefixes) or add `LANG=C ` manually at the call site.

**Example:** [lfm_files.lua:48](../../lfm_files.lua#L48) — `io.popen('LANG=C stat -c ...')`.

## [architecture.global_state_via_module_locals] (prefer)

UI state (panels, active panel, screen layout) lives as `local` variables at module scope. Do not use Lua globals (`_G`), do not pollute the global environment.

**Why:** Globals make testing impossible and hide the data flow between functions.

**How to apply:** Prefer module-level locals; pass them to helpers explicitly rather than relying on upvalues.
