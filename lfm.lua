#!lua

--[[
    LFM - Lua File Manager
    A simple terminal-based file manager written in Lua.

    Author: Olexandr Yavorsky
    License: Apache 2.0
    Version: 0.1
]]

local lfm_sys = require("lfm_sys")
local lfm_files = require("lfm_files")
local lfm_scr = require("lfm_scr")
local lfm_view = require("lfm_view")
local lfm_str = require("lfm_str")

-- Panel data structure
local panel_info = {
    current_dir = ".",
    absolute_path = lfm_files.get_absolute_path("."),
    selected_item = 1,
    scroll_offset = 0,
    items = {},
    view_width = 0,
    view_height = 0
}

-- Two panels
local panel1 = {}
for k, v in pairs(panel_info) do panel1[k] = v end
local panel2 = {}
for k, v in pairs(panel_info) do panel2[k] = v end

local screen_info = {
    view_height = 0,
    view_width = 0
}

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

-- Function to update scroll position
local function update_scroll(panel)
    if panel.selected_item < panel.scroll_offset + 1 then
        panel.scroll_offset = panel.selected_item - 1
    elseif panel.selected_item > panel.scroll_offset + panel.view_height then
        panel.scroll_offset = panel.selected_item - panel.view_height
    end
    if panel.scroll_offset < 0 then panel.scroll_offset = 0 end
end

-- Function to draw the footer section (position info and hints)
local function draw_footer(panel1_info, panel2_info)
    -- Display hint with position info
    lfm_scr.move_cursor(screen_info.view_height - 1, 1)
    local position_info1 = string.format("[%d/%d]", panel1_info.selected_item - 1, #panel1_info.items - 1)
    local position_info2 = string.format("[%d/%d]", panel2_info.selected_item - 1, #panel2_info.items - 1)

    -- Draw left vertical separator
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 1 position info and padding
    lfm_scr.move_cursor(screen_info.view_height - 1, 2)
    lfm_scr.draw_text_colored("green", position_info1)

    local pad1 = panel1_info.view_width - #position_info1
    if pad1 < 0 then pad1 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad1))

    -- Draw vertical separator between panels
    lfm_scr.move_cursor(screen_info.view_height - 1, panel1_info.view_width + 2)
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 2 position info and padding
    lfm_scr.move_cursor(screen_info.view_height - 1, panel1_info.view_width + 3)
    lfm_scr.draw_text_colored("green", position_info2)

    local pad2 = panel2_info.view_width - #position_info2
    if pad2 < 0 then pad2 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad2))

    -- Draw right vertical separator
    lfm_scr.move_cursor(screen_info.view_height - 1, screen_info.view_width)
    lfm_scr.draw_text_colored("white", "|")
    lfm_scr.draw_text("\n")
    lfm_scr.draw_text_colored("gray", " Up/Down: Navigate | Enter: Open | v: View file | e: Edit file | r: Refresh | Tab: Switch | q: Quit\n")
end

