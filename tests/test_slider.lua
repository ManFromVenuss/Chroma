local h = require("tests.harness")
local Slider = h.makeRequire()("widgets/slider")

return {
    ["fractionOf maps a value onto 0..1"] = function()
        h.assertNear(Slider.fractionOf(0, 0, 100), 0)
        h.assertNear(Slider.fractionOf(50, 0, 100), 0.5)
        h.assertNear(Slider.fractionOf(100, 0, 100), 1)
    end,

    ["fractionOf clamps values outside the range"] = function()
        h.assertNear(Slider.fractionOf(-20, 0, 100), 0)
        h.assertNear(Slider.fractionOf(150, 0, 100), 1)
    end,

    ["fractionOf handles a negative range"] = function()
        h.assertNear(Slider.fractionOf(0, -50, 50), 0.5)
        h.assertNear(Slider.fractionOf(-50, -50, 50), 0)
    end,

    ["fractionOf returns 0 rather than dividing by zero"] = function()
        h.assertNear(Slider.fractionOf(5, 10, 10), 0)
    end,

    ["valueAt maps 0..1 back onto the range"] = function()
        h.assertNear(Slider.valueAt(0, 0, 90, 0), 0)
        h.assertNear(Slider.valueAt(1, 0, 90, 0), 90)
        h.assertNear(Slider.valueAt(0.5, 0, 90, 0), 45)
    end,

    ["valueAt rounds to whole numbers at 0 decimals"] = function()
        -- 0.5 of 0..9 is 4.5, which must land on a whole number
        h.assertNear(Slider.valueAt(0.5, 0, 9, 0), 5)
        h.assertNear(Slider.valueAt(0.4, 0, 9, 0), 4)
    end,

    ["valueAt honours a decimal precision"] = function()
        h.assertNear(Slider.valueAt(1 / 3, 0, 1, 2), 0.33)
        h.assertNear(Slider.valueAt(1 / 3, 0, 1, 1), 0.3)
    end,

    ["valueAt clamps a fraction outside 0..1"] = function()
        h.assertNear(Slider.valueAt(-1, 0, 90, 0), 0)
        h.assertNear(Slider.valueAt(2, 0, 90, 0), 90)
    end,

    ["valueAt rounds negative values away from zero at .5"] = function()
        h.assertNear(Slider.valueAt(0.5, -9, 0, 0), -4)
    end,

    ["a round trip through both is stable"] = function()
        local v = Slider.valueAt(Slider.fractionOf(37, 0, 90), 0, 90, 0)
        h.assertNear(v, 37)
    end,

    ["format applies decimals and a unit suffix"] = function()
        h.assertEqual(Slider.format(20, 0, "°"), "20°")
        h.assertEqual(Slider.format(0.5, 2, ""), "0.50")
        h.assertEqual(Slider.format(7, 0, nil), "7")
    end,
}
