local h = require("tests.harness")
local Keybind = h.makeRequire()("widgets/keybind")

return {
    ["mouse buttons get short names"] = function()
        h.assertEqual(Keybind.formatKey("MouseButton1", nil), "MOUSE1")
        h.assertEqual(Keybind.formatKey("MouseButton2", nil), "MOUSE2")
        h.assertEqual(Keybind.formatKey("MouseButton3", nil), "MOUSE3")
    end,

    ["an unbound key reads NONE"] = function()
        h.assertEqual(Keybind.formatKey(nil, nil), "NONE")
        h.assertEqual(Keybind.formatKey("Keyboard", "Unknown"), "NONE")
        h.assertEqual(Keybind.formatKey("Keyboard", ""), "NONE")
    end,

    ["long modifier names are abbreviated"] = function()
        h.assertEqual(Keybind.formatKey("Keyboard", "LeftShift"), "LSHIFT")
        h.assertEqual(Keybind.formatKey("Keyboard", "RightControl"), "RCTRL")
        h.assertEqual(Keybind.formatKey("Keyboard", "LeftAlt"), "LALT")
    end,

    ["common keys are abbreviated to fit the field"] = function()
        h.assertEqual(Keybind.formatKey("Keyboard", "Return"), "ENTER")
        h.assertEqual(Keybind.formatKey("Keyboard", "Backspace"), "BACK")
        h.assertEqual(Keybind.formatKey("Keyboard", "PageDown"), "PGDN")
    end,

    ["anything else is upper-cased verbatim"] = function()
        h.assertEqual(Keybind.formatKey("Keyboard", "F"), "F")
        h.assertEqual(Keybind.formatKey("Keyboard", "Insert"), "INSERT")
        h.assertEqual(Keybind.formatKey("Keyboard", "Nine"), "NINE")
    end,

    ["an unbindable mouse type falls through to the key code"] = function()
        -- MouseWheel and the dead MouseBackButton entry are not bindable, so
        -- they must not silently produce a mouse label.
        h.assertEqual(Keybind.formatKey("MouseWheel", nil), "NONE")
    end,
}
