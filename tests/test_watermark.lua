local h = require("tests.harness")
local Watermark = h.makeRequire()("core/watermark")

local SIZE = { w = 120, h = 22 }
local VIEW = { w = 1920, h = 1080 }
local PAD = 6

return {
    ["a position inside the viewport is returned unchanged"] = function()
        local p = Watermark.clampToViewport({ x = 400, y = 300 }, SIZE, VIEW, PAD)
        h.assertEqual(p.x, 400)
        h.assertEqual(p.y, 300)
    end,

    ["a negative x clamps to padding"] = function()
        local p = Watermark.clampToViewport({ x = -50, y = 100 }, SIZE, VIEW, PAD)
        h.assertEqual(p.x, 6)
    end,

    ["overflow right clamps to viewport minus size minus padding"] = function()
        local p = Watermark.clampToViewport({ x = 5000, y = 100 }, SIZE, VIEW, PAD)
        h.assertEqual(p.x, 1920 - 120 - 6)
    end,

    ["overflow bottom clamps on Y"] = function()
        local p = Watermark.clampToViewport({ x = 100, y = 5000 }, SIZE, VIEW, PAD)
        h.assertEqual(p.y, 1080 - 22 - 6)
    end,

    ["a viewport smaller than the pill still returns padding"] = function()
        -- Degenerate case: a 1080p position loaded on a 100x100 window. Prefer
        -- top-left over off-screen.
        local p = Watermark.clampToViewport({ x = 500, y = 500 }, SIZE,
            { w = 100, h = 50 }, PAD)
        h.assertEqual(p.x, 6)
        h.assertEqual(p.y, 6)
    end,
}
