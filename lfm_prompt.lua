-- lfm_prompt.lua
-- Modal single-line overlay: text input, y/N confirm, error message.
-- See [C_OPS_03_02] and [SP_OPS_02_05..07]. Terminal is assumed to be in raw
-- mode already (set by lfm_sys.init_terminal).

local M = {}
local lfm_sys = require("lfm_sys")
local lfm_scr = require("lfm_scr")
local lfm_str = require("lfm_str")

-- How many follow-up bytes are expected after `byte` to form one UTF-8 codepoint.
-- On invalid bytes we conservatively treat them as standalone — the caller keeps
-- moving instead of hanging.
local function utf8_expected_length(byte)
    if byte < 0x80 then return 1
    elseif byte >= 0xC2 and byte < 0xE0 then return 2
    elseif byte >= 0xE0 and byte < 0xF0 then return 3
    elseif byte >= 0xF0 and byte < 0xF8 then return 4
    else return 1 end
end

-- Split a UTF-8 string into an array of per-codepoint sub-strings.
local function to_char_array(s)
    local out = {}
    local i = 1
    while i <= #s do
        local n = utf8_expected_length(s:byte(i))
        out[#out + 1] = s:sub(i, i + n - 1)
        i = i + n
    end
    return out
end

local function chars_to_string(chars, from, to)
    from = from or 1
    to = to or #chars
    if from > to then return "" end
    return table.concat(chars, "", from, to)
end

-- Render label + editable buffer + block-cursor at layout.row, clearing the
-- rest of the row. Truncates from the left if label+buffer is wider than
-- layout.cols so the cursor is always visible.
local function render(label, chars, cursor, layout)
    local prefix = label .. " "
    local prefix_w = lfm_str.get_string_width(prefix)

    local before = chars_to_string(chars, 1, cursor)
    local after  = chars_to_string(chars, cursor + 1)

    local before_w = lfm_str.get_string_width(before)
    local after_w  = lfm_str.get_string_width(after)
    local cursor_glyph_w = 1 -- the block-cursor cell itself

    -- Budget for the editable part (after the label).
    local budget = layout.cols - prefix_w - 1
    if budget < 1 then budget = 1 end

    -- If total edit content exceeds budget, scroll so the cursor stays visible
    -- with a small left-of-cursor margin.
    local visible_before = before
    local visible_after  = after
    if before_w + cursor_glyph_w + after_w > budget then
        -- Scroll window: show as much to the right as possible while keeping
        -- the cursor within budget.
        local max_before = budget - cursor_glyph_w
        if before_w > max_before then
            -- Trim from the left codepoint-by-codepoint.
            local drop = 0
            while lfm_str.get_string_width(before:sub(drop + 1)) > max_before do
                -- Advance past one codepoint.
                local b = before:byte(drop + 1) or 0
                drop = drop + utf8_expected_length(b)
                if drop >= #before then break end
            end
            visible_before = before:sub(drop + 1)
        end
        local max_after = budget - lfm_str.get_string_width(visible_before) - cursor_glyph_w
        if max_after < 0 then max_after = 0 end
        if lfm_str.get_string_width(visible_after) > max_after then
            -- Trim from the right.
            local keep = 0
            local acc_w = 0
            local i = 1
            while i <= #after do
                local b = after:byte(i)
                local n = utf8_expected_length(b)
                local ch = after:sub(i, i + n - 1)
                local w = lfm_str.get_string_width(ch)
                if acc_w + w > max_after then break end
                acc_w = acc_w + w
                keep = i + n - 1
                i = i + n
            end
            visible_after = after:sub(1, keep)
        end
    end

    lfm_scr.move_cursor(layout.row, 1)
    lfm_scr.set_bg_color("black")
    lfm_scr.set_color("bright_white")
    lfm_scr.draw_text(prefix)
    lfm_scr.set_color("white")
    lfm_scr.draw_text(visible_before)

    -- Block cursor: show next char (or space) with inverted background.
    local cursor_char = chars[cursor + 1]
    if cursor_char then
        -- Drop the first codepoint from visible_after, since it's being drawn
        -- as the cursor.
        local n = utf8_expected_length(visible_after:byte(1) or 0)
        visible_after = visible_after:sub(n + 1)
    end
    lfm_scr.set_bg_color("gray")
    lfm_scr.draw_text(cursor_char or " ")
    lfm_scr.set_bg_color("black")
    lfm_scr.draw_text(visible_after)

    -- Clear trailing cells.
    local drawn_w = prefix_w
        + lfm_str.get_string_width(visible_before)
        + 1
        + lfm_str.get_string_width(visible_after)
    local pad = layout.cols - drawn_w
    if pad > 0 then lfm_scr.draw_text(string.rep(" ", pad)) end

    lfm_scr.reset_colors()
    io.flush()
end

-- [SP_OPS_02_05] Text input prompt. Returns entered string (possibly empty) on
-- Enter or nil on Escape.
function M.prompt_text(label, initial, layout)
    local chars = to_char_array(initial or "")
    local cursor = #chars

    -- UTF-8 accumulator across get_key() calls (raw mode returns one byte at a
    -- time for multi-byte codepoints).
    local pending = ""
    local pending_need = 0

    while true do
        render(label, chars, cursor, layout)
        local key = lfm_sys.get_key()
        if key == nil then
            -- no-op; loop again
        elseif key == "enter" then
            return chars_to_string(chars)
        elseif key == "escape" then
            return nil
        elseif key == "left" then
            if cursor > 0 then cursor = cursor - 1 end
            pending = ""; pending_need = 0
        elseif key == "right" then
            if cursor < #chars then cursor = cursor + 1 end
            pending = ""; pending_need = 0
        elseif key == "home" then
            cursor = 0
            pending = ""; pending_need = 0
        elseif key == "end" then
            cursor = #chars
            pending = ""; pending_need = 0
        elseif key == "\127" or key == "\8" then
            -- Backspace
            if cursor > 0 then
                table.remove(chars, cursor)
                cursor = cursor - 1
            end
            pending = ""; pending_need = 0
        elseif #key == 1 then
            local b = key:byte(1)
            if pending_need > 0 then
                -- Continuation byte expected
                if b >= 0x80 and b < 0xC0 then
                    pending = pending .. key
                    pending_need = pending_need - 1
                    if pending_need == 0 then
                        cursor = cursor + 1
                        table.insert(chars, cursor, pending)
                        pending = ""
                    end
                else
                    -- Stray: abandon pending, re-process this byte.
                    pending = ""; pending_need = 0
                    -- fall through by recursing the single-byte path
                    if b >= 0x20 and b < 0x7F then
                        cursor = cursor + 1
                        table.insert(chars, cursor, key)
                    end
                end
            elseif b >= 0x20 and b < 0x7F then
                -- Printable ASCII
                cursor = cursor + 1
                table.insert(chars, cursor, key)
            elseif b >= 0x80 then
                local need = utf8_expected_length(b)
                if need == 1 then
                    -- Lone continuation byte — ignore.
                else
                    pending = key
                    pending_need = need - 1
                    if pending_need == 0 then
                        cursor = cursor + 1
                        table.insert(chars, cursor, pending)
                        pending = ""
                    end
                end
            end
            -- Ignore other control bytes (Ctrl+*, Tab, etc.) inside prompt.
        end
    end
end

-- [SP_OPS_02_06] Yes/No confirm. Returns true only on 'y' or 'Y'.
function M.confirm(label, layout)
    lfm_scr.move_cursor(layout.row, 1)
    lfm_scr.set_bg_color("black")
    lfm_scr.set_color("bright_yellow")
    local text = label
    local pad = layout.cols - lfm_str.get_string_width(text)
    if pad < 0 then pad = 0 end
    lfm_scr.draw_text(text .. string.rep(" ", pad))
    lfm_scr.reset_colors()
    io.flush()

    while true do
        local key = lfm_sys.get_key()
        if key == "y" or key == "Y" then return true end
        if key ~= nil then return false end
    end
end

-- [SP_DSP_02_01] Single-row menu: shows "<label>  (k1) text1  (k2) text2 …  Esc=cancel"
-- Returns the chosen key string, or nil on Escape. Other keys are ignored.
function M.menu(label, items, layout)
    local parts = {}
    for _, it in ipairs(items) do
        parts[#parts + 1] = "(" .. it.key .. ") " .. it.text
    end
    local content = label .. "  " .. table.concat(parts, "  ") .. "  Esc=cancel"

    local w = lfm_str.get_string_width(content)
    if w > layout.cols then
        -- Truncate codepoint-by-codepoint so we don't slice a UTF-8 sequence.
        local keep = 0
        local acc_w = 0
        local i = 1
        while i <= #content do
            local b = content:byte(i)
            local n = utf8_expected_length(b)
            local ch = content:sub(i, i + n - 1)
            local cw = lfm_str.get_string_width(ch)
            if acc_w + cw + 1 > layout.cols then break end
            acc_w = acc_w + cw
            keep = i + n - 1
            i = i + n
        end
        content = content:sub(1, keep) .. "~"
        w = lfm_str.get_string_width(content)
    end

    lfm_scr.move_cursor(layout.row, 1)
    lfm_scr.set_bg_color("black")
    lfm_scr.set_color("bright_white")
    lfm_scr.draw_text(content)
    local pad = layout.cols - w
    if pad > 0 then
        lfm_scr.set_color("white")
        lfm_scr.draw_text(string.rep(" ", pad))
    end
    lfm_scr.reset_colors()
    io.flush()

    -- Build an allowed-keys lookup once.
    local allowed = {}
    for _, it in ipairs(items) do allowed[it.key] = true end

    while true do
        local key = lfm_sys.get_key()
        if key == "escape" then return nil end
        if key and allowed[key] then return key end
        -- ignore all other keys
    end
end

-- [SP_OPS_02_07] Error banner — red on the hints row, dismissed by any key.
function M.show_error(message, layout)
    lfm_scr.move_cursor(layout.row, 1)
    lfm_scr.set_bg_color("black")
    lfm_scr.set_color("bright_red")
    local text = "! " .. message .. "  (press any key)"
    local w = lfm_str.get_string_width(text)
    if w > layout.cols then
        -- Truncate by bytes; good enough for an error banner.
        text = text:sub(1, layout.cols - 1) .. "~"
    else
        text = text .. string.rep(" ", layout.cols - w)
    end
    lfm_scr.draw_text(text)
    lfm_scr.reset_colors()
    io.flush()

    while true do
        local key = lfm_sys.get_key()
        if key ~= nil then return end
    end
end

return M
