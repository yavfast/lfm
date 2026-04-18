# Platform Constraints — IoT / BusyBox / Plain Lua  {#C_PLT}

> **Code:** C_PLT
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** user (clarified target platform during roadmap planning)
>
> **Depends on:** —
> **Used by:** [C_LFM](./lfm.concept.md), [C_FIL](./lfm_files.concept.md), [C_SYS](./lfm_sys.concept.md), [C_TRM](./lfm_terminal.concept.md), [C_SCR](./lfm_scr.concept.md), [C_VIW](./lfm_view.concept.md), [C_STR](./lfm_str.concept.md)
> **Specification:** [SP_PLT](./platform_constraints.sp.md)
> **Plan:** — (this is a cross-cutting constraint, enforced via [.dev_flow/rules/architecture.md](../.dev_flow/rules/architecture.md); no standalone implementation plan)
>
> Project-wide architectural constraint: LFM is built for IoT devices running BusyBox userland and a stock Lua interpreter, with no rich library ecosystem available.

## 1. Philosophy  {#C_PLT_01}

### 1.1. Core Principle  {#C_PLT_01_01}

LFM's primary deployment target is not a developer laptop — it is a **resource-constrained IoT device**: router, SBC, industrial gateway, OpenWrt-class appliance. Such devices typically have:

- **Userland:** BusyBox (`/bin/sh` is `ash` or `hush`, not `bash`; all standard utilities are BusyBox applets).
- **Lua:** a stock interpreter compiled against the device's libc — usually 5.1 or 5.3 — with **no** LuaRocks, **no** LuaFileSystem, **no** luaposix, **no** FFI.
- **Resources:** 16–128 MB RAM, slow flash storage, single-core CPU under ~1 GHz.
- **Shell tools:** only what BusyBox ships — `ash` builtins + applets (`stat`, `stty`, `cp`, `mv`, `rm`, `mkdir`, `cat`, `ls`, `tar`, `gzip`, `realpath`, `readlink`, `free`, `vi`). **No** `bash`-isms, **no** `jq`, **no** `git`, **no** GNU coreutils unless explicitly installed.

Every design decision must assume this environment is the baseline. "Works on my Ubuntu box" is not enough — the code must also work on `/bin/ash` with BusyBox `stat`.

### 1.2. Design Constraints  {#C_PLT_01_02}

- **No runtime binaries are required beyond BusyBox.** If a feature would need `jq`, `awk` scripts longer than 3 lines, `python`, or any external language — rethink the design.
- **No Lua C modules.** The Lua interpreter is stock. If Lua stdlib + `io.popen` can't do it, it's out of scope or must be a runtime-optional feature with a graceful fallback.
- **BusyBox flag subset only.** Shell commands must stick to flags that both BusyBox and GNU versions support. When BusyBox lacks a flag, the feature either works around it or degrades gracefully.
- **Memory-frugal.** Don't buffer whole directory trees, don't keep unbounded output histories, don't recursively pre-compute sizes — these patterns break at IoT memory budgets.
- **Startup-frugal.** Avoid `fork`-per-keystroke patterns; IoT CPUs amplify shell-exec costs by 10–100×.

### 1.3. Scope boundary  {#C_PLT_01_03}

**In scope — LFM must run here:**

- OpenWrt / LEDE (ash + BusyBox 1.25+)
- Alpine Linux / Docker Alpine (ash + BusyBox)
- Embedded Linux buildroot targets
- Any POSIX desktop (BusyBox or GNU both acceptable)

**Out of scope (nice-to-have but not blocking):**

- Windows (no POSIX tty semantics)
- DOS-era 16-bit Lua
- Real-time OSes without a POSIX-compatible shell

## 2. Domain Model  {#C_PLT_02}

### 2.1. Key Entities  {#C_PLT_02_01}

- **Userland profile** — the runtime discovery of which userland is present (BusyBox vs GNU). Detected lazily via capability probes, not hardcoded.
- **Shell capability flag** — per-applet boolean (e.g. `stat_has_printf`, `readlink_has_f`) computed at startup from probe output.
- **Fallback strategy** — for each feature that depends on an optional flag / applet, the spec names both the preferred and the degraded code path.

### 2.2. Data Flows  {#C_PLT_02_02}

```
startup
  ├── probe_userland()       → sets a small capability table (module-local)
  ├── warn_if_degraded(cap)  → one-line stderr hint if critical applet is missing
  └── main loop              → modules consult the capability table before choosing syscall form
```

