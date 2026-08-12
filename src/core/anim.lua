-- Three-stage open/close sequencer.
--
-- The window frame keeps AnchorPoint (0, 0) permanently, which is also its drag
-- origin, so animation and dragging never disagree about where the window is.
-- Everything shrinks Size toward that fixed corner; Position is never touched.
local Guard = require("util/guard")

-- Resolved lazily in M.new. A module-scope game:GetService() executes on require,
-- which breaks the Lua 5.4 test harness the moment any suite requires this file --
-- exactly the failure core/cursor.lua hit.
local TweenService

local M = {}

-- Offsets and durations in seconds. Total is 0.32s each way.
M.TIMING = {
    open = {
        bar      = { delay = 0.00, time = 0.11 },
        height   = { delay = 0.08, time = 0.14 },
        contents = { delay = 0.17, time = 0.15 },
    },
    close = {
        contents = { delay = 0.00, time = 0.09 },
        height   = { delay = 0.09, time = 0.12 },
        bar      = { delay = 0.21, time = 0.11 },
    },
}

local EASE_OUT = Enum.EasingStyle.Quint
local EASE_IN = Enum.EasingStyle.Quad

local Anim = {}
Anim.__index = Anim

-- parts: { frame, body, contents, barHeight, fullSize(), contentSlide, contentTop }
--
-- contentTop is the contents frame's resting Y offset (title bar height + gap).
-- The slide tween must preserve it: writing UDim2.fromOffset(x, 0) would snap the
-- contents up under the title bar and destroy the gap that makes the bar read as
-- separate.
function M.new(root, parts)
    TweenService = TweenService or game:GetService("TweenService")

    local self = setmetatable({
        _root = root,
        _parts = parts,
        _guard = Guard.new(),
        _tweens = {},
        _open = false,
    }, Anim)

    -- One cleanup closure covers every tween this instance ever creates.
    -- Registering a closure per-tween (as _tween used to) would append to
    -- root's junk list on every open/close, growing it without bound.
    root:keep(function()
        for i = 1, #self._tweens do
            pcall(function() self._tweens[i]:Cancel() end)
        end
        self._tweens = {}
    end)

    return self
end

function Anim:isOpen()
    return self._open
end

function Anim:_home()
    return UDim2.fromOffset(0, self._parts.contentTop)
end

function Anim:_away()
    local p = self._parts
    return UDim2.fromOffset(-p.contentSlide, p.contentTop)
end

function Anim:_tween(object, time, delay, props, easing, direction)
    -- TweenInfo.new(Time, EasingStyle, EasingDirection, RepeatCount, Reverses, DelayTime)
    -- The delay is the SIXTH argument. Passing it fourth sets RepeatCount and the
    -- stage fires immediately, collapsing the three stages into one.
    local info = TweenInfo.new(time, easing, direction, 0, false, delay)
    local tween = TweenService:Create(object, info, props)
    table.insert(self._tweens, tween)
    tween:Play()
    return tween
end

-- Cancels outstanding tweens and snaps their targets, so a superseded animation
-- never leaves the window mid-fold.
function Anim:_cancel()
    self._guard:cancel()
    for i = 1, #self._tweens do
        pcall(function() self._tweens[i]:Cancel() end)
    end
    self._tweens = {}
end

function Anim:_snap(open)
    local p = self._parts
    local full = p.fullSize()
    if open then
        p.frame.Size = UDim2.fromOffset(full.X, full.Y)
        p.contents.Position = self:_home()
        p.contents.Visible = true
    else
        p.frame.Size = UDim2.fromOffset(0, p.barHeight)
        p.contents.Position = self:_away()
        p.contents.Visible = false
    end
end

function Anim:open(animate)
    if self._open then return end
    self._open = true
    self:_cancel()

    local p = self._parts
    local full = p.fullSize()

    if animate == false then
        self:_snap(true)
        return
    end

    local t = M.TIMING.open
    local token = self._guard:begin()

    -- Start from fully collapsed: zero width, title-bar height, contents parked
    -- off to the left.
    p.frame.Size = UDim2.fromOffset(0, p.barHeight)
    p.contents.Position = self:_away()
    p.contents.Visible = true

    self:_tween(p.frame, t.bar.time, t.bar.delay,
        { Size = UDim2.fromOffset(full.X, p.barHeight) }, EASE_OUT, Enum.EasingDirection.Out)

    task.delay(t.height.delay, function()
        self._guard:run(token, function()
            local liveFull = p.fullSize()
            self:_tween(p.frame, t.height.time, 0,
                { Size = UDim2.fromOffset(liveFull.X, liveFull.Y) }, EASE_OUT, Enum.EasingDirection.Out)
        end)
    end)

    task.delay(t.contents.delay, function()
        self._guard:run(token, function()
            self:_tween(p.contents, t.contents.time, 0,
                { Position = self:_home() }, EASE_OUT, Enum.EasingDirection.Out)
        end)
    end)
end

function Anim:close(animate)
    if not self._open then return end
    self._open = false
    self:_cancel()

    local p = self._parts

    if animate == false then
        self:_snap(false)
        return
    end

    local t = M.TIMING.close
    local token = self._guard:begin()

    self:_tween(p.contents, t.contents.time, t.contents.delay,
        { Position = self:_away() }, EASE_IN, Enum.EasingDirection.In)

    task.delay(t.height.delay, function()
        self._guard:run(token, function()
            local liveFull = p.fullSize()
            self:_tween(p.frame, t.height.time, 0,
                { Size = UDim2.fromOffset(liveFull.X, p.barHeight) }, EASE_IN, Enum.EasingDirection.In)
        end)
    end)

    task.delay(t.bar.delay, function()
        self._guard:run(token, function()
            local tween = self:_tween(p.frame, t.bar.time, 0,
                { Size = UDim2.fromOffset(0, p.barHeight) }, EASE_IN, Enum.EasingDirection.In)
            tween.Completed:Connect(function()
                if self._guard:isCurrent(token) then
                    p.contents.Visible = false
                end
            end)
        end)
    end)
end

function Anim:toggle(animate)
    if self._open then
        self:close(animate)
    else
        self:open(animate)
    end
end

return M
