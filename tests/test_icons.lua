local h = require("tests.harness")
local Icons = h.makeRequire()("core/icons")

local ASSETS = { settings = "106205298246017", crosshair = "83752373575368" }

return {
    ["nil returns letter"] = function()
        local r = Icons.resolveIcon(nil, ASSETS)
        h.assertEqual(r.kind, "letter")
    end,

    ["empty string returns letter"] = function()
        local r = Icons.resolveIcon("", ASSETS)
        h.assertEqual(r.kind, "letter")
    end,

    ["an rbxassetid passes through"] = function()
        -- A consumer's own image asset short-circuits the Lucide table.
        local r = Icons.resolveIcon("rbxassetid://123", ASSETS)
        h.assertEqual(r.kind, "asset")
        h.assertEqual(r.value, "rbxassetid://123")
    end,

    ["a known Lucide name resolves to its asset id"] = function()
        local r = Icons.resolveIcon("settings", ASSETS)
        h.assertEqual(r.kind, "asset")
        h.assertEqual(r.value, "rbxassetid://106205298246017")
    end,

    ["a name that looks like a URL but is not rbxassetid falls back"] = function()
        -- The asset check is strict on the rbxassetid:// prefix, so a stray
        -- http:// url doesn't get plumbed to an ImageLabel that will fail.
        local r = Icons.resolveIcon("http://example.com/x.png", ASSETS)
        h.assertEqual(r.kind, "letter")
    end,

    ["an unknown name falls back to letter"] = function()
        -- Warned about at the caller, not here -- resolveIcon is pure.
        local r = Icons.resolveIcon("not-a-real-lucide-icon", ASSETS)
        h.assertEqual(r.kind, "letter")
    end,

    ["a non-string Icon falls back to letter"] = function()
        -- Consumer error, but at the API surface. Falling back is friendlier
        -- than an assertion here; the settings page still builds.
        local r = Icons.resolveIcon(42, ASSETS)
        h.assertEqual(r.kind, "letter")
    end,
}
