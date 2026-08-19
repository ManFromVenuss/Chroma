local h = require("tests.harness")
local CP = h.makeRequire()("widgets/colorpicker")

-- parseColor returns r, g, b in 0..255 and alpha in 0..1, or nil.
local function parse4(text)
    local r, g, b, a = CP.parseColor(text)
    return { r, g, b, a }
end

local function assertRGBA(got, r, g, b, a)
    h.assertEqual(got[1], r)
    h.assertEqual(got[2], g)
    h.assertEqual(got[3], b)
    h.assertNear(got[4], a)
end

return {
    ["long hex parses with or without the hash"] = function()
        assertRGBA(parse4("#17B8A6"), 23, 184, 166, 1)
        assertRGBA(parse4("17B8A6"), 23, 184, 166, 1)
    end,

    ["hex is case insensitive"] = function()
        assertRGBA(parse4("#17b8a6"), 23, 184, 166, 1)
    end,

    ["eight-digit hex carries alpha"] = function()
        assertRGBA(parse4("#17B8A680"), 23, 184, 166, 128 / 255)
    end,

    ["short hex expands each digit"] = function()
        assertRGBA(parse4("#F00"), 255, 0, 0, 1)
        assertRGBA(parse4("#1B8"), 17, 187, 136, 1)
    end,

    ["four-digit short hex carries alpha"] = function()
        assertRGBA(parse4("#F00F"), 255, 0, 0, 1)
    end,

    ["three comma components parse as RGB"] = function()
        assertRGBA(parse4("23, 184, 166"), 23, 184, 166, 1)
    end,

    ["whitespace anywhere is ignored"] = function()
        assertRGBA(parse4("  23,184 , 166  "), 23, 184, 166, 1)
        assertRGBA(parse4(" # 17B8A6 "), 23, 184, 166, 1)
    end,

    ["a fractional fourth component is alpha as written"] = function()
        assertRGBA(parse4("255,0,0,0.5"), 255, 0, 0, 0.5)
    end,

    ["an out-of-range alpha clamps to opaque"] = function()
        -- Someone typing 255,0,0,255 means opaque. Clamping is what they meant.
        assertRGBA(parse4("255,0,0,255"), 255, 0, 0, 1)
    end,

    ["out-of-range channels clamp rather than reject"] = function()
        assertRGBA(parse4("300,-20,166"), 255, 0, 166, 1)
    end,

    ["fractional channels round to the nearest byte"] = function()
        assertRGBA(parse4("22.6,183.4,166"), 23, 183, 166, 1)
    end,

    ["garbage returns nil"] = function()
        h.assertEqual(CP.parseColor("nonsense"), nil)
        h.assertEqual(CP.parseColor(""), nil)
        h.assertEqual(CP.parseColor("#12345"), nil)
        h.assertEqual(CP.parseColor("#GGGGGG"), nil)
        h.assertEqual(CP.parseColor("1,2"), nil)
        h.assertEqual(CP.parseColor("1,2,3,4,5"), nil)
        h.assertEqual(CP.parseColor("1,two,3"), nil)
        h.assertEqual(CP.parseColor(nil), nil)
        h.assertEqual(CP.parseColor(42), nil)
    end,

    ["toHex renders the compact display format"] = function()
        h.assertEqual(CP.toHex(23, 184, 166), "#17B8A6")
        h.assertEqual(CP.toHex(23, 184, 166, 1), "#17B8A6FF")
        h.assertEqual(CP.toHex(255, 0, 0, 0.5), "#FF000080")
    end,

    ["toHex round-trips through parseColor"] = function()
        local r, g, b, a = CP.parseColor(CP.toHex(23, 184, 166, 0.5))
        h.assertEqual(r, 23)
        h.assertEqual(g, 184)
        h.assertEqual(b, 166)
        h.assertNear(a, 128 / 255, 0.01)
    end,
}
