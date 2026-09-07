local h = require("tests.harness")
local Config = h.makeRequire()("core/config")

local function sorted(t)
    local out = {}
    for i = 1, #t do out[i] = t[i] end
    return table.concat(out, ",")
end

return {
    ["an ordinary name passes through"] = function()
        h.assertEqual(Config.sanitiseName("legit"), "legit")
        h.assertEqual(Config.sanitiseName("rage hvh 2"), "rage hvh 2")
    end,

    ["surrounding whitespace is trimmed"] = function()
        h.assertEqual(Config.sanitiseName("  legit  "), "legit")
    end,

    ["path separators are stripped"] = function()
        -- Otherwise a config named "../../boot" escapes the config folder.
        h.assertEqual(Config.sanitiseName("../../boot"), "boot")
        h.assertEqual(Config.sanitiseName("a/b"), "ab")
        h.assertEqual(Config.sanitiseName("a\\b"), "ab")
    end,

    ["characters the filesystem rejects are stripped"] = function()
        h.assertEqual(Config.sanitiseName('a:b*c?d"e<f>g|h'), "abcdefgh")
    end,

    ["leading dots are stripped"] = function()
        h.assertEqual(Config.sanitiseName(".hidden"), "hidden")
    end,

    ["an empty or unusable name is rejected"] = function()
        h.assertEqual(Config.sanitiseName(""), nil)
        h.assertEqual(Config.sanitiseName("   "), nil)
        h.assertEqual(Config.sanitiseName("///"), nil)
        h.assertEqual(Config.sanitiseName(nil), nil)
        h.assertEqual(Config.sanitiseName(42), nil)
    end,

    ["an overlong name is truncated"] = function()
        local long = string.rep("x", 200)
        h.assertEqual(#Config.sanitiseName(long), 64)
    end,

    ["diffFlags reports flags saved with no widget"] = function()
        local unknown = Config.diffFlags(
            { a = 1, gone = 2 }, { a = true })
        h.assertEqual(sorted(unknown), "gone")
    end,

    ["diffFlags reports widgets with nothing saved"] = function()
        local _, missing = Config.diffFlags(
            { a = 1 }, { a = true, fresh = true })
        h.assertEqual(sorted(missing), "fresh")
    end,

    ["diffFlags returns both lists sorted"] = function()
        local unknown, missing = Config.diffFlags(
            { z = 1, y = 1 }, { b = true, a = true })
        h.assertEqual(sorted(unknown), "y,z")
        h.assertEqual(sorted(missing), "a,b")
    end,

    ["diffFlags on a perfect match returns two empty lists"] = function()
        local unknown, missing = Config.diffFlags({ a = 1 }, { a = true })
        h.assertEqual(#unknown, 0)
        h.assertEqual(#missing, 0)
    end,
}
