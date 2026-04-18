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
local lfm_terminal = require("lfm_terminal")
local lfm_prompt = require("lfm_prompt")
local lfm_ops = require("lfm_ops")

-- Screen layout configuration
local screen_layout = {
    terminal_height_percent = 30, -- Terminal takes 30% of screen height
    main_height = 0,             -- Will be calculated
    terminal_height = 0,         -- Will be calculated
    terminal_start_row = 0       -- Will be calculated
}

-- Panel data structure.
--   `selected`       — set keyed by item name [SP_OPS_01_01].
--   `sort_by`        — "name" | "ext" | "size" | "date" [SP_DSP_01_01].
--   `sort_desc`      — descending direction flag [SP_DSP_01_01].
--   `show_hidden`    — include dotfile entries [SP_DSP_01_01].
local function new_panel()
    return {
        current_dir = ".",
        absolute_path = lfm_files.get_absolute_path("."),
        selected_item = 1,
        scroll_offset = 0,
        items = {},
        view_width = 0,
        view_height = 0,
        selected = {},
        sort_by = "name",
        sort_desc = false,
        show_hidden = false,
    }
end

-- Two panels
local panel1 = new_panel()
local panel2 = new_panel()

local screen_info = {
    view_height = 0,
    view_width = 0
}

local active_panel = 1 -- 1 for panel1, 2 for panel2

