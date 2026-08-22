-- Type tagging, so the values Chroma stores survive JSON.
--
-- JSON has no Color3 and no EnumItem, and an executor's JSONEncode will either
-- drop them or throw. Each becomes a plain table carrying a __t tag, and decode
-- turns it back.
--
-- Pure: dispatches on typeof() and builds Roblox datatypes, but calls no
-- Instance method, so it is unit tested. Lua 5.4 / Luau intersection -- no
-- compound assignment, no bitwise ops, no goto.

local M = {}

local TAG = "__t"

local function byte(channel)
    local n = math.floor(channel * 255 + 0.5)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

-- Returns a JSON-safe value, or nil for anything unstorable. Unstorable is not
-- an error: a consumer may hand a widget something odd, and losing one flag is
-- better than losing the whole config.
function M.encode(value)
    local kind = typeof(value)

    if kind == "boolean" or kind == "number" or kind == "string" then
        return value
    end

    if kind == "Color3" then
        return { [TAG] = "Color3", r = byte(value.R), g = byte(value.G), b = byte(value.B) }
    end

    if kind == "EnumItem" then
        -- By name rather than by value: enum numbering is not stable across
        -- Roblox versions, and a name is legible in the saved file.
        return { [TAG] = "Enum", enum = value.EnumType.Name, name = value.Name }
    end

    if kind == "table" then
        local out = {}
        for k, v in pairs(value) do
            local encoded = M.encode(v)
            if encoded ~= nil then out[k] = encoded end
        end
        return out
    end

    return nil
end

function M.decode(value)
    if type(value) ~= "table" then
        -- Booleans, numbers and strings need nothing; so does nil.
        return value
    end

    local tag = value[TAG]

    if tag == "Color3" then
        return Color3.fromRGB(value.r, value.g, value.b)
    end

    if tag == "Enum" then
        local group = Enum[value.enum]
        if group == nil then return nil end
        -- Indexing a missing item throws in Roblox, so probe it.
        local ok, item = pcall(function() return group[value.name] end)
        if not ok then return nil end
        return item
    end

    if tag ~= nil then
        -- A tag this version does not know: written by a newer Chroma. Drop the
        -- one value rather than taking the menu down.
        return nil
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = M.decode(v)
    end
    return out
end

return M
