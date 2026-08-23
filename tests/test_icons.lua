local h = require("tests.harness")
local Icons = h.makeRequire()("core/icons")

local GLYPHS = { settings = 0xe4a5, crosshair = 0xe0c7 }

return {
    ["nil returns letter"] = function()
        local r = Icons.resolveIcon(nil, GLYPHS, true)
        h.assertEqual(r.kind, "letter")
    end,

    ["empty string returns letter"] = function()
        local r = Icons.resolveIcon("", GLYPHS, true)
        h.assertEqual(r.kind, "letter")
    end,

    ["an asset id passes through even without a font loaded"] = function()
        -- The asset branch has nothing to do with Lucide, so a missing font
        -- must not degrade an rbxassetid.
        local r = Icons.resolveIcon("rbxassetid://123", GLYPHS, false)
        h.assertEqual(r.kind, "asset")
        h.assertEqual(r.value, "rbxassetid://123")
    end,

    ["a known Lucide name with the font loaded returns the glyph"] = function()
        local r = Icons.resolveIcon("settings", GLYPHS, true)
        h.assertEqual(r.kind, "glyph")
        h.assertEqual(r.codepoint, 0xe4a5)
    end,

    ["a known Lucide name without the font falls back to letter"] = function()
        local r = Icons.resolveIcon("settings", GLYPHS, false)
        h.assertEqual(r.kind, "letter")
    end,

    ["an unknown name falls back to letter"] = function()
        -- Warned about at the caller, not here -- resolveIcon is pure.
        local r = Icons.resolveIcon("not-a-real-lucide-icon", GLYPHS, true)
        h.assertEqual(r.kind, "letter")
    end,

    ["a name that looks like an asset URL but is not rbxassetid falls back"] = function()
        -- The asset check is strict on the rbxassetid:// prefix, so a stray
        -- http:// url doesn't get plumbed to an ImageLabel that will fail.
        local r = Icons.resolveIcon("http://example.com/x.png", GLYPHS, true)
        h.assertEqual(r.kind, "letter")
    end,

    ["a non-string Icon falls back to letter"] = function()
        -- Consumer error, but at the API surface. Falling back is friendlier
        -- than an assertion here; the settings page still builds.
        local r = Icons.resolveIcon(42, GLYPHS, true)
        h.assertEqual(r.kind, "letter")
    end,
}
