local h = require("tests.harness")
local Search = h.makeRequire()("core/search")

local function entry(label)
    return { label = label, path = "" }
end

return {
    ["empty or whitespace query returns nothing"] = function()
        h.assertEqual(#Search.rank("", { entry("Aim") }), 0)
        h.assertEqual(#Search.rank("   ", { entry("Aim") }), 0)
    end,

    ["case-insensitive match on query and label"] = function()
        local out = Search.rank("AIM", { entry("aim fov") })
        h.assertEqual(#out, 1)
        h.assertEqual(out[1].label, "aim fov")
    end,

    ["non-matching entries are dropped"] = function()
        local out = Search.rank("zzz", { entry("Aim"), entry("Trigger") })
        h.assertEqual(#out, 0)
    end,

    ["exact match ranks above prefix"] = function()
        local out = Search.rank("aim", { entry("Aimbot"), entry("Aim") })
        h.assertEqual(out[1].label, "Aim")
        h.assertEqual(out[2].label, "Aimbot")
    end,

    ["prefix ranks above word-start"] = function()
        local out = Search.rank("aim", { entry("Silent Aim"), entry("Aimbot") })
        h.assertEqual(out[1].label, "Aimbot")
        h.assertEqual(out[2].label, "Silent Aim")
    end,

    ["word-start ranks above interior substring"] = function()
        local out = Search.rank("aim", { entry("Claim"), entry("Silent Aim") })
        h.assertEqual(out[1].label, "Silent Aim")
        h.assertEqual(out[2].label, "Claim")
    end,

    ["word-start match works after an underscore"] = function()
        local out = Search.rank("fov", { entry("aim_fov") })
        h.assertEqual(#out, 1)
    end,

    ["ties break alphabetically by label"] = function()
        local out = Search.rank("a", { entry("Charlie"), entry("Alpha"), entry("Bravo") })
        h.assertEqual(out[1].label, "Alpha")
        h.assertEqual(out[2].label, "Bravo")
        h.assertEqual(out[3].label, "Charlie")
    end,

    ["query is trimmed of surrounding whitespace"] = function()
        local out = Search.rank("  aim  ", { entry("Aim") })
        h.assertEqual(#out, 1)
    end,

    ["path is not searched"] = function()
        -- If path matched, this would return a result.
        local out = Search.rank("combat",
            { { label = "Aim", path = "Combat > Aimbot" } })
        h.assertEqual(#out, 0)
    end,
}
