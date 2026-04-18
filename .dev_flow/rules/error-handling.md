# Error Handling Rules

## [error_handling.nil_guard_popen] (must)

Always check the handle returned by `io.popen` / `io.open` for nil before invoking `:read`, `:lines`, or `:close`.

**Why:** `io.popen` returns `nil` when the command cannot be spawned; calling methods on nil crashes the whole UI loop and leaves the tty in raw mode.

**How to apply:**

```lua
local handle = io.popen('LANG=C some_cmd')
if not handle then return nil end  -- or suitable fallback
local out = handle:read("*a")
handle:close()
```

**Example:** [lfm_sys.lua:5-10](../../lfm_sys.lua#L5-L10), [lfm_files.lua:49](../../lfm_files.lua#L49).

## [error_handling.safe_defaults] (should)

Shell failures return typed fallback values, not exceptions. Callers must continue to render a sane UI.

**Why:** A missing `free`, unreadable directory, or unparseable `stat` output must not crash the program.

**How to apply:** Typical fallbacks:
- `get_terminal_size` → `24, 80`.
- `get_ram_info` → `"RAM: N/A"`.
- `get_directory_items` → items containing only the synthetic `..` (or empty at `/`).
- `get_absolute_path` → cache the input path as identity.

**Example:** [lfm_sys.lua:17](../../lfm_sys.lua#L17) returns `24, 80` fallback.

## [error_handling.tty_restore] (must)

Every code path that enters raw mode via `lfm_sys.init_terminal()` or `stty raw` **must** call the corresponding `restore_terminal()` (or `stty -raw echo`) before the function returns or delegates to an external program.

**Why:** Leaving the terminal in raw mode after a crash or external-program exit makes the user's shell unusable.

**How to apply:**
- Around `view_file` / `edit_file`: `restore_terminal()` → launch external → `init_terminal()` again.
- Around a user-entered shell command: `stty -raw echo` → `io.popen(cmd)` → `stty raw -echo`.

**Example:** [lfm_terminal.lua:116-134](../../lfm_terminal.lua#L116-L134), [lfm.lua:396-400](../../lfm.lua#L396-L400).

## [error_handling.silent_permission_skip] (prefer)

Operations that cannot proceed because of missing permissions (unreadable directory, unwritable file) silently do nothing — no error dialog, no beep.

**Why:** Matches the existing UX and avoids blocking modal error flows in a minimalist TUI.

**How to apply:** Guard action-triggering keys with `lfm_files.check_permissions(item.permissions, "read"|"write")` before invoking viewer/editor.

**Example:** [lfm.lua:394, lfm.lua:405](../../lfm.lua#L394).
