-- The saved-colour palette, shared by every colorpicker in the window.
--
-- Global rather than per-config, in its own file: a palette is a preference
-- about how you work, not a setting of one config, and loading a config should
-- not silently swap your swatches.

local serialise = require("core/serialise")

local M = {}

local MAX = 10

local Palette = {}
Palette.__index = Palette

function M.new(root, folder)
    local self = setmetatable({
        _root = root,
        _path = folder .. "/palette.json",
        _colours = {},
        _listeners = {},
    }, Palette)
    self:_read()
    return self
end

function Palette:Get()
    return self._colours
end

function Palette:onChanged(fn)
    table.insert(self._listeners, fn)
end

function Palette:_notify()
    for i = 1, #self._listeners do
        self._listeners[i]()
    end
end

function Palette:Add(colour)
    if typeof(colour) ~= "Color3" then return end
    for i = 1, #self._colours do
        if self._colours[i] == colour then return end
    end
    table.insert(self._colours, colour)
    -- Oldest out first: the row is a fixed width, and silently refusing to add
    -- would read as the button being broken.
    while #self._colours > MAX do
        table.remove(self._colours, 1)
    end
    self:_write()
    self:_notify()
end

function Palette:Remove(index)
    if self._colours[index] == nil then return end
    table.remove(self._colours, index)
    self:_write()
    self:_notify()
end

function Palette:_read()
    if self._root:isDegraded("config") or not isfile then return end
    if not isfile(self._path) then return end

    local ok, text = pcall(readfile, self._path)
    if not ok then return end

    local HttpService = game:GetService("HttpService")
    local decoded, data = pcall(function() return HttpService:JSONDecode(text) end)
    if not decoded or type(data) ~= "table" then return end

    for i = 1, #data do
        local colour = serialise.decode(data[i])
        if typeof(colour) == "Color3" then
            table.insert(self._colours, colour)
        end
    end
end

function Palette:_write()
    if self._root:isDegraded("config") or not writefile then return end

    local out = {}
    for i = 1, #self._colours do
        out[i] = serialise.encode(self._colours[i])
    end

    local HttpService = game:GetService("HttpService")
    local ok, text = pcall(function() return HttpService:JSONEncode(out) end)
    if not ok then return end
    pcall(writefile, self._path, text)
end

return M
