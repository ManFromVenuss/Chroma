-- The config manager: the pure name and diff helpers, plus the registry,
-- restore lifecycle and file IO.
--
-- The helpers here are unit tested, so they stay in the Lua 5.4 / Luau
-- intersection: no compound assignment, no bitwise ops, no goto.

local M = {}

local MAX_NAME = 64

-- A config name becomes a filename, so it has to survive the filesystem and
-- must not be able to escape the config folder. Returns nil for anything
-- unusable rather than guessing a replacement.
function M.sanitiseName(name)
    if type(name) ~= "string" then return nil end

    local s = name:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    -- Path separators and the characters Windows rejects in a filename.
    s = s:gsub("[/\\:%*%?\"<>|]", "")
    -- Leading dots hide the file, and ".." is how a traversal starts.
    s = s:gsub("^%.+", "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")

    if s == "" then return nil end
    if #s > MAX_NAME then s = s:sub(1, MAX_NAME) end
    return s
end

-- Compares a loaded config against the registered flags.
--
-- `unknown` is the orphaning case -- a flag in the file with no widget, which
-- usually means a Flag was renamed and every saved value under the old name is
-- now stranded. It is warned about rather than passed over silently.
--
-- `missing` is ordinary: a config saved before an option existed.
--
-- Both are sorted, so the warning reads the same twice running.
function M.diffFlags(saved, registered)
    local unknown, missing = {}, {}

    for flag in pairs(saved) do
        if registered[flag] == nil then
            table.insert(unknown, flag)
        end
    end
    for flag in pairs(registered) do
        if saved[flag] == nil then
            table.insert(missing, flag)
        end
    end

    table.sort(unknown)
    table.sort(missing)
    return unknown, missing
end

return M
