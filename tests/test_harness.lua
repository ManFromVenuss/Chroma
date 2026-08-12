-- Proves the require shim can load a module from src/ and cache it.
local h = require("tests.harness")

return {
    ["shim loads a module"] = function()
        local req = h.makeRequire()
        local Guard = req("util/guard")
        h.assertTrue(type(Guard.new) == "function")
    end,

    ["shim caches modules"] = function()
        local req = h.makeRequire()
        local a = req("util/guard")
        local b = req("util/guard")
        h.assertSame(a, b)
    end,

    ["shim errors on unknown module"] = function()
        local req = h.makeRequire()
        local ok, err = pcall(req, "util/does_not_exist")
        h.assertEqual(ok, false)
        h.assertMatch(tostring(err), "unknown module")
    end,
}
