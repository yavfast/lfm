#!lua

--[[
    LFM - Lua File Manager
    A simple terminal-based file manager written in Lua.

    Author: Olexandr Yavorsky
    License: Apache 2.0
    Version: 0.1
]]

local function get_terminal_size()
    local handle = io.popen("stty size")
    if handle then
        local output = handle:read("*a")
        handle:close()
        local rows, cols = output:match("(%d+)%s+(%d+)")
        return tonumber(rows) or 24, tonumber(cols) or 80
    end
    return 24, 80
end

local function get_absolute_path(path)
    local handle = io.popen('realpath "' .. path .. '" 2>/dev/null')
    if handle then
        local absolute_path = handle:read("*a"):gsub("\n", "")
        handle:close()
        return absolute_path
    end
    return path
end

local HEADER_LINES = 2
local FOOTER_LINES = 2

local current_dir = "."
local absolute_path = get_absolute_path(current_dir)
local selected_item = 1
local scroll_offset = 0
local items = {}
local view_height, view_width = get_terminal_size()
view_height = view_height - HEADER_LINES - FOOTER_LINES

-- Table to store positions for each directory
local dir_positions = {}

local function get_directory_items(path)
    local items = {}
    local absolute_path = get_absolute_path(path)
    
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
                local link_target = nil
                
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
                            link_target = get_absolute_path(link_target)
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

local function sort_items(items)
    table.sort(items, function(a, b)
        -- ".." always first
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        
        if a.is_dir and not b.is_dir then
            return true
        elseif not a.is_dir and b.is_dir then
            return false
        else
            return a.name:lower() < b.name:lower()
        end
    end)
end

local function clear_screen()
    io.write("\27[2J\27[H")
end

-- Function to move cursor
local function move_cursor(row, col)
    io.write(string.format("\27[%d;%dH", row, col))
end

-- Function to set text color
local function set_color(color)
    local colors = {
        reset = "0",
        red = "31",
        green = "32",
        blue = "34",
        yellow = "33",
        white = "37",
        bright_blue = "94",
        bright_white = "97"
    }
    io.write("\27[" .. (colors[color] or "0") .. "m")
end

-- Function to get key press
local function get_key()
    -- Set terminal to "raw" mode
    os.execute("stty raw -echo")
    
    local key = io.read(1)
    local result = nil
    
    if key == "\27" then -- ESC
        local next1 = io.read(1)
        if next1 == "[" then
            local next2 = io.read(1)
            if next2 == "A" then
                result = "up"
            elseif next2 == "B" then
                result = "down"
            elseif next2 == "C" then
                result = "right"
            elseif next2 == "D" then
                result = "left"
            elseif next2 == "5" then -- PageUp
                local next3 = io.read(1)
                if next3 == "~" then
                    result = "pageup"
                end
            elseif next2 == "6" then -- PageDown
                local next3 = io.read(1)
                if next3 == "~" then
                    result = "pagedown"
                end
            elseif next2 == "H" then -- Home
                result = "home"
            elseif next2 == "F" then -- End
                result = "end"
            end
        end
    elseif key == "\13" then -- Enter
        result = "enter"
    elseif key == "q" then
        result = "quit"
    elseif key == "v" then
        result = "view"
    elseif key == "e" then
        result = "edit"
    elseif key == "r" then
        result = "refresh"
    end
    
    -- Return terminal to normal mode
    os.execute("stty -raw echo")
    
    return result
end

