-- The popup overlay: placement maths, plus the single-slot manager.
--
-- place() is unit tested, so it stays in the Lua 5.4 / Luau intersection --
-- no compound assignment, no bitwise ops, no goto.

local M = {}

M.GAP = 2       -- pixels between the control slot and the popup
M.MARGIN = 6    -- minimum distance from any screen edge

-- Places a popup against the rect of the control that opened it.
--
-- Right-aligned to the slot and extending left: the colorpicker is 176px
-- against a 110px slot, so left-aligning hangs it over the next column.
--
-- All in the anchor's coordinate space, like Tooltip.place. GetMouseLocation
-- never enters into it, so the GUI-inset mismatch can't happen here.
function M.place(anchor, size, viewport, gap, margin)
    gap = gap or M.GAP
    margin = margin or M.MARGIN

    local x = anchor.x + anchor.w - size.w
    if x + size.w > viewport.w - margin then
        x = viewport.w - margin - size.w
    end
    if x < margin then x = margin end

    local y = anchor.y + anchor.h + gap
    if y + size.h > viewport.h - margin then
        -- Flip above rather than clamp: clamping slides the popup over the
        -- control that opened it.
        y = anchor.y - size.h - gap
    end
    if y < margin then y = margin end

    return x, y
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

-- Resolved lazily: a module-scope game:GetService() executes on require, and
-- the Lua 5.4 harness requires this file to reach place().
local UserInputService
local RunService

local Popup = {}
Popup.__index = Popup

-- Whether an AbsolutePosition-space point falls inside a GuiObject's rect.
local function inside(object, x, y)
    if object == nil then return false end
    local p, s = object.AbsolutePosition, object.AbsoluteSize
    return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end

-- One popup at a time. Containers clip and columns scroll, so a popup lives in
-- the overlay layer at absolute coordinates, with no parent-child link to the
-- row that opened it -- nothing hides it automatically. One slot keeps "this is
-- stale, close it" to a single code path; with several, every dismissal has to
-- walk a list, and the failure mode is a dropdown floating over another page.
function M.new(root)
    UserInputService = UserInputService or game:GetService("UserInputService")
    RunService = RunService or game:GetService("RunService")

    local self = setmetatable({
        _root = root,
        _owner = nil,
        _frame = nil,
        _anchor = nil,
        _onClose = nil,
        _watch = nil,
    }, Popup)

    -- A hit test, not a full-screen blocker button. The blocker swallowed the
    -- dismissing click: dragging the title bar with a dropdown open closed it
    -- on mouse-release and never started the drag, because the bar never saw
    -- the press.
    root:keep(UserInputService.InputBegan:Connect(function(input)
        if self._owner == nil then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            self:close()
            return
        end

        -- Touch is here so a tap outside can't strand a popup on a touch-only
        -- target. Untested there, but a silent dead end is worse.
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.MouseButton2
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local mx, my = root:mouseInGuiSpace()
        -- The anchor counts as inside: a click on the field that opened this
        -- has to fall through to the widget's own toggle, or it reopens what we
        -- just closed.
        if inside(self._frame, mx, my) or inside(self._anchor, mx, my) then return end
        self:close()
    end))

    -- One cleanup closure, registered once: doing it per open would grow the
    -- junk list on every click.
    root:keep(function()
        if self._watch then
            self._watch:Disconnect()
            self._watch = nil
        end
    end)

    return self
end

-- `anchor` is the GuiObject that opened the popup. Its rect is read here
-- rather than passed in, so the two can't get out of step -- and the drift
-- watch below needs the object anyway.
function Popup:open(owner, frame, anchor, onClose)
    -- close() fires the outgoing onClose, which may itself open a popup. Loop
    -- until the slot is empty, or the open below overwrites _watch and orphans
    -- a RenderStepped connection.
    local guard = 0
    while self._owner ~= nil or self._watch ~= nil do
        self:close()
        guard = guard + 1
        assert(guard < 8, "chroma: a popup onClose callback kept reopening a popup")
    end

    -- From the declared pixel Size, not AbsoluteSize: that reads (0, 0) until
    -- the frame has rendered once, and a popup is placed the instant it opens.
    local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
    assert(w > 0 and h > 0, "chroma: popup frames must declare a pixel Size")

    self._owner = owner
    self._frame = frame
    self._anchor = anchor
    self._onClose = onClose

    local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
    local viewport = workspace.CurrentCamera.ViewportSize
    local x, y = M.place(
        { x = pos.X, y = pos.Y, w = size.X, h = size.Y },
        { w = w, h = h },
        { w = viewport.X, h = viewport.Y })
    frame.Position = UDim2.fromOffset(self._root:toLayerSpace(x, y, frame.Parent))
    frame.Visible = true

    -- While open, close if the anchor moves at all -- the same watch-while-
    -- visible trick the tooltip uses. Covers column scrolling, dragging and
    -- resizing in one place. Page and tab switches don't move the anchor, so
    -- those go through bindDismissal instead.
    local originX, originY = pos.X, pos.Y
    self._watch = RunService.RenderStepped:Connect(function()
        if not anchor.Parent then
            self:close()
            return
        end
        local p = anchor.AbsolutePosition
        if p.X ~= originX or p.Y ~= originY then
            self:close()
        end
    end)
end

function Popup:close()
    -- Fired last, once every field is cleared, so an onClose that opens
    -- something else isn't racing a half-torn-down manager.
    local onClose = self._onClose

    if self._watch then
        self._watch:Disconnect()
        self._watch = nil
    end
    if self._frame then
        self._frame.Visible = false
    end
    self._owner = nil
    self._frame = nil
    self._anchor = nil
    self._onClose = nil

    if onClose then onClose() end
end

-- No argument: is anything open. With an owner: is that owner's popup open,
-- which is what lets a widget toggle itself.
function Popup:isOpen(owner)
    if owner == nil then return self._owner ~= nil end
    return self._owner == owner
end

-- A popup never follows its owner; it closes. Anything that reflows or replaces
-- the view routes here.
function Popup:bindDismissal(window)
    window:onLayoutChanged(function()
        self:close()
    end)
end

return M
