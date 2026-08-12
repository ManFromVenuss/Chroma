-- Isolates CONSUMER callbacks. Chroma's own errors are deliberately not routed
-- through this: those are bugs and should surface loudly.
-- Lua 5.4 / Luau intersection.
local M = {}

local logger = nil

function M.setLogger(fn)
    logger = fn
end

local function report(label, err)
    local msg = "[Chroma] " .. tostring(label) .. " -> " .. tostring(err)
    if logger then
        logger(msg)
    else
        warn(msg)
    end
end

function M.call(label, fn, ...)
    if fn == nil then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then
        report(label, result)
        return nil
    end
    return result
end

function M.wrap(label, fn)
    return function(...)
        return M.call(label, fn, ...)
    end
end

return M
