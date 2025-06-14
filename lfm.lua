#!lua

--[[
    LFM - Lua File Manager
    A simple terminal-based file manager written in Lua.

    Author: Olexandr Yavorsky
    License: Apache 2.0
    Version: 0.1
]]

local lfm_files = require("lfm_files")
local lfm_scr = require("lfm_scr")

local function get_terminal_size()
    local output = lfm_files.exec_command_output("stty size")
    if output then
        local rows, cols = output:match("(%d+)%s+(%d+)")
        return tonumber(rows) or 24, tonumber(cols) or 80
    end
    return 24, 80
end

local HEADER_LINES = 2
local FOOTER_LINES = 2

-- Table to store positions for each directory
local dir_positions = {}

-- Panel data structure
local panel_info = {
    current_dir = ".",
    absolute_path = lfm_files.get_absolute_path("."),
    selected_item = 1,
    scroll_offset = 0,
    items = {},
    view_width = 0
}

-- Two panels
local panel1 = {}
for k, v in pairs(panel_info) do panel1[k] = v end
local panel2 = {}
for k, v in pairs(panel_info) do panel2[k] = v end

local active_panel = 1 -- 1 for panel1, 2 for panel2

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

-- Function to get key press
local function get_key()
    -- Set terminal to "raw" mode
    os.execute("stty raw -echo")
    
    local key = io.read(1)
    local result

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
    local absolute_path = lfm_files.get_absolute_path(path)
    
    -- Clear screen
    lfm_scr.clear_screen()
    
    -- Display header
    lfm_scr.draw_text_colored("bright_blue", "View file: " .. absolute_path .. "\n")
    lfm_scr.draw_text_colored("gray", string.rep("=", view_width) .. "\n")

    lfm_scr.set_color("white")

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
            lfm_scr.move_cursor(HEADER_LINES + i, 1)
            lfm_scr.draw_text(string.rep(" ", view_width))
        end
        
        -- Display current portion of content
        for i = 1, max_lines do
            local line_num = current_line + i - 1
            if line_num <= #lines then
                lfm_scr.move_cursor(HEADER_LINES + i, 1)
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
                    lfm_scr.draw_text(line .. "\n")
                end
            end
        end
        
        -- Display hint (ASCII only)
        lfm_scr.move_cursor(view_height + HEADER_LINES + 1, 1)
        local position_info = string.format("[%d-%d/%d] ", current_line, current_line + max_lines - 1, #lines)
        lfm_scr.draw_text_colored("green", position_info)
        lfm_scr.draw_text_colored("gray", string.rep("=", view_width - #position_info) .. "\n")
        lfm_scr.draw_text_colored("gray", "Up/Down: scroll  Left/Right: horiz scroll  PgUp/PgDn: page  Home/End: top/bottom  q: back\n")
        
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
    local output = lfm_files.exec_command_output("free")
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

-- Function to draw the footer section (position info and hints)
local function draw_footer(panel1, panel2, view_height, view_width)
    -- Display hint with position info
    lfm_scr.move_cursor(view_height + HEADER_LINES + 1, 1)
    local position_info1 = string.format("[%d/%d]", panel1.selected_item - 1, #panel1.items - 1)
    local position_info2 = string.format("[%d/%d]", panel2.selected_item - 1, #panel2.items - 1)

    -- Draw left vertical separator
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 1 position info and padding
    lfm_scr.move_cursor(view_height + HEADER_LINES + 1, 2)
    lfm_scr.draw_text_colored("green", position_info1)

    local pad1 = panel1.view_width - #position_info1
    if pad1 < 0 then pad1 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad1))

    -- Draw vertical separator between panels
    lfm_scr.move_cursor(view_height + HEADER_LINES + 1, panel1.view_width + 2)
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 2 position info and padding
    lfm_scr.move_cursor(view_height + HEADER_LINES + 1, panel1.view_width + 3)
    lfm_scr.draw_text_colored("green", position_info2)

    local pad2 = panel2.view_width - #position_info2
    if pad2 < 0 then pad2 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad2))

    -- Draw right vertical separator
    lfm_scr.move_cursor(view_height + HEADER_LINES + 1, view_width)
    lfm_scr.draw_text_colored("white", "|")
    lfm_scr.draw_text("\n")
    lfm_scr.draw_text_colored("gray", " Up/Down: Navigate | Enter: Open | v: View file | e: Edit file | r: Refresh | Tab: Switch | q: Quit\n")
end

-- Function to draw the header section (LFM info, RAM info, and path separator)
local function draw_header(panel1, panel2, active_panel, view_width)
    -- Display RAM information in the header (LFM left, RAM right)
    local lfm_info = "Lua File Manager (v0.1)"
    local ram_info = get_ram_info()
    lfm_scr.draw_text_colored("bright_white", lfm_info)
    local pad = view_width - #lfm_info - #ram_info
    if pad < 1 then pad = 1 end
    lfm_scr.draw_text_colored("black", string.rep(" ", pad))
    lfm_scr.draw_text_colored("green", ram_info .. "\n")

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
        lfm_scr.draw_text_colored("bright_white", "|" .. sep1)
        lfm_scr.draw_text_colored("white", "|" .. sep2)
    else
        lfm_scr.draw_text_colored("white", "|" .. sep1)
        lfm_scr.draw_text_colored("bright_white", "|" .. sep2)
    end
    lfm_scr.draw_text_colored("white", "|") -- Right separator

    lfm_scr.draw_text("\n")
end

-- Function to draw a single row of a panel
local function draw_panel_row(panel, row_index, start_col, is_active, panel_view_width)
    local item_index = row_index + panel.scroll_offset
    local item = panel.items[item_index]

    -- Draw panel content
    lfm_scr.move_cursor(HEADER_LINES + row_index, start_col)
    if item then
        if item_index == panel.selected_item and is_active then
            lfm_scr.draw_text_colored("bright_white", ">")
        else
            lfm_scr.draw_text(" ")
        end

        -- Check if we have read permissions
        local has_read = check_permissions(item.permissions, "read")
        local is_executable = check_permissions(item.permissions, "execute")

        if not has_read then
            lfm_scr.draw_text_colored("red", " ")
        elseif item.is_dir then
            lfm_scr.draw_text_colored("bright_white", "/")
        elseif is_executable then
            lfm_scr.draw_text_colored("green", "*")
        else
            lfm_scr.draw_text_colored("white", " ")
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
        local name_padded = pad_string(item.name, math.floor(panel_view_width * 0.4), true)
        local size_padded = pad_string(size_str, math.floor(panel_view_width * 0.2), false)
        local date_padded = pad_string(date_str, math.floor(panel_view_width * 0.3), true)

        lfm_scr.draw_text(string.format("%s %s %s", name_padded, size_padded, date_padded))

        -- Display link target if it's a symlink
        if item.is_link and item.link_target then
            lfm_scr.draw_text(" -> " .. item.link_target)
        end

    else
        lfm_scr.draw_text(string.rep(" ", panel_view_width))
    end
end

-- Function to draw the content of both panels (the file list)
local function draw_panels_content(panel1, panel2, active_panel, view_height, view_width)
    -- Display file list
    for i = 1, view_height do
        -- Draw left vertical separator
        lfm_scr.move_cursor(HEADER_LINES + i, 1)
        lfm_scr.draw_text_colored("white", "|")

        -- Draw panel 1 row
        draw_panel_row(panel1, i, 2, active_panel == 1, panel1.view_width)

        -- Add vertical separator between panels
        lfm_scr.move_cursor(HEADER_LINES + i, panel1.view_width + 2)
        lfm_scr.draw_text_colored("white", "|")

        -- Draw panel 2 row
        draw_panel_row(panel2, i, panel1.view_width + 3, active_panel == 2, panel2.view_width)

        -- Draw right vertical separator
        lfm_scr.move_cursor(HEADER_LINES + i, view_width)
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text("\n")
    end
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

    lfm_scr.clear_screen()

    -- Draw the header section
    draw_header(panel1, panel2, active_panel, view_width)

    -- Draw the content of both panels
    draw_panels_content(panel1, panel2, active_panel, view_height, view_width)

    -- Draw the footer section
    draw_footer(panel1, panel2, view_height, view_width)
end

-- Function to edit file using vi
local function edit_file(path)
    -- Return terminal to normal mode before launching vi
    os.execute("stty -raw echo")
    
    -- Clear screen before launching vi
    lfm_scr.clear_screen()
    
    -- Launch vi editor
    os.execute("vi " .. path)
    
    -- Force redraw of the interface
    lfm_scr.clear_screen()
    display_file_manager()
end

-- Main loop
local function main()
    -- Initial load of directory items for both panels
    panel1.items = lfm_files.get_directory_items(panel1.current_dir)
    sort_items(panel1.items)
    panel1.absolute_path = lfm_files.get_absolute_path(panel1.current_dir)

    panel2.current_dir = panel1.current_dir -- Start panel2 in the same directory
    panel2.items = lfm_files.get_directory_items(panel2.current_dir)
    sort_items(panel2.items)
    panel2.absolute_path = lfm_files.get_absolute_path(panel2.current_dir)
    
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
                lfm_files.clear_path_cache()
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                -- Ensure root directory is represented as "/"
                current_panel.current_dir = target_path == "" and "/" or target_path
                current_panel.absolute_path = lfm_files.get_absolute_path(current_panel.current_dir)
                -- Load new directory items
                current_panel.items = lfm_files.get_directory_items(current_panel.current_dir)
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
            lfm_files.clear_path_cache()

            current_panel.items = lfm_files.get_directory_items(current_panel.current_dir)
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