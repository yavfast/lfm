#!lua

--[[
    LFM - Lua File Manager
    A simple terminal-based file manager written in Lua.

    Author: Olexandr Yavorsky
    License: Apache 2.0
    Version: 0.1
]]

-- Execute a system command with LANG=C and return its output as string
local function exec_command_output(command)
    local handle = io.popen('LANG=C ' .. command)
    if not handle then return nil end
    local output = handle:read("*a")
    handle:close()
    return output
end

local function get_terminal_size()
    local output = exec_command_output("stty size")
    if output then
        local rows, cols = output:match("(%d+)%s+(%d+)")
        return tonumber(rows) or 24, tonumber(cols) or 80
    end
    return 24, 80
end

-- Simple cache for absolute paths
local abs_path_cache = {}
local function get_absolute_path(path)
    local absolute_path = abs_path_cache[path]
    if absolute_path then
        return absolute_path
    end
    local output = exec_command_output('realpath "' .. path .. '" 2>/dev/null')
    if output then
        absolute_path = output:gsub("\n", "")
        abs_path_cache[path] = absolute_path
        return absolute_path
    end
    abs_path_cache[path] = path
    return path
end

local HEADER_LINES = 2
local FOOTER_LINES = 2

-- Table to store positions for each directory
local dir_positions = {}

-- Panel data structure
local panel = {
    current_dir = ".",
    absolute_path = get_absolute_path("."),
    selected_item = 1,
    scroll_offset = 0,
    items = {},
    view_width = 0
}

-- Two panels
local panel1 = {}
for k, v in pairs(panel) do panel1[k] = v end
local panel2 = {}
for k, v in pairs(panel) do panel2[k] = v end

local active_panel = 1 -- 1 for panel1, 2 for panel2

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

local colors = {
    reset = "0",
    black = "30",
    red = "31",
    green = "32",
    blue = "34",
    yellow = "33",
    white = "37",
    gray = "90",
    silver = "37",
    bright_red = "91",
    bright_green = "92",
    bright_yellow = "93",
    bright_blue = "94",
    bright_white = "97"
}

-- Function to set text color
local function set_color(color)
    io.write("\27[" .. (colors[color] or "0") .. "m")
end

-- Function to draw colored text
local function draw_text(text)
    io.write(text)
end

-- Function to draw colored text
local function draw_text_xy(row, col, text)
    move_cursor(row, col)
    draw_text(text)
end

-- Function to draw colored text
local function draw_text_colored(color, text)
    set_color(color)
    draw_text(text)
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
    elseif key == "t" then
        result = "terminal"
    elseif key == "\t" then -- Handle Tab key
        result = "tab"
    end
    
    -- Return terminal to normal mode
    os.execute("stty -raw echo")
    
    return result
end

