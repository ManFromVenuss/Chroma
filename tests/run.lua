-- Discovers tests/test_*.lua, runs every exported case, reports results.
package.path = "./?.lua;./?/init.lua;" .. package.path

local files = {
    "tests.test_harness",
    "tests.test_signal",
    "tests.test_safecall",
    "tests.test_guard",
    "tests.test_theme",
    "tests.test_backdrop",
    "tests.test_cursor",
    "tests.test_column",
    "tests.test_tooltip",
    "tests.test_slider",
    "tests.test_popup",
    "tests.test_keybind",
    "tests.test_colorpicker",
    "tests.test_serialise",
    "tests.test_config",
    "tests.test_icons",
    "tests.test_rail",
    "tests.test_toasts",
    "tests.test_watermark",
}

local passed, failed = 0, 0
local failures = {}
local skipped = {}

for _, modname in ipairs(files) do
    -- Decide skip-vs-fail by file existence, not by sniffing the require
    -- error string: Lua 5.4 emits the same "module not found" text whether
    -- the suite file itself is missing (expected, skip) or the suite file
    -- exists but one of its own requires points at something missing (a
    -- real bug that must fail loudly).
    local path = modname:gsub("%.", "/") .. ".lua"
    local f = io.open(path, "r")
    if not f then
        table.insert(skipped, (modname:gsub("^tests%.", "")))
    else
        f:close()
        local loaded, suite = pcall(require, modname)
        if not loaded then
            failed = failed + 1
            table.insert(failures, modname .. " (load error): " .. tostring(suite))
        else
            local names = {}
            for name in pairs(suite) do table.insert(names, name) end
            table.sort(names)
            for _, name in ipairs(names) do
                local ok, err = pcall(suite[name])
                if ok then
                    passed = passed + 1
                    print(string.format("  ok   %s :: %s", modname, name))
                else
                    failed = failed + 1
                    print(string.format("  FAIL %s :: %s", modname, name))
                    table.insert(failures, modname .. " :: " .. name .. "\n      " .. tostring(err))
                end
            end
        end
    end
end

print("")
if failed > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do print("  " .. f) end
end
if #skipped > 0 then
    print(string.format("skipped %d suites (not yet written): %s", #skipped, table.concat(skipped, ", ")))
end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
