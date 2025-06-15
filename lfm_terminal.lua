-- lfm_terminal.lua
-- Terminal emulator functionality for LFM

local lfm_scr = require("lfm_scr")
local M = {}

-- Terminal state
local terminal_state = {
    command = "",
    output = "",
    cursor_pos = 1,
    history = {},
    history_pos = 0,
    view_offset = 0,
    content_height = 0  -- Store content height for calculations
}

-- Function to draw the terminal window
function M.draw_terminal(start_row, width, height)
    -- Draw terminal content area
    terminal_state.content_height = height - 1 -- Reserve one line for command input
    
    -- Get the lines of output to display
    local output_lines = {}
    -- Split output by newlines, ensuring we catch the last line even without a newline
    if terminal_state.output ~= "" then
        for line in (terminal_state.output .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(output_lines, line)
        end
    end
    
    -- Draw output area
    for i = 1, terminal_state.content_height do
        lfm_scr.move_cursor(start_row + i - 1, 1)
        
        -- Calculate which line to display based on view offset
        local line_idx = i + terminal_state.view_offset
        if line_idx <= #output_lines then
            local line = output_lines[line_idx]
            if #line > width then
                line = line:sub(1, width - 3) .. "..."
            end
            lfm_scr.draw_text_colored("bright_white", line)
            lfm_scr.draw_text(string.rep(" ", width - #line))
        else
            lfm_scr.draw_text(string.rep(" ", width))
        end
    end

    -- Draw command input line
    lfm_scr.move_cursor(start_row + height - 1, 1)
    lfm_scr.draw_text_colored("bright_blue", "$ ")
    
    local command_display = terminal_state.command
    local cursor_pos = terminal_state.cursor_pos
    local prompt_len = 2  -- length of "$ "
    
    -- Calculate visible portion of command
    local visible_width = width - prompt_len
    local display_start = 1
    if #command_display > visible_width then
        -- If cursor is beyond visible area, scroll the command
        if cursor_pos > visible_width then
            display_start = cursor_pos - visible_width + 1
        end
        command_display = command_display:sub(display_start, display_start + visible_width - 1)
        if display_start > 1 then
            command_display = "←" .. command_display:sub(2)
        end
        if display_start + visible_width <= #terminal_state.command then
            command_display = command_display:sub(1, -2) .. "→"
        end
    end
    
    -- Draw command text with cursor
    local cursor_screen_pos = cursor_pos - display_start + 1
    
    -- Draw text before cursor
    if cursor_screen_pos > 1 then
        local pre_cursor = command_display:sub(1, cursor_screen_pos - 1)
        lfm_scr.draw_text_colored("bright_white", pre_cursor)
    end
    
    -- Draw cursor character with inverted colors
    local cursor_char = command_display:sub(cursor_screen_pos, cursor_screen_pos)
    if cursor_char == "" then cursor_char = " " end
    lfm_scr.set_bg_color("gray")
    lfm_scr.draw_text_colored("black", cursor_char)
    lfm_scr.set_bg_color("black")
    
    -- Draw text after cursor
    if cursor_screen_pos < #command_display then
        local post_cursor = command_display:sub(cursor_screen_pos + 1)
        lfm_scr.draw_text_colored("bright_white", post_cursor)
    end
    
    -- Fill remaining space
    local remaining = visible_width - #command_display
    if remaining > 0 then
        lfm_scr.draw_text(string.rep(" ", remaining))
    end
end

-- Function to handle terminal input
function M.handle_input(char)
    if not char then return end
    
    if char == "enter" then
        -- Execute command
        if terminal_state.command ~= "" then
            table.insert(terminal_state.history, terminal_state.command)
            terminal_state.history_pos = #terminal_state.history + 1
            
            -- Execute the command and capture output
            -- Temporarily restore terminal mode for command execution
            os.execute("stty -raw echo")
            local handle = io.popen(terminal_state.command .. " 2>&1")
            if handle then
                local result = handle:read("*a")
                handle:close()
                
                -- Append command and output to terminal output
                terminal_state.output = terminal_state.output .. 
                    "\n$ " .. terminal_state.command .. "\n" .. result
                
                -- Reset command and cursor
                terminal_state.command = ""
                terminal_state.cursor_pos = 1
                
                -- Scroll to bottom after command execution
                M.scroll_output("bottom")
            end
            -- Return to raw mode after command execution
            os.execute("stty raw -echo")
        end
    elseif char == "ctrl_up" then -- Ctrl+Up (history)
        if terminal_state.history_pos > 1 then
            terminal_state.history_pos = terminal_state.history_pos - 1
            terminal_state.command = terminal_state.history[terminal_state.history_pos]
            terminal_state.cursor_pos = #terminal_state.command + 1
        end
    elseif char == "ctrl_down" then -- Ctrl+Down (history)
        if terminal_state.history_pos < #terminal_state.history then
            terminal_state.history_pos = terminal_state.history_pos + 1
            terminal_state.command = terminal_state.history[terminal_state.history_pos]
            terminal_state.cursor_pos = #terminal_state.command + 1
        elseif terminal_state.history_pos == #terminal_state.history then
            terminal_state.history_pos = terminal_state.history_pos + 1
            terminal_state.command = ""
            terminal_state.cursor_pos = 1
        end
    elseif char == "ctrl_shift_up" then -- Ctrl+Shift+Up (scroll output up)
        M.scroll_output("up")
    elseif char == "ctrl_shift_down" then -- Ctrl+Shift+Down (scroll output down)
        M.scroll_output("down")
    elseif char == "right" then -- Right arrow
        if terminal_state.cursor_pos <= #terminal_state.command then
            terminal_state.cursor_pos = terminal_state.cursor_pos + 1
        end
    elseif char == "left" then -- Left arrow
        if terminal_state.cursor_pos > 1 then
            terminal_state.cursor_pos = terminal_state.cursor_pos - 1
        end
    elseif char == "home" then -- Home
        terminal_state.cursor_pos = 1
    elseif char == "end" then -- End
        terminal_state.cursor_pos = #terminal_state.command + 1
    elseif char == "pageup" then -- Page Up
        M.scroll_output("up")
    elseif char == "pagedown" then -- Page Down
        M.scroll_output("down")
    elseif char == "\127" or char == "\b" then -- Backspace
        if terminal_state.cursor_pos > 1 then
            local pre = terminal_state.command:sub(1, terminal_state.cursor_pos - 2)
            local post = terminal_state.command:sub(terminal_state.cursor_pos)
            terminal_state.command = pre .. post
            terminal_state.cursor_pos = terminal_state.cursor_pos - 1
        end
    elseif #char == 1 and char >= " " then -- Printable characters
        -- Insert character at cursor position
        local pre = terminal_state.command:sub(1, terminal_state.cursor_pos - 1)
        local post = terminal_state.command:sub(terminal_state.cursor_pos)
        terminal_state.command = pre .. char .. post
        terminal_state.cursor_pos = terminal_state.cursor_pos + 1
    end
end

-- Function to scroll terminal output
function M.scroll_output(direction)
    local max_offset = M.get_max_scroll_offset()
    
    if direction == "up" then
        terminal_state.view_offset = math.min(max_offset, terminal_state.view_offset + 1)
    elseif direction == "down" then
        terminal_state.view_offset = math.max(0, terminal_state.view_offset - 1)
    elseif direction == "bottom" then
        terminal_state.view_offset = max_offset
    end
end

-- Function to check if command line has text
function M.has_command()
    return terminal_state.command ~= ""
end

-- Function to check if we're in command editing mode
function M.is_editing()
    return terminal_state.command ~= "" or terminal_state.history_pos > 0
end

-- Function to handle navigation keys when in edit mode
function M.handle_navigation_key(key)
    -- Only handle navigation if we're in edit mode or have output to scroll
    if not M.is_editing() and terminal_state.view_offset == 0 and terminal_state.output == "" then
        return false
    end

    if key == "left" then
        if terminal_state.cursor_pos > 1 then
            terminal_state.cursor_pos = terminal_state.cursor_pos - 1
            return true
        end
    elseif key == "right" then
        if terminal_state.cursor_pos <= #terminal_state.command then
            terminal_state.cursor_pos = terminal_state.cursor_pos + 1
            return true
        end
    elseif key == "home" then
        if terminal_state.cursor_pos > 1 then
            terminal_state.cursor_pos = 1
            return true
        end
    elseif key == "end" then
        if terminal_state.cursor_pos <= #terminal_state.command then
            terminal_state.cursor_pos = #terminal_state.command + 1
            return true
        end
    elseif key == "pageup" then
        -- Always handle page up if we have output to scroll
        if terminal_state.output ~= "" then
            M.scroll_output("up")
            return true
        end
    elseif key == "pagedown" then
        -- Handle page down only if we're scrolled up
        if terminal_state.view_offset > 0 then
            M.scroll_output("down")
            return true
        end
    end

    return false
end

-- Function to get output lines count
function M.get_output_lines_count()
    if terminal_state.output == "" then
        return 0
    end
    local count = 0
    for _ in (terminal_state.output .. "\n"):gmatch("([^\n]*)\n") do
        count = count + 1
    end
    return count
end

-- Function to get maximum scroll offset
function M.get_max_scroll_offset()
    local total_lines = M.get_output_lines_count()
    return math.max(0, total_lines - terminal_state.content_height)
end

return M
