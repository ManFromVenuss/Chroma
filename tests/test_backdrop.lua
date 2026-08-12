local h = require("tests.harness")
local Backdrop = h.makeRequire()("core/backdrop")

local ASPECT = 1024 / 576   -- 1.7777...

return {
    ["a window wider than the image scales by width"] = function()
        local w, hh, offset = Backdrop.computeCover(800, 300, ASPECT, 0)
        h.assertNear(w, 800)
        h.assertNear(hh, 800 / ASPECT, 1e-6)
        h.assertNear(offset, 0)
    end,

    ["a window taller than the image scales by height"] = function()
        local w, hh, offset = Backdrop.computeCover(360, 270, ASPECT, 0)
        h.assertNear(hh, 270)
        h.assertNear(w, 270 * ASPECT, 1e-6)
        h.assertNear(offset, 0)
    end,

    ["cover always fully covers the window"] = function()
        for _, size in ipairs({ { 240, 190 }, { 900, 620 }, { 640, 420 }, { 210, 600 } }) do
            local w, hh = Backdrop.computeCover(size[1], size[2], ASPECT, 0)
            h.assertTrue(w >= size[1] - 1e-9)
            h.assertTrue(hh >= size[2] - 1e-9)
        end
    end,

    ["shift oversizes and offsets by the same amount"] = function()
        -- Oversizing by the shift then pushing down by it leaves the top edge
        -- exactly at the window top, so nothing is uncovered.
        local baseW, baseH = Backdrop.computeCover(360, 270, ASPECT, 0)
        local w, hh, offset = Backdrop.computeCover(360, 270, ASPECT, 0.22)
        h.assertNear(w, baseW * 1.22, 1e-6)
        h.assertNear(hh, baseH * 1.22, 1e-6)
        h.assertNear(offset, baseH * 0.22, 1e-6)
        -- top edge = windowH - scaledH + offset
        h.assertNear(270 - hh + offset, 0, 1e-6)
    end,

    ["zero shift leaves the bottom edge flush"] = function()
        local _, hh, offset = Backdrop.computeCover(640, 420, ASPECT, 0)
        h.assertNear(offset, 0)
        h.assertNear(420 - hh + offset, 420 - hh, 1e-9)
    end,

    ["degenerate sizes do not divide by zero"] = function()
        local w, hh = Backdrop.computeCover(0, 0, ASPECT, 0)
        h.assertTrue(w >= 0)
        h.assertTrue(hh >= 0)
    end,
}
