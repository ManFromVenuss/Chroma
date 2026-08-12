local h = require("tests.harness")
local Theme = h.makeRequire()("core/theme")

return {
    ["stored palette exposes the documented keys"] = function()
        local t = Theme.new()
        for _, key in ipairs({
            "Window", "Body", "TitleBar", "Container", "ContainerBorder",
            "Rail", "RailActive", "Field", "FieldBorder",
            "Text", "TextDim", "TextBright",
        }) do
            h.assertTrue(t:get(key) ~= nil)
        end
    end,

    ["hueAt advances with time and wraps"] = function()
        h.assertNear(Theme.hueAt(0, 0.15), 0)
        h.assertNear(Theme.hueAt(2, 0.15), 0.3)
        h.assertNear(Theme.hueAt(10, 0.15), 0.5)
        -- 0.15 * 20 = 3.0, three whole rotations, so back to zero
        h.assertNear(Theme.hueAt(20, 0.15), 0)
    end,

    ["RGB mode drives the accent from the clock"] = function()
        local t = Theme.new({ Accent = "RGB", AccentSpeed = 0.25 })
        t:tick(0)
        local first = t:get("Accent")
        t:tick(2)
        local second = t:get("Accent")
        h.assertFalse(first == second)
    end,

    ["static accent ignores the clock"] = function()
        local fixed = Color3.fromRGB(23, 184, 166)
        local t = Theme.new({ Accent = fixed })
        t:tick(0)
        local a = t:get("Accent")
        t:tick(9)
        h.assertTrue(a == t:get("Accent"))
        h.assertFalse(t:isAnimated())
    end,

    ["AccentDim is a darkened accent"] = function()
        local t = Theme.new({ Accent = Color3.new(0.4, 0.8, 1) })
        t:tick(0)
        local dim = t:get("AccentDim")
        h.assertNear(dim.R, 0.4 * 0.55)
        h.assertNear(dim.G, 0.8 * 0.55)
        h.assertNear(dim.B, 1.0 * 0.55)
    end,

    ["Selection carries the accent colour and its transparency"] = function()
        local t = Theme.new({ Accent = Color3.new(0.1, 0.7, 0.6) })
        t:tick(0)
        h.assertTrue(t:get("Selection") == t:get("Accent"))
        h.assertNear(t:transparency("Selection"), 0.84)
    end,

    ["the hairline gradient shifts hue by 60 degrees"] = function()
        local t = Theme.new({ Accent = Color3.fromHSV(0.5, 1, 1) })
        t:tick(0)
        local h1 = select(1, t:get("HairA"):ToHSV())
        local h2 = select(1, t:get("HairB"):ToHSV())
        h.assertNear(h1, 0.5, 1e-3)
        h.assertNear(h2, 0.5 + 60 / 360, 1e-3)
    end,

    ["hairline hue wraps past 1"] = function()
        local t = Theme.new({ Accent = Color3.fromHSV(0.95, 1, 1) })
        t:tick(0)
        local h2 = select(1, t:get("HairB"):ToHSV())
        h.assertNear(h2, (0.95 + 60 / 360) % 1, 1e-3)
    end,

    ["bindings write the current colour on apply"] = function()
        local t = Theme.new({ Accent = Color3.new(1, 0, 0) })
        local obj = h.fakeInstance({ BackgroundColor3 = Color3.new(0, 0, 0) })
        t:bind(obj, "BackgroundColor3", "Accent")
        t:tick(0)
        t:apply()
        h.assertTrue(obj.BackgroundColor3 == Color3.new(1, 0, 0))
    end,

    ["apply skips writes when the value is unchanged"] = function()
        local t = Theme.new({ Accent = Color3.new(1, 0, 0) })
        local obj = h.fakeInstance({ BackgroundColor3 = Color3.new(0, 0, 0) })
        t:bind(obj, "BackgroundColor3", "Accent")
        t:tick(0)
        t:apply()
        local afterFirst = obj.__writes
        t:apply()
        t:apply()
        h.assertEqual(obj.__writes, afterFirst)
    end,

    ["setPalette overrides a stored key and rewrites bindings"] = function()
        local t = Theme.new()
        local obj = h.fakeInstance({ BackgroundColor3 = Color3.new(0, 0, 0) })
        t:bind(obj, "BackgroundColor3", "Container")
        t:tick(0)
        t:apply()
        t:setPalette({ Container = Color3.new(0.5, 0.5, 0.5) })
        t:apply()
        h.assertTrue(obj.BackgroundColor3 == Color3.new(0.5, 0.5, 0.5))
    end,

    ["setAccent switches an animated theme to static"] = function()
        local t = Theme.new({ Accent = "RGB" })
        h.assertTrue(t:isAnimated())
        t:setAccent(Color3.new(0, 1, 0))
        h.assertFalse(t:isAnimated())
        t:apply()
        h.assertTrue(t:get("Accent") == Color3.new(0, 1, 0))
    end,

    ["bind paints immediately without waiting for apply"] = function()
        local t = Theme.new({ Accent = Color3.new(1, 0, 0) })
        local obj = h.fakeInstance({ BackgroundColor3 = Color3.new(0, 0, 0) })
        t:bind(obj, "BackgroundColor3", "Accent")
        h.assertTrue(obj.BackgroundColor3 == Color3.new(1, 0, 0))
    end,

    ["bind writes the key's transparency when given a property for it"] = function()
        local t = Theme.new()
        local obj = h.fakeInstance({
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0,
        })
        t:bind(obj, "BackgroundColor3", "TitleBar", "BackgroundTransparency")
        h.assertNear(obj.BackgroundTransparency, 0.35)
        local plain = h.fakeInstance({
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0,
        })
        t:bind(plain, "BackgroundColor3", "Container")
        h.assertNear(plain.BackgroundTransparency, 0)
    end,

    ["unbinding an object stops it being written"] = function()
        local t = Theme.new({ Accent = Color3.new(1, 0, 0) })
        local obj = h.fakeInstance({ BackgroundColor3 = Color3.new(0, 0, 0) })
        t:bind(obj, "BackgroundColor3", "Accent")
        t:tick(0)
        t:apply()
        t:unbind(obj)
        t:setAccent(Color3.new(0, 0, 1))
        t:apply()
        h.assertTrue(obj.BackgroundColor3 == Color3.new(1, 0, 0))
    end,
}
