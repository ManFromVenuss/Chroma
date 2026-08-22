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

-- A single flag erroring (Keybind:Load calling SetMode on a corrupt value, for
-- instance) must not stop every flag after it in iteration order from
-- applying -- pairs() order is arbitrary, so that would drop configs at
-- random. Isolate each apply and warn with enough to find the bad flag.
local function applyOne(self, flag, value, configName)
    local ok, err = pcall(self._apply, self, flag, value)
    if not ok then
        warn(string.format("[Chroma] config '%s' flag '%s' failed to load: %s",
            tostring(configName), tostring(flag), tostring(err)))
    end
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

--== file IO ==--
-- Executors sandbox these to their own workspace folder, so paths are relative
-- and no absolute path is ever built.

local function ensureFolder(path)
    if isfolder and not isfolder(path) then
        if makefolder then makefolder(path) end
    end
end

function Config:_configPath(name)
    return self._folder .. "/configs/" .. name .. ".json"
end

function Config:isAvailable()
    return not self._root:isDegraded("config")
end

function Config:ensureFolders()
    if not self:isAvailable() then return end
    ensureFolder(self._folder)
    ensureFolder(self._folder .. "/configs")
end

function Config:List()
    if not self:isAvailable() or not listfiles then return {} end
    self:ensureFolders()

    local out = {}
    local ok, files = pcall(listfiles, self._folder .. "/configs")
    if not ok then return out end

    for i = 1, #files do
        local name = files[i]:match("([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    table.sort(out)
    return out
end

function Config:Save(rawName)
    if not self:isAvailable() then return false, "configs unavailable" end

    local name = M.sanitiseName(rawName)
    if name == nil then return false, "invalid config name" end

    self:ensureFolders()

    -- Unknown flags are carried through rather than dropped: a config written
    -- by a build with more widgets should survive a round trip through one with
    -- fewer, or loading a script twice would quietly prune it.
    local data = self:_snapshot()
    for flag, value in pairs(self._pending) do
        if self._widgets[flag] == nil then data[flag] = value end
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then return false, "could not encode config" end

    local written = pcall(writefile, self:_configPath(name), encoded)
    if not written then return false, "could not write config" end
    return true, name
end

function Config:Load(rawName)
    if not self:isAvailable() then return false, "configs unavailable" end

    local name = M.sanitiseName(rawName)
    if name == nil then return false, "invalid config name" end

    local path = self:_configPath(name)
    if isfile and not isfile(path) then return false, "no such config" end

    local ok, text = pcall(readfile, path)
    if not ok then return false, "could not read config" end

    local decoded, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if not decoded or type(data) ~= "table" then
        -- Corrupt on disk. Warn and leave the menu alone rather than erroring:
        -- a bad file must not cost the user their whole session.
        warn("[Chroma] config '" .. name .. "' is unreadable and was ignored")
        return false, "corrupt config"
    end

    local unknown = M.diffFlags(data, self._widgets)
    if #unknown > 0 then
        -- Almost always a renamed Flag, which strands every value saved under
        -- the old name. Silence here is what makes that expensive to find.
        warn("[Chroma] config '" .. name .. "' has " .. #unknown ..
            " flag(s) with no widget: " .. table.concat(unknown, ", "))
    end

    for flag, value in pairs(data) do
        if self._widgets[flag] ~= nil then
            applyOne(self, flag, value, name)
        else
            self._pending[flag] = value
        end
    end
    return true, name
end

function Config:Delete(rawName)
    if not self:isAvailable() then return false, "configs unavailable" end

    local name = M.sanitiseName(rawName)
    if name == nil then return false, "invalid config name" end

    local path = self:_configPath(name)
    if isfile and not isfile(path) then return false, "no such config" end
    if not delfile then return false, "delfile unavailable" end

    local ok = pcall(delfile, path)
    if not ok then return false, "could not delete config" end
    return true, name
end

--== autoload ==--
-- Chroma:Window() returns before a single widget exists, so there is no natural
-- moment at which the menu is known to be built. Saved values therefore wait in
-- _pending until one of two signals, then apply with an ordinary Set so
-- callbacks fire once, normally.

-- No new widget for this long also counts as finished. It exists for scripts
-- that end in a render loop, whose thread never dies.
local QUIET = 1

function Config:_autoloadPath()
    return self._folder .. "/autoload.txt"
end

function Config:GetAutoload()
    if not self:isAvailable() or not isfile then return nil end
    local path = self:_autoloadPath()
    if not isfile(path) then return nil end
    local ok, text = pcall(readfile, path)
    if not ok then return nil end
    return M.sanitiseName(text)
end

function Config:SetAutoload(rawName)
    if not self:isAvailable() then return false end
    self:ensureFolders()

    if rawName == nil then
        if delfile and isfile and isfile(self:_autoloadPath()) then
            pcall(delfile, self:_autoloadPath())
        end
        return true
    end

    local name = M.sanitiseName(rawName)
    if name == nil then return false end
    return pcall(writefile, self:_autoloadPath(), name) and true or false
end

-- Reads the marked config into _pending without touching any widget. Called
-- during Window(), when there are none yet.
function Config:primeAutoload()
    local name = self:GetAutoload()
    if name == nil then return end

    local path = self:_configPath(name)
    if isfile and not isfile(path) then return end

    local ok, text = pcall(readfile, path)
    if not ok then return end

    local decoded, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if not decoded or type(data) ~= "table" then
        warn("[Chroma] autoload config '" .. name .. "' is unreadable and was ignored")
        return
    end

    for flag, value in pairs(data) do
        self._pending[flag] = value
    end
    self._autoloadName = name
end

-- Applies everything still pending, then marks the manager live so any widget
-- built afterwards catches up on registration instead.
--
-- A flag still unmatched here is not yet known to be orphaned: finish() can
-- fire on the quiet timeout while the consumer script is merely slow (an
-- HttpGet mid-build, say), before every widget has registered. Such a flag
-- stays in _pending, where a late registration or the next Save still finds
-- it, so no warning is given here -- it would be a guess, and wrong for the
-- common slow-script case. A flag that really is orphaned is surfaced
-- unambiguously later, by an explicit LoadConfig call.
function Config:finish()
    if self._live then return end
    self._live = true

    local applied = 0
    for flag, value in pairs(self._pending) do
        if self._widgets[flag] ~= nil then
            applyOne(self, flag, value, self._autoloadName)
            self._pending[flag] = nil
            applied = applied + 1
        end
    end

    return applied
end

-- Watches for the menu being finished. `thread` is the consumer's script
-- thread, captured in Window(): once it is dead, the script body has run to
-- completion. That handles a script yielding mid-build -- an HttpGet leaves the
-- thread suspended, not dead -- which a deferred call does not.
--
-- LoadConfig() always works by hand, so if both signals somehow fail the cost
-- is that autoload did not fire, not that configs are broken.
function Config:watchForCompletion(thread)
    local RunService = game:GetService("RunService")
    local waited = 0
    local lastCount = 0

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not self._root:isAlive() or self._live then
            conn:Disconnect()
            return
        end

        local count = 0
        for _ in pairs(self._widgets) do count = count + 1 end
        if count ~= lastCount then
            lastCount = count
            waited = 0
        else
            waited = waited + dt
        end

        local dead = thread == nil or coroutine.status(thread) == "dead"
        if dead or waited >= QUIET then
            conn:Disconnect()
            self:finish()
        end
    end)
    self._root:keep(conn)
end

return M
