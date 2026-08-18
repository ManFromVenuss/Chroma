-- Popup: the pure placement maths, plus (from the next task) the single-slot
-- overlay manager.
--
-- place() is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

M.GAP = 2       -- pixels between the control slot and the popup
M.MARGIN = 6    -- minimum distance from any screen edge

-- Places a popup against the rect of the control that opened it.
--
-- Popups align to the RIGHT edge of the control slot and extend leftward. The
-- colorpicker is 176px against a 110px slot, so left-aligning would hang it out
-- over the neighbouring column; right-aligning keeps it inside the window.
--
-- Everything here is in the anchor's coordinate space, exactly as Tooltip.place
-- is -- GetMouseLocation never enters the calculation, so the GUI-inset
-- mismatch that caused four earlier bugs cannot happen.
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
        -- Flip ABOVE the anchor rather than clamping upward: clamping would
        -- slide the popup over the control that opened it, which reads as the
        -- menu having eaten the row.
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

-- ONE popup at a time, and that is a decision rather than a simplification.
-- Containers clip and columns scroll, so a popup has to live in the overlay
-- layer positioned by absolute coordinates -- it has NO parent-child link to
-- the row that opened it, and nothing hides it automatically. With one slot,
-- "this popup is stale, close it" is one code path. With several, every
-- dismissal event has to walk a list and decide individually, and the failure
-- mode is a dropdown left floating over an unrelated page.
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

    -- Click-outside dismissal is a hit test, NOT a full-screen blocker button.
    -- A blocker was tried first and swallowed the click that dismissed the
    -- popup: dragging the title bar with a dropdown open closed the dropdown on
    -- mouse-RELEASE and never started the drag, because the bar never received
    -- the press. Testing the pointer against the popup's own rect lets the click
    -- reach whatever is underneath, which is what a menu should do.
    root:keep(UserInputService.InputBegan:Connect(function(input)
        if self._owner == nil then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            self:close()
            return
        end

        -- Touch is included so a tap outside cannot leave a popup stuck open
        -- forever on a touch-only target. Chroma is mouse-oriented and this is
        -- untested there, but a silent dead end is worse than an untested line.
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.MouseButton2
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local mx, my = root:mouseInGuiSpace()
        -- The anchor counts as inside. A click on the field that opened this
        -- popup must fall through to that widget's own toggle, or the widget
        -- would reopen what this just closed and the popup could never be
        -- dismissed by clicking its own control.
        if inside(self._frame, mx, my) or inside(self._anchor, mx, my) then return end
        self:close()
    end))

    -- ONE cleanup closure for the watch connection, registered once. Registering
    -- per open would grow the junk list on every click.
    root:keep(function()
        if self._watch then
            self._watch:Disconnect()
            self._watch = nil
        end
    end)

    return self
end

-- `anchor` is the GuiObject that opened the popup (a field, a swatch). The rect
-- is read from it rather than passed in, so the caller cannot get the two out of
-- step, and it gives the drift watch below something to watch.
function Popup:open(owner, frame, anchor, onClose)
    -- close() fires the outgoing popup's onClose, and that callback may itself
    -- open a popup. Loop until the slot is actually empty: otherwise the open
    -- below would overwrite _watch and orphan a RenderStepped connection that
    -- the re-entrant open had just installed.
    local guard = 0
    while self._owner ~= nil or self._watch ~= nil do
        self:close()
        guard = guard + 1
        assert(guard < 8, "chroma: a popup onClose callback kept reopening a popup")
    end

    -- Positioned from the frame's declared pixel Size, NOT AbsoluteSize:
    -- AbsoluteSize is (0, 0) until the frame has rendered once, and a popup is
    -- placed the instant it opens. Every popup therefore sets an explicit
    -- offset size.
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

    -- While one is open -- and only then -- close it if its anchor moves at all.
    -- This is the same "watch while visible" pattern the tooltip uses for a
    -- stuck hover, and it covers column scrolling, window dragging and resizing
    -- in one place. Page and tab switches do NOT move the anchor (an inactive
    -- page keeps its geometry), so those are wired separately in bindDismissal.
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
    -- Captured and fired LAST, after every field is cleared: an onClose that
    -- opens something else must not race a half-torn-down manager.
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

-- With no argument: is anything open. With an owner: is that owner's popup
-- open, which is what lets a widget toggle itself.
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
