local h = require("tests.harness")
local Popup = h.makeRequire()("core/popup")

local VIEW = { w = 1920, h = 1080 }

-- A 110px control slot at (400, 300), 14px tall -- the real geometry a
-- dropdown field has inside a row.
local SLOT = { x = 400, y = 300, w = 110, h = 14 }

return {
    ["right-aligns to the control slot and opens downward"] = function()
        local x, y = Popup.place(SLOT, { w = 110, h = 128 }, VIEW)
        h.assertEqual(x, 400 + 110 - 110)
        h.assertEqual(y, 300 + 14 + 2)
    end,

    ["a popup wider than the slot extends leftward from its right edge"] = function()
        local x = Popup.place(SLOT, { w = 176, h = 149 }, VIEW)
        h.assertEqual(x, 400 + 110 - 176)
    end,

    ["flips above the anchor when it would overflow the bottom"] = function()
        local _, y = Popup.place({ x = 400, y = 1000, w = 110, h = 14 },
            { w = 110, h = 128 }, VIEW)
        h.assertEqual(y, 1000 - 128 - 2)
    end,

    ["clamps to the left margin rather than hanging off screen"] = function()
        local x = Popup.place({ x = 10, y = 300, w = 110, h = 14 },
            { w = 176, h = 149 }, VIEW)
        h.assertEqual(x, 6)
    end,

    ["clamps to the right margin when the slot sits at the screen edge"] = function()
        local x = Popup.place({ x = 1900, y = 300, w = 110, h = 14 },
            { w = 176, h = 149 }, VIEW)
        h.assertEqual(x, 1920 - 6 - 176)
    end,

    ["flips and clamps together in the bottom-left corner"] = function()
        local x, y = Popup.place({ x = 10, y = 1000, w = 110, h = 14 },
            { w = 176, h = 149 }, VIEW)
        h.assertEqual(x, 6)
        h.assertEqual(y, 1000 - 149 - 2)
    end,

    ["never places above the top margin when it fits nowhere"] = function()
        local _, y = Popup.place({ x = 400, y = 40, w = 110, h = 14 },
            { w = 110, h = 2000 }, VIEW)
        h.assertEqual(y, 6)
    end,
}
