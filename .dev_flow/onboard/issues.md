# Onboard Issues

Items requiring human attention after onboard.

## Status after fix pass (2026-04-18)

| Item | Status |
|------|--------|
| Refresh nil-deref at [lfm.lua:416-419](../../lfm.lua#L416-L419) | **FIXED** — guard added. |
| Stale comment at [lfm.lua:24](../../lfm.lua#L24) | **FIXED** — now says 30%. |
| `|` in filenames breaks stat parser | **FIXED** — stat uses NUL-separated fields. |
| Shell injection via unescaped paths | **FIXED** — `lfm_sys.shell_quote` everywhere. |
| No `pcall` around main loop | **FIXED** — `xpcall` wrap restores tty on any error. |
| Byte-based truncation in viewer / terminal output | **FIXED** — both now use `lfm_str.pad_string`. |
| `check_permissions` owner-triplet bug (found in verify) | **FIXED** — read/write/execute all use positions 2/3/4. |
| Terminal command-line horizontal scroll still uses `#s` | open — captured in [lfm_terminal.plan.md](../../docs/lfm_terminal.plan.md) backlog. |
| Binary file rendering corrupts terminal | open — [lfm_view.plan.md](../../docs/lfm_view.plan.md) backlog. |
| `read_with_timeout` per-keystroke fork/exec overhead | open — performance, [lfm_sys.plan.md](../../docs/lfm_sys.plan.md) backlog. |
| Magic string `set_bg_color("black")` as reset-bg | open — code smell, not a bug. |
| Global panel state at module scope | open — [lfm.plan.md](../../docs/lfm.plan.md) backlog. |

## Ambiguities / TODO-class findings in code

- [lfm.lua:416-419](../../lfm.lua#L416-L419) — `refresh` reads `panel.items[selected_item].name` without nil-check; if the selected index is out of bounds (e.g., after an external delete) this throws. Minor robustness gap.
- [lfm.lua:24](../../lfm.lua#L24) — Comment says "Terminal takes 20%" but value is `30`. Stale comment.
- [lfm_files.lua:48](../../lfm_files.lua#L48) — Filenames with `|` (pipe) break the `%F|%n|...` parse. Edge case, not handled.
- [lfm_files.lua:14](../../lfm_files.lua#L14) — `realpath "$path"` uses unescaped double-quoted interpolation. Paths containing `"` or `$` could cause shell injection or expansion. Known limitation of the `io.popen` + shell-string pattern used throughout.
- [lfm.lua:436](../../lfm.lua#L436) — Both panels initialize at `"."` — no way to restore per-panel directory state across runs.
- [lfm_terminal.lua:117](../../lfm_terminal.lua#L117) — `io.popen(cmd .. " 2>&1")` executes arbitrary user input in the host shell. Intentional (this IS a terminal widget), but worth calling out.
- [lfm_view.lua:62-64](../../lfm_view.lua#L62-L64) — Long-line truncation uses `#line` (byte count), not Unicode width — inconsistent with `lfm_str.get_string_width` used elsewhere.
- [lfm_sys.lua:63-71](../../lfm_sys.lua#L63-L71) — `read_with_timeout` toggles `stty -icanon` on every ESC press — adds per-keystroke fork/exec overhead.

## Conflicts / architectural smells

- `lfm_scr.set_bg_color("black")` is hard-coded in several places as "reset background" — magic string used as a sentinel.
- Two panels share global mutable state (`panel1`, `panel2`, `active_panel`) at module scope. No panel abstraction.

None of these are blockers — all modules operate and the program runs as described in the README.
