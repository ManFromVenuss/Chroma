local h = require("tests.harness")
local Hotkeys = h.makeRequire()("core/hotkeys")

return {
    ["Always mode always renders [always]"] = function()
        h.assertEqual(Hotkeys.formatRow("Trigger", "Always", "V"), "[always] Trigger")
        -- Even if no bind is set, Always still reads as active.
        h.assertEqual(Hotkeys.formatRow("Trigger", "Always", "NONE"), "[always] Trigger")
    end,

    ["Hold mode with a bind renders [KEY] Name"] = function()
        h.assertEqual(Hotkeys.formatRow("Aim", "Hold", "MOUSE2"), "[MOUSE2] Aim")
    end,

    ["Toggle mode with a bind renders [KEY] Name"] = function()
        h.assertEqual(Hotkeys.formatRow("Silent", "Toggle", "V"), "[V] Silent")
    end,

    ["Hold or Toggle without a bind renders [NONE] Name"] = function()
        h.assertEqual(Hotkeys.formatRow("Trigger", "Hold", "NONE"), "[NONE] Trigger")
        h.assertEqual(Hotkeys.formatRow("Silent", "Toggle", "NONE"), "[NONE] Silent")
    end,

    ["a nil mode falls back to whatever the key label says"] = function()
        -- Defensive: a corrupt widget should not crash the overlay.
        h.assertEqual(Hotkeys.formatRow("Feature", nil, "V"), "[V] Feature")
    end,
}