-- Function to view file contents
local function view_file(path)
    local handle = io.open(path, "r")
    if not handle then
        return
    end
    
    local content = handle:read("*a")
    handle:close()
    
    -- Get absolute path for the header
    local absolute_path = get_absolute_path(path)
    
    -- Clear screen
    clear_screen()
    
    -- Display header
    set_color("bright_blue")
    print("View file: " .. absolute_path)
    set_color("reset")
    print(string.rep("=", view_width))
    
    -- Display content
    local lines = {}
    -- Split content into lines preserving empty lines
    for line in content:gmatch("[^\r\n]*\r?\n?") do
        -- Remove trailing newline if present
        line = line:gsub("\r?\n$", "")
        table.insert(lines, line)
    end
    
    local current_line = 1
    local current_col = 0  -- Add horizontal scroll position
    local max_lines = view_height
    
    while true do
        -- Clear content area
        for i = 1, max_lines do
            move_cursor(HEADER_LINES + i, 1)
            io.write(string.rep(" ", view_width))
        end
        
        -- Display current portion of content
        for i = 1, max_lines do
            local line_num = current_line + i - 1
            if line_num <= #lines then
                move_cursor(HEADER_LINES + i, 1)
                local line = lines[line_num]
                if line then
                    -- Apply horizontal scroll
                    if current_col > 0 then
                        line = line:sub(current_col + 1)
                    end
                    -- Limit line length
                    if #line > view_width then
                        line = line:sub(1, view_width - 3) .. "..."
                    end
                    print(line)
                end
            end
        end
        
        -- Display hint
        move_cursor(view_height + HEADER_LINES + 1, 1)
        -- Display position info
        local position_info = string.format("[%d-%d/%d] ", current_line, current_line + max_lines - 1, #lines)
        set_color("green")
        io.write(position_info)
        set_color("reset")
        print(string.rep("=", view_width - #position_info))
        print("Up/Down: scroll  Left/Right: horiz scroll  PgUp/PgDn: page  Home/End: top/bottom  q: back")
        
        -- Wait for key press
        local key = get_key()
        if key == "quit" then
            break
        elseif key == "up" then
            current_line = math.max(1, current_line - 1)
        elseif key == "down" then
            current_line = math.min(#lines - max_lines + 1, current_line + 1)
        elseif key == "pageup" then
            current_line = math.max(1, current_line - max_lines)
        elseif key == "pagedown" then
            current_line = math.min(#lines - max_lines + 1, current_line + max_lines)
        elseif key == "home" then
            current_line = 1
        elseif key == "end" then
            current_line = math.max(1, #lines - max_lines + 1)
        elseif key == "left" then
            current_col = math.max(0, current_col - 10)  -- Scroll left by 10 characters
        elseif key == "right" then
            current_col = current_col + 10  -- Scroll right by 10 characters
        end
        
        -- Ensure current_line is not negative
        current_line = math.max(1, current_line)
    end
end

-- Function to update scroll position
local function update_scroll()
    if selected_item < scroll_offset + 1 then
        scroll_offset = selected_item - 1
    elseif selected_item > scroll_offset + view_height then
        scroll_offset = selected_item - view_height
    end
    if scroll_offset < 0 then scroll_offset = 0 end
end

-- Function to calculate string width considering Unicode characters
local function get_string_width(str)
    local width = 0
    for _ in str:gmatch("[^\128-\191][\128-\191]*") do
        width = width + 1
    end
    return width
end

-- Function to pad string with spaces considering Unicode characters
local function pad_string(str, width, align_left)
    local current_width = get_string_width(str)
    local padding = width - current_width
    
    -- If string is too long, truncate it and add "~"
    if current_width > width then
        local truncated = ""
        local current_pos = 1
        local current_width = 0
        
        -- Iterate through Unicode characters
        for char in str:gmatch("[^\128-\191][\128-\191]*") do
            if current_width + 1 <= width - 1 then
                truncated = truncated .. char
                current_width = current_width + 1
            else
                break
            end
        end
        
        return truncated .. "~"
    end
    
    if padding <= 0 then
        return str
    end
    
    if align_left then
        return str .. string.rep(" ", padding)
    else
        return string.rep(" ", padding) .. str
    end
end

local function check_permissions(permissions, action)
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

-- Function to display file manager interface
local function display_file_manager()
    -- Update terminal size
    view_height, view_width = get_terminal_size()
    view_height = view_height - HEADER_LINES - FOOTER_LINES - 1
    
    -- Update scroll position
    update_scroll()
    
    clear_screen()
    set_color("bright_blue")
    -- Limit header length
    local header = "LFM - " .. absolute_path
    if #header > view_width then
        header = "LFM - ..." .. absolute_path:sub(-(view_width - 10))
    end
    print(header)
    set_color("reset")
    print(string.rep("=", view_width))
    
    -- Display file list
    for i = 1, view_height do
        local item_index = i + scroll_offset
        local item = items[item_index]
        if item then
            if item_index == selected_item then
                set_color("bright_white")
                io.write("> ")
            else
                io.write("  ")
            end
            
            -- Check if we have read permissions
            local has_read = check_permissions(item.permissions, "read")
            local is_executable = check_permissions(item.permissions, "execute")
            
            if not has_read then
                set_color("red")
            elseif item.is_link then
                set_color("yellow")
            elseif item.is_dir then
                set_color("bright_blue")
            elseif is_executable then
                set_color("green")
            else
                set_color("white")
            end
            
            -- Convert timestamp to readable date
            local date_str = ""
            if item.modified then
                local timestamp = tonumber(item.modified)
                if timestamp then
                    date_str = os.date("%Y-%m-%d %H:%M", timestamp)
                end
            end
            
            local size_str = item.is_dir and "<DIR>" or (item.size or "0")
            
            -- Format each column with proper Unicode handling
            local name_padded = pad_string(item.name, 40, true)
            local size_padded = pad_string(size_str, 10, false)
            local date_padded = pad_string(date_str, 20, true)
            
            io.write(string.format("%s %s %s", name_padded, size_padded, date_padded))
            
            -- Display link target if it's a symlink
            if item.is_link and item.link_target then
                set_color("yellow")
                io.write(" -> " .. item.link_target)
            end
            
            print()
            set_color("reset")
        else 
            print()
        end
    end
    
    -- Display hint with position info
    local position_info = string.format("[%d/%d] ", selected_item - 1, #items - 1)
    set_color("green")
    io.write(position_info)
    set_color("reset")
    print(string.rep("=", view_width - #position_info))
    print("Up/Down: Navigate | Enter: Open directory | v: View file | e: Edit file | r: Refresh | q: Quit")
end

-- Function to edit file using vi
local function edit_file(path)
    -- Return terminal to normal mode before launching vi
    os.execute("stty -raw echo")
    
    -- Clear screen before launching vi
    clear_screen()
    
    -- Launch vi editor
    os.execute("vi " .. path)
    
    -- Force redraw of the interface
    clear_screen()
    display_file_manager()
end

-- Main loop
local function main()
    -- Initial load of directory items
    items = get_directory_items(current_dir)
    sort_items(items)
    
    while true do
        display_file_manager()
        
        local key = get_key()
        
        if key == "quit" then
            break
        elseif key == "up" then
            selected_item = math.max(1, selected_item - 1)
        elseif key == "down" then
            selected_item = math.min(#items, selected_item + 1)
        elseif key == "pageup" then
            selected_item = math.max(1, selected_item - view_height)
        elseif key == "pagedown" then
            selected_item = math.min(#items, selected_item + view_height)
        elseif key == "home" then
            selected_item = 1
        elseif key == "end" then
            selected_item = #items
        elseif key == "enter" then
            local selected = items[selected_item]
            if selected and selected.is_dir and check_permissions(selected.permissions, "read") then
                -- Save current position before changing directory
                dir_positions[current_dir] = selected_item
                
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                -- Ensure root directory is represented as "/"
                current_dir = target_path == "" and "/" or target_path
                absolute_path = get_absolute_path(current_dir)
                
                -- Load new directory items
                items = get_directory_items(current_dir)
                sort_items(items)
                
                -- Restore position if exists, otherwise start from beginning
                selected_item = dir_positions[current_dir] or 1
                scroll_offset = 0
            end
        elseif key == "view" then
            local selected = items[selected_item]
            if selected and not selected.is_dir and check_permissions(selected.permissions, "read") then
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                view_file(target_path)
            end
        elseif key == "edit" then
            local selected = items[selected_item]
            if selected and not selected.is_dir and check_permissions(selected.permissions, "write") then
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                edit_file(target_path)
            end
        elseif key == "refresh" then
            items = get_directory_items(current_dir)
            sort_items(items)
        end
    end
end

-- Run program
main()