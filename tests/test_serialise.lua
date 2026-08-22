local h = require("tests.harness")
local S = h.makeRequire()("core/serialise")

return {
    ["primitives pass through untouched"] = function()
        h.assertEqual(S.encode(true), true)
        h.assertEqual(S.encode(42), 42)
        h.assertEqual(S.encode("head"), "head")
        h.assertEqual(S.decode(true), true)
        h.assertEqual(S.decode(42), 42)
        h.assertEqual(S.decode("head"), "head")
    end,

    ["a Color3 round-trips through its tag"] = function()
        local encoded = S.encode(Color3.fromRGB(23, 184, 166))
        h.assertEqual(encoded.__t, "Color3")
        h.assertEqual(encoded.r, 23)
        h.assertEqual(encoded.g, 184)
        h.assertEqual(encoded.b, 166)
        local back = S.decode(encoded)
        h.assertEqual(back, Color3.fromRGB(23, 184, 166))
    end,

    ["colour channels are stored as bytes, not floats"] = function()
        -- JSON floats are lossy across encoders; bytes are exact and readable
        -- when someone opens the file.
        local encoded = S.encode(Color3.new(1, 0, 0))
        h.assertEqual(encoded.r, 255)
        h.assertEqual(encoded.g, 0)
    end,

    ["an EnumItem round-trips by name"] = function()
        local encoded = S.encode(Enum.KeyCode.C)
        h.assertEqual(encoded.__t, "Enum")
        h.assertEqual(encoded.enum, "KeyCode")
        h.assertEqual(encoded.name, "C")
        h.assertSame(S.decode(encoded), Enum.KeyCode.C)
    end,

    ["a UserInputType round-trips too"] = function()
        local encoded = S.encode(Enum.UserInputType.MouseButton2)
        h.assertEqual(encoded.enum, "UserInputType")
        h.assertSame(S.decode(encoded), Enum.UserInputType.MouseButton2)
    end,

    ["arrays round-trip element by element"] = function()
        local encoded = S.encode({ "Head", "Torso" })
        h.assertEqual(encoded[1], "Head")
        h.assertEqual(encoded[2], "Torso")
        local back = S.decode(encoded)
        h.assertEqual(back[1], "Head")
        h.assertEqual(back[2], "Torso")
    end,

    ["a table of tagged values round-trips"] = function()
        -- Keybind's Save() returns exactly this shape: a bind plus a mode.
        local encoded = S.encode({ bind = Enum.KeyCode.V, mode = "Toggle" })
        local back = S.decode(encoded)
        h.assertSame(back.bind, Enum.KeyCode.V)
        h.assertEqual(back.mode, "Toggle")
    end,

    ["nil encodes to nil rather than erroring"] = function()
        h.assertEqual(S.encode(nil), nil)
        h.assertEqual(S.decode(nil), nil)
    end,

    ["an unknown tag decodes to nil instead of throwing"] = function()
        -- A config written by a newer Chroma must not take the menu down.
        h.assertEqual(S.decode({ __t = "Nonsense", x = 1 }), nil)
    end,

    ["an enum that no longer exists decodes to nil"] = function()
        h.assertEqual(S.decode({ __t = "Enum", enum = "NoSuchEnum", name = "X" }), nil)
    end,

    ["a function encodes to nil rather than erroring"] = function()
        h.assertEqual(S.encode(print), nil)
    end,
}
