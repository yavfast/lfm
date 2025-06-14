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