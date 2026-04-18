-- lfm_ops.lua
-- Thin shell-out wrappers around cp / mv / rm / mkdir.
-- See [C_OPS_03_01] and [SP_OPS_02_01..04]. Blocking; no progress UI.

local M = {}
local lfm_sys = require("lfm_sys")

-- Run a shell command, capture combined stdout+stderr, return OpResult.
local function run(cmd)
    local handle = io.popen("LANG=C " .. cmd .. " 2>&1", "r")
    if not handle then
        return { ok = false, error_line = "popen failed" }
    end
    local out = handle:read("*a") or ""
    local ok, _, code = handle:close()
    if ok == nil then
        -- Lua 5.1 returns nil from io.popen:close() — infer success from empty
        -- output. Commands like cp / mv / rm / mkdir are silent on success.
        ok = (out == "")
    end
    if ok then return { ok = true } end
    local first = out:match("([^\n]+)") or ("exit code " .. tostring(code or "?"))
    return { ok = false, error_line = first }
end

local function quote_list(paths)
    local parts = {}
    for i, p in ipairs(paths) do
        parts[i] = lfm_sys.shell_quote(p)
    end
    return table.concat(parts, " ")
end

-- [SP_OPS_02_01]
function M.copy(targets, dest)
    if not targets or #targets == 0 then
        return { ok = false, error_line = "no source" }
    end
    if not dest or dest == "" then
        return { ok = false, error_line = "no destination" }
    end
    local cmd = "cp -r -f -- " .. quote_list(targets) .. " " .. lfm_sys.shell_quote(dest)
    return run(cmd)
end

-- [SP_OPS_02_02]
function M.move(targets, dest)
    if not targets or #targets == 0 then
        return { ok = false, error_line = "no source" }
    end
    if not dest or dest == "" then
        return { ok = false, error_line = "no destination" }
    end
    local cmd = "mv -f -- " .. quote_list(targets) .. " " .. lfm_sys.shell_quote(dest)
    return run(cmd)
end

-- [SP_OPS_02_03] Caller MUST filter out ".." from targets.
function M.remove(targets)
    if not targets or #targets == 0 then
        return { ok = false, error_line = "nothing to delete" }
    end
    local cmd = "rm -rf -- " .. quote_list(targets)
    return run(cmd)
end

-- [SP_OPS_02_04]
function M.mkdir(path)
    if not path then
        return { ok = false, error_line = "empty name" }
    end
    local trimmed = path:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return { ok = false, error_line = "empty name" }
    end
    local cmd = "mkdir -p -- " .. lfm_sys.shell_quote(trimmed)
    return run(cmd)
end

return M
