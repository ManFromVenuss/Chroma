local h = require("tests.harness")
local Rail = h.makeRequire()("core/rail")

return {
    ["t = 0 returns the starting width"] = function()
        h.assertNear(Rail.easeExpand(28, 120, 0), 28)
    end,

    ["t = 1 lands exactly on the target"] = function()
        -- Lands exactly, not "near": a tween that undershoots by 0.4 pixels
        -- leaves the columns' widths one short forever.
        h.assertEqual(Rail.easeExpand(28, 120, 1), 120)
    end,

    ["t is clamped below 0"] = function()
        h.assertEqual(Rail.easeExpand(28, 120, -0.5), 28)
    end,

    ["t is clamped above 1"] = function()
        h.assertEqual(Rail.easeExpand(28, 120, 2), 120)
    end,

    ["monotonic between the endpoints"] = function()
        local prev = Rail.easeExpand(28, 120, 0)
        for i = 1, 20 do
            local now = Rail.easeExpand(28, 120, i / 20)
            h.assertTrue(now >= prev)
            prev = now
        end
    end,

    ["works in the collapse direction too"] = function()
        h.assertEqual(Rail.easeExpand(120, 28, 0), 120)
        h.assertEqual(Rail.easeExpand(120, 28, 1), 28)
    end,
}
