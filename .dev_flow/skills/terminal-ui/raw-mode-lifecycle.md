# Raw-mode lifecycle (lfm_sys)

The program reads keystrokes byte-by-byte, so the tty must be in **raw mode**: no line buffering, no echo.

## Setup / teardown

| Step | Command |
|------|---------|
| Enter | `stty raw -echo` (via `lfm_sys.init_terminal`) |
| Leave | `stty -raw echo` (via `lfm_sys.restore_terminal`) |

## Momentary non-blocking poll

`lfm_sys.read_with_timeout` (internal) uses `stty -icanon min 0 time 1` for a ~100ms timeout to distinguish lone ESC from `ESC [ ...` sequences, then restores `stty -icanon min 1 time 0` (blocking).

## Invariants

- **Every** code path that enters raw mode pairs it with a restore:
  - On normal exit at the end of `main()`.
  - Before calling an external program that expects cooked mode (`vi`, user shell command), even temporarily.
- Skipping the restore leaves the user's shell unusable after the program crashes.

## Common pitfalls

- `os.execute("stty raw -echo")` forks `/bin/sh` every call — acceptable once at startup; avoid in hot paths.
- Lua lacks `pcall`-around-main-loop here — any runtime error leaks raw mode. Future work: wrap `main()` in `pcall` + unconditional restore.
- `stty` reads and writes to the controlling terminal; running the program via pipe (no tty) breaks everything. Document this requirement in the README.
