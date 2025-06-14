-- lfm_view.lua
-- File viewer for LFM

local lfm_files = require("lfm_files")
local lfm_scr = require("lfm_scr")
local lfm_sys = require("lfm_sys")

local M = {}

M.view_file = function(path, view_width, view_height, HEADER_LINES)
    local handle = io.open(path, "r")
    if not handle then
        return
    end
    local content = handle:read("*a")
    handle:close()
    local absolute_path = lfm_files.get_absolute_path(path)
    lfm_scr.clear_screen()
    lfm_scr.draw_text_colored("bright_blue", "View file: " .. absolute_path .. "\n")
    lfm_scr.draw_text_colored("gray", string.rep("=", view_width) .. "\n")
    lfm_scr.set_color("white")
    local lines = {}
    for line in content:gmatch("[^\r\n]*\r?\n?") do
        line = line:gsub("\r?\n$", "")
        table.insert(lines, line)
    end
    local current_line = 1
    local current_col = 0
    local max_lines = view_height
    while true do
        for i = 1, max_lines do
            lfm_scr.move_cursor(HEADER_LINES + i, 1)
            lfm_scr.draw_text_colored("white", string.rep(" ", view_width))
        end
        for i = 1, max_lines do
            local line_num = current_line + i - 1
            if line_num <= #lines then
                lfm_scr.move_cursor(HEADER_LINES + i, 1)
                local line = lines[line_num]
                if line then
                    if current_col > 0 then
                        line = line:sub(current_col + 1)
                    end
                    if #line > view_width then
                        line = line:sub(1, view_width - 3) .. "..."
                    end
                    lfm_scr.draw_text_colored("white", line .. "\n")
                end
            end
        end
        lfm_scr.move_cursor(view_height + HEADER_LINES + 1, 1)
        local position_info = string.format("[%d-%d/%d] ", current_line, current_line + max_lines - 1, #lines)
        lfm_scr.draw_text_colored("green", position_info)
        lfm_scr.draw_text_colored("gray", string.rep("=", view_width - #position_info) .. "\n")
        lfm_scr.draw_text_colored("gray", "Up/Down: scroll  Left/Right: horiz scroll  PgUp/PgDn: page  Home/End: top/bottom  q: back\n")
        local key = lfm_sys.get_key()
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
            current_col = current_col + 10
        end
        current_line = math.max(1, current_line)
    end
end

return M

