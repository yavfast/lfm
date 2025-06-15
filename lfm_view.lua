-- lfm_view.lua
-- File viewer for LFM

local lfm_files = require("lfm_files")
local lfm_scr = require("lfm_scr")
local lfm_sys = require("lfm_sys")

local M = {}

M.view_file = function(path, view_width, view_height)
    local handle = io.open(path, "r")
    if not handle then
        return
    end
    local content = handle:read("*a")
    handle:close()

    -- Initialize terminal
    lfm_sys.init_terminal()
    -- Enter fullscreen mode
    lfm_scr.enter_fullscreen()
    
    local absolute_path = lfm_files.get_absolute_path(path)
    lfm_scr.clear_screen()

    -- Display header
    lfm_scr.move_cursor(1, 1)
    lfm_scr.draw_text_colored("bright_blue", "View file: " .. absolute_path)
    lfm_scr.move_cursor(2, 1)
    lfm_scr.draw_text_colored("gray", string.rep("=", view_width))
    lfm_scr.set_color("white")

    local lines = {}
    for line in content:gmatch("[^\r\n]*\r?\n?") do
        line = line:gsub("\r?\n$", "")
        table.insert(lines, line)
    end

    local current_line = 1
    local current_col = 0
    local header_height = 2
    local footer_height = 2
    local max_lines = view_height - header_height - footer_height

    while true do
        -- Clear view area
        for i = 1, max_lines do
            lfm_scr.move_cursor(header_height + i, 1)
            lfm_scr.draw_text_colored("white", string.rep(" ", view_width))
        end

        -- Draw content
        for i = 1, max_lines do
            local line_num = current_line + i - 1
            if line_num <= #lines then
                lfm_scr.move_cursor(header_height + i, 1)
                local line = lines[line_num]
                if line then
                    if current_col > 0 then
                        line = line:sub(current_col + 1)
                    end
                    if #line > view_width then
                        line = line:sub(1, view_width - 3) .. "..."
                    end
                    lfm_scr.draw_text_colored("white", line)
                end
            end
        end

        -- Draw footer
        lfm_scr.move_cursor(view_height - 1, 1)
        local position_info = string.format("[%d-%d/%d] ", current_line, current_line + max_lines - 1, #lines)
        lfm_scr.draw_text_colored("green", position_info)
        lfm_scr.draw_text_colored("gray", string.rep("=", view_width - #position_info))
        lfm_scr.move_cursor(view_height, 1)
        lfm_scr.draw_text_colored("gray", " Up/Down/Left/Right: Scroll | PgUp/PgDn: Page | Home/End: Top/Bottom | ESC,q: Exit")
        io.flush()  -- Ensure all text is displayed

        local key = lfm_sys.get_key()
        if key == "q" or key == "escape" then
            break
        elseif key == "up" then
            current_line = math.max(1, current_line - 1)
        elseif key == "down" and current_line < #lines then
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
    end

    -- Cleanup
    lfm_scr.exit_fullscreen()
    lfm_sys.restore_terminal()
end

return M
