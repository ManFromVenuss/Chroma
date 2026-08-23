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

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach resolveIcon.
local HttpService

-- The font is fetched from the repo, written to a stable workspace path, then
-- registered via getcustomasset. After the first success it stays on disk and
-- the fetch is skipped.
local FONT_URL = "https://raw.githubusercontent.com/ManFromVenuss/Chroma/main/assets/lucide.ttf"
local FONT_PATH = "chroma/lucide.ttf"

-- Cached on M so a rebuild reuses it. root.iconFont is written from here so
-- pages can read it through root without knowing about this module.
local cachedFont = nil

local function fetchFont(root)
    -- Prefer a cached file: no network, no timeout, no failure mode.
    if isfile and isfile(FONT_PATH) then
        return true
    end

    if not writefile then
        root:degrade("icons", "writefile missing: cannot cache lucide font")
        return false
    end

    HttpService = HttpService or game:GetService("HttpService")

    -- HttpGet is what the executor gives us. On some it yields; on others it
    -- blocks the whole VM until the request completes. A Lua-side cap is not
    -- possible for a blocking C call, so we do not fake one. The saving grace
    -- is that the file is small (~1MB) and cached on disk after the first
    -- fetch, so this only stalls once per script session.
    local ok, body = pcall(game.HttpGet, game, FONT_URL, true)
    if not ok then
        root:degrade("icons", "lucide font fetch failed: " .. tostring(body))
        return false
    end

    local wrote = pcall(writefile, FONT_PATH, body)
    if not wrote then
        root:degrade("icons", "could not write lucide font to " .. FONT_PATH)
        return false
    end
    return true
end

-- Called once from Chroma:Window(). Populates root.iconFont on success and
-- leaves it nil (with a degrade) on failure. Synchronous.
function M.load(root)
    if root.iconFont then return end
    if cachedFont then
        root.iconFont = cachedFont
        return
    end

    if not getcustomasset then
        root:degrade("icons", "getcustomasset missing: lucide icons disabled")
        return
    end

    if not fetchFont(root) then return end

    local ok, asset = pcall(getcustomasset, FONT_PATH)
    if not ok or type(asset) ~= "string" then
        root:degrade("icons", "getcustomasset failed on lucide font")
        return
    end

    -- Font.new(assetUrl, weight, style). weight/style stay at Regular; Lucide
    -- ships a single face.
    local font = Font.new(asset, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    cachedFont = font
    root.iconFont = font
end

-- Testing hook: lets a probe clear the cache without an Unload.
function M._reset()
    cachedFont = nil
end

return M
