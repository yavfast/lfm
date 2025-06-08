#!/usr/bin/env lua

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
    local handle = io.popen('realpath "' .. path .. '"')
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
    
    if path ~= "/" then
        local parent_path = path:match("(.*)/[^/]*$") or "/"
        table.insert(items, {
            name = "..",
            path = parent_path,
            is_dir = true,
            permissions = "",
            size = "0",
            modified = ""
        })
    end
    
    local handle = io.popen('LANG=C stat -c "%F|%n|%s|%Y|%A" "' .. path .. '"/* 2>/dev/null')
    if handle then
        for line in handle:lines() do
            local file_type, name, size, timestamp, permissions = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
            if name then
                -- Extract only filename without path
                local filename = name:match("([^/]+)$")
                local is_dir = file_type:match("directory")
                if filename ~= "." and filename ~= ".." then
                    table.insert(items, {
                        name = filename,
                        path = path .. "/" .. filename,
                        is_dir = is_dir,
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
    
    -- Clear screen
    clear_screen()
    
    -- Display header
    set_color("bright_blue")
    print("View file: " .. path)
    set_color("reset")
    print(string.rep("─", view_width))
    
    -- Display content
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        if line then
            table.insert(lines, line)
        end
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
        print(string.rep("─", view_width - #position_info))
        print("Up/Down: Scroll | Left/Right: Horizontal scroll | q: Return to file manager")
        
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
    print(string.rep("─", view_width))
    
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
            
            if item.is_dir then
                set_color("bright_blue")
            else
                set_color("white")
            end
            
            local size_str = item.is_dir and "<DIR>" or (item.size or "0")
            io.write(string.format("%-60s %10s", item.name, size_str))
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
    print(string.rep("─", view_width - #position_info))
    print("Up/Down: Navigate | Enter: Open directory | v: View file | q: Quit")
end

-- Main loop
local function main()
    while true do
        items = get_directory_items(current_dir)
        sort_items(items)
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
            if selected and selected.is_dir then
                -- Save current position before changing directory
                dir_positions[current_dir] = selected_item
                
                current_dir = selected.path
                absolute_path = get_absolute_path(current_dir)
                
                -- Restore position if exists, otherwise start from beginning
                selected_item = dir_positions[current_dir] or 1
                scroll_offset = 0
            end
        elseif key == "view" then
            local selected = items[selected_item]
            if selected and not selected.is_dir then
                view_file(selected.path)
            end
        end
    end
end

-- Run program
main() 