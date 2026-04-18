# Lua File Manager (LFM)

A lightweight, terminal-based file manager written in pure Lua. Two-panel
layout with an embedded shell at the bottom — inspired by Midnight Commander
and Norton Commander, scaled down to a single-file script you can drop into
`$PATH`.

## Screenshot

```
Lua File Manager (v0.1)                                   RAM: 9.2G / 125.8G
|[/home/you/projects/lfm]==========|[/home/you]============================|
|/..                     <DIR>     |/..                     <DIR>          |
|/docs                   <DIR>     |/bin                    <DIR>          |
| lfm.lua              17.5K 17:06 | Documents              <DIR>          |
| lfm_files.lua         5.1K 17:08 | Downloads              <DIR>          |
| lfm_sys.lua           5.1K 17:05 | README.md              1.2K 16:40     |
| README.md              322 16:40 |                                       |
|[3/7]=============================|[0/5]==================================|

$ pwd
/home/you/projects/lfm

$
--------------------------------------------------------------------------------
 F3: View | F4: Edit | Ctrl+R: Refresh | Tab: Switch Panel | F10: Quit
```

## Features

- **Two independent panels** with side-by-side file listings.
- **Embedded shell terminal** in the bottom band — run any shell command
  without leaving the file manager, with command history (`Ctrl+↑` / `Ctrl+↓`)
  and scrollable output (`Ctrl+Shift+↑` / `Ctrl+Shift+↓`).
- **Built-in file viewer** (F3) with vertical and horizontal scrolling, plus
  delegation to `vi` for editing (F4).
- **Color-coded listings** — directories, executables, readable/unreadable
  entries, and the active panel's cursor are visually distinct.
- **Symlink-aware** — links resolve to their targets, with correct directory
  detection.
- **Unicode-aware column alignment** — UTF-8 / CJK / emoji filenames line up
  correctly (see [lfm_str.lua](lfm_str.lua)).
- **Robust against weird filenames** — spaces, `|`, `'`, `$`, and other
  shell metacharacters are safely handled end-to-end.
- **Live terminal resize** — layout recomputes on every frame, no SIGWINCH
  handler needed.
- **Zero dependencies** — only Lua stdlib plus POSIX shell utilities
  (`stty`, `stat`, `realpath`, `free`, `readlink`).

## Requirements

- Lua 5.1, 5.2, 5.3, or 5.4 (no LuaRocks / FFI / external bindings)
- A POSIX-ish environment: Linux, macOS, BSD, WSL
- A VT100-compatible terminal emulator with ANSI color support
- GNU-compatible `stat`, `stty`, `realpath`, `readlink`, `free`, `vi`
  available in `PATH`

## Usage

```sh
lua lfm.lua
```

Or make it executable (the file starts with `#!lua`):

```sh
chmod +x lfm.lua
./lfm.lua
```

### Keybindings

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move selection within the active panel |
| `PgUp` / `PgDn` | Move selection by a full page |
| `Home` / `End` | Jump to the first / last entry |
| `Enter` | Open the selected directory; `..` returns to the parent (cursor is restored to the previously-open child) |
| `Tab` | Switch active panel |
| `F3` | View the selected file (read-only pager) |
| `F4` | Edit the selected file in `vi` |
| `Ctrl+R` | Refresh both panels (preserves selection by name) |
| `F10` | Quit |

### Terminal widget

The bottom pane is a fully interactive shell command line:

| Key | Action |
|-----|--------|
| any printable | Insert at cursor |
| `←` / `→` | Move cursor within the command |
| `Home` / `End` | Jump to start / end of the command |
| `Backspace` | Delete character left of the cursor |
| `Enter` | Execute; output is appended above |
| `Ctrl+↑` / `Ctrl+↓` | Previous / next history entry |
| `Ctrl+Shift+↑` / `Ctrl+Shift+↓` | Scroll the output buffer |

When the command line is empty the arrow keys navigate the panel instead —
so you can freely switch between navigating files and typing commands without
a modal toggle.

## Project layout

```
lfm.lua              — entry point; two-panel layout + input dispatch
lfm_view.lua         — F3 read-only file viewer
lfm_terminal.lua     — embedded shell widget (input, history, scrolling)
lfm_files.lua        — directory listing, symlink resolution, permissions
lfm_sys.lua          — shell exec, tty mode, key decoding, terminal size
lfm_scr.lua          — ANSI escape primitives: cursor, colors, alt-buffer
lfm_str.lua          — UTF-8 width and padding for column alignment
```

Internals are documented in `docs/` (concepts, specifications, plans) —
generated from the codebase via the [dev-flow](.dev_flow/) pipeline.

## Status

Version 0.1 — usable for daily filesystem browsing; backlog items
(persistent per-panel directory state, `SIGWINCH` handling, copy/move/delete
hotkeys, configurable keybindings) are tracked in the per-module plans
under `docs/`.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Author

Olexandr Yavorsky
