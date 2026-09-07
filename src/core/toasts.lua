-- Toasts: pure stackFor that decides where each toast sits, plus (from the
-- next task) the manager and rendering.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

local CORNERS = {
    ["top-right"] = true, ["top-left"] = true,
    ["bottom-right"] = true, ["bottom-left"] = true,
}

-- Positions for N toasts anchored to `corner`, with newest at index 1 at the
-- anchor corner and older toasts spaced toward the vertical centre.
--
-- toastSize = { w, h }, viewport = { w, h }. gap and margin are pixels.
-- An unknown corner falls back to top-right rather than erroring: the corner
-- is user-configured and a stale flag from an older Chroma should not crash.
function M.stackFor(count, corner, toastSize, gap, viewport, margin)
    if not CORNERS[corner] then corner = "top-right" end

    local out = {}
    if count <= 0 then return out end

    local isRight = corner == "top-right" or corner == "bottom-right"
    local isTop = corner == "top-right" or corner == "top-left"

    local x
    if isRight then
        x = viewport.w - margin - toastSize.w
    else
        x = margin
    end

    local step = toastSize.h + gap
    for i = 1, count do
        local offset = (i - 1) * step
        local y
        if isTop then
            y = margin + offset
        else
            y = viewport.h - margin - toastSize.h - offset
        end
        out[i] = { x = x, y = y }
    end

    return out
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

-- Resolved lazily: a module-scope game:GetService() runs on require, and the
-- Lua 5.4 harness requires this file to reach stackFor.
local RunService
local TweenService

local Toasts = {}
Toasts.__index = Toasts

local TOAST_W = 220
local TOAST_H = 42
local GAP = 8
local MARGIN = 12
local FADE_TIME = 0.16

local KIND_DEFAULTS = {
    info    = { duration = 3, stripe = "Accent" },
    success = { duration = 3, stripe = "Success" },
    warn    = { duration = 5, stripe = "Warn" },
    error   = { duration = 8, stripe = "Error" },
}

local FLAG_POSITION = "chroma_toasts_position"

function M.new(root)
    RunService = RunService or game:GetService("RunService")
    TweenService = TweenService or game:GetService("TweenService")

    local self = setmetatable({
        _root = root,
        _layer = root.overlayLayer,
        _toasts = {},   -- ordered list; index 1 is newest
        _nextId = 1,
        _tweens = {},   -- flat list of currently-playing tweens, for Unload
        _unknownKindWarned = {},
    }, Toasts)

    -- One cleanup closure for every tween this instance ever creates. Matches
    -- anim.lua's pattern. A closure per tween would grow the junk list on
    -- every Notify().
    root:keep(function()
        for i = 1, #self._tweens do
            pcall(function() self._tweens[i]:Cancel() end)
        end
        self._tweens = {}
    end)

    -- Wire root:notify so config, settings, and other Chroma internals get
    -- toasts by calling one method. Programmer-error warns keep calling warn()
    -- directly (they never reach here).
    root:setNotifyHandler(function(kind, text)
        self:show(text, kind)
    end)

    -- Per-frame gradient update for every live toast's outline stroke, so
    -- the toasts' outlines sweep in lockstep with the menu's own outline.
    -- Iterating _toasts is cheap -- cap is 5 -- and it's the only place
    -- toasts exist, so no walk of arbitrary descendants is needed.
    root:keep(RunService.Heartbeat:Connect(function()
        if not root:isAlive() then return end
        if #self._toasts == 0 then return end
        local a = root.theme:get("HairA")
        local b = root.theme:get("HairB")
        local seq = ColorSequence.new(a, b)
        for i = 1, #self._toasts do
            self._toasts[i].strokeGradient.Color = seq
        end
    end))

    return self
end

-- Tracks a tween in _tweens for Unload cancellation, and prunes it on
-- Completed so the array does not grow for the life of the session. Returns
-- the tween unchanged for a fluent call site.
function Toasts:_track(tween)
    table.insert(self._tweens, tween)
    tween.Completed:Connect(function()
        for i = 1, #self._tweens do
            if self._tweens[i] == tween then
                table.remove(self._tweens, i)
                return
            end
        end
    end)
    return tween
end

function Toasts:_position()
    -- Read via Chroma.Flags so a settings-page change updates immediately.
    local flag = self._root.config and self._root.config.Flags[FLAG_POSITION]
    return flag or "top-right"
