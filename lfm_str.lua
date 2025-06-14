local M = {}

-- Function to calculate string width considering Unicode characters
function M.get_string_width(str)
    local width = 0
    for _ in str:gmatch("[^\128-\191][\128-\191]*") do
        width = width + 1
    end
    return width
end

-- Function to pad string with spaces considering Unicode characters
function M.pad_string(str, width, align_left)
    local current_width = M.get_string_width(str)
    local padding = width - current_width

    -- If string is too long, truncate it and add "~"
    if current_width > width then
        local truncated = ""
        local length = 0

        -- Iterate through Unicode characters
        for char in str:gmatch("[^\128-\191][\128-\191]*") do
            if length + 1 <= length - 1 then
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
    else
        return string.rep(" ", padding) .. str
    end
end


return M