-- Two-stage open/close sequencer.
--
-- The window frame keeps AnchorPoint (0, 0) permanently, also its drag
-- origin, so animation and dragging never disagree about where the window
-- is. Everything shrinks Size toward that fixed corner; Position is never
-- touched. The body never moves horizontally: only the frame's Size
-- animates, so the title bar widens/narrows and the frame unfolds/collapses
-- vertically, with no separate contents slide to read as a third motion.
local Guard = require("util/guard")

-- Resolved lazily in M.new: a module-scope game:GetService() runs on
-- require, which breaks the Lua 5.4 test harness the moment any suite
-- requires this file -- the same failure core/cursor.lua hit.
local TweenService

local M = {}

-- Offsets and durations in seconds. Total is 0.33s each way.
--
-- The stages are separated by a 0.05s gap rather than overlapped: each stage
-- finishes before the next begins, so the two read as "bar, then frame"
-- instead of one blended motion. Overlapping felt mushy.
M.TIMING = {
    open = {
        bar    = { delay = 0.00, time = 0.12 },
        height = { delay = 0.17, time = 0.16 },
    },
    close = {
        height = { delay = 0.00, time = 0.14 },
        bar    = { delay = 0.19, time = 0.14 },
    },
}

local EASE_OUT = Enum.EasingStyle.Quint
local EASE_IN = Enum.EasingStyle.Quad

local Anim = {}
Anim.__index = Anim

-- parts: { frame, contents, barHeight, fullSize() }
--
-- The contents frame is positioned once by the window (at title bar height +
-- gap) and never moved again here; only frame.Size animates.
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
    -- A closure per-tween would append to root's junk list on every
    -- open/close, growing it without bound.
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

-- Longest end-to-end duration of a close, derived from TIMING so a retune of
-- the table can't desynchronise callers that need to know when the window is
-- gone.
function M.closeDuration()
    local t = M.TIMING.close
    local total = 0
    for _, stage in pairs(t) do
        local finish = stage.delay + stage.time
        if finish > total then total = finish end
    end
    return total
end

function Anim:_tween(object, time, delay, props, easing, direction)
    -- TweenInfo.new(Time, EasingStyle, EasingDirection, RepeatCount, Reverses, DelayTime)
    -- The delay is the sixth argument; passing it fourth sets RepeatCount
    -- instead and the stage fires immediately, collapsing all three into one.
    local info = TweenInfo.new(time, easing, direction, 0, false, delay)
    local tween = TweenService:Create(object, info, props)
    table.insert(self._tweens, tween)
    tween:Play()
    return tween
end

-- Cancels outstanding tweens so a superseded animation never leaves the
-- window mid-fold.
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
        p.contents.Visible = true
    else
        p.frame.Size = UDim2.fromOffset(0, p.barHeight)
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

    -- Start fully collapsed: zero width, title-bar height. The title bar
    -- expands rightward from its left edge (AnchorPoint stays (0, 0)), then
    -- the frame unfolds downward from the bar.
    p.frame.Size = UDim2.fromOffset(0, p.barHeight)
    p.contents.Visible = true

    self:_tween(p.frame, t.bar.time, t.bar.delay,
        { Size = UDim2.fromOffset(full.X, p.barHeight) }, EASE_OUT, Enum.EasingDirection.Out)

    -- task.delay can't be cancelled: Unload only stops future work by making
    -- callbacks check isAlive() themselves, since disconnecting anything here
    -- wouldn't stop a pending stage firing after teardown.
    task.delay(t.height.delay, function()
        if not self._root:isAlive() then return end
        self._guard:run(token, function()
            local liveFull = p.fullSize()
            self:_tween(p.frame, t.height.time, 0,
                { Size = UDim2.fromOffset(liveFull.X, liveFull.Y) }, EASE_OUT, Enum.EasingDirection.Out)
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

    -- The frame collapses upward into the title bar first, then the bar
    -- retracts leftward.
    local full = p.fullSize()
    self:_tween(p.frame, t.height.time, t.height.delay,
        { Size = UDim2.fromOffset(full.X, p.barHeight) }, EASE_IN, Enum.EasingDirection.In)

    task.delay(t.bar.delay, function()
        if not self._root:isAlive() then return end
        self._guard:run(token, function()
            local tween = self:_tween(p.frame, t.bar.time, 0,
                { Size = UDim2.fromOffset(0, p.barHeight) }, EASE_IN, Enum.EasingDirection.In)
            tween.Completed:Connect(function()
                if self._guard:isCurrent(token) and self._root:isAlive() then
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
