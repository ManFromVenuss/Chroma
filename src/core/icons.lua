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
local FETCH_TIMEOUT = 3

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

    -- HttpGet in a wrapped thread so a hang past FETCH_TIMEOUT does not stall
    -- Chroma:Window() forever. task.spawn returns immediately; the thread's
    -- coroutine.status is what tells us it finished.
    local done, body, err = false, nil, nil
    local thread = task.spawn(function()
        local ok, result = pcall(function()
            return game:HttpGet(FONT_URL, true)
        end)
        if ok then body = result else err = tostring(result) end
        done = true
    end)

    local start = os.clock()
    while not done and (os.clock() - start) < FETCH_TIMEOUT do
        task.wait()
    end

    if not done then
        root:degrade("icons", "lucide font fetch timed out after " .. FETCH_TIMEOUT .. "s")
        return false
    end
    if body == nil then
        root:degrade("icons", "lucide font fetch failed: " .. tostring(err))
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
