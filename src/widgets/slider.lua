-- Slider: the pure value/fraction maths, plus the 2px track.
-- The maths half is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

-- Where `value` sits on the track, as 0..1. Clamped, and safe when min == max.
function M.fractionOf(value, min, max)
    if max <= min then return 0 end
    local f = (value - min) / (max - min)
    if f < 0 then return 0 end
    if f > 1 then return 1 end
    return f
end

-- The value at 0..1 along the track, rounded to `decimals` places.
-- Note: `mult` is a float, so borderline values can round the "wrong" way
-- -- e.g. 0.145 at 2 decimals yields 0.14, since 0.145 * 100 + 0.5 evaluates
-- to 14.999999999999998 rather than 15. Fixing this needs decimal
-- arithmetic; not worth it for a slider label being one ulp out.
function M.valueAt(fraction, min, max, decimals)
    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end
    local raw = min + (max - min) * fraction
    -- Decimals is consumer-supplied, so normalise rather than trusting it:
    -- a negative value would invert the rounding and a fractional one would
    -- silently produce nonsense.
    decimals = math.floor(decimals or 0)
    if decimals < 0 then decimals = 0 end
    local mult = 10 ^ decimals
    -- floor(x + 0.5) rounds .5 up for positives and, for negatives, toward
    -- zero -- which is what a slider should do: dragging to the middle of
    -- -9..0 lands on -4, not -5.
    return math.floor(raw * mult + 0.5) / mult
end

function M.format(value, decimals, unit)
    -- Decimals is consumer-supplied, so normalise rather than trusting it: a
    -- negative or fractional value produces an invalid format specification
    -- and would throw at runtime.
    decimals = math.floor(decimals or 0)
    if decimals < 0 then decimals = 0 end
    local s = string.format("%." .. tostring(decimals) .. "f", value)
    if unit and unit ~= "" then s = s .. unit end
    return s
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local safecall = require("util/safecall")

-- Resolved lazily: a module-scope game:GetService() executes on require, and
-- the harness requires this file to reach the maths above.
local UserInputService

local Slider = {}
Slider.__index = Slider

local TRACK_WIDTH = 74
local TRACK_HEIGHT = 2
local KNOB_HEIGHT = 8
local HIT_HEIGHT = 19   -- the row height; a 2px track is impossible to grab

