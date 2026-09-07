local h = require("tests.harness")
local Hotkeys = h.makeRequire()("core/hotkeys")

return {
    ["Always mode always renders [always]"] = function()
        h.assertEqual(Hotkeys.formatRow("Trigger", "Always", "V"), "Trigger [always]")
        -- Even if no bind is set, Always still reads as active.
        h.assertEqual(Hotkeys.formatRow("Trigger", "Always", "NONE"), "Trigger [always]")
    end,

    ["Hold mode with a bind renders Name [KEY]"] = function()
        h.assertEqual(Hotkeys.formatRow("Aim", "Hold", "MOUSE2"), "Aim [MOUSE2]")
    end,

    ["Toggle mode with a bind renders Name [KEY]"] = function()
        h.assertEqual(Hotkeys.formatRow("Silent", "Toggle", "V"), "Silent [V]")
    end,

    ["Hold or Toggle without a bind renders Name [NONE]"] = function()
        h.assertEqual(Hotkeys.formatRow("Trigger", "Hold", "NONE"), "Trigger [NONE]")
        h.assertEqual(Hotkeys.formatRow("Silent", "Toggle", "NONE"), "Silent [NONE]")
    end,

    ["a nil mode falls back to whatever the key label says"] = function()
        -- Defensive: a corrupt widget should not crash the overlay.
        h.assertEqual(Hotkeys.formatRow("Feature", nil, "V"), "Feature [V]")
    end,
}
