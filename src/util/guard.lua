-- Generation counter for cancelling superseded animation chains.
-- Lua 5.4 / Luau intersection.
local Guard = {}
Guard.__index = Guard

function Guard.new()
    return setmetatable({ _gen = 0 }, Guard)
end

function Guard:begin()
    self._gen = self._gen + 1
    return self._gen
end

function Guard:isCurrent(token)
    return token == self._gen
end

-- Runs step only if token is still the live generation. Returns whether it ran,
-- so a caller can tell "cancelled" apart from "completed".
function Guard:run(token, step)
    if token ~= self._gen then return false end
    step()
    return true
end

function Guard:cancel()
    self._gen = self._gen + 1
end

return Guard
