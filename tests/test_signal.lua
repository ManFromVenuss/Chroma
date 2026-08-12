local h = require("tests.harness")
local Signal = h.makeRequire()("util/signal")

return {
    ["fire calls every listener with args"] = function()
        local s = Signal.new()
        local seen = {}
        s:connect(function(a, b) table.insert(seen, a .. b) end)
        s:connect(function(a, b) table.insert(seen, b .. a) end)
        s:fire("x", "y")
        h.assertEqual(#seen, 2)
        h.assertEqual(seen[1], "xy")
        h.assertEqual(seen[2], "yx")
    end,

    ["disconnect stops a listener"] = function()
        local s = Signal.new()
        local count = 0
        local conn = s:connect(function() count = count + 1 end)
        s:fire()
        conn:disconnect()
        s:fire()
        h.assertEqual(count, 1)
    end,

    ["disconnect is idempotent"] = function()
        local s = Signal.new()
        local conn = s:connect(function() end)
        conn:disconnect()
        conn:disconnect()
        h.assertEqual(s:count(), 0)
    end,

    ["disconnecting during fire does not skip listeners"] = function()
        local s = Signal.new()
        local calls = {}
        local c1
        c1 = s:connect(function() table.insert(calls, "a") c1:disconnect() end)
        s:connect(function() table.insert(calls, "b") end)
        s:fire()
        h.assertEqual(#calls, 2)
        h.assertEqual(calls[2], "b")
    end,

    ["destroy drops all listeners"] = function()
        local s = Signal.new()
        s:connect(function() error("should not run") end)
        s:destroy()
        s:fire()
        h.assertEqual(s:count(), 0)
    end,
}
