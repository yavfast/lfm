# Analysis: lfm_sys

**Layer:** 0 | **File:** [lfm_sys.lua](../../../lfm_sys.lua) | **Depends on:** none

## Purpose

Thin wrapper over Unix system calls and tty state — shields the rest of the code from `io.popen`, `os.execute`, and `stty` details.

## Public contracts

| Function | Inputs | Output | Side effects |
|----------|--------|--------|--------------|
| `exec_command_output(command)` | shell command string | full stdout or `nil` | Forks `LANG=C <command>`; collects stdout via `io.popen`. |
| `get_terminal_size()` | — | `rows, cols` (numbers) | Runs `stty size`; falls back to `24, 80`. |
| `format_size(bytes)` | number | human string (e.g. `"1.3M"`) | Pure. Units `'', K, M, G, T`; switches at `>1024`. |
| `get_ram_info()` | — | `"RAM: <used> / <total>"` or `"RAM: N/A"` | Runs `free`; parses `Mem:` line; multiplies kB→B. |
| `init_terminal()` | — | — | `stty raw -echo` — puts tty into raw mode. |
| `restore_terminal()` | — | — | `stty -raw echo` — restore cooked mode. |
| `get_key()` | — | symbolic key name or `nil` | Blocking `io.read(1)`; decodes ANSI escape sequences. |

## Key domain: key decoding

`get_key` returns symbolic constants consumed by `lfm.lua` and `lfm_terminal.lua`:

- Arrows: `up`, `down`, `left`, `right`
- Paging: `pageup`, `pagedown`, `home`, `end`
- Modifiers: `ctrl_up`, `ctrl_down`, `ctrl_shift_up`, `ctrl_shift_down`
- Function: `view` (F3), `edit` (F4), `quit` (F10)
- Control: `escape`, `enter`, `tab`, `refresh` (Ctrl+R)
- Any other single byte is returned verbatim (printable chars, backspace `\127`).

Internal `read_with_timeout` briefly toggles `stty -icanon min 0 time 1` to disambiguate lone ESC from escape sequences.

## Invariants / constraints

- Caller must wrap interactive work with `init_terminal` / `restore_terminal` pairs — raw mode leaks otherwise.
- `get_key` **must** be invoked only after `init_terminal`; otherwise behavior depends on cooked-mode line buffering.
- All shell invocations force `LANG=C` for locale-stable parsing.

## Error handling

- `io.popen` failure → returns `nil` (caller must guard).
- `stty`/`free` absent or unparseable → fallback defaults (terminal size `24x80`, RAM `N/A`).
