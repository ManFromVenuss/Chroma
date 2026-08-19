-- Owns the ScreenGui, the layer stack, and the single junk list that Unload
-- walks. No other module cleans up after itself.
local Theme = require("core/theme")

local GuiService
local UserInputService

local Root = {}
Root.__index = Root

local function pickParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui, "gethui" end
    end
    local okCoreGui, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if okCoreGui and cloneref then
        local ok, cloned = pcall(cloneref, coreGui)
        if ok and cloned then return cloned, "cloneref(CoreGui)" end
    end
    local ok, playerGui = pcall(function()
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end)
    if ok and playerGui then return playerGui, "PlayerGui" end
    if okCoreGui and coreGui then return coreGui, "CoreGui" end
    error("chroma: no viable GUI parent (tried gethui, cloneref, PlayerGui, CoreGui)", 0)
end

local function randomName()
    local chars = "abcdefghijklmnopqrstuvwxyz"
    local out = {}
    for _ = 1, 12 do
        local i = math.random(1, #chars)
        table.insert(out, chars:sub(i, i))
    end
    return table.concat(out)
end

function Root.new(opts)
    opts = opts or {}
    GuiService = GuiService or game:GetService("GuiService")
    UserInputService = UserInputService or game:GetService("UserInputService")

    local parent, parentKind = pickParent()

    local self = setmetatable({
        _junk = {},
        _degraded = {},
        _alive = true,
        -- Set by a Keybind while it is capturing. The window's toggle handler
        -- checks it: without this, binding the menu's own toggle key would bind
        -- the key AND close the menu in one press.
        capturing = false,
        parentKind = parentKind,
        theme = Theme.new(opts),
    }, Root)

    local gui = Instance.new("ScreenGui")
    gui.Name = randomName()
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 2147483000
    gui.Parent = parent
    self.gui = gui
    self:keep(function() gui:Destroy() end)

    -- Layer stack. Popups and tooltips are siblings ABOVE the window, never
    -- children of a container: the window body clips for the slide animation,
    -- so anything meant to overflow has to live outside it.
    self.windowLayer = self:_layer("windows", 1)
    self.popupLayer = self:_layer("popups", 100)
    self.tooltipLayer = self:_layer("tooltips", 200)

    if not writefile then self:degrade("config", "writefile missing: configs disabled") end
    if not DrawingImmediate then self:degrade("cursor", "DrawingImmediate missing: OS cursor retained") end

    self:_startHeartbeat()
    return self
end

function Root:_layer(name, zindex)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ZIndex = zindex
    frame.Parent = self.gui
    return frame
end

-- Register anything that must be undone on Unload: instances, connections,
-- tweens, restored globals. Accepts a function, an Instance, a Connection, or
-- an object with a Disconnect method.
function Root:keep(item)
    if type(item) == "function" then
        table.insert(self._junk, item)
    elseif typeof(item) == "Instance" then
        table.insert(self._junk, function() item:Destroy() end)
    elseif typeof(item) == "RBXScriptConnection" then
        table.insert(self._junk, function() item:Disconnect() end)
    else
        -- Executor signal implementations (e.g. Potassium's
        -- DrawingImmediate.GetPaint():Connect()) return connection-like
        -- userdata that is neither an Instance nor an RBXScriptConnection
        -- (typeof reports something executor-specific, e.g. "PsmConnection").
        -- There is no closed set of these types to check against, so fall
        -- back to structural typing: anything exposing a callable Disconnect
        -- is treated as a connection. Indexing arbitrary userdata can itself
        -- throw, so probe it through pcall rather than assuming it is safe.
        local ok, disconnect = pcall(function() return item.Disconnect end)
        if ok and type(disconnect) == "function" then
            table.insert(self._junk, function()
                pcall(function() item:Disconnect() end)
            end)
            return item
        end
        error("chroma: Root:keep expects a function, Instance, Connection, or an object with a Disconnect method", 2)
    end
    return item
end

--== coordinate spaces ==--
-- GetMouseLocation is true screen space. AbsolutePosition is measured below the
-- GUI inset, and Position is relative to a parent that may itself be offset.
-- Converting by hand caused four separate bugs: the window teleporting on every
-- drag, the cursor's hover rect sitting 58px high, the window centring itself
-- too high, and the tooltip floating above its icon. Convert here instead.

-- The pointer, in the same space as any AbsolutePosition.
function Root:mouseInGuiSpace()
    local mouse = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    return mouse.X - inset.X, mouse.Y - inset.Y
end

-- An AbsolutePosition-space point, as a Position offset for a child of `layer`.
function Root:toLayerSpace(x, y, layer)
    local origin = (layer or self.gui).AbsolutePosition
    return x - origin.X, y - origin.Y
end

function Root:degrade(feature, reason)
    if self._degraded[feature] then return end
    self._degraded[feature] = reason
    warn("[Chroma] degraded: " .. reason)
end

function Root:isDegraded(feature)
    return self._degraded[feature] ~= nil
end

-- task.delay cannot be cancelled, so deferred callbacks scheduled before an
-- Unload can still fire afterwards; they must check this explicitly instead
-- of relying on the junk list to have stopped them.
function Root:isAlive()
    return self._alive
end

function Root:_startHeartbeat()
    local clock = 0
    local conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        clock = clock + dt
        self.theme:tick(clock)
        if self.theme:isAnimated() then
            self.theme:apply()
        end
        if self._onFrame then
            -- Internal hook (registered by Chroma's own window module), not a
            -- consumer callback: let errors propagate instead of swallowing them.
            self._onFrame(dt, clock)
        end
    end)
    self:keep(conn)
end

function Root:onFrame(fn)
    assert(self._onFrame == nil, "chroma: Root:onFrame already registered")
    self._onFrame = fn
end

function Root:Unload()
    self._alive = false
    for i = #self._junk, 1, -1 do
        pcall(self._junk[i])
    end
    self._junk = {}
    self.theme:clearBindings()
end

return Root
