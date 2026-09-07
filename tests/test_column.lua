local h = require("tests.harness")
local Column = h.makeRequire()("core/column")

local function sum(t)
    local n = 0
    for i = 1, #t do n = n + t[i] end
    return n
end

return {
    ["equal weights split evenly and fill exactly"] = function()
        local w = Column.widths({ 1, 1 }, 300, 8)
        h.assertEqual(#w, 2)
        h.assertEqual(sum(w) + 8, 300)
        h.assertEqual(w[1], 146)
        h.assertEqual(w[2], 146)
    end,

    ["a 2:1 weighting splits proportionally"] = function()
        local w = Column.widths({ 2, 1 }, 308, 8)
        -- 308 - 8 = 300 usable, 200 / 100
        h.assertEqual(w[1], 200)
        h.assertEqual(w[2], 100)
        h.assertEqual(sum(w) + 8, 308)
    end,

    ["the last column absorbs rounding so there is no seam"] = function()
        -- 100 usable across 3 equal columns does not divide evenly
        local w = Column.widths({ 1, 1, 1 }, 100 + 16, 8)
        h.assertEqual(sum(w) + 16, 116)
        h.assertEqual(w[1], 33)
        h.assertEqual(w[2], 33)
        h.assertEqual(w[3], 34)
    end,

    ["a single column takes the whole width with no gap"] = function()
        local w = Column.widths({ 1 }, 250, 8)
        h.assertEqual(#w, 1)
        h.assertEqual(w[1], 250)
    end,

    ["no columns yields no widths"] = function()
        h.assertEqual(#Column.widths({}, 300, 8), 0)
    end,

    ["non-positive weights fall back to an even split"] = function()
        local w = Column.widths({ 0, 0 }, 308, 8)
        h.assertEqual(w[1], 150)
        h.assertEqual(w[2], 150)
    end,

    ["widths never go negative when the gaps exceed the width"] = function()
        local w = Column.widths({ 1, 1, 1 }, 10, 8)
        for i = 1, #w do h.assertTrue(w[i] >= 0) end
    end,
}
