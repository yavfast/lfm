# Code Structure Rules

## [structure.module_return_table] (must)

Every module begins with `local M = {}` and ends with `return M`. Attach public members to `M` directly; keep helpers as `local function ...`.

**Why:** Uniform module shape — no module has to "discover" how another exposes functions.

**How to apply:** New module skeleton:

```lua
local M = {}

local function helper(...)
    -- module-private
end

function M.public_fn(...)
    -- exposed
end

return M
```

**Example:** [lfm_str.lua:1](../../lfm_str.lua#L1), [lfm_scr.lua:29](../../lfm_scr.lua#L29) (note: `local M = {}` may appear implicitly; `M` first line pattern is the convention).

## [structure.require_local] (must)

Dependencies are loaded with `local <name> = require("<module>")` at the top of the file, before any declarations.

**Why:** Makes the dependency set visible at a glance; allows static dependency-graph extraction.

**How to apply:** No inline `require(...)` inside functions. No global imports.

**Example:** [lfm_view.lua:4-6](../../lfm_view.lua#L4-L6):
```lua
local lfm_files = require("lfm_files")
local lfm_scr = require("lfm_scr")
local lfm_sys = require("lfm_sys")
```

## [structure.single_state_table] (should)

If a module has internal state, store it in a single `local state_table = { ... }` instead of multiple module-level locals.

**Why:** Makes reset/snapshot easy, reduces the risk of partial updates.

**How to apply:**

**Example:** [lfm_terminal.lua:8-16](../../lfm_terminal.lua#L8-L16) — `terminal_state`.
