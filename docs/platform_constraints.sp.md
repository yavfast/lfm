# Specification: Platform Constraints  {#SP_PLT}

> **Code:** SP_PLT
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_PLT](./platform_constraints.concept.md)
> **Plan:** — (enforced via [.dev_flow/rules/architecture.md](../.dev_flow/rules/architecture.md); feature-specific probes are scheduled in [PL_RMP](./roadmap.plan.md))
>
> Concrete rules and contracts that every module must obey to keep LFM viable on BusyBox / IoT hosts.

## 1. Runtime profile  {#SP_PLT_01}

### 1.1. Baseline environment  {#SP_PLT_01_01}

The **minimum supported runtime** is:

| Component | Minimum | Notes |
|-----------|---------|-------|
| Lua interpreter | 5.1 | 5.2/5.3/5.4 also supported; same source must run on all four. |
| Shell | POSIX `sh` (ash/dash/hush) | `bash`-isms forbidden (`[[ ]]`, `${var//…}`, arrays, process substitution). |
| Userland | BusyBox 1.24+ | 1.24 is when `stat --printf` landed. Older BusyBox requires graceful degradation. |
| Terminal | VT100 / VT220 | 16-color SGR, no 256-color, no true-color, no italic. |
| RAM | 16 MB free | Target memory budget for the LFM process is ≤ 4 MB RSS at steady state. |

If the host is richer (GNU coreutils, `bash`, 256-color terminal) — LFM takes advantage opportunistically via probes, but never **requires** it.

### 1.2. Forbidden dependencies  {#SP_PLT_01_02}

- **No Lua C modules:** `luafilesystem`, `luaposix`, `luasocket`, `lsqlite3`, `cjson`, FFI.
- **No Lua pure-Lua packages from LuaRocks:** vendor-in at your peril, but default install must not need them.
- **No external binaries beyond BusyBox:** `jq`, `yq`, `git`, `python`, `awk` scripts > 3 lines, `sed` with GNU-only extensions (`sed -z`, `\s`, `\+`).
- **No persistent daemons:** LFM is a single process; don't spawn helpers.

Rule: if a feature cannot be implemented in **pure Lua 5.1 stdlib + BusyBox-applet shell-out**, the feature is either redesigned or shelved.

## 2. Shell invocation contract  {#SP_PLT_02}

### 2.1. `lfm_sys.exec_command_output` as the single shell gateway  {#SP_PLT_02_01}

**Contract:** every shell invocation MUST go through `lfm_sys.exec_command_output` (which prefixes `LANG=C `) or `os.execute` with a command that begins `LANG=C `. Raw `io.popen("foo")` bypasses the locale guard and is forbidden in new code.

### 2.2. Allowed applet / flag catalog  {#SP_PLT_02_02}

