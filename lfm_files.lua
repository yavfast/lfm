-- lfm_files.lua
-- Files function for LFM (Lua File Manager)

local M = {}
local lfm_sys = require("lfm_sys")

-- Simple cache for absolute paths
local abs_path_cache = {}
function M.get_absolute_path(path)
    local absolute_path = abs_path_cache[path]
    if absolute_path then
        return absolute_path
    end
    local output = lfm_sys.exec_command_output("realpath -- " .. lfm_sys.shell_quote(path) .. " 2>/dev/null")
    if output and output ~= "" then
        absolute_path = output:gsub("\n", "")
        abs_path_cache[path] = absolute_path
        return absolute_path
    end
    abs_path_cache[path] = path
    return path
end

function M.clear_path_cache()
    abs_path_cache = {}
end

function M.get_directory_items(path)
    local items = {}
    local absolute_path = M.get_absolute_path(path)

    if path ~= "/" and absolute_path ~= "/" then
        local parent_path = absolute_path:match("(.*)/[^/]*$") or "/"
        if parent_path ~= "/" then
            table.insert(items, {
                name = "..",
                path = parent_path,
                is_dir = true,
                is_link = false,
                link_target = nil,
                permissions = "-r--r--r--",
                size = 0,
                modified = ""
            })
        end
    end

    -- NUL-separated fields so any byte (|, \n, spaces, etc.) in filenames is preserved.
    local quoted_path = lfm_sys.shell_quote(path)
    local cmd = "stat --printf='%F\\0%n\\0%s\\0%Y\\0%A\\0%N\\0' "
        .. quoted_path .. "/* " .. quoted_path .. "/.* 2>/dev/null"
    local output = lfm_sys.exec_command_output(cmd)
    if not output then return items end

    local fields = {}
    for field in output:gmatch("([^%z]*)%z") do
        fields[#fields + 1] = field
    end

    for i = 1, #fields - 5, 6 do
        local file_type   = fields[i]
        local name        = fields[i + 1]
        local size        = fields[i + 2]
        local timestamp   = fields[i + 3]
        local permissions = fields[i + 4]
        local link_info   = fields[i + 5]

        if name and name ~= "" then
            local filename = name:match("([^/]+)$") or name
            local is_dir = file_type:match("directory") ~= nil
            local is_link = not is_dir and file_type:match("symbolic link") ~= nil
            local link_target

            if filename ~= "." and filename ~= ".." then
                if is_link then
                    -- Prefer readlink for robust target extraction; fall back to %N parse.
                    local item_full_path = (path == "/") and (path .. filename) or (path .. "/" .. filename)
                    local target_out = lfm_sys.exec_command_output(
                        "readlink -- " .. lfm_sys.shell_quote(item_full_path) .. " 2>/dev/null")
                    if target_out and target_out ~= "" then
                        link_target = target_out:gsub("\n$", "")
                    else
                        link_target = link_info:match("'[^']+'%s*->%s*'([^']+)'")
                    end
                    if link_target then
                        if not link_target:match("^/") then
                            link_target = (path == "/") and (path .. link_target) or (path .. "/" .. link_target)
                        end
                        link_target = M.get_absolute_path(link_target)
                        local target_type = lfm_sys.exec_command_output(
                            "stat -c '%F' -- " .. lfm_sys.shell_quote(link_target) .. " 2>/dev/null")
                        if target_type then
                            is_dir = target_type:match("directory") ~= nil
                        end
                    end
                end

                local item_path
                if path == "/" then
                    item_path = path .. filename
                else
                    item_path = path .. "/" .. filename
                end

                local size_num = is_dir and 0 or tonumber(size) or 0

                table.insert(items, {
                    name = filename,
                    path = item_path,
                    is_dir = is_dir,
                    is_link = is_link,
                    link_target = link_target,
                    permissions = permissions,
                    size = size_num,
                    modified = timestamp
                })
            end
        end
    end

    return items
end

-- [SP_FIL_02_04] Consults the owner triplet (positions 2-4 of the mode string):
-- position 2 = read, 3 = write, 4 = execute.
function M.check_permissions(permissions, action)
    if not permissions or #permissions < 4 then return false end
    local owner = permissions:sub(2, 4)
    if action == "read" then
        return owner:sub(1, 1) == "r"
    elseif action == "write" then
        return owner:sub(2, 2) == "w"
    elseif action == "execute" then
        return owner:sub(3, 3) == "x"
    end
    return false
end

function M.get_basename(path)
    -- Remove trailing slash if present
    local s = path:gsub("/*$", "")
    -- Return the last component after the last '/'
    return s:match("([^/]+)$") or s
end


return M