-- Function to view file contents
local function view_file(path) -- Note: AI, don`t remove ")"
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
    draw_text_colored("bright_blue", "View file: " .. absolute_path .. "\n")
    draw_text_colored("gray", string.rep("=", view_width) .. "\n")
    
    set_color("white")

    -- Display content
    local lines = {}
    -- Split content into lines preserving empty lines
    for line in content:gmatch("[^\r\n]*\r?\n?") do
        -- Remove trailing newline if present
        line = line:gsub("\r?\n$", "")
        table.insert(lines, line)
    end
    
    local current_line = 1
    local current_col = 0
    local max_lines = view_height
    while true do
        -- Clear content area
        for i = 1, max_lines do
            move_cursor(HEADER_LINES + i, 1)
            draw_text(string.rep(" ", view_width))
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
                    draw_text(line .. "\n")
                end
            end
        end
        
        -- Display hint (ASCII only)
        move_cursor(view_height + HEADER_LINES + 1, 1)
        local position_info = string.format("[%d-%d/%d] ", current_line, current_line + max_lines - 1, #lines)
        draw_text_colored("green", position_info)
        draw_text_colored("gray", string.rep("=", view_width - #position_info) .. "\n")
        draw_text_colored("gray", "Up/Down: scroll  Left/Right: horiz scroll  PgUp/PgDn: page  Home/End: top/bottom  q: back\n")
        
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
            current_col = math.max(0, current_col - 10)
        elseif key == "right" then
            current_col = current_col + 10  -- Scroll right by 10 characters
        end
        current_line = math.max(1, current_line)
    end
end

-- Function to update scroll position
local function update_scroll(panel)
    if panel.selected_item < panel.scroll_offset + 1 then
        panel.scroll_offset = panel.selected_item - 1
    elseif panel.selected_item > panel.scroll_offset + view_height then
        panel.scroll_offset = panel.selected_item - view_height
    end
    if panel.scroll_offset < 0 then panel.scroll_offset = 0 end
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

-- Function to get RAM information
local function get_ram_info()
    local output = exec_command_output("free")
    if output then
        local total, used = output:match("Mem:%s+(%d+)%s+(%d+)")
        if total and used then
            total = tonumber(total)
            used = tonumber(used)
            -- Convert to human readable format
            local function format_size(bytes)
                local units = {'KB', 'MB', 'GB'}
                local size = bytes
                local unit_index = 1
                while size > 1024 and unit_index < #units do
                    size = size / 1024
                    unit_index = unit_index + 1
                end
                return string.format("%.1f %s", size, units[unit_index])
            end
            return "RAM: " .. format_size(used) .. " / " .. format_size(total)
        end
    end
    return "RAM: N/A"
end

-- Function to display file manager interface
local function display_file_manager()
    -- Update terminal size
    view_height, view_width = get_terminal_size()
    view_height = view_height - HEADER_LINES - FOOTER_LINES - 1
    
    -- Calculate panel widths considering 3 vertical separators
    local usable_width = view_width - 3 -- Account for left, middle, and right separators
    panel1.view_width = math.floor(usable_width / 2)
    panel2.view_width = usable_width - panel1.view_width

    -- Update scroll position for both panels
    update_scroll(panel1)
    update_scroll(panel2)
    
    clear_screen()
    
    -- Display RAM information in the header (LFM left, RAM right)
    local lfm_info = "Lua File Manager (v0.1)"
    local ram_info = get_ram_info()
    draw_text_colored("bright_white", lfm_info)
    local pad = view_width - #lfm_info - #ram_info
    if pad < 1 then pad = 1 end
    draw_text_colored("black", string.rep(" ", pad))
    draw_text_colored("green", ram_info .. "\n")

    -- Display path in the separator line (left-aligned, =[ path ]===...)
    local path_str1 = panel1.absolute_path
    if #path_str1 > panel1.view_width - 2 then -- Adjust truncation for panel width
        path_str1 = "..." .. path_str1:sub(-(panel1.view_width - 5))
    end
    local sep1 = "[" .. path_str1 .. "]" .. string.rep("=", math.max(0, panel1.view_width - (#path_str1 + 2)))

    local path_str2 = panel2.absolute_path
    if #path_str2 > panel2.view_width - 2 then -- Adjust truncation for panel width
        path_str2 = "..." .. path_str2:sub(-(panel2.view_width - 5))
    end
     local sep2 = "[" .. path_str2 .. "]" .. string.rep("=", math.max(0, panel2.view_width - (#path_str2 + 2)))

    -- Highlight active panel path
    if active_panel == 1 then
        draw_text_colored("bright_white", "|" .. sep1)
        draw_text_colored("white", "|" .. sep2)
    else
        draw_text_colored("white", "|" .. sep1)
        draw_text_colored("bright_white", "|" .. sep2)
    end
    draw_text_colored("white", "|") -- Right separator

    draw_text("\n")
    
    -- Display file list
    for i = 1, view_height do
        local item_index1 = i + panel1.scroll_offset
        local item1 = panel1.items[item_index1]

        local item_index2 = i + panel2.scroll_offset
        local item2 = panel2.items[item_index2]

        -- Draw left vertical separator
        move_cursor(HEADER_LINES + i, 1)
        draw_text_colored("white", "|")

        -- Draw panel 1
        move_cursor(HEADER_LINES + i, 2)
        if item1 then
            if item_index1 == panel1.selected_item and active_panel == 1 then
                draw_text_colored("bright_white", ">")
            else
                draw_text(" ")
            end
            
            -- Check if we have read permissions
            local has_read1 = check_permissions(item1.permissions, "read")
            local is_executable1 = check_permissions(item1.permissions, "execute")
            
            if not has_read1 then
                draw_text_colored("red", " ")
            elseif item1.is_dir then
                draw_text_colored("bright_white", "/")
            elseif is_executable1 then
                draw_text_colored("green", "*")
            else
                draw_text_colored("white", " ")
            end
            
            -- Convert timestamp to readable date
            local date_str1 = ""
            if item1.modified then
                local timestamp1 = tonumber(item1.modified)
                if timestamp1 then
                    date_str1 = os.date("%Y-%m-%d %H:%M", timestamp1)
                end
            end
            
            local size_str1 = item1.is_dir and "<DIR>" or (item1.size or "0")
            
            -- Format each column with proper Unicode handling
            local name_padded1 = pad_string(item1.name, math.floor(panel1.view_width * 0.4), true)
            local size_padded1 = pad_string(size_str1, math.floor(panel1.view_width * 0.2), false)
            local date_padded1 = pad_string(date_str1, math.floor(panel1.view_width * 0.3), true)
            
            draw_text(string.format("%s %s %s", name_padded1, size_padded1, date_padded1))
            
            -- Display link target if it's a symlink
            if item1.is_link and item1.link_target then
                draw_text(" -> " .. item1.link_target)
            end
            
        else 
            draw_text(string.rep(" ", panel1.view_width))
        end

        -- Add vertical separator between panels
        move_cursor(HEADER_LINES + i, panel1.view_width + 2)
        draw_text_colored("white", "|")

        -- Draw panel 2
        move_cursor(HEADER_LINES + i, panel1.view_width + 3)
        if item2 then
             if item_index2 == panel2.selected_item and active_panel == 2 then
                draw_text_colored("bright_white", ">")
            else
                draw_text(" ")
            end
            
            -- Check if we have read permissions
            local has_read2 = check_permissions(item2.permissions, "read")
            local is_executable2 = check_permissions(item2.permissions, "execute")
            
            if not has_read2 then
                draw_text_colored("red", " ")
            elseif item2.is_dir then
                draw_text_colored("bright_white", "/")
            elseif is_executable2 then
                draw_text_colored("green", "*")
            else
                draw_text_colored("white", " ")
            end
            
            -- Convert timestamp to readable date
            local date_str2 = ""
            if item2.modified then
                local timestamp2 = tonumber(item2.modified)
                if timestamp2 then
                    date_str2 = os.date("%Y-%m-%d %H:%M", timestamp2)
                end
            end
            
            local size_str2 = item2.is_dir and "<DIR>" or (item2.size or "0")
            
            -- Format each column with proper Unicode handling
            local name_padded2 = pad_string(item2.name, math.floor(panel2.view_width * 0.4), true)
            local size_padded2 = pad_string(size_str2, math.floor(panel2.view_width * 0.2), false)
            local date_padded2 = pad_string(date_str2, math.floor(panel2.view_width * 0.3), true)
            
            draw_text(string.format("%s %s %s", name_padded2, size_padded2, date_padded2))
            
            -- Display link target if it's a symlink
            if item2.is_link and item2.link_target then
                draw_text(" -> " .. item2.link_target)
            end
            
        else
            draw_text(string.rep(" ", panel2.view_width))
        end

        -- Draw right vertical separator
        move_cursor(HEADER_LINES + i, view_width)
        draw_text_colored("white", "|")
        draw_text("\n")
    end
    
    -- Display hint with position info
    move_cursor(view_height + HEADER_LINES + 1, 1)
    local position_info1 = string.format("[%d/%d]", panel1.selected_item - 1, #panel1.items - 1)
    local position_info2 = string.format("[%d/%d]", panel2.selected_item - 1, #panel2.items - 1)

    -- Draw left vertical separator
    draw_text_colored("white", "|")

    -- Draw panel 1 position info and padding
    move_cursor(view_height + HEADER_LINES + 1, 2)
    draw_text_colored("green", position_info1)

    local pad1 = panel1.view_width - #position_info1
    if pad1 < 0 then pad1 = 0 end -- Ensure non-negative padding
    draw_text_colored("white", string.rep("=", pad1))

    -- Draw vertical separator between panels
    move_cursor(view_height + HEADER_LINES + 1, panel1.view_width + 2)
    draw_text_colored("white", "|")

    -- Draw panel 2 position info and padding
    move_cursor(view_height + HEADER_LINES + 1, panel1.view_width + 3)
    draw_text_colored("green", position_info2)

    local pad2 = panel2.view_width - #position_info2
    if pad2 < 0 then pad2 = 0 end -- Ensure non-negative padding
    draw_text_colored("white", string.rep("=", pad2))

    -- Draw right vertical separator
    move_cursor(view_height + HEADER_LINES + 1, view_width)
    draw_text_colored("white", "|")
    draw_text("\n")
    draw_text_colored("gray", " Up/Down: Navigate | Enter: Open | v: View file | e: Edit file | r: Refresh | Tab: Switch | q: Quit\n")
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
    -- Initial load of directory items for both panels
    panel1.items = get_directory_items(panel1.current_dir)
    sort_items(panel1.items)
    panel1.absolute_path = get_absolute_path(panel1.current_dir)

    panel2.current_dir = panel1.current_dir -- Start panel2 in the same directory
    panel2.items = get_directory_items(panel2.current_dir)
    sort_items(panel2.items)
    panel2.absolute_path = get_absolute_path(panel2.current_dir)
    
    while true do
        display_file_manager()
        
        local key = get_key()
        
        local current_panel = (active_panel == 1) and panel1 or panel2

        if key == "quit" then
            break
        elseif key == "up" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - 1)
        elseif key == "down" then
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + 1)
        elseif key == "pageup" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - view_height)
        elseif key == "pagedown" then
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + view_height)
        elseif key == "home" then
            current_panel.selected_item = 1
        elseif key == "end" then
            current_panel.selected_item = #current_panel.items
        elseif key == "enter" then
            local selected = current_panel.items[current_panel.selected_item]
            if selected and selected.is_dir and check_permissions(selected.permissions, "read") then
                -- Save current position before changing directory
                dir_positions[current_panel.current_dir] = current_panel.selected_item
                -- Clear absolute path cache when changing directory
                abs_path_cache = {}
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                -- Ensure root directory is represented as "/"
                current_panel.current_dir = target_path == "" and "/" or target_path
                current_panel.absolute_path = get_absolute_path(current_panel.current_dir)
                -- Load new directory items
                current_panel.items = get_directory_items(current_panel.current_dir)
                sort_items(current_panel.items)
                -- Restore position if exists, otherwise start from beginning
                current_panel.selected_item = dir_positions[current_panel.current_dir] or 1
                current_panel.scroll_offset = 0
            end
        elseif key == "view" then
            local selected = current_panel.items[current_panel.selected_item]
            if selected and not selected.is_dir and check_permissions(selected.permissions, "read") then
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                view_file(target_path)
            end
        elseif key == "edit" then
            local selected = current_panel.items[current_panel.selected_item]
            if selected and not selected.is_dir and check_permissions(selected.permissions, "write") then
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                edit_file(target_path)
            end
        elseif key == "refresh" then
            -- Clear absolute path cache
            abs_path_cache = {}

            current_panel.items = get_directory_items(current_panel.current_dir)
            sort_items(current_panel.items)
        elseif key == "terminal" then
             open_terminal(current_panel.current_dir)
        elseif key == "tab" then
            active_panel = (active_panel == 1) and 2 or 1
        end
    end
end

-- Run program
main()