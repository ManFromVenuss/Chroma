local h = require("tests.harness")
local Guard = h.makeRequire()("util/guard")

return {
    ["a fresh token is current"] = function()
        local g = Guard.new()
        local token = g:begin()
        h.assertTrue(g:isCurrent(token))
    end,

    ["beginning again supersedes the previous token"] = function()
        local g = Guard.new()
        local first = g:begin()
        local second = g:begin()
        h.assertFalse(g:isCurrent(first))
        h.assertTrue(g:isCurrent(second))
    end,

    ["tokens are distinct across many generations"] = function()
        local g = Guard.new()
        local seen = {}
        for _ = 1, 50 do
            local t = g:begin()
            h.assertFalse(seen[t])
            seen[t] = true
        end
    end,

    ["run only invokes the step while the token is current"] = function()
        local g = Guard.new()
        local ran = 0
        local token = g:begin()
        g:run(token, function() ran = ran + 1 end)
        h.assertEqual(ran, 1)
        g:begin()
        g:run(token, function() ran = ran + 1 end)
        h.assertEqual(ran, 1)
    end,

    ["cancel invalidates every outstanding token"] = function()
        local g = Guard.new()
        local token = g:begin()
        g:cancel()
        h.assertFalse(g:isCurrent(token))
    end,
}
