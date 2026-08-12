local h = require("tests.harness")
local safecall = h.makeRequire()("util/safecall")

return {
    ["passes through the return value"] = function()
        local got = safecall.call("Test/Thing", function(a, b) return a + b end, 2, 3)
        h.assertEqual(got, 5)
    end,

    ["returns nil and logs when the callback errors"] = function()
        local logged = {}
        safecall.setLogger(function(msg) table.insert(logged, msg) end)
        local got = safecall.call("Combat/Aimbot/Enabled", function() error("boom") end)
        h.assertEqual(got, nil)
        h.assertEqual(#logged, 1)
        h.assertMatch(logged[1], "[Chroma]")
        h.assertMatch(logged[1], "Combat/Aimbot/Enabled")
        h.assertMatch(logged[1], "boom")
        safecall.setLogger(nil)
    end,

    ["a nil callback is a no-op, not an error"] = function()
        local got = safecall.call("Test/Nil", nil, 1, 2)
        h.assertEqual(got, nil)
    end,

    ["wrap returns a reusable guarded function"] = function()
        local logged = {}
        safecall.setLogger(function(msg) table.insert(logged, msg) end)
        local fn = safecall.wrap("Test/Wrapped", function(x)
            if x < 0 then error("negative") end
            return x * 2
        end)
        h.assertEqual(fn(4), 8)
        h.assertEqual(fn(-1), nil)
        h.assertEqual(#logged, 1)
        safecall.setLogger(nil)
    end,
}
