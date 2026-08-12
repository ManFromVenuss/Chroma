-- Tooltip: the pure placement maths, plus (from a later task) the single reused
-- frame in the tooltip layer.
--
-- place() is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

M.GAP = 8       -- pixels between the anchor and the tooltip
M.MARGIN = 8    -- minimum distance from any screen edge
M.Y_NUDGE = -3  -- lifts the tooltip so its text sits level with the icon, not below it

-- Anchored placement beside `anchor`, flipping left and clamping up as needed.
--
-- Everything here is in one coordinate space -- the anchor's -- which is the
-- quiet advantage of anchoring over following the cursor: GetMouseLocation
-- never enters the calculation, so the GUI-inset mismatch that caused two M1
-- bugs cannot happen.
function M.place(anchor, tip, viewport, gap, margin)
    gap = gap or M.GAP
    margin = margin or M.MARGIN

    local x = anchor.x + anchor.w + gap
    if x + tip.w > viewport.w - margin then
        x = anchor.x - tip.w - gap
    end
    if x < margin then x = margin end

    local y = anchor.y + M.Y_NUDGE
    if y + tip.h > viewport.h - margin then
        y = viewport.h - margin - tip.h
    end
    if y < margin then y = margin end

    return x, y
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

-- Resolved lazily: a module-scope game:GetService() executes on require, and
-- the Lua 5.4 harness requires this file to reach place().
local UserInputService
local RunService
local GuiService

local Tooltip = {}
Tooltip.__index = Tooltip

local DELAY = 0.15
local MAX_WIDTH = 220

-- One manager per window, owning ONE reused frame -- the same pooling reasoning
-- as the star particles. Rows attach to it; they never create tooltips.
function M.new(root)
    UserInputService = UserInputService or game:GetService("UserInputService")
    RunService = RunService or game:GetService("RunService")
    GuiService = GuiService or game:GetService("GuiService")

    local theme = root.theme

    local frame = Instance.new("Frame")
    frame.Name = "tooltip"
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Size = UDim2.fromOffset(MAX_WIDTH, 0)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 10
    -- Active stays false and no button is used: the tooltip must NEVER
    -- intercept input. If it did, a tooltip placed over its own icon would
    -- steal the pointer, fire MouseLeave on the icon, hide itself, and
    -- immediately re-trigger -- a hide/show flicker loop.
    frame.Parent = root.tooltipLayer
    root:keep(frame)
    theme:bind(frame, "BackgroundColor3", "Window")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = frame
    theme:bind(stroke, "Color", "Accent")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "text"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.Ubuntu
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    -- Wrapping is correct HERE and nowhere else in Chroma: this is a standalone
    -- floating frame, not a child of an auto-sizing container, so a re-flow
    -- cannot under-size anything around it.
    label.TextWrapped = true
    label.ZIndex = 11
    label.Parent = frame
    theme:bind(label, "TextColor3", "Text")

    local self = setmetatable({
        _root = root,
        _frame = frame,
        _label = label,
        _timer = nil,
        _pendingIcon = nil,
        _watch = nil,
        _owner = nil,
    }, Tooltip)

    -- ONE cleanup closure for the watch connection, registered once. Registering
    -- per show would grow the junk list on every hover.
    root:keep(function()
        if self._watch then
            self._watch:Disconnect()
            self._watch = nil
        end
    end)

    return self
end

function Tooltip:_hide()
    if self._timer then
        task.cancel(self._timer)
        self._timer = nil
    end
    self._pendingIcon = nil
    if self._watch then
        self._watch:Disconnect()
        self._watch = nil
    end
    self._owner = nil
    self._frame.Visible = false
end

function Tooltip:_show(icon, text)
    self._label.Text = text
    self._owner = icon
    self._frame.Visible = true

    -- AbsoluteSize is only correct after a render pass, so place on the next
    -- frame rather than against a stale or zero size.
    RunService.RenderStepped:Wait()
    if self._owner ~= icon then return end

    local viewport = workspace.CurrentCamera.ViewportSize
    local pos, size = icon.AbsolutePosition, icon.AbsoluteSize
    local x, y = M.place(
        { x = pos.X, y = pos.Y, w = size.X, h = size.Y },
        { w = self._frame.AbsoluteSize.X, h = self._frame.AbsoluteSize.Y },
        { w = viewport.X, h = viewport.Y })
    -- place() works in screen space (it is derived from AbsolutePosition), but
    -- Position is parent space, and the tooltip layer sits `inset` above the
    -- screen origin because the ScreenGui ignores the GUI inset. Subtract the
    -- layer's own offset or the tooltip floats away from its icon.
    local layerOrigin = self._frame.Parent.AbsolutePosition
    self._frame.Position = UDim2.fromOffset(x - layerOrigin.X, y - layerOrigin.Y)

    -- MouseLeave is unreliable when the pointer moves fast, and a STUCK tooltip
    -- is the only genuinely bad failure here. So while one is visible -- and
    -- only then -- confirm each frame that the pointer is still over the icon.
    self._watch = RunService.RenderStepped:Connect(function()
        if not self._owner or not self._owner.Parent then
            self:_hide()
            return
        end
        local m = UserInputService:GetMouseLocation()
        local p, s = self._owner.AbsolutePosition, self._owner.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local mx, my = m.X, m.Y
        local ax, ay = p.X + inset.X, p.Y + inset.Y
        if mx < ax or mx > ax + s.X or my < ay or my > ay + s.Y then
            self:_hide()
        end
    end)
end

-- Called by the row builder for every (?) icon that has a description.
--
-- The pending timer is tagged with the icon it belongs to (_pendingIcon), and
-- MouseLeave only tears it down if it's still that icon's timer. This must
-- not assume any ordering between MouseEnter/MouseLeave firing on different
-- GuiObjects -- Roblox gives no such guarantee, and a fast sweep across a
-- column of icons can deliver icon B's Enter before icon A's Leave.
function Tooltip:attach(icon, text)
    self._root:keep(icon.MouseEnter:Connect(function()
        if self._timer then task.cancel(self._timer) end
        self._pendingIcon = icon
        self._timer = task.delay(DELAY, function()
            self._timer = nil
            self._pendingIcon = nil
            if not self._root:isAlive() then return end
            self:_show(icon, text)
        end)
    end))

    self._root:keep(icon.MouseLeave:Connect(function()
        if self._owner == icon or self._pendingIcon == icon then self:_hide() end
    end))
end

return M
