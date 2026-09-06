-- Watermark: pure clampToViewport plus (from the next task) the pill widget
-- and its drag lifecycle.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Keeps a saved pill position inside the viewport after a resize. The
-- degenerate case (viewport smaller than the pill) collapses to the
-- top-left corner + padding, which is at least visible.
function M.clampToViewport(pos, size, viewport, padding)
    local maxX = viewport.w - size.w - padding
    local maxY = viewport.h - size.h - padding

    -- If the pill doesn't fit on either axis, don't half-fit it on the other:
    -- collapse both axes to the top-left corner so the whole pill stays put
    -- and visible, rather than pinning one edge while the rest hangs off.
    if maxX < padding or maxY < padding then
        return { x = padding, y = padding }
    end

    local x = pos.x
    if x > maxX then x = maxX end
    if x < padding then x = padding end

    local y = pos.y
    if y > maxY then y = maxY end
    if y < padding then y = padding end

    return { x = x, y = y }
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local safecall = require("util/safecall")

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach clampToViewport.
local Players
local RunService
local UserInputService

local Watermark = {}
Watermark.__index = Watermark

local PAD = 12
local REFRESH_INTERVAL = 1
-- Plain numbers, not Vector2.new(...): this is module scope, and Vector2
-- doesn't exist under the Lua 5.4 harness that also loads this file.
local DEFAULT_WIDTH = 140
local DEFAULT_HEIGHT = 22

local FLAG_POS = "chroma_watermark_pos"
local FLAG_SHOW = "chroma_watermark_show"

-- opts.Watermark:
--   nil    -> default template "NAME | FPS | PING"
--   string -> that string, static
--   func   -> called once per REFRESH_INTERVAL, returns the string
--   false  -> nothing built, manager is a no-op
function M.new(root, window, opts)
    opts = opts or {}
    if opts.Watermark == false then
        return setmetatable({ _disabled = true }, Watermark)
    end

    RunService = RunService or game:GetService("RunService")
    UserInputService = UserInputService or game:GetService("UserInputService")
    Players = Players or game:GetService("Players")

    local self = setmetatable({
        _root = root,
        _window = window,
        _theme = root.theme,
        _name = opts.Name or "Chroma",
        _source = opts.Watermark,
        _fpsBuffer = {},
        _fpsIndex = 1,
        _accum = 0,
    }, Watermark)

    self:_buildPill()
    self:_wireDrag()
    self:_wireHeartbeat()
    self:_applyPositionFromFlag()

    return self
end

function Watermark:_buildPill()
    local pill = Instance.new("TextButton")
    pill.Name = "watermark"
    pill.Size = UDim2.fromOffset(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    pill.BorderSizePixel = 0
    pill.AutoButtonColor = false
    pill.Font = Enum.Font.Ubuntu
    pill.TextSize = 12
    pill.Text = self._name
    pill.BackgroundTransparency = 0.15
    -- Passes clicks through while the menu is closed. Flipped in the drag
    -- setup based on window:isOpen().
    pill.Active = false
    pill.Parent = self._root.overlayLayer
    self._theme:bind(pill, "BackgroundColor3", "TitleBar")
    self._theme:bind(pill, "TextColor3", "Text")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = pill
    self._theme:bind(stroke, "Color", "FieldBorder")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = pill

    self._pill = pill
end

function Watermark:_wireDrag()
    local dragging = false
    local startMouse, startPos

    -- Only accepts drag input while the menu is open. Checked at InputBegan
    -- time; if the menu closes mid-drag, InputEnded still fires and drops it.
    self._root:keep(self._pill.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not self._window:isOpen() then return end
        dragging = true
        startMouse = UserInputService:GetMouseLocation()
        startPos = Vector2.new(self._pill.Position.X.Offset, self._pill.Position.Y.Offset)
    end))

    self._root:keep(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = UserInputService:GetMouseLocation() - startMouse
        local target = startPos + delta
        self._pill.Position = UDim2.fromOffset(target.X, target.Y)
    end))

    self._root:keep(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not dragging then return end
        dragging = false
        -- Persist the final position. No widget owns this flag, so
        -- setUnownedFlag writes both to Flags (for the live mirror) and to
        -- _pending (so the next SaveConfig serialises it).
        local pill = self._pill
        self._root.config:setUnownedFlag(FLAG_POS,
            Vector2.new(pill.Position.X.Offset, pill.Position.Y.Offset))
    end))

    -- Toggle Active whenever menu open/close changes. Poll on Heartbeat -- one
    -- read per frame, no signal wiring needed.
    self._root:keep(RunService.Heartbeat:Connect(function()
        self._pill.Active = self._window:isOpen()
    end))
end

function Watermark:_wireHeartbeat()
    self._root:keep(RunService.Heartbeat:Connect(function(dt)
        -- Rolling 30-frame average -- FPS jitters otherwise.
        local fps = 1 / math.max(dt, 1e-6)
        self._fpsBuffer[self._fpsIndex] = fps
        self._fpsIndex = self._fpsIndex % 30 + 1

        self._accum = self._accum + dt
        if self._accum < REFRESH_INTERVAL then return end
        self._accum = 0

        -- Toggle-driven visibility -- read from Flags for zero wiring cost.
        local show = self._root.config.Flags[FLAG_SHOW]
        if show == nil then show = true end
        self._pill.Visible = show
        if not show then return end

        self._pill.Text = self:_currentText()
    end))
end

function Watermark:_currentText()
    if type(self._source) == "string" then return self._source end
    if type(self._source) == "function" then
        local result = safecall.call("Watermark", self._source)
        if type(result) == "string" then return result end
        return "(watermark error)"
    end

    -- Default template.
    local sum, count = 0, 0
    for i = 1, #self._fpsBuffer do
        sum = sum + self._fpsBuffer[i]
        count = count + 1
    end
    local fps = count > 0 and math.floor(sum / count + 0.5) or 0

    local ping = 0
    local player = Players.LocalPlayer
    if player then
        local ok, p = pcall(function() return player:GetNetworkPing() * 1000 end)
        if ok then ping = math.floor(p + 0.5) end
    end

    return string.format("%s | %d FPS | %d ms", self._name, fps, ping)
end

function Watermark:_applyPositionFromFlag()
    -- flagValue rather than Flags[FLAG_POS]: this runs during Chroma:Window,
    -- before finish() has hydrated unowned flags into Flags from _pending.
    local saved = self._root.config:flagValue(FLAG_POS)
    local viewport = workspace.CurrentCamera.ViewportSize
    local pos
    if typeof(saved) == "Vector2" then
        pos = M.clampToViewport({ x = saved.X, y = saved.Y },
            { w = self._pill.Size.X.Offset, h = self._pill.Size.Y.Offset },
            { w = viewport.X, h = viewport.Y }, PAD)
    else
        -- Default: bottom-right, 12px in from each edge.
        pos = {
            x = viewport.X - self._pill.Size.X.Offset - PAD,
            y = viewport.Y - self._pill.Size.Y.Offset - PAD,
        }
    end
    -- Raw viewport coords go straight to Position. toLayerSpace is for
    -- converting an AbsolutePosition (already inset-shifted) into a Position
    -- offset; using it on raw viewport coords double-compensates and lands
    -- the pill 58px below the visible bottom.
    self._pill.Position = UDim2.fromOffset(pos.x, pos.y)
end

return M
