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

-- Function to get RAM information
function M.get_ram_info()
    local output = M.exec_command_output("free")
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


-- Function to get key press
function M.get_key()
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



return M