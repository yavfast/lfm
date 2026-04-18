# Naming Rules

## [naming.module_prefix] (should)

Module files use `lfm_<subsystem>.lua` snake_case naming. The entry module is plain [lfm.lua](../../lfm.lua).

**Why:** Consistent prefix groups project files in directory listings and makes `require` targets easy to scan.

**How to apply:** When adding a new module, name it `lfm_<subsystem>.lua` (e.g. `lfm_clipboard.lua`).

**Example:** [lfm_sys.lua](../../lfm_sys.lua), [lfm_files.lua](../../lfm_files.lua), [lfm_str.lua](../../lfm_str.lua).

## [naming.snake_case_functions] (should)

Public functions in modules use `snake_case`. No camelCase.

**Why:** Matches idiomatic Lua and existing codebase.

**How to apply:** `get_directory_items`, not `getDirectoryItems`. Applies to module members and locals.

**Example:** [lfm_files.lua:28](../../lfm_files.lua#L28) — `function M.get_directory_items(path)`.

## [naming.color_tokens] (prefer)

Color names passed to `lfm_scr.set_color` / `set_bg_color` come from the fixed tables in [lfm_scr.lua](../../lfm_scr.lua): `black, red, green, blue, yellow, white, gray, silver, bright_*`. Unknown names silently reset.

**Why:** There is no type system — misspelled colors fail silently to "reset", which is hard to debug.

**How to apply:** If you need a new color, add it to the table in `lfm_scr.lua` first, then use it.
