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
    local output = lfm_sys.exec_command_output('realpath "' .. path .. '" 2>/dev/null')
    if output then
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
                size = "0",
                modified = ""
            })
        end
    end

    local handle = io.popen('LANG=C stat -c "%F|%n|%s|%Y|%A|%N" "' .. path .. '"/* "' .. path .. '"/.* 2>/dev/null')
    if handle then
        for line in handle:lines() do
            local file_type, name, size, timestamp, permissions, link_info = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
            if name then
                -- Extract only filename without path
                local filename = name:match("([^/]+)$")
                local is_dir = file_type:match("directory")
                local is_link = not is_dir and file_type:match("symbolic link")
                local link_target

                if filename ~= "." and filename ~= ".." then
                    if is_link then
                        -- Extract link target from the link_info
                        link_target = link_info:match("'[^']+'%s*->%s*'([^']+)'")
                        if link_target then
                            -- Handle different link_target formats
                            if not link_target:match("^/") then
                                -- If it's a relative path, add current path
                                if path == "/" then
                                    link_target = path .. link_target
                                else
                                    link_target = path .. "/" .. link_target
                                end
                            end

                            -- Get absolute path of the link target
                            link_target = M.get_absolute_path(link_target)
                            -- Check if target is a directory
                            local target_handle = io.popen('LANG=C stat -c "%F" "' .. link_target .. '" 2>/dev/null')
                            if target_handle then
                                local target_type = target_handle:read("*a"):gsub("\n", "")
                                target_handle:close()
                                is_dir = target_type:match("directory")
                            end
                        end
                    end

                    -- Form path with root directory
                    local item_path
                    if path == "/" then
                        item_path = path .. filename
                    else
                        item_path = path .. "/" .. filename
                    end

                    table.insert(items, {
                        name = filename,
                        path = item_path,
                        is_dir = is_dir,
                        is_link = is_link,
                        link_target = link_target,
                        permissions = permissions,
                        size = size,
                        modified = timestamp
                    })
                end
            end
        end
        handle:close()
    end
    return items
end

function M.check_permissions(permissions, action)
    if not permissions then return false end

    local user_perms = {
        read = permissions:sub(2, 4),
        write = permissions:sub(5, 7),
        execute = permissions:sub(8, 10)
    }

    if action == "read" then
        return user_perms.read:match("r")
    elseif action == "write" then
        return user_perms.write:match("w")
    elseif action == "execute" then
        return user_perms.execute:match("x")
    end
    return false
end


return M
