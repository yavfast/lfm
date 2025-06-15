local M = {}

-- Execute a system command with LANG=C and return its output as string
function M.exec_command_output(command)
    local handle = io.popen('LANG=C ' .. command)
    if not handle then return nil end
    local output = handle:read("*a")
    handle:close()
    return output
end

function M.get_terminal_size()
    local output = M.exec_command_output("stty size")
    if output then
        local rows, cols = output:match("(%d+)%s+(%d+)")
        return tonumber(rows) or 24, tonumber(cols) or 80
    end
    return 24, 80
end

-- Convert to human readable format
function M.format_size(bytes)
    local units = {'', 'K', 'M', 'G', 'T'}
    local size = bytes
    local unit_index = 1
    while size > 1024 and unit_index < #units do
        size = size / 1024
        unit_index = unit_index + 1
    end

    if unit_index > 1 then
        return string.format("%.1f%s", size, units[unit_index])
    end

    return tostring(size)
end

-- Function to get RAM information
function M.get_ram_info()
    local output = M.exec_command_output("free")
    if output then
        local total, used = output:match("Mem:%s+(%d+)%s+(%d+)")
        if total and used then
            total = tonumber(total) * 1024
            used = tonumber(used) * 1024
            return "RAM: " .. M.format_size(used) .. " / " .. M.format_size(total)
        end
    end
    return "RAM: N/A"
end


-- Initialize terminal in raw mode
function M.init_terminal()
    os.execute("stty raw -echo")
end

-- Restore terminal to normal mode
function M.restore_terminal()
    os.execute("stty -raw echo")
end

-- Function to get key press (assumes terminal is already in raw mode)
function M.get_key()
    local key = io.read(1)
    if not key then return nil end

    if key == "\27" then -- ESC sequence
        local next1 = io.read(1)
        if next1 == "[" then
            local next2 = io.read(1)
            if next2 == "A" then
                return "up"
            elseif next2 == "B" then
                return "down"
            elseif next2 == "C" then
                return "right"
            elseif next2 == "D" then
                return "left"
            elseif next2 == "5" then -- PageUp
                local next3 = io.read(1)
                if next3 == "~" then
                    return "pageup"
                end
            elseif next2 == "6" then -- PageDown
                local next3 = io.read(1)
                if next3 == "~" then
                    return "pagedown"
                end
            elseif next2 == "H" then -- Home
                return "home"
            elseif next2 == "F" then -- End
                return "end"
            elseif next2 == "1" then
                local next3 = io.read(1)
                if next3 == ";" then
                    local next4 = io.read(1)
                    if next4 == "5" then
                        local next5 = io.read(1)
                        if next5 == "A" then
                            return "ctrl_up"
                        elseif next5 == "B" then
                            return "ctrl_down"
                        end
                    elseif next4 == "6" then -- Ctrl+Shift
                        local next5 = io.read(1)
                        if next5 == "A" then
                            return "ctrl_shift_up"
                        elseif next5 == "B" then
                            return "ctrl_shift_down"
                        end
                    end
                end
            elseif next2 == "2" then -- F10
                local next3 = io.read(1)
                if next3 == "1" then
                    local next4 = io.read(1)
                    if next4 == "~" then
                        return "quit"
                    end
                end
            end
        elseif next1 == "O" then -- F3, F4
            local next2 = io.read(1)
            if next2 == "R" then -- F3
                return "view"
            elseif next2 == "S" then -- F4
                return "edit"
            end
        end
        return nil -- Invalid escape sequence
    elseif key == "\13" then -- Enter
        return "enter"
    elseif key == "\18" then -- Ctrl+R (ASCII 18)
        return "refresh"
    elseif key == "\t" then -- Handle Tab key
        return "tab"
    else
        -- Return any other character as is
        return key
    end
end



return M