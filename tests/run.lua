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
}

local passed, failed = 0, 0
local failures = {}

for _, modname in ipairs(files) do
    local loaded, suite = pcall(require, modname)
    if not loaded then
        -- A suite that does not exist yet is skipped, not a failure: this lets
        -- the file list stay complete while tasks are implemented in order.
        if not tostring(suite):find("not found", 1, true) then
            failed = failed + 1
            table.insert(failures, modname .. " (load error): " .. tostring(suite))
        end
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

print("")
if failed > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do print("  " .. f) end
end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