-- Count entries in a set (used for panel.selected).
local function count_set(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Extract the extension after the last dot; "" for names with no dot.
-- A leading dot is skipped so that ".hidden" has no ext (it's a dotfile name,
-- not an extension), while "a.tar.gz" still has ext "gz".
local function ext_of(name)
    local head = (name:sub(1, 1) == ".") and name:sub(2) or name
    return (head:match("%.([^.]+)$") or ""):lower()
end

-- [SP_DSP_02_02] Return a table.sort comparator using (mode, desc).
-- Invariants: ".." first; dirs before files; name-lower tiebreaker always asc.
local function sort_comparator(mode, desc)
    return function(a, b)
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        if a.is_dir ~= b.is_dir then return a.is_dir end

        local cmp = 0
        if mode == "size" then
            local sa, sb = tonumber(a.size) or 0, tonumber(b.size) or 0
            if sa < sb then cmp = -1 elseif sa > sb then cmp = 1 end
        elseif mode == "date" then
            local da, db = tonumber(a.modified) or 0, tonumber(b.modified) or 0
            if da < db then cmp = -1 elseif da > db then cmp = 1 end
        elseif mode == "ext" then
            local ea, eb = ext_of(a.name), ext_of(b.name)
            if ea < eb then cmp = -1 elseif ea > eb then cmp = 1 end
        else -- "name" (default)
            local na, nb = a.name:lower(), b.name:lower()
            if na < nb then cmp = -1 elseif na > nb then cmp = 1 end
        end
        if desc then cmp = -cmp end
        if cmp ~= 0 then return cmp < 0 end
        -- Deterministic tiebreaker: name ascending.
        return a.name:lower() < b.name:lower()
    end
end

-- [SP_DSP_02_03] Drop dotfile entries (except ".." synthetic) when show_hidden is false.
local function filter_hidden(items, show_hidden)
    if show_hidden then return items end
    local out = {}
    for _, it in ipairs(items) do
        if it.name == ".." or it.name:sub(1, 1) ~= "." then
            out[#out + 1] = it
        end
    end
    return out
end

local function sort_items(panel)
    table.sort(panel.items, sort_comparator(panel.sort_by, panel.sort_desc))
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

-- Function to draw hints at the bottom of the screen
local function draw_hints()
    -- Calculate the position after terminal area
    local hint_row = screen_layout.terminal_start_row + screen_layout.terminal_height
    lfm_scr.move_cursor(hint_row, 1)
    lfm_scr.draw_text_colored("gray", string.rep("-", screen_info.view_width))
    lfm_scr.move_cursor(hint_row + 1, 1)
    local hints = " F3:View F4:Edit F5:Copy F6:Move F7:Mkdir F8:Del F9:Opts F10:Quit"
    lfm_scr.draw_text_colored("gray", lfm_str.pad_string(hints, screen_info.view_width, true))
end

-- Build a position-marker string with optional selection count — [SP_OPS_04_02].
local function position_marker(panel)
    local sel = count_set(panel.selected)
    if sel > 0 then
        return string.format("[%d/%d,%d]", panel.selected_item - 1, #panel.items - 1, sel)
    end
    return string.format("[%d/%d]", panel.selected_item - 1, #panel.items - 1)
end

-- Function to draw the footer section (position info and hints)
local function draw_footer(panel1_info, panel2_info)
    -- Display hint with position info at the end of main area
    lfm_scr.move_cursor(screen_layout.main_height, 1)
    local position_info1 = position_marker(panel1_info)
    local position_info2 = position_marker(panel2_info)

    -- Draw left vertical separator
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 1 position info and padding
    lfm_scr.move_cursor(screen_layout.main_height, 2)
    lfm_scr.draw_text_colored("green", position_info1)

    local pad1 = panel1_info.view_width - #position_info1
    if pad1 < 0 then pad1 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad1))

    -- Draw vertical separator between panels
    lfm_scr.move_cursor(screen_layout.main_height, panel1_info.view_width + 2)
    lfm_scr.draw_text_colored("white", "|")

    -- Draw panel 2 position info and padding
    lfm_scr.move_cursor(screen_layout.main_height, panel1_info.view_width + 3)
    lfm_scr.draw_text_colored("green", position_info2)

    local pad2 = panel2_info.view_width - #position_info2
    if pad2 < 0 then pad2 = 0 end -- Ensure non-negative padding
    lfm_scr.draw_text_colored("white", string.rep("=", pad2))

    -- Draw right vertical separator
    lfm_scr.move_cursor(screen_layout.main_height, screen_info.view_width)
    lfm_scr.draw_text_colored("white", "|")
end

-- Function to draw the header section (LFM info, RAM info, and path separator)
local function draw_header(panel1_info, panel2_info, active_panel_idx)
    -- Display LFM and RAM information in the header
    local lfm_info = "Lua File Manager (v0.1)"
    local ram_info = lfm_sys.get_ram_info()
    lfm_scr.move_cursor(1, 1)  -- Ensure we start at the first line
    lfm_scr.draw_text_colored("bright_white", lfm_info)
    local pad = screen_info.view_width - #lfm_info - #ram_info
    if pad < 1 then pad = 1 end
    lfm_scr.draw_text(string.rep(" ", pad))
    lfm_scr.draw_text_colored("green", ram_info)
    lfm_scr.draw_text("\n")

    -- Move to the second line for path display
    lfm_scr.move_cursor(2, 1)

    -- Create path strings with proper truncation for panel 1
    local path_str1 = panel1_info.absolute_path
    if #path_str1 > panel1_info.view_width - 4 then
        path_str1 = "..." .. path_str1:sub(-(panel1_info.view_width - 7))
    end
    local sep1 = "[" .. path_str1 .. "]" .. string.rep("=", math.max(0, panel1_info.view_width - #path_str1 - 2))

    -- Create path strings with proper truncation for panel 2
    local path_str2 = panel2_info.absolute_path
    if #path_str2 > panel2_info.view_width - 4 then
        path_str2 = "..." .. path_str2:sub(-(panel2_info.view_width - 7))
    end
    local sep2 = "[" .. path_str2 .. "]" .. string.rep("=", math.max(0, panel2_info.view_width - #path_str2 - 2))

    -- Draw the paths with proper highlighting for active panel
    if active_panel_idx == 1 then
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text_colored("bright_white", sep1)
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text_colored("white", sep2)
    else
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text_colored("white", sep1)
        lfm_scr.draw_text_colored("white", "|")
        lfm_scr.draw_text_colored("bright_white", sep2)
    end
    lfm_scr.draw_text_colored("white", "|")
    lfm_scr.draw_text("\n")
end

-- Function to draw a single row of a panel
local function draw_panel_row(panel, row_index, start_col, is_active, panel_view_width)
    local item_index = row_index + panel.scroll_offset
    local item = panel.items[item_index]

    -- Draw panel content
    lfm_scr.move_cursor(2 + row_index, start_col)

    local is_selected = item_index == panel.selected_item
    if item then
        if is_selected and is_active then
            lfm_scr.set_bg_color("gray")
        else
            lfm_scr.set_bg_color("black")
        end

        -- Check if we have read permissions
        local has_read = lfm_files.check_permissions(item.permissions, "read")
        local is_executable = lfm_files.check_permissions(item.permissions, "execute")
        -- [SP_OPS_04_01] Multi-selected items render in yellow regardless of type.
        local is_marked = panel.selected and panel.selected[item.name]

        if not has_read then
            lfm_scr.draw_text_colored("red", " ")
        elseif item.is_dir then
            lfm_scr.draw_text_colored(is_marked and "bright_yellow" or "bright_white", "/")
        elseif is_executable then
            lfm_scr.draw_text_colored(is_marked and "bright_yellow" or "green", "*")
        else
            lfm_scr.draw_text_colored(is_marked and "bright_yellow" or "white", " ")
        end
        if is_marked then lfm_scr.set_color("bright_yellow") end

        -- Convert timestamp to readable date
        local date_str = ""
        if item.modified then
            local timestamp = tonumber(item.modified)
            if timestamp then
                date_str = tostring(os.date("%Y-%m-%d %H:%M", timestamp))
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
        local name_width = panel_view_width - date_width - size_width - 4

        local name_padded = lfm_str.pad_string(item.name, name_width, true)   -- left-aligned
        local size_padded = lfm_str.pad_string(size_str, size_width, false)   -- right-aligned
        local date_padded = lfm_str.pad_string(date_str, date_width, false)   -- right-aligned

        lfm_scr.draw_text(string.format("%s %s  %s", name_padded, size_padded, date_padded))

        if is_selected and is_active then
            lfm_scr.set_bg_color("black")
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
    screen_info.view_width = width

    -- Calculate heights
    local hints_height = 2  -- 1 for separator line, 1 for hints text
    screen_layout.terminal_height = math.floor(height * screen_layout.terminal_height_percent / 100)
    if screen_layout.terminal_height < 5 then screen_layout.terminal_height = 5 end -- Minimum terminal height
    
    -- Calculate main area height (remaining space after terminal and hints)
    screen_layout.main_height = height - screen_layout.terminal_height - hints_height
    screen_info.view_height = height -- Store full terminal height
    screen_layout.terminal_start_row = screen_layout.main_height + 1

    -- Calculate panel widths considering 3 vertical separators
    local usable_width = screen_info.view_width - 3 -- Account for left, middle, and right separators
    panel1.view_width = math.floor(usable_width / 2)
    panel2.view_width = usable_width - panel1.view_width

    -- Set panel heights (accounting for header (2 lines) and footer (1 line))
    panel1.view_height = screen_layout.main_height - 3
    panel2.view_height = screen_layout.main_height - 3

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

    -- Draw the terminal window
    lfm_terminal.draw_terminal(screen_layout.terminal_start_row, screen_info.view_width, screen_layout.terminal_height)

    -- Draw hints at the bottom
    draw_hints()
end

-- Function to edit file using vi
local function edit_file(path)
    -- Return terminal to normal mode before launching vi
    os.execute("stty -raw echo")
    
    -- Clear screen before launching vi
    lfm_scr.clear_screen()
    
    -- Launch vi editor
    os.execute("vi " .. lfm_sys.shell_quote(path))
    
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
    -- Load new directory items (respects panel's show_hidden and sort preferences).
    panel.items = filter_hidden(lfm_files.get_directory_items(panel.current_dir), panel.show_hidden)
    sort_items(panel)
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
    -- [SP_OPS_01_01] Selection is per-directory; clear on navigation.
    panel.selected = {}
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

-- Layout of the overlay prompt row — [C_OPS_03_02].
local function prompt_layout()
    return {
        row = screen_layout.terminal_start_row + screen_layout.terminal_height + 1,
        col = 1,
        cols = screen_info.view_width,
    }
end

-- [SP_OPS_06] Reduce panel state to the list of absolute paths we should act
-- on. Multi-selection wins; otherwise the cursor item. `..` is never included.
local function resolve_targets(panel)
    local out = {}
    if panel.selected then
        for name, _ in pairs(panel.selected) do
            if name ~= ".." then
                for _, it in ipairs(panel.items) do
                    if it.name == name then
                        out[#out + 1] = it.path
                        break
                    end
                end
            end
        end
    end
    if #out == 0 then
        local it = panel.items[panel.selected_item]
        if it and it.name ~= ".." then out[#out + 1] = it.path end
    end
    return out
end

-- Refresh both panels in place, preserving cursor-by-name AND selection sets —
-- [SP_OPS_01_01] says selection survives a Ctrl+R on the same directory.
local function refresh_panels()
    local sel1, sel2 = panel1.selected or {}, panel2.selected or {}
    local cur1 = panel1.items[panel1.selected_item]
    local cur2 = panel2.items[panel2.selected_item]
    open_dir(panel1, panel1.current_dir, cur1 and cur1.name or nil)
    open_dir(panel2, panel2.current_dir, cur2 and cur2.name or nil)
    -- Restore only names that still exist after the op.
    local function restore(p, prev)
        for _, it in ipairs(p.items) do
            if prev[it.name] and it.name ~= ".." then p.selected[it.name] = true end
        end
    end
    restore(panel1, sel1)
    restore(panel2, sel2)
end

local function inactive()
    return (active_panel == 1) and panel2 or panel1
end

-- [SP_DSP_03_04] Render the current sort state as "<mode><arrow>".
local function sort_label(panel)
    local arrow = panel.sort_desc and "\226\134\147" or "\226\134\145"  -- ↓ / ↑ in UTF-8
    return panel.sort_by .. arrow
end

-- [SP_DSP_03_03] Sort sub-menu. Returns true if an action was taken (parent
-- menu should close) or false if the user hit Esc (parent should re-open).
local function handle_sort_menu(panel)
    local label = "Sort by (current " .. sort_label(panel) .. "):"
    local items = {
        { key = "n", text = "name" },
        { key = "e", text = "ext" },
        { key = "s", text = "size" },
        { key = "d", text = "date" },
        { key = "r", text = "reverse" },
    }
    local ch = lfm_prompt.menu(label, items, prompt_layout())
    if ch == nil then return false end
    local mode_map = { n = "name", e = "ext", s = "size", d = "date" }
    if ch == "r" then
        panel.sort_desc = not panel.sort_desc
    else
        local new_mode = mode_map[ch]
        if new_mode == panel.sort_by then
            panel.sort_desc = not panel.sort_desc
        else
            panel.sort_by = new_mode
            panel.sort_desc = false
        end
    end
    -- Capture the cursor's current item BEFORE sort so we can restore by name.
    local cur = panel.items[panel.selected_item]
    sort_items(panel)
    if cur then
        for i, it in ipairs(panel.items) do
            if it.name == cur.name then panel.selected_item = i; break end
        end
    end
    return true
end

-- [SP_DSP_03_02] Top-level options menu. Loops so that Esc from a sub-menu
-- re-opens this parent; any direct action closes.
local function handle_display_menu(panel)
    while true do
        local items = {
            { key = "1", text = "Sort: " .. sort_label(panel) },
            { key = "2", text = "Hidden: " .. (panel.show_hidden and "on" or "off") },
            { key = "3", text = "Sync paths" },
        }
        local ch = lfm_prompt.menu("Options:", items, prompt_layout())
        if ch == nil then return end
        if ch == "1" then
            if handle_sort_menu(panel) then return end
            -- else: loop → re-render parent
        elseif ch == "2" then
            panel.show_hidden = not panel.show_hidden
            -- Toggle requires re-fetching; refresh both panels (other panel
            -- may be in same directory and benefits from consistent view).
            refresh_panels()
            return
        elseif ch == "3" then
            -- Sync: inactive panel adopts the active panel's path. Short-circuit
            -- when paths already match so we don't clobber the inactive panel's
            -- multi-selection (open_dir always resets panel.selected).
            local inact = inactive()
            if inact.current_dir ~= panel.current_dir then
                open_dir(inact, panel.current_dir)
            end
            return
        end
    end
end

-- Wrap any op that displays modal UI: ensures the full frame is repainted
-- afterwards and that a failure surfaces as an on-screen error.
local function after_op(result)
    if not result.ok and result.error_line then
        lfm_prompt.show_error(result.error_line, prompt_layout())
    end
end

-- Function to handle navigation and file operations
local function handle_navigation_key(key)
    local current_panel = (active_panel == 1) and panel1 or panel2

    if key == "up" or key == "down" then
        if key == "up" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - 1)
        else
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + 1)
        end
        return true
    elseif key == "pageup" or key == "pagedown" or key == "home" or key == "end" then
        if key == "pageup" then
            current_panel.selected_item = math.max(1, current_panel.selected_item - current_panel.view_height)
        elseif key == "pagedown" then
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + current_panel.view_height)
        elseif key == "home" then
            current_panel.selected_item = 1
        elseif key == "end" then
            current_panel.selected_item = #current_panel.items
        end
        return true
    elseif key == "tab" then
        active_panel = active_panel == 1 and 2 or 1
        return true
    elseif key == "enter" then
        handle_enter_key(current_panel)
        return true
    elseif key == "view" then -- F3
        local selected = current_panel.items[current_panel.selected_item]
        if selected and not selected.is_dir and lfm_files.check_permissions(selected.permissions, "read") then
            -- Temporarily restore terminal mode for external viewer
            lfm_sys.restore_terminal()
            local target_path = selected.is_link and selected.link_target or selected.path
            lfm_view.view_file(target_path, screen_info.view_width, screen_info.view_height)
            -- Re-initialize terminal for raw input after viewer exits
            lfm_sys.init_terminal()
        end
        return true
    elseif key == "edit" then -- F4
        local selected = current_panel.items[current_panel.selected_item]
        if selected and not selected.is_dir and lfm_files.check_permissions(selected.permissions, "write") then
            -- Temporarily restore terminal mode for editor
            lfm_sys.restore_terminal()
            local target_path = selected.is_link and selected.link_target or selected.path
            edit_file(target_path)
            -- Re-initialize terminal for raw input after editor exits
            lfm_sys.init_terminal()
        end
        return true
    elseif key == "refresh" then -- Ctrl+R
        refresh_panels()
        return true
    elseif key == "insert" then -- [SP_OPS_03_01] toggle multi-select + advance
        local it = current_panel.items[current_panel.selected_item]
        if it and it.name ~= ".." then
            current_panel.selected[it.name] = (not current_panel.selected[it.name]) or nil
            current_panel.selected_item = math.min(#current_panel.items, current_panel.selected_item + 1)
        end
        return true
    elseif key == "swap_panels" then -- [SP_OPS_03_01] Ctrl+U swap
        local p1, p2 = panel1, panel2
        for k, v in pairs(p2) do local t = p1[k]; p1[k] = v; p2[k] = t end
        -- Keep the active side visually active — flip index to follow the data.
        active_panel = active_panel == 1 and 2 or 1
        return true
    elseif key == "copy" then -- F5
        local targets = resolve_targets(current_panel)
        if #targets == 0 then return true end
        local default = inactive().absolute_path
        local dest = lfm_prompt.prompt_text("Copy to:", default, prompt_layout())
        if dest and dest ~= "" then
            after_op(lfm_ops.copy(targets, dest))
            current_panel.selected = {}
            refresh_panels()
        end
        return true
    elseif key == "move" then -- F6
        local targets = resolve_targets(current_panel)
        if #targets == 0 then return true end
        local default = inactive().absolute_path
        local dest = lfm_prompt.prompt_text("Move to:", default, prompt_layout())
        if dest and dest ~= "" then
            after_op(lfm_ops.move(targets, dest))
            current_panel.selected = {}
            refresh_panels()
        end
        return true
    elseif key == "mkdir" then -- F7
        local name = lfm_prompt.prompt_text("New directory:", "", prompt_layout())
        if name and name ~= "" then
            local full
            if name:sub(1, 1) == "/" then
                full = name
            else
                local base = current_panel.absolute_path
                if base:sub(-1) ~= "/" then base = base .. "/" end
                full = base .. name
            end
            after_op(lfm_ops.mkdir(full))
            refresh_panels()
        end
        return true
    elseif key == "delete_key" then -- F8 / Delete
        local targets = resolve_targets(current_panel)
        if #targets == 0 then return true end
        local label = string.format("Delete %d item(s)? [y/N]", #targets)
        if lfm_prompt.confirm(label, prompt_layout()) then
            after_op(lfm_ops.remove(targets))
            current_panel.selected = {}
            refresh_panels()
        end
        return true
    elseif key == "options" then -- F9 [SP_DSP_03_02]
        handle_display_menu(current_panel)
        return true
    elseif type(key) == "string" and key:sub(1, 4) == "alt_" then
        -- [SP_NAV_02_01] Alt+letter: jump to next item starting with that letter.
        local letter = key:sub(5)
        if #letter == 1 and letter:match("[a-z]") then
            local n = #current_panel.items
            if n > 0 then
                local start = current_panel.selected_item + 1
                for offset = 0, n - 1 do
                    local i = ((start - 1 + offset) % n) + 1
                    local it = current_panel.items[i]
                    if it and it.name ~= ".." and it.name:sub(1, 1) ~= "."
                        and it.name:sub(1, 1):lower() == letter then
                        current_panel.selected_item = i
                        break
                    end
                end
            end
        end
        return true
    end

    return false
end

-- Function to run the main event loop
local function main()
    -- Clear terminal before starting
    os.execute("clear")
    
    -- Initial load of directory items for both panels
    panel1.items = filter_hidden(lfm_files.get_directory_items(panel1.current_dir), panel1.show_hidden)
    sort_items(panel1)
    panel1.absolute_path = lfm_files.get_absolute_path(panel1.current_dir)

    panel2.current_dir = panel1.current_dir -- Start panel2 in the same directory
    panel2.items = filter_hidden(lfm_files.get_directory_items(panel2.current_dir), panel2.show_hidden)
    sort_items(panel2)
    panel2.absolute_path = lfm_files.get_absolute_path(panel2.current_dir)
    
    -- Initialize terminal for raw input
    lfm_sys.init_terminal()
    
    while true do
        display_file_manager()
        
        -- Get key input (terminal is already in raw mode)
        local key = lfm_sys.get_key()
        
        if key then
            if key == "quit" then -- F10
                break
            else
                -- [SP_NAV_01_02] Alt+<letter> is always a panel action, even when
                -- the terminal widget has pending command text.
                local force_panel = type(key) == "string" and key:sub(1, 4) == "alt_"
                local panel_try = force_panel or not lfm_terminal.has_command()
                if not panel_try or not handle_navigation_key(key) then
                    -- Try terminal navigation first
                    if not lfm_terminal.handle_navigation_key(key) then
                        -- All other characters go to terminal
                        lfm_terminal.handle_input(key)
                    end
                end
            end
        end
    end
    
    -- Clean up and restore terminal mode before exit
    lfm_sys.restore_terminal()
end

-- [C_LFM_03_02] Run program with a safety net: any unhandled error must not leave
-- the tty in raw mode or the alt-screen buffer active.
local ok, err = xpcall(main, debug.traceback)
if not ok then
    lfm_scr.exit_fullscreen()
    lfm_sys.restore_terminal()
    io.stderr:write("lfm: fatal error\n" .. tostring(err) .. "\n")
    os.exit(1)
end