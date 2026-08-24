-- Icons: pure resolveIcon that decides between the two branches Chroma renders,
-- an image asset (Roblox-hosted) or a first-letter fallback.
--
-- Pure: keeps to the Lua 5.4 / Luau intersection so the harness can drive it
-- without a Roblox environment.

local M = {}

-- Returns { kind, value? } for the two branches:
--   { kind = "asset", value = "rbxassetid://..." }
--   { kind = "letter" }
--
-- A Lucide name is resolved through icons.rest's mapping (baked into
-- lucide_assets.lua) into an ordinary Roblox image asset. There is no font
-- involved -- an earlier attempt to ship the Lucide TTF via getcustomasset
-- failed because Roblox's Font system refuses to load a TTF referenced from
-- inside a custom-font manifest that was itself provided by getcustomasset.
-- icons.rest sidesteps the whole problem by pre-uploading each glyph as its
-- own image.
--
-- The letter itself is not returned; the caller has the page name and takes
-- its first character. Keeping the fallback textless here keeps the function
-- pure and its cases countable.
function M.resolveIcon(icon, assets)
    if type(icon) ~= "string" or icon == "" then
        return { kind = "letter" }
    end

    if icon:sub(1, 13) == "rbxassetid://" then
        return { kind = "asset", value = icon }
    end

    local id = assets[icon]
    if id ~= nil then
        return { kind = "asset", value = "rbxassetid://" .. id }
    end

    return { kind = "letter" }
end

return M
