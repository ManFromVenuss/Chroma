-- Colorpicker: the pure text parsing, plus (from the next task) the swatch, the
-- HSV square, the hue and alpha strips and the text field.
--
-- parseColor and toHex are unit tested, so keep them in the Lua 5.4 / Luau
-- intersection: no compound assignment, no bitwise ops, no goto. That also
-- means no Color3 construction here -- these deal in plain numbers, and the
-- Instance half converts.

local M = {}

-- Channels are 0..255 and alpha is 0..1, matching how each is written by hand.
local function clampByte(n)
    n = math.floor(n + 0.5)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

-- Returns r, g, b, a or nil. Unparseable input is USER error at runtime, not a
-- programming mistake, so the caller reverts silently rather than erroring --
-- exactly as the slider's typed value does.
function M.parseColor(text)
    if type(text) ~= "string" then return nil end

    local s = text:gsub("%s", "")
    if s == "" then return nil end

    -- Sniffed on the comma rather than by asking the caller which format it is:
    -- the whole point of one field is that it takes either.
    if s:find(",", 1, true) then
        local parts = {}
        for piece in s:gmatch("[^,]+") do
            table.insert(parts, tonumber(piece))
        end
        if #parts < 3 or #parts > 4 then return nil end
        for i = 1, #parts do
            if parts[i] == nil then return nil end
        end

        local a = parts[4]
        if a == nil then
            a = 1
        elseif a > 1 then
            -- 255,0,0,255 means opaque. Clamping is what they meant; rejecting
            -- it would be pedantic about a format nobody agreed on.
            a = 1
        elseif a < 0 then
            a = 0
        end
        return clampByte(parts[1]), clampByte(parts[2]), clampByte(parts[3]), a
    end

    local hex = s:gsub("^#", "")
    if hex:match("^%x+$") == nil then return nil end

    local n = #hex
    if n == 3 or n == 4 then
        -- Each digit doubles: F -> FF, which is 15 * 17 = 255.
        local r = tonumber(hex:sub(1, 1), 16) * 17
        local g = tonumber(hex:sub(2, 2), 16) * 17
        local b = tonumber(hex:sub(3, 3), 16) * 17
        local a = 1
        if n == 4 then a = tonumber(hex:sub(4, 4), 16) * 17 / 255 end
        return r, g, b, a
    end
    if n == 6 or n == 8 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = 1
        if n == 8 then a = tonumber(hex:sub(7, 8), 16) / 255 end
        return r, g, b, a
    end
    return nil
end

-- Hex is the display format, being the compact one. Alpha is appended only when
-- the picker has an alpha strip at all.
function M.toHex(r, g, b, a)
    if a == nil then
        return string.format("#%02X%02X%02X", clampByte(r), clampByte(g), clampByte(b))
    end
    return string.format("#%02X%02X%02X%02X",
        clampByte(r), clampByte(g), clampByte(b), clampByte(a * 255))
end

return M
