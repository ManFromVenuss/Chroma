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

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local serialise = require("core/serialise")

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach the helpers above.
local HttpService

local Config = {}
Config.__index = Config

function M.new(root, folder)
    HttpService = HttpService or game:GetService("HttpService")

    return setmetatable({
        _root = root,
        _folder = folder,
        _widgets = {},   -- flag -> widget
        _opts = {},      -- flag -> the opts it was built with, for warnings
        _pending = {},   -- flag -> encoded value, waiting for the menu to finish
        _live = false,
        -- Plain current values, exposed as Chroma.Flags. Maintained through the
        -- widget contract rather than by the widgets themselves.
        Flags = {},
    }, Config)
end

-- Called by container.lua for every widget it builds.
function Config:register(flag, widget)
    if self._widgets[flag] ~= nil then
        error(string.format("chroma: two widgets share the flag '%s'", tostring(flag)), 2)
    end
    self._widgets[flag] = widget

    self.Flags[flag] = widget:Get()
    widget:OnChanged(function(value)
        self.Flags[flag] = value
    end)

    -- Before the menu is finished, saved values wait in _pending and are
    -- applied together. After it, a widget built later catches up immediately.
    local saved = self._pending[flag]
    if saved ~= nil and self._live then
        self:_apply(flag, saved)
        self._pending[flag] = nil
    end
end

function Config:get(flag)
    return self._widgets[flag]
end

-- Widgets whose state is more than Get() returns say so with Save()/Load().
function Config:_apply(flag, encoded)
    local widget = self._widgets[flag]
    if widget == nil then return end
    local value = serialise.decode(encoded)
    if value == nil then return end

    if type(widget.Load) == "function" then
        widget:Load(value)
    else
        widget:Set(value)
    end
    self.Flags[flag] = widget:Get()
end

function Config:_snapshot()
    local out = {}
    for flag, widget in pairs(self._widgets) do
        local value
        if type(widget.Save) == "function" then
            value = widget:Save()
        else
            value = widget:Get()
        end
        local encoded = serialise.encode(value)
        if encoded ~= nil then out[flag] = encoded end
    end
    return out
end

return M
