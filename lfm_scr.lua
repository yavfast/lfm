-- lfm_files.lua
-- Files function for LFM (Lua File Manager)

local M = {}

function M.clear_screen()
    io.write("\27[2J\27[H")
end

-- Function to move cursor
function M.move_cursor(row, col)
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
function M.set_color(color)
    io.write("\27[" .. (colors[color] or "0") .. "m")
end

-- Function to draw colored text
function M.draw_text(text)
    io.write(text)
end

-- Function to draw colored text
function M.draw_text_xy(row, col, text)
    M.move_cursor(row, col)
    M.draw_text(text)
end

-- Function to draw colored text
function M.draw_text_colored(color, text)
    M.set_color(color)
    M.draw_text(text)
end


return M
