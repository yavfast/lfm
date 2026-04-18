# Project Structure: LFM (Lua File Manager)

**Type:** Flat-layout Lua application (no package manager, plain `require` with `LUA_PATH` resolution against project root).
**Language:** Lua 5.x (uses `io.popen`, `os.execute`, bit-level string byte ops — no external deps).
**Runtime target:** Linux/Unix terminal with ANSI escape support, `stty`, `free`, `stat`, `realpath` available in `PATH`.

## File inventory

| File | Lines | Role |
|------|-------|------|
| [lfm.lua](../../lfm.lua) | 469 | Entry point — main event loop, two-panel layout orchestration |
| [lfm_terminal.lua](../../lfm_terminal.lua) | 273 | Embedded shell terminal (command input, history, output scrolling) |
| [lfm_sys.lua](../../lfm_sys.lua) | 160 | System primitives — terminal size, RAM info, raw-mode tty, key decoding |
| [lfm_files.lua](../../lfm_files.lua) | 143 | File/directory listing, permissions, symlink resolution |
| [lfm_view.lua](../../lfm_view.lua) | 106 | Read-only file viewer (F3) with horizontal/vertical scroll |
| [lfm_scr.lua](../../lfm_scr.lua) | 96 | Screen/ANSI primitives — cursor, colors, fullscreen buffer |
| [lfm_str.lua](../../lfm_str.lua) | 94 | Unicode-aware string width + padding/truncation |
| [README.md](../../README.md) | — | One-paragraph project description |
| [LICENSE](../../LICENSE) | — | Apache 2.0 |

## Conventions observed

- Module pattern: `local M = {}` + named functions `function M.name(...)` + `return M`.
- File naming: `lfm_<subsystem>.lua` (snake_case, short subsystem names).
- Entry point: `lfm.lua` starts with `#!lua` shebang + block comment header.
- No tests, no build scripts, no linting config, no CI.
- No `docs/`, no `.dev_flow/` prior to this onboard.