end

function Toasts:show(text, kind, opts)
    if type(text) ~= "string" then
        warn("[Chroma] Notify: text must be a string, got " .. type(text))
        return
    end

    opts = opts or {}
    local defaults = KIND_DEFAULTS[kind]
    if defaults == nil then
        if kind ~= nil and not self._unknownKindWarned[kind] then
            warn("[Chroma] Notify: unknown kind '" .. tostring(kind) ..
                "', falling back to 'info'")
            self._unknownKindWarned[kind] = true
        end
        kind = "info"
        defaults = KIND_DEFAULTS.info
    end

    local id = self._nextId
    self._nextId = id + 1

    local frame, strokeGradient = self:_build(text, defaults.stripe)
    frame.Parent = self._layer

    local entry = {
        id = id,
        frame = frame,
        strokeGradient = strokeGradient,
        expireAt = os.clock() + (opts.Duration or defaults.duration),
    }

    -- Insert at index 1 (newest at the anchor corner).
    table.insert(self._toasts, 1, entry)

    -- Evict oldest immediately if we're over cap. Skips the fade-out --
    -- capacity pressure means the user is not tracking the old one anyway.
    while #self._toasts > 5 do
        local evicted = table.remove(self._toasts)
        if evicted._expireThread then
            pcall(task.cancel, evicted._expireThread)
        end
        evicted.frame:Destroy()
    end

    self:_reflow(true)

    -- Click-to-dismiss. Tied to the frame's own Activated so the connection
    -- dies when the frame is destroyed -- no root:keep needed and no leak
    -- when the toast expires.
    entry.frame.Activated:Connect(function() self:_dismiss(id) end)

    entry._expireThread = task.delay(opts.Duration or defaults.duration, function()
        if not self._root:isAlive() then return end
        self:_dismiss(id)
    end)
end

function Toasts:_build(text, stripeKey)
    local theme = self._root.theme

    local frame = Instance.new("ImageButton")
    frame.Name = "toast"
    frame.Size = UDim2.fromOffset(TOAST_W, TOAST_H)
    frame.BorderSizePixel = 0
    frame.AutoButtonColor = false
    frame.BackgroundTransparency = 0.05
    frame.Image = ""
    theme:bind(frame, "BackgroundColor3", "TitleBar")

    -- 1px HairA -> HairB gradient stroke, updated per frame by
    -- _updateStrokeGradients. Same look as the window's outline so toasts
    -- read as part of the menu rather than a stark rectangle.
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = frame

    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new(
        theme:get("HairA"), theme:get("HairB"))
    strokeGradient.Parent = stroke

    local stripe = Instance.new("Frame")
    stripe.Name = "stripe"
    stripe.Size = UDim2.new(0, 4, 1, 0)
    stripe.BorderSizePixel = 0
    stripe.Parent = frame
    theme:bind(stripe, "BackgroundColor3", stripeKey)

    local label = Instance.new("TextLabel")
    label.Name = "text"
    label.Position = UDim2.fromOffset(12, 0)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Ubuntu
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Text = text
    label.Parent = frame
    theme:bind(label, "TextColor3", "Text")

    return frame, strokeGradient
end

function Toasts:_dismiss(id)
    for i = 1, #self._toasts do
        if self._toasts[i].id == id then
            local entry = table.remove(self._toasts, i)
            if entry._expireThread then
                pcall(task.cancel, entry._expireThread)
            end
            local tween = self:_track(TweenService:Create(entry.frame,
                TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1 }))
            tween:Play()
            tween.Completed:Connect(function() entry.frame:Destroy() end)
            self:_reflow(true)
            return
        end
    end
end

function Toasts:_reflow(animate)
    local viewport = workspace.CurrentCamera.ViewportSize
    local positions = M.stackFor(#self._toasts, self:_position(),
        { w = TOAST_W, h = TOAST_H }, GAP,
        { w = viewport.X, h = viewport.Y }, MARGIN)

    for i = 1, #self._toasts do
        local entry = self._toasts[i]
        local x, y = self._root:toLayerSpace(positions[i].x, positions[i].y, self._layer)
        local target = UDim2.fromOffset(x, y)
        if animate then
            self:_track(TweenService:Create(entry.frame,
                TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = target })):Play()
        else
            entry.frame.Position = target
        end
    end
end

return M