Enumerated list of shell constructs LFM is allowed to call without a probe. Anything outside this list requires a probe (see [SP_PLT_03](#SP_PLT_03)).

**Always-available (BusyBox core):**

| Applet | Allowed flags | Used for |
|--------|---------------|----------|
| `stat` | `-c FMT PATH` with `%F %n %s %Y %A %N` | directory listing |
| `realpath` | `-- PATH` | path canonicalization |
| `readlink` | `-- PATH`, `-f -- PATH` | symlink target extraction |
| `stty` | `size`, `raw -echo -icanon`, `sane`, `-g`/`<state>` | tty mode toggle |
| `free` | (no flags) | RAM info; parse `Mem:` row as KB integers |
| `vi` | `PATH` | F4 editor integration |
| `cp` | `-r`, `-p`, `-f`, `--`, `PATH…` | file ops (future) |
| `mv` | `-f`, `--`, `PATH…` | file ops (future) |
| `rm` | `-r`, `-f`, `--`, `PATH…` | file ops (future) |
| `mkdir` | `-p`, `--`, `PATH` | file ops (future) |
| `cat` | `-- PATH…` | file viewer (future binary detection) |
| `tar` | `-tzf`, `-xzf`, `-czf`, `-f -` | archive browse (future) |
| `find` | `-type`, `-name`, `-maxdepth`, `-print0` | limited walking (future) |

**Probe-required (may be missing or differ):**

| Applet | Preferred form | Fallback when probe fails |
|--------|----------------|--------------------------|
| `stat --printf='…\0…'` | NUL-separated fields | Fall back to `stat -c` with a less-safe separator (`|`) and warn once |
| `readlink -z` | NUL-terminated output | Use `readlink --` and strip trailing `\n` |
| `find -printf` | machine-readable listing | Use `-print0 | xargs -0 stat -c` two-stage form |
| `unzip` | optional BusyBox applet | Feature-gate zip browsing; show "unzip not available" |
| `gzip -c` / `gunzip -c` | standard | Probe `gzip` presence before offering `.gz` browse |
| `sort` | `-k`, `-n`, `-r`, `-z` | `-z` (NUL-terminated) is GNU-only; fall back to in-Lua sort |

### 2.3. Escaping contract  {#SP_PLT_02_03}

**Contract:** every shell argument derived from user input, filesystem, or configuration MUST pass through `lfm_sys.shell_quote` before concatenation.

**Invariant:** there are zero `io.popen("… " .. user_value .. " …")` calls in the codebase where `user_value` is unquoted.

## 3. Capability probing  {#SP_PLT_03}

### 3.1. Probe contract  {#SP_PLT_03_01}

A **capability probe** is a shell command invoked once per LFM launch, whose output determines which of two implementation paths the code takes.

**Signature** (recommended pattern, see [PL_RMP task R-PLAT-01](./roadmap.plan.md#task-r-plat-01)):

    -- Returns a boolean. Called lazily (on first dependent call) or at startup.
    -- Result memoized in a module-local table.
    function M.has_capability(name) -> boolean

### 3.2. Probe error budget  {#SP_PLT_03_02}

- **Total probe cost at startup:** ≤ 5 forks, ≤ 50 ms on a 1 GHz MIPS class CPU.
- **Probes must not write to disk** or modify environment.
- **Probes must time out gracefully** — any probe hung for > 1 s is treated as "failed" (capability absent).

### 3.3. Required probes (initial set)  {#SP_PLT_03_03}

| Name | Probe command | Used to decide |
|------|---------------|----------------|
| `stat_printf` | `stat --printf='ok' . 2>/dev/null` → `== "ok"` | NUL-separated stat vs. `|`-separated fallback |
| `readlink_f` | `readlink -f / 2>/dev/null` → non-empty | recursive symlink resolution form |
| `unzip_present` | `unzip 2>&1 | head -1` contains "UnZip" | whether to expose `.zip` browsing |
| `tar_present` | `command -v tar` → exit 0 | whether to expose `.tar`/`.tar.gz` browsing |

## 4. Memory and fork budgets  {#SP_PLT_04}

### 4.1. Memory invariants  {#SP_PLT_04_01}

- **Panel items** — no cap beyond directory size (must load all entries to sort/render correctly). If a directory has > 10 000 entries, the spec reserves the right to add pagination (tracked in [PL_RMP task R-PERF-01](./roadmap.plan.md#task-r-perf-01)).
- **Terminal output history** — MUST be capped at 2 000 lines (ring buffer semantics). Current code is uncapped — violation tracked in [PL_TRM backlog](./lfm_terminal.plan.md#backlog).
- **Command history** — MUST be capped at 500 entries.
- **Absolute-path cache** — MUST be cleared on panel directory change (already implemented in `lfm_files.clear_path_cache`).
- **File viewer buffer** — viewer loads the whole file; MUST refuse to open files > 16 MB and show a hint to use `less`.

### 4.2. Fork budget per keystroke  {#SP_PLT_04_02}

- **Panel navigation (↑/↓/PgUp/PgDn/Home/End):** 0 forks. Pure in-memory.
- **Directory change (Enter on a dir):** ≤ 2 forks (1× `stat` glob, 1× `realpath`).
- **Refresh (Ctrl+R):** ≤ 2 forks × 2 panels.
- **Terminal command execution:** unbounded by design — user invokes the shell.
- **Terminal cursor / scroll / history navigation:** 0 forks.
- **F3 open:** 1 fork (`cat` or direct Lua read — prefer Lua read).
- **F4 open:** 1 fork (`vi`).

**Forbidden:** any key-dispatch path that forks on every repaint. Current violation: `read_with_timeout` re-runs `stty -icanon` per ESC press — tracked in [PL_SYS backlog](./lfm_sys.plan.md#backlog).

## 5. Terminal emulator assumptions  {#SP_PLT_05}

### 5.1. Required escape sequences  {#SP_PLT_05_01}

- Cursor movement: `\27[<row>;<col>H`
- Clear screen: `\27[2J`, clear line: `\27[2K`
- SGR 16-color foreground/background: `\27[3Xm`, `\27[4Xm`, reset `\27[0m`
- Alt-screen enter/leave: `\27[?1049h` / `\27[?1049l`
- Cursor show/hide: `\27[?25h` / `\27[?25l`

### 5.2. NOT assumed  {#SP_PLT_05_02}

- 256-color or truecolor SGR (`\27[38;5;Xm`, `\27[38;2;R;G;Bm`).
- Italics (`\27[3m`), underline sub-styles, blink.
- Mouse tracking beyond basic SGR 1006 (feature-gated).
- Bracketed paste (`\27[?2004h`).
- Kitty / iTerm2 image protocols.

## 6. Error handling contract  {#SP_PLT_06}

- **Shell failures are not exceptions.** Every `io.popen` returning `nil`, every empty output, every non-zero exit MUST result in a typed fallback (empty list, "N/A" string, default terminal size `24×80`).
- **Missing applet MUST NOT crash LFM.** If `vi` is not installed, F4 displays a hint; LFM continues running.
- **All raw-mode code paths MUST be wrapped in `xpcall`** (already implemented in `lfm.lua` entry) so tty restores even on programmer errors.

## 7. Conformance verification  {#SP_PLT_07}

### 7.1. Pre-merge checks  {#SP_PLT_07_01}

For any PR that adds or changes shell invocations:

1. Grep for new shell commands: `Grep -n "io.popen\|os.execute" <changed-files>`.
2. For each, verify against [SP_PLT_02_02](#SP_PLT_02_02) allowed list.
3. If not in list — require a probe per [SP_PLT_03](#SP_PLT_03).
4. Verify `shell_quote` wraps every user-sourced argument.

### 7.2. IoT smoke test (manual, pre-release)  {#SP_PLT_07_02}

- Launch on Alpine Docker image (`alpine:3.19`, Lua installed) — full feature set must work.
- Launch on a BusyBox-only image (`busybox:latest`) with Lua sideloaded — core navigation + F3 + F4 + terminal must work; degraded features (archive browsing) show fallback messages.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial version — codifies the BusyBox / IoT target. |