function M.new(root, row, opts)
    UserInputService = UserInputService or game:GetService("UserInputService")

    local min = opts.Min or 0
    local max = opts.Max or 100
    if min >= max then
        -- A programming mistake that can only produce a slider which never
        -- moves. Failing at build time is kinder than debugging it later.
        error(string.format(
            "chroma: slider '%s' has Min (%s) >= Max (%s)",
            tostring(opts.Name), tostring(min), tostring(max)), 2)
    end

    local theme = root.theme

    -- A TextBox rather than a TextLabel, kept non-editable until clicked, so
    -- typing an exact value needs no second element and nothing moves.
    local value = Instance.new("TextBox")
    value.Name = "value"
    value.AnchorPoint = Vector2.new(1, 0.5)
    value.Position = UDim2.new(1, 0, 0.5, 0)
    value.Size = UDim2.fromOffset(30, 12)
    value.BackgroundTransparency = 1
    value.Font = Enum.Font.Ubuntu
    value.TextSize = 11
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.TextEditable = false
    value.ClearTextOnFocus = false
    value.Parent = row.control
    theme:bind(value, "TextColor3", "TextDim")

    local track = Instance.new("Frame")
    track.Name = "track"
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -34, 0.5, 0)
    track.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
    track.BorderSizePixel = 0
    track.Parent = row.control
    theme:bind(track, "BackgroundColor3", "FieldBorder")

    local fill = Instance.new("Frame")
    fill.Name = "fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BorderSizePixel = 0
    fill.Parent = track
    theme:bind(fill, "BackgroundColor3", "Accent")

    local knob = Instance.new("Frame")
    knob.Name = "knob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.fromScale(0, 0.5)
    knob.Size = UDim2.fromOffset(2, KNOB_HEIGHT)
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = track
    theme:bind(knob, "BackgroundColor3", "Accent")

    -- A taller invisible button over the track: a 2px target is unusable, and
    -- this is also what makes click-to-jump land where you clicked. Its height
    -- is a constant, not read from AbsoluteSize, which is zero until the frame
    -- has rendered once.
    local hit = Instance.new("TextButton")
    hit.Name = "hit"
    hit.AnchorPoint = Vector2.new(0.5, 0.5)
    hit.Position = UDim2.fromScale(0.5, 0.5)
    hit.Size = UDim2.new(1, 8, 0, HIT_HEIGHT)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 3
    hit.Parent = track

    local self = setmetatable({
        _root = root,
        _row = row,
        _track = track,
        _fill = fill,
        _knob = knob,
        _value = value,
        _min = min,
        _max = max,
        _decimals = opts.Decimals or 0,
        _unit = opts.Unit,
        _label = opts.Name or "Slider",
        _callback = opts.Callback,
        _listeners = {},
        _current = min,
        _editing = false,
    }, Slider)

    local dragging = false

    local function applyFromMouse()
        local mx = root:mouseInGuiSpace()
        local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
        local fraction = width > 0 and (mx - left) / width or 0
        self:Set(M.valueAt(fraction, self._min, self._max, self._decimals))
    end

    --== typing an exact value ==--
    root:keep(value.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if self._editing then return end
        self._editing = true
        value.TextEditable = true
        -- Edit the bare number: the unit is presentation, not something to type.
        value.Text = M.format(self._current, self._decimals, nil)
        theme:unbind(value)
        theme:bind(value, "TextColor3", "Text")
        value:CaptureFocus()
        -- Select the whole value so typing replaces it: the common case is
        -- entering a new number, not editing a digit of the old one.
        value.CursorPosition = #value.Text + 1
        value.SelectionStart = 1
    end))

    root:keep(value.FocusLost:Connect(function(enterPressed, inputThatCausedFocusLoss)
        self._editing = false
        value.TextEditable = false
        theme:unbind(value)
        theme:bind(value, "TextColor3", "TextDim")

        -- Escape must cancel, and it has to be handled explicitly. Roblox does
        -- not restore a TextBox's previous text before releasing focus --
        -- measured in-game: at FocusLost the box still held the typed value
        -- with cause=Escape. Relying on that would silently commit the edit,
        -- which is the opposite of cancelling.
        if inputThatCausedFocusLoss ~= nil
            and inputThatCausedFocusLoss.KeyCode == Enum.KeyCode.Escape then
            self:Set(self._current, true)
            return
        end

        -- Clicking away still commits, and a non-number is a cancel: Set
        -- re-renders the current value, formatted.
        local typed = tonumber(value.Text)
        if typed then self:Set(typed) else self:Set(self._current, true) end
    end))

    root:keep(hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            applyFromMouse()   -- click-to-jump
        end
    end))

    root:keep(UserInputService.InputChanged:Connect(function(input)
        -- A stray mouse move while typing would fight the text box for the value.
        if dragging and not self._editing and input.UserInputType == Enum.UserInputType.MouseMovement then
            applyFromMouse()
        end
    end))

    root:keep(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    self:Set(opts.Default or min, true)
    return self
end

function Slider:Get()
    return self._current
end

function Slider:Set(v, silent)
    if type(v) ~= "number" then return end
    local rounded = M.valueAt(
        M.fractionOf(v, self._min, self._max), self._min, self._max, self._decimals)
    local changed = rounded ~= self._current
    self._current = rounded

    local fraction = M.fractionOf(rounded, self._min, self._max)
    self._fill.Size = UDim2.fromScale(fraction, 1)
    self._knob.Position = UDim2.fromScale(fraction, 0.5)
    -- Leave the text alone mid-edit, or a programmatic Set would overwrite
    -- what is being typed.
    if not self._editing then
        self._value.Text = M.format(rounded, self._decimals, self._unit)
    end

    if silent or not changed then return end
    safecall.call(self._label, self._callback, rounded)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], rounded)
    end
end

function Slider:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function Slider:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
