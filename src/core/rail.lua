-- Rail: pure easeExpand for the hover tween, plus (from the next task) the
-- hover watcher and instance-side tween.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Ease-out quart. Chosen to match the window's own open animation, which uses
-- Enum.EasingStyle.Quint / EasingDirection.Out via TweenService; a quart here
-- is close enough that the two motions read as belonging to the same UI.
--
-- The TweenService codepath is what actually runs in-game; this exists so a
-- caller that wants to sample the curve outside a Tween has one endpoint.
function M.easeExpand(from, to, t)
    if t <= 0 then return from end
    if t >= 1 then return to end
    local eased = 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t)
    return from + (to - from) * eased
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach easeExpand.
local RunService
local TweenService
local UserInputService

local Rail = {}
Rail.__index = Rail

local COMPACT = 28
local EXPANDED_DEFAULT = 120
local DELAY_IN = 0.12
local DELAY_OUT = 0.4
local TWEEN_TIME = 0.16

-- opts: HoverExpand (defaults true), ExpandedWidth (defaults 120)
function M.new(root, window, opts)
    opts = opts or {}
    RunService = RunService or game:GetService("RunService")
    TweenService = TweenService or game:GetService("TweenService")
    UserInputService = UserInputService or game:GetService("UserInputService")

    local self = setmetatable({
        _root = root,
        _window = window,
        _rail = window._rail,
        _pageArea = window._pageArea,
        _expanded = false,
        _expandedWidth = opts.ExpandedWidth or EXPANDED_DEFAULT,
        _enabled = opts.HoverExpand ~= false,
        _inTimer = nil,   -- task.delay handle waiting to expand
        _outTimer = nil,  -- task.delay handle waiting to collapse
        _activeTween = nil,
    }, Rail)

    if not self._enabled then
        return self
    end

    -- One RenderStepped connection polling whether the pointer is over the
    -- rail's rect. MouseEnter/MouseLeave on the rail Frame would look
    -- simpler, but they fire against child buttons in ways that make hover
    -- state jitter -- a poll against AbsolutePosition is stable.
    root:keep(RunService.RenderStepped:Connect(function()
        if not root:isAlive() then return end
        local mx, my = root:mouseInGuiSpace()
        local origin, extent = self._rail.AbsolutePosition, self._rail.AbsoluteSize
        local over = mx >= origin.X and mx < origin.X + extent.X
                 and my >= origin.Y and my < origin.Y + extent.Y

        if over then
            self:_wantExpand()
        else
            self:_wantCollapse()
        end
    end))

    return self
end

function Rail:_wantExpand()
    -- Reaching the rail cancels an outstanding collapse.
    if self._outTimer then
        task.cancel(self._outTimer)
        self._outTimer = nil
    end
    if self._expanded or self._inTimer then return end

    self._inTimer = task.delay(DELAY_IN, function()
        self._inTimer = nil
        if not self._root:isAlive() then return end
        self:_expand(true)
    end)
end

function Rail:_wantCollapse()
    -- Leaving cancels an outstanding expand.
    if self._inTimer then
        task.cancel(self._inTimer)
        self._inTimer = nil
    end
    if not self._expanded or self._outTimer then return end

    -- A popup opened from a widget uses that widget's rect as its anchor. If
    -- the rail collapses now, the columns shift, the anchor moves, and the
    -- popup's drift-watch closes it -- eating a dropdown the user asked for.
    -- Wait for the popup to close.
    if self._root.popup and self._root.popup:isOpen() then
        return
    end

    self._outTimer = task.delay(DELAY_OUT, function()
        self._outTimer = nil
        if not self._root:isAlive() then return end
        -- Re-check the popup at fire time: it may have opened during the wait.
        if self._root.popup and self._root.popup:isOpen() then return end
        self:_expand(false)
    end)
end

function Rail:_expand(open)
    if self._expanded == open then return end
    self._expanded = open

    local width = open and self._expandedWidth or COMPACT

    -- Cancel a superseded tween so a rapid hover-in/out doesn't leave two
    -- tweens fighting each other.
    if self._activeTween then
        pcall(function() self._activeTween:Cancel() end)
        self._activeTween = nil
    end

    local info = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    -- Rail: only its width changes.
    self._activeTween = TweenService:Create(self._rail, info,
        { Size = UDim2.new(0, width, 1, 0) })
    self._activeTween:Play()

    -- Page area follows in lockstep so the columns reflow through the
    -- existing AbsoluteSize-changed signal on each tab's holder.
    TweenService:Create(self._pageArea, info, {
        Position = UDim2.fromOffset(width, 0),
        Size = UDim2.new(1, -width, 1, 0),
    }):Play()

    -- Every page's text label tweens transparency in the same window, so text
    -- appears alongside the rail rather than snapping in at either end.
    -- Pinned pages have no _text (see page.lua's construction guard).
    local targetTransparency = open and 0 or 1
    for i = 1, #self._window._pages do
        local page = self._window._pages[i]
        if page._text then
            TweenService:Create(page._text, info,
                { TextTransparency = targetTransparency }):Play()
        end
    end
end

function Rail:setEnabled(enabled)
    if self._enabled == enabled then return end
    self._enabled = enabled
    if not enabled and self._expanded then
        -- Turning it off mid-hover should collapse the rail so the page area
        -- returns to full width rather than being frozen expanded.
        self:_expand(false)
    end
end

return M
