-- Minimal signal. No Roblox dependency, so it is unit tested locally.
-- Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops.
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:disconnect()
    if self._dead then return end
    self._dead = true
    local listeners = self._signal._listeners
    for i = 1, #listeners do
        if listeners[i] == self then
            table.remove(listeners, i)
            return
        end
    end
end

function Signal.new()
    return setmetatable({ _listeners = {} }, Signal)
end

function Signal:connect(fn)
    local conn = setmetatable({ _signal = self, _fn = fn, _dead = false }, Connection)
    table.insert(self._listeners, conn)
    return conn
end

function Signal:fire(...)
    -- Iterate a copy: a listener may disconnect itself or others mid-fire.
    local snapshot = {}
    for i = 1, #self._listeners do snapshot[i] = self._listeners[i] end
    for i = 1, #snapshot do
        local conn = snapshot[i]
        if not conn._dead then conn._fn(...) end
    end
end

function Signal:count()
    return #self._listeners
end

function Signal:destroy()
    for i = 1, #self._listeners do self._listeners[i]._dead = true end
    self._listeners = {}
end

return Signal
