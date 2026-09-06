local h = require("tests.harness")
local Toasts = h.makeRequire()("core/toasts")

local TOAST = { w = 220, h = 42 }
local VIEW = { w = 1920, h = 1080 }
local GAP = 8
local MARGIN = 12

return {
    ["top-right stacks downward from the top edge"] = function()
        local ps = Toasts.stackFor(3, "top-right", TOAST, GAP, VIEW, MARGIN)
        h.assertEqual(#ps, 3)
        -- Newest at index 1, at the top.
        h.assertEqual(ps[1].x, 1920 - 12 - 220)
        h.assertEqual(ps[1].y, 12)
        h.assertEqual(ps[2].y, 12 + 42 + 8)
        h.assertEqual(ps[3].y, 12 + (42 + 8) * 2)
    end,

    ["top-left stacks downward from the top edge, anchored left"] = function()
        local ps = Toasts.stackFor(2, "top-left", TOAST, GAP, VIEW, MARGIN)
        h.assertEqual(ps[1].x, 12)
        h.assertEqual(ps[2].x, 12)
        h.assertEqual(ps[1].y, 12)
        h.assertEqual(ps[2].y, 12 + 42 + 8)
    end,

    ["bottom-right stacks upward from the bottom edge"] = function()
        local ps = Toasts.stackFor(3, "bottom-right", TOAST, GAP, VIEW, MARGIN)
        -- Newest at index 1, at the bottom.
        h.assertEqual(ps[1].x, 1920 - 12 - 220)
        h.assertEqual(ps[1].y, 1080 - 12 - 42)
        h.assertEqual(ps[2].y, 1080 - 12 - 42 - (42 + 8))
    end,

    ["bottom-left stacks upward, anchored left"] = function()
        local ps = Toasts.stackFor(2, "bottom-left", TOAST, GAP, VIEW, MARGIN)
        h.assertEqual(ps[1].x, 12)
        h.assertEqual(ps[1].y, 1080 - 12 - 42)
        h.assertEqual(ps[2].y, 1080 - 12 - 42 - (42 + 8))
    end,

    ["zero toasts returns an empty array"] = function()
        local ps = Toasts.stackFor(0, "top-right", TOAST, GAP, VIEW, MARGIN)
        h.assertEqual(#ps, 0)
    end,

    ["an unknown corner falls back to top-right"] = function()
        -- A config with a garbage value should not crash the manager.
        local ps = Toasts.stackFor(1, "nowhere", TOAST, GAP, VIEW, MARGIN)
        h.assertEqual(ps[1].x, 1920 - 12 - 220)
        h.assertEqual(ps[1].y, 12)
    end,
}
