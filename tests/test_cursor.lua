local h = require("tests.harness")
local Cursor = h.makeRequire()("core/cursor")

return {
    ["a point inside the rect hits"] = function()
        h.assertTrue(Cursor.hitTest(50, 50, 10, 10, 100, 100))
    end,

    ["a point outside the rect misses"] = function()
        h.assertFalse(Cursor.hitTest(5, 50, 10, 10, 100, 100))
        h.assertFalse(Cursor.hitTest(50, 5, 10, 10, 100, 100))
        h.assertFalse(Cursor.hitTest(200, 50, 10, 10, 100, 100))
        h.assertFalse(Cursor.hitTest(50, 200, 10, 10, 100, 100))
    end,

    ["edges are inclusive"] = function()
        h.assertTrue(Cursor.hitTest(10, 10, 10, 10, 100, 100))
        h.assertTrue(Cursor.hitTest(110, 110, 10, 10, 100, 100))
    end,

    ["one pixel beyond an edge misses"] = function()
        h.assertFalse(Cursor.hitTest(111, 110, 10, 10, 100, 100))
        h.assertFalse(Cursor.hitTest(110, 111, 10, 10, 100, 100))
    end,

    ["a zero-size rect hits nothing but its own corner"] = function()
        h.assertTrue(Cursor.hitTest(10, 10, 10, 10, 0, 0))
        h.assertFalse(Cursor.hitTest(11, 10, 10, 10, 0, 0))
    end,
}
