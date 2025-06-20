-- lfm_files.lua
-- Files function for LFM (Lua File Manager)

local M = {}

-- Enter alternative screen buffer
function M.enter_fullscreen()
    io.write("\27[?1049h")  -- Enter alternative screen buffer
    io.write("\27[?25l")    -- Hide cursor
    io.flush()
end

-- Exit alternative screen buffer
function M.exit_fullscreen()
    io.write("\27[?25h")    -- Show cursor
    io.write("\27[?1049l")  -- Exit alternative screen buffer
    io.flush()
end

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

local bg_colors = {
    black = "40",
    red = "41",
    green = "42",
    yellow = "43",
    blue = "44",
    white = "47",
    gray = "100"
}

-- Function to set background color
function M.set_bg_color(color)
    io.write("\27[" .. (bg_colors[color] or "0") .. "m")
end

-- Function to reset all colors
function M.reset_colors()
    io.write("\27[0m")
end

-- Function to draw colored text with background
function M.draw_text_with_bg(fg_color, bg_color, text)
    M.set_color(fg_color)
    M.set_bg_color(bg_color)
    M.draw_text(text)
    M.reset_colors()
end

return M
