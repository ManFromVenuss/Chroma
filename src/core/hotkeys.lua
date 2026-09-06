-- Hotkeys: pure formatRow that produces a display string per opted-in Keybind,
-- plus (from the next task) the overlay panel.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Always-mode reads as permanently active regardless of a bind. Any other mode
-- shows its key label -- which is "NONE" when the bind is unset (from
-- Keybind.formatKey).
function M.formatRow(name, mode, keyLabel)
    if mode == "Always" then
        return "[always] " .. tostring(name)
    end
    return "[" .. tostring(keyLabel) .. "] " .. tostring(name)
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local Keybind = require("widgets/keybind")   -- for Keybind.formatKey

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach formatRow.
local RunService
local UserInputService

local Hotkeys = {}
Hotkeys.__index = Hotkeys

local PAD = 12
local ROW_HEIGHT = 18
local PANEL_WIDTH = 160
local FLAG_POS = "chroma_hotkey_pos"
local FLAG_SHOW = "chroma_hotkey_show"

function M.new(root, window)
    RunService = RunService or game:GetService("RunService")
    UserInputService = UserInputService or game:GetService("UserInputService")

    local self = setmetatable({
        _root = root,
        _window = window,
        _theme = root.theme,
        _rows = {},   -- widget -> { frame, label }
    }, Hotkeys)

    self:_buildPanel()
    self:_wireDrag()
    self:_wireHeartbeat()
    self:_applyPositionFromFlag()

    return self
end

function Hotkeys:_buildPanel()
    local panel = Instance.new("TextButton")
    panel.Name = "hotkeys"
    panel.Size = UDim2.fromOffset(PANEL_WIDTH, ROW_HEIGHT)
    panel.BorderSizePixel = 0
    panel.AutoButtonColor = false
    panel.Text = ""
    panel.BackgroundTransparency = 0.15
    panel.Active = false
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false   -- shown once at least one row exists
    panel.Parent = self._root.overlayLayer
    self._theme:bind(panel, "BackgroundColor3", "TitleBar")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = panel
    self._theme:bind(stroke, "Color", "FieldBorder")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.Name
    layout.Padding = UDim.new(0, 2)
    layout.Parent = panel

    self._panel = panel
end

function Hotkeys:_wireDrag()
    local dragging = false
    local startMouse, startPos

    self._root:keep(self._panel.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not self._window:isOpen() then return end
        dragging = true
        startMouse = UserInputService:GetMouseLocation()
        startPos = Vector2.new(self._panel.Position.X.Offset, self._panel.Position.Y.Offset)
    end))

    self._root:keep(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = UserInputService:GetMouseLocation() - startMouse
        local target = startPos + delta
        self._panel.Position = UDim2.fromOffset(target.X, target.Y)
    end))

    self._root:keep(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not dragging then return end
        dragging = false
        -- Persist through the config manager so a Save picks it up. No widget
        -- owns this flag; setUnownedFlag handles the Flags + _pending pair.
        self._root.config:setUnownedFlag(FLAG_POS, Vector2.new(
            self._panel.Position.X.Offset, self._panel.Position.Y.Offset))
    end))

    self._root:keep(RunService.Heartbeat:Connect(function()
        self._panel.Active = self._window:isOpen()
    end))
end

function Hotkeys:_wireHeartbeat()
    self._root:keep(RunService.Heartbeat:Connect(function()
        local show = self._root.config.Flags[FLAG_SHOW]
        if show == nil then show = true end
        if not show then
            self._panel.Visible = false
            return
        end

        self:_rebuild()
    end))
end

function Hotkeys:_rebuild()
    -- Enumerate every registered Keybind that opted in. Access the config's
    -- widget registry directly -- there is one widget map, no widget-type
    -- filter needed beyond ShowsInHotkeys.
    local optedIn = {}
    for flag, widget in pairs(self._root.config._widgets) do
        if type(widget.ShowsInHotkeys) == "function" and widget:ShowsInHotkeys() then
            table.insert(optedIn, { flag = flag, widget = widget })
        end
    end

    -- Sort by Name so rows stay in a stable order as binds toggle. Tiebreak
    -- on flag (unique per widget) since table.sort is not stable and pairs()
    -- enumeration order is undefined -- without it, two same-named rows
    -- would flap between frames.
    table.sort(optedIn, function(a, b)
        local la, lb = tostring(a.widget._label), tostring(b.widget._label)
        if la ~= lb then return la < lb end
        return a.flag < b.flag
    end)

    -- Track which widgets still have rows, so orphans get destroyed.
    local seen = {}
    for i = 1, #optedIn do
        local widget = optedIn[i].widget
        seen[widget] = true

        local row = self._rows[widget]
        if row == nil then
            row = self:_buildRow(widget)
            self._rows[widget] = row
        end

        local bind = widget:Get()
        local mode = widget:GetMode()
        local keyLabel
        if bind == nil then
            keyLabel = "NONE"
        elseif typeof(bind) == "EnumItem" and bind.EnumType == Enum.UserInputType then
            keyLabel = Keybind.formatKey(bind.Name, nil)
        else
            keyLabel = Keybind.formatKey(nil, bind.Name)
        end

        row.label.Text = M.formatRow(widget._label, mode, keyLabel)
        row.label.Name = widget._label   -- feeds UIListLayout SortOrder.Name

        local held = widget:IsHeld()
        self._theme:unbind(row.label)
        self._theme:bind(row.label, "TextColor3", held and "TextBright" or "TextDim")
    end

    for widget, row in pairs(self._rows) do
        if not seen[widget] then
            self._theme:unbind(row.label)
            row.frame:Destroy()
            self._rows[widget] = nil
        end
    end

    self._panel.Visible = #optedIn > 0
end

function Hotkeys:_buildRow(widget)
    local frame = Instance.new("Frame")
    frame.Name = widget._label
    frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = self._panel

    local label = Instance.new("TextLabel")
    label.Name = "text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Ubuntu
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = ""
    label.Parent = frame

    return { frame = frame, label = label }
end

function Hotkeys:_applyPositionFromFlag()
    -- flagValue rather than Flags[FLAG_POS]: this runs during Chroma:Window,
    -- before finish() has hydrated unowned flags into Flags from _pending.
    local saved = self._root.config:flagValue(FLAG_POS)
    local viewport = workspace.CurrentCamera.ViewportSize
    local pos
    if typeof(saved) == "Vector2" then
        -- Same clamp shape as watermark.lua's clampToViewport, inlined rather
        -- than required across modules -- one small local function beats the
        -- cross-file dependency for a five-line calculation.
        local sx, sy = saved.X, saved.Y
        local maxX = viewport.X - PANEL_WIDTH - PAD
        local maxY = viewport.Y - ROW_HEIGHT * 4 - PAD
        if sx > maxX then sx = maxX end
        if sx < PAD then sx = PAD end
        if sy > maxY then sy = maxY end
        if sy < PAD then sy = PAD end
        pos = { x = sx, y = sy }
    end
    if pos == nil then
        pos = { x = PAD, y = viewport.Y - ROW_HEIGHT * 4 - PAD }
    end
    -- Raw viewport coords go straight to Position. toLayerSpace is for
    -- converting AbsolutePosition (already inset-shifted) into a Position
    -- offset; using it on raw viewport coords double-compensates and lands
    -- the panel 58px below the visible bottom.
    self._panel.Position = UDim2.fromOffset(pos.x, pos.y)
end

return M