No persistent cache of probe results — probes are cheap (1–3 forks total) and re-run on every launch to handle package upgrades.

## 3. Mechanisms  {#C_PLT_03}

### 3.1. BusyBox vs GNU compatibility — known divergences  {#C_PLT_03_01}

Shortlist of applets LFM currently uses and their compatibility status:

| Applet | Used by | BusyBox status | Notes |
|--------|---------|----------------|-------|
| `stat -c '%F|%n|...'` | `lfm_files.get_directory_items` | supported since BusyBox 1.20 | `-c` is OK; format specifiers `%F %n %s %Y %A %N` are all supported. |
| `stat --printf='…\0…'` | `lfm_files.get_directory_items` | **supported since BusyBox 1.24**, risky on older | Older BusyBox silently ignores `--printf`. Detect via probe. |
| `realpath -- PATH` | `lfm_files.get_absolute_path` | supported | `--` end-of-options: OK. |
| `readlink -- PATH` | `lfm_files.get_directory_items` | supported | `-f` also OK if needed. |
| `stty size`, `stty raw -echo -icanon` | `lfm_sys` | supported | Full parity. |
| `free` (no `-h`) | `lfm_sys.get_ram_info` | supported | **Correct:** we parse KB values, not human-formatted — works identically on both. |
| `vi` | `lfm.lua` F4 | supported | BusyBox `vi` is feature-light but covers F4 needs. |
| `cp -r`, `mv`, `rm -rf`, `mkdir -p` | future | supported | All in BusyBox core. |
| `tar`, `gunzip` | future | supported | `unzip` is **optional** in BusyBox — feature-gate archive browsing accordingly. |
| `find` | future | partial | Many GNU-specific flags missing (`-printf`, `-regex` limited). Prefer `find ... -print0 | …` patterns. |
| `xargs` | future | supported | `xargs -0` is available. |

### 3.2. Compatibility probe policy  {#C_PLT_03_02}

When introducing a feature that depends on a non-baseline flag:

1. **Probe once at startup** (or on first use) and store the result in a module-local table.
2. **Pick the code path** based on the flag — do not re-probe on every call.
3. **Fallback must be functionally correct**, even if slower or less featureful.
4. **Document** the probe and fallback in the module's spec under a "Platform profile" section.

Example probe pattern:

    local function probe_stat_printf()
        local out = lfm_sys.exec_command_output("stat --printf='ok' . 2>/dev/null")
        return out == "ok"
    end

### 3.3. Forbidden patterns on IoT  {#C_PLT_03_03}

- **Per-keystroke `fork`/`exec`** — amortize shell calls across frames; cache results.
- **Unbounded Lua tables that grow with runtime** — terminal output, history, caches must have size caps.
- **GNU-only extensions without a fallback** — e.g. `stat --format=%w` (birth time is GNU-only), `readlink -z` (NUL output is GNU-only).
- **Escapes beyond VT100 + SGR basics** — some IoT serial consoles don't implement 256-color, italic, or bracketed paste. Stick to 16-color SGR.

## 4. Integration Points  {#C_PLT_04}

### 4.1. Dependencies  {#C_PLT_04_01}

This concept has **no implementation dependencies** — it is an architectural invariant. It governs what every other module may and may not do.

### 4.2. API Surface  {#C_PLT_04_02}

Not an API. Enforcement happens through:

- [.dev_flow/rules/architecture.md](../.dev_flow/rules/architecture.md) — codified rules with severity.
- Review gate — rejects PRs introducing GNU-only shell flags without a fallback or probe.
- Optional future module `lfm_platform.lua` — centralizes userland probes (see [PL_RMP](./roadmap.plan.md) task `R-PLAT-01`).

## 5. Non-Goals  {#C_PLT_05}

- **Not a portability shim for Windows/macOS-specific features.** macOS stat syntax differs from both Linux-GNU and BusyBox — macOS support is best-effort, not blocking.
- **Not a build-system for cross-compiling Lua.** Users install Lua through their distro's package manager; LFM does not ship a Lua binary.
- **Not a BusyBox detector for every applet.** Probe only when behavior divergence would produce wrong results — most applets (`cp`, `mv`, `mkdir`) are bit-compatible for the subset of flags LFM uses.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial version — captured the IoT / BusyBox target that was previously implicit. |
