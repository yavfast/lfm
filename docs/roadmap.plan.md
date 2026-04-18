# Roadmap: Future Features & Capability Tasks  {#PL_RMP}

> **Code:** PL_RMP
> **Status:** in-progress
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_PLT](./platform_constraints.concept.md) (all items must respect platform constraints)
> **Specification:** [SP_PLT](./platform_constraints.sp.md)
>
> Living catalog of candidate features. Each item has a brief description, the module(s) affected, and an **IoT/BusyBox feasibility** rating. Items promoted to active development get their own concept+spec+plan via `/dev-flow concept`.

## How to read this roadmap

- **IoT-feasibility ratings:**
  - `✅ native` — BusyBox + Lua 5.1 stdlib is sufficient as-is.
  - `🟡 probe` — works with a capability probe + graceful fallback (see [SP_PLT_03](./platform_constraints.sp.md#SP_PLT_03)).
  - `🟠 degraded` — core flow works; some sub-feature requires optional applet (e.g. `unzip`).
  - `🔴 risky` — needs Lua C module or non-BusyBox binary; requires architectural concession or redesign.
- **Priority:** P0 (should be next), P1 (valuable), P2 (nice-to-have).
- **Status:** `proposed` (not started) / `concept` (concept+spec drafted) / `planned` (full plan drafted) / `in-progress` / `done`.

Adding/promoting an item follows the dev-flow pipeline: `proposed` → `/dev-flow concept` → `/dev-flow spec` → `/dev-flow plan` → `/dev-flow implement`.

---

## Area A — File Operations (MC-style)

The single biggest gap between LFM and Midnight Commander. Without these, LFM is a read-only browser.

### A1. Copy / Move / Delete / Rename / Mkdir  {#task-r-ops-01}
- **Keys:** `F5` copy, `F6` move-or-rename, `F7` mkdir, `F8`/`Delete` delete.
- **Modules:** new `lfm_ops.lua` (Layer 1), prompt UI via new `lfm_prompt.lua`.
- **Shell:** `cp -r -f -- src dst`, `mv -f -- src dst`, `rm -rf -- path`, `mkdir -p -- path` — all BusyBox core.
- **Feasibility:** ✅ native. Priority: **P0**. Status: **done** (see [PL_OPS](./file_operations.plan.md)).

### A2. Multi-select  {#task-r-ops-02}
- **Keys:** `Insert` toggle. (`*` invert, `+` / `-` by glob mask — deferred.)
- **Modules:** `Panel.selected` set keyed by name.
- **Feasibility:** ✅ native. Priority: **P0**. Status: **done** (with revision 2026-04-18 — `*` hotkey dropped; no printable-char hotkeys per IoT-terminal directive).

### A3. Panel sync / swap  {#task-r-ops-03}
- **Keys:** `Ctrl+U` swap panels; **sync** (inactive ← active's path) via F9 "Options" menu → `(3) Sync paths`.
- **Feasibility:** ✅ native. Priority: **P2**. Status: **done** (revised 2026-04-18 — `=` hotkey replaced by the F9 menu item; avoids conflicts with terminal command input).

---

## Area B — Navigation

### B1. Incremental filename search in panel  {#task-r-nav-01}
- **Keys:** `/` opens search prompt; type → cursor jumps to first match; `n` / `N` next/prev.
- **Modules:** `lfm.lua` (search state), simple string-prefix or substring match.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

### B2. Bookmarks / hotlist  {#task-r-nav-02}
- **Keys:** `Ctrl+\` show list, `Ctrl+D` add current dir.
- **Persistence:** `~/.lfm/bookmarks` (plain text, one path per line).
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

### B3. Persistent per-panel state across sessions  {#task-r-nav-03}
- **Persistence:** `~/.lfm/state` — last dir per panel, selection preserved by name.
- **Modules:** new small `lfm_state.lua` (Layer 1, reads/writes one file).
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.
- **Notes:** Must degrade gracefully if `$HOME` is unwritable (common on read-only IoT rootfs — state file goes to `/tmp/lfm-$USER-state`).

### B4. Directory history (`Alt+←` / `Alt+→`)  {#task-r-nav-04}
- **Keys:** step back/forward through visited directories of the active panel.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

### B5. Quick path entry  {#task-r-nav-05}
- **Keys:** `Ctrl+L` opens a path prompt pre-filled with the current path.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

### B6. Alt+letter first-char jump (FAR-style)  {#task-r-nav-06}
- **Keys:** `Alt+<letter>` jumps cursor to next item whose name starts with that letter (case-insensitive, skips `..` and dotfiles, wraps around).
- **Modules:** `lfm_sys.get_key` Alt-letter decoder + dispatch arm in `lfm.lua`.
- **Feasibility:** ✅ native. Priority: **P1**. Status: **done** (see [C_NAV](./quick_nav.concept.md) / [PL_NAV](./quick_nav.plan.md)).

---

## Area C — Display & Sorting

### C1. Sort modes (name / size / mtime / ext, asc/desc)  {#task-r-disp-01}
- **UX:** Reached through the unified F9 menu (Display Options → Sort sub-menu). Per-panel state.
- **Modules:** sort comparator in `lfm.lua`; `sort_by`/`sort_desc` fields on `Panel`.
- **Feasibility:** ✅ native. Priority: **P1**. Status: **done** (see [PL_DSP](./display_options.plan.md)).

### C2. Toggle hidden files  {#task-r-disp-02}
- **UX:** F9 menu → "Hidden" entry. Per-panel `show_hidden` boolean; dotfiles filtered post-fetch in Lua.
- **Feasibility:** ✅ native. Priority: **P1**. Status: **done**.

### C3. Filter by glob mask  {#task-r-disp-03}
- **UX:** Future F9 menu entry opening a pattern prompt (`*.lua`, `!*.log`).
- **Modules:** new `panel.filter_pattern` + `lfm_str` glob matcher.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

### C4. Git status column (if `git` is available)  {#task-r-disp-04}
- **Status: explicitly deferred** per user's IoT directive — target devices do not ship `git`, so this is out of scope. If a git-enabled deployment variant is ever considered, promote and add a `command -v git` probe per [SP_PLT_03](./platform_constraints.sp.md#SP_PLT_03). Priority: **P2**. Status: **deferred**.

---

## Area D — Integrations

### D1. Archive browsing as pseudo-dirs  {#task-r-int-01}
- **Behavior:** `Enter` on `*.tar` / `*.tar.gz` enters a virtual listing read via `tar -tzf` / `tar -tf`.
- **Modules:** new `lfm_archive.lua` (Layer 1), dispatch in `lfm.lua`.
- **Feasibility:** 🟠 degraded — `tar` is BusyBox core (✅). `unzip` is optional (probe; if absent, hide `.zip` support). 7z / rar out of scope.
- **Priority:** **P2**. Status: proposed.

### D2. User menu (`F2`)  {#task-r-int-02}
- **Behavior:** user-editable menu of per-extension actions (e.g. `.md` → open in less, `.jpg` → run `fbi`).
- **Persistence:** `~/.lfm/menu` — simple key/value syntax.
- **Feasibility:** ✅ native (just a config parser + `os.execute`). Priority: **P1**. Status: proposed.

### D3. Shell-macro substitution in terminal widget  {#task-r-int-03}
- **Behavior:** `!` in the terminal command substitutes the selected filename (`%f`), both selected (`%F`), other panel path (`%d`).
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.
- **Notes:** All substitutions MUST be `lfm_sys.shell_quote`-escaped before expansion.

---

## Area E — Configuration & Theming

### E1. Config file (`~/.lfmrc` or `~/.config/lfm/config.lua`)  {#task-r-cfg-01}
- **Format:** Lua table (`return { colors = {...}, keys = {...}, terminal_height_pct = 30 }`) — no YAML/TOML lib needed; Lua parses Lua natively via `loadfile` + sandbox.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.
- **Safety:** `loadfile` must use an empty environment (no `_G` access) to avoid a config file running arbitrary side effects.

### E2. Configurable color theme  {#task-r-cfg-02}
- **Modules:** `lfm_scr.lua` reads colors from config with hardcoded defaults.
- **Feasibility:** ✅ native (16 colors only, per [SP_PLT_05_02](./platform_constraints.sp.md#SP_PLT_05_02)). Priority: **P2**. Status: proposed.

### E3. Configurable keybindings  {#task-r-cfg-03}
- **Modules:** `lfm.lua` key dispatch table built from config override + defaults.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

---

## Area F — Robustness & Performance

### F1. SIGWINCH-aware resize (vs. per-frame `stty size`)  {#task-r-perf-02}
- **Problem:** current code runs `stty size` every frame → 1 fork per render.
- **Blocker:** plain Lua has **no signal API**. Solutions:
  - (a) accept current per-frame cost but reduce frame rate (already effectively done — input-driven).
  - (b) depend on `luaposix` — rejected per [SP_PLT_01_02](./platform_constraints.sp.md#SP_PLT_01_02).
  - (c) detect resize via ANSI cursor-position-report trick (`\27[6n` → reply `\27[R;Cr`) once per N keystrokes.
- **Feasibility:** 🟡 probe / architectural. Priority: **P2**. Status: proposed.

### F2. Cache directory listings with mtime invalidation  {#task-r-perf-03}
- **Problem:** `Ctrl+R` re-forks `stat` glob; for unchanged dirs this is waste.
- **Solution:** cache keyed by `(path, parent_dir_mtime)` — invalidate on mtime change or explicit `Ctrl+R`.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

### F3. Stream long-running command output in terminal widget  {#task-r-perf-04}
- **Problem:** `io.popen(cmd):read("*a")` blocks until command exits — no live output.
- **Solution:** `read("*l")` in a loop with between-line frame repaints.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

### F4. Ctrl+C signal handling for long-running commands  {#task-r-perf-05}
- **Problem:** currently Ctrl+C during a `io.popen` command is delivered to LFM, not the child (since we don't PTY-fork).
- **Feasibility:** 🔴 risky — proper job control needs `setpgid` / `kill` — neither in plain Lua. Workarounds: trap SIGINT in shell (`trap` is in `ash`) or prefix commands with `sh -c 'trap "" INT; …'`.
- **Priority:** **P2**. Status: proposed.

### F5. Terminal output ring buffer (cap at 2 000 lines)  {#task-r-perf-06}
- Enforces [SP_PLT_04_01](./platform_constraints.sp.md#SP_PLT_04_01).
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

### F6. Binary-file detection in F3 viewer  {#task-r-perf-07}
- **Problem:** opening a binary file in F3 spews control codes into the terminal, potentially corrupting state.
- **Solution:** scan first 4 KB; if > 10% non-printable (excluding tab, CR, LF) → refuse or switch to hex view.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

### F7. Stop per-keystroke `stty -icanon` toggling  {#task-r-perf-08}
- **Problem:** `lfm_sys.read_with_timeout` forks `stty` on every ESC press — big on IoT CPU.
- **Solution:** enter `-icanon min 0 time 1` once, leave it on; adjust logic to accept timeout natively.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

---

## Area G — Platform Infrastructure (enables other areas)

### G1. `lfm_platform.lua` — capability probe module  {#task-r-plat-01}
- **Deliverable:** small Layer 0 module implementing the probe protocol from [SP_PLT_03](./platform_constraints.sp.md#SP_PLT_03).
- **API:** `lfm_platform.has(cap_name) -> bool`, `lfm_platform.prefer(cap_name, preferred_fn, fallback_fn)`.
- **Initial probe set:** `stat_printf`, `readlink_f`, `tar_present`, `unzip_present`.
- **Feasibility:** ✅ native. Priority: **P0** (unblocks D1, enables safer stat handling).
- **Status:** proposed.

### G2. Stat fallback for BusyBox < 1.24  {#task-r-plat-02}
- **Blocker without G1.** With G1: switch to `stat -c '%F|%n|%s|%Y|%A|%N' ...` when `stat_printf` probe fails. Pipe-in-filename still safe because we're parsing numeric fields only at known positions — but filenames with pipes corrupt the `%n` field. Document as known degradation in the probe-failed path.
- **Feasibility:** 🟡 probe. Priority: **P1**. Status: proposed.

### G3. Startup-degraded-mode hint line  {#task-r-plat-03}
- **Behavior:** on startup, if any probe failed, write a single line to stderr ("lfm: running in BusyBox-1.23 compat mode, some features degraded: see F10→About") before entering alt-screen.
- **Feasibility:** ✅ native. Priority: **P2**. Status: proposed.

---

## Area H — Testing infrastructure

### H1. Minimal Lua test harness (no external deps)  {#task-r-test-01}
- **Goal:** unit tests for pure-Lua modules (`lfm_str`, `lfm_files` parsing, `shell_quote`) runnable on-device with plain Lua.
- **Design:** ~50-line assertion runner in `test/` — no busted, no luaunit.
- **Feasibility:** ✅ native. Priority: **P1**. Status: proposed.

### H2. IoT CI smoke-test (Docker: alpine + busybox images)  {#task-r-test-02}
- **Goal:** every PR runs against `alpine:3.19` (BusyBox 1.36) and a minimal BusyBox-only image (BusyBox 1.24 — the spec floor).
- **Feasibility:** ✅ native (CI infrastructure, not Lua). Priority: **P2**. Status: proposed.

---

## Priority summary

| Priority | Count | IDs |
|----------|-------|-----|
| **P0** (next up) | 3 | R-OPS-01, R-OPS-02, R-PLAT-01 |
| **P1** (valuable) | 10 | R-NAV-01, R-NAV-03, R-DISP-01, R-DISP-02, R-INT-02, R-CFG-01, R-PERF-04, R-PERF-06, R-PERF-07, R-PERF-08, R-PLAT-02, R-TEST-01 |
| **P2** (nice-to-have) | 13 | everything else |

## Recommended next step

Promote **R-PLAT-01** (capability-probe module) first — it is small, enables `R-PLAT-02`, and the protocol it defines is referenced by every probe-dependent item.

After that, the natural sequence is:

1. R-PLAT-01 → R-PLAT-02 (platform foundation)
2. R-OPS-02 (multi-select) → R-OPS-01 (file ops) — the MC-parity feature set
3. R-PERF-07 → R-PERF-08 — robustness wins that make IoT UX noticeably better
4. R-NAV-03 + R-CFG-01 — persistence + config, unblocks most UX wins

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial roadmap — captures the feature backlog brainstormed during the README-expansion session, filtered against the IoT/BusyBox platform constraint. |
