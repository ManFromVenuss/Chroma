-- Icons: pure resolveIcon that decides between asset, font glyph and letter
-- fallback, plus (from the next task) the font loader.
--
-- Pure: keeps to the Lua 5.4 / Luau intersection so the harness can drive it
-- without a Roblox environment.

local M = {}

-- Returns { kind, value?/codepoint? } for the three branches:
--   { kind = "asset", value = "rbxassetid://..." }
--   { kind = "glyph", codepoint = 0xe4a5 }
--   { kind = "letter" }
--
-- The letter itself is not returned; the caller has the page name and takes
-- its first character. Keeping the fallback textless here keeps the function
-- pure and its cases countable.
function M.resolveIcon(icon, glyphs, fontLoaded)
    if type(icon) ~= "string" or icon == "" then
        return { kind = "letter" }
    end

    if icon:sub(1, 13) == "rbxassetid://" then
        return { kind = "asset", value = icon }
    end

    if fontLoaded and glyphs[icon] ~= nil then
        return { kind = "glyph", codepoint = glyphs[icon] }
    end

    return { kind = "letter" }
end

return M
