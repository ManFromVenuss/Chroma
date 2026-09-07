local h = require("tests.harness")
local Tooltip = h.makeRequire()("core/tooltip")

local VIEW = { w = 1920, h = 1080 }

return {
    ["sits to the right of the anchor by default"] = function()
        local x, y = Tooltip.place({ x = 100, y = 200, w = 11, h = 11 },
            { w = 220, h = 40 }, VIEW)
        h.assertEqual(x, 100 + 11 + 8)
        h.assertEqual(y, 200 - 3)
    end,

    ["flips to the left when it would overflow the right edge"] = function()
        local x = Tooltip.place({ x = 1800, y = 200, w = 11, h = 11 },
            { w = 220, h = 40 }, VIEW)
        h.assertEqual(x, 1800 - 220 - 8)
    end,

    ["clamps upward when it would overflow the bottom"] = function()
        local _, y = Tooltip.place({ x = 100, y = 1060, w = 11, h = 11 },
            { w = 220, h = 40 }, VIEW)
        h.assertEqual(y, 1080 - 8 - 40)
    end,

    ["flips and clamps together in the bottom-right corner"] = function()
        local x, y = Tooltip.place({ x = 1850, y = 1050, w = 11, h = 11 },
            { w = 220, h = 60 }, VIEW)
        h.assertEqual(x, 1850 - 220 - 8)
        h.assertEqual(y, 1080 - 8 - 60)
    end,

    ["never places above the top margin"] = function()
        local _, y = Tooltip.place({ x = 100, y = 0, w = 11, h = 11 },
            { w = 220, h = 40 }, VIEW)
        h.assertTrue(y >= 8)
    end,

    ["falls back to the left margin when it fits on neither side"] = function()
        local x = Tooltip.place({ x = 10, y = 100, w = 11, h = 11 },
            { w = 3000, h = 40 }, VIEW)
        h.assertEqual(x, 8)
    end,
}
