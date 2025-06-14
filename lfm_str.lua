local M = {}

-- Function to calculate string width considering Unicode characters
function M.get_string_width(str)
    -- Handle nil
    if not str then return 0 end

    local width = 0
    local i = 1
    while i <= #str do
        local byte = str:byte(i)
        local char_len = 1

        if byte >= 0xE0 and byte <= 0xEF then
            -- 3-byte sequence
            char_len = 3
            local codepoint = ((byte * 0x1000) + (str:byte(i + 1) * 0x40) + str:byte(i + 2)) - 0xE0 * 0x1000

            -- Check for wide characters (CJK, etc)
            if  (codepoint >= 0x1100 and codepoint <= 0x115F) or    -- Hangul Jamo
                (codepoint >= 0x2E80 and codepoint <= 0x9FFF) or    -- CJK
                (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or    -- Hangul Syllables
                (codepoint >= 0xF900 and codepoint <= 0xFAFF) or    -- CJK Compatibility
                (codepoint >= 0xFE10 and codepoint <= 0xFE19) or    -- Vertical forms
                (codepoint >= 0xFE30 and codepoint <= 0xFE6F) or    -- CJK Compatibility Forms
                (codepoint >= 0xFF00 and codepoint <= 0xFF60) or    -- Fullwidth Forms
                (codepoint >= 0xFFE0 and codepoint <= 0xFFE6) then  -- Fullwidth Signs
                width = width + 2
            else
                width = width + 1
            end
        elseif byte >= 0xF0 and byte <= 0xF7 then
            -- 4-byte sequence (emoji and others)
            char_len = 4
            width = width + 2
        elseif byte >= 0xC2 and byte <= 0xDF then
            -- 2-byte sequence
            char_len = 2
            width = width + 1
        else
            -- 1-byte sequence or continuation byte
            width = width + 1
        end

        i = i + char_len
    end
    return width
end

-- Function to pad string with spaces considering Unicode characters
function M.pad_string(str, width, align_left)
    -- Handle nil or empty string
    str = str or ""
    if str == "" then
        return string.rep(" ", width)
    end

    -- Ensure width is positive
    width = math.max(0, width)

    local current_width = M.get_string_width(str)
    local padding = width - current_width

    -- If string is too long, truncate it and add "~"
    if current_width > width then
        if width <= 1 then
            return "~"
        end

        local truncated = ""
        local length = 0
        for char in str:gmatch("[^\128-\191][\128-\191]*") do
            if length + 1 < width then
                truncated = truncated .. char
                length = length + 1
            else
                break
            end
        end
        return truncated .. "~"
    end

    if padding <= 0 then
        return str
    end

    if align_left then
        return str .. string.rep(" ", padding)
    else -- align right
        return string.rep(" ", padding) .. str
    end
end


return M