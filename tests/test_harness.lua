-- Proves the require shim can load a module from src/ and cache it.
local h = require("tests.harness")

return {
    ["shim loads a module"] = function()
        local req = h.makeRequire()
        local mod = req("util/nothing")
        h.assertEqual(mod.answer, 42)
    end,

    ["shim caches modules"] = function()
        local req = h.makeRequire()
        local a = req("util/nothing")
        local b = req("util/nothing")
        h.assertSame(a, b)
    end,

    ["shim errors on unknown module"] = function()
        local req = h.makeRequire()
        local ok, err = pcall(req, "util/does_not_exist")
        h.assertEqual(ok, false)
        h.assertMatch(tostring(err), "unknown module")
    end,
}