-- Function to draw the header section (LFM info, RAM info, and path separator)
local function draw_header(panel1_info, panel2_info, active_panel_idx)
    -- Display RAM information in the header (LFM left, RAM right)
    local lfm_info = "Lua File Manager (v0.1)"
    local ram_info = lfm_sys.get_ram_info()
    lfm_scr.draw_text_colored("bright_white", lfm_info)
    local pad = screen_info.view_width - #lfm_info - #ram_info
    if pad < 1 then pad = 1 end
    lfm_scr.draw_text_colored("black", string.rep(" ", pad))
    lfm_scr.draw_text_colored("green", ram_info .. "\n")

    -- Display path in the separator line (left-aligned, =[ path ]===...)
    local path_str1 = panel1_info.absolute_path
    if #path_str1 > panel1_info.view_width - 2 then -- Adjust truncation for panel width
        path_str1 = "..." .. path_str1:sub(-(panel1_info.view_width - 5))
    end
    local sep1 = "[" .. path_str1 .. "]" .. string.rep("=", math.max(0, panel1_info.view_width - (#path_str1 + 2)))

    local path_str2 = panel2_info.absolute_path
    if #path_str2 > panel2_info.view_width - 2 then -- Adjust truncation for panel width
        path_str2 = "..." .. path_str2:sub(-(panel2_info.view_width - 5))
    end
     local sep2 = "[" .. path_str2 .. "]" .. string.rep("=", math.max(0, panel2_info.view_width - (#path_str2 + 2)))

    -- Highlight active panel path
    if active_panel_idx == 1 then
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
    lfm_scr.move_cursor(2 + row_index, start_col)
    if item then
        if item_index == panel.selected_item and is_active then
            lfm_scr.draw_text_colored("bright_white", ">")
        else
            lfm_scr.draw_text(" ")
        end

        -- Check if we have read permissions
        local has_read = lfm_files.check_permissions(item.permissions, "read")
        local is_executable = lfm_files.check_permissions(item.permissions, "execute")

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

        -- Format size string
        local size_str
        if item.is_dir then
            size_str = "<DIR>"
        else
            -- Format size with proper units
            size_str = lfm_sys.format_size(item.size)
        end

        -- Format each column with proper Unicode handling
        local date_width = 16
        local size_width = 8
        local name_width = panel_view_width - date_width - size_width - 6  -- -2 prefix

        local name_padded = lfm_str.pad_string(item.name, name_width, true)   -- left-aligned
        local size_padded = lfm_str.pad_string(size_str, size_width, false)   -- right-aligned
        local date_padded = lfm_str.pad_string(date_str, date_width, false)   -- right-aligned

        lfm_scr.draw_text(string.format("%s %s  %s", name_padded, size_padded, date_padded))

        if item_index == panel.selected_item and is_active then
            lfm_scr.draw_text_colored("bright_white", "<")
        end

    else
        lfm_scr.draw_text(string.rep(" ", panel_view_width))
    end
end

-- Function to draw the content of both panels (the file list)
local function draw_panels_content(panel1_info, panel2_info, active_panel_idx)
    -- Display file list
    for i = 1, panel1_info.view_height do
        -- Draw left vertical separator
        lfm_scr.move_cursor(2 + i, 1)
        lfm_scr.draw_text_colored("white", "|")

        -- Draw panel 1 row
        draw_panel_row(panel1_info, i, 2, active_panel_idx == 1, panel1_info.view_width)

        -- Add vertical separator between panels
        lfm_scr.move_cursor(2 + i, panel1_info.view_width + 2)
        lfm_scr.draw_text_colored("white", "|")

        -- Draw panel 2 row
        draw_panel_row(panel2_info, i, panel1_info.view_width + 3, active_panel_idx == 2, panel2_info.view_width)

        -- Draw right vertical separator
        lfm_scr.move_cursor(2 + i, screen_info.view_width)
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text("\n")
    end
end

-- Function to display file manager interface
local function display_file_manager()
    -- Update terminal size
    local height, width = lfm_sys.get_terminal_size()
    screen_info.view_height = height - 1
    screen_info.view_width = width

    -- Calculate panel widths considering 3 vertical separators
    local usable_width = screen_info.view_width - 3 -- Account for left, middle, and right separators
    panel1.view_width = math.floor(usable_width / 2)
    panel2.view_width = usable_width - panel1.view_width

    -- Set panel heights (accounting for header and footer)
    panel1.view_height = screen_info.view_height - 4
    panel2.view_height = screen_info.view_height - 4

    -- Update scroll position for both panels
    update_scroll(panel1)
    update_scroll(panel2)

    lfm_scr.clear_screen()

    -- Draw the header section
    draw_header(panel1, panel2, active_panel)

    -- Draw the content of both panels
    draw_panels_content(panel1, panel2, active_panel)

    -- Draw the footer section
    draw_footer(panel1, panel2)
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

-- Function to open directory and update panel
local function open_dir(panel, target_path, prev_dir)
    -- Clear absolute path cache when changing directory
    lfm_files.clear_path_cache()
    -- Ensure root directory is represented as "/"
    panel.current_dir = target_path == "" and "/" or target_path
    panel.absolute_path = lfm_files.get_absolute_path(panel.current_dir)
    -- Load new directory items
    panel.items = lfm_files.get_directory_items(panel.current_dir)
    sort_items(panel.items)
    -- Restore position if exists, otherwise start from beginning
    if prev_dir then
        local prev_name = lfm_files.get_basename(prev_dir)
        local found = 1
        for i, item in ipairs(panel.items) do
            if item.name == prev_name then
                found = i
                break
            end
        end
        panel.selected_item = found
    else
        panel.selected_item = 1
    end
    panel.scroll_offset = 0
end

-- Function to handle Enter key press
local function handle_enter_key(current_panel)
    local selected = current_panel.items[current_panel.selected_item]
    if selected and selected.is_dir and lfm_files.check_permissions(selected.permissions, "read") then
        local target_path = selected.is_link and selected.link_target or selected.path
        if selected.name == ".." then
            open_dir(current_panel, target_path, current_panel.current_dir)
        else
            open_dir(current_panel, target_path)
        end
    end
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
        
        local key = lfm_sys.get_key()
        
        local current_panel = (active_panel == 1) and panel1 or panel2

        if key == "quit" then
            break
        elseif key == "up" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - 1)
        elseif key == "down" then
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + 1)
        elseif key == "pageup" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - current_panel.view_height)
        elseif key == "pagedown" then
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + current_panel.view_height)
        elseif key == "home" then
            current_panel.selected_item = 1
        elseif key == "end" then
            current_panel.selected_item = #current_panel.items
        elseif key == "enter" then
            handle_enter_key(current_panel)
        elseif key == "view" then
            local selected = current_panel.items[current_panel.selected_item]
            if selected and not selected.is_dir and lfm_files.check_permissions(selected.permissions, "read") then
                local target_path = selected.is_link and selected.link_target or selected.path
                lfm_view.view_file(target_path, screen_info.view_width, screen_info.view_height)
            end
        elseif key == "edit" then
            local selected = current_panel.items[current_panel.selected_item]
            if selected and not selected.is_dir and lfm_files.check_permissions(selected.permissions, "write") then
                -- If it's a symlink, use the link target path
                local target_path = selected.is_link and selected.link_target or selected.path
                edit_file(target_path)
            end
        elseif key == "refresh" then
            -- Clear absolute path cache
            lfm_files.clear_path_cache()

            current_panel.items = lfm_files.get_directory_items(current_panel.current_dir)
            sort_items(current_panel.items)
        elseif key == "tab" then
            active_panel = (active_panel == 1) and 2 or 1
        end
    end
end

-- Run program
main()