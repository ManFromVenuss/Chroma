-- Palette, accent engine and binding registry.
-- Pure logic: no Instance API is called, only property assignment on whatever
-- objects are bound, so this is unit tested locally.
-- Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops.

local Theme = {}
Theme.__index = Theme

local HAIR_HUE_SHIFT = 60 / 360
local ACCENT_DIM_FACTOR = 0.55
local SELECTION_TRANSPARENCY = 0.84

local STORED = {
    Window          = { 14, 17, 19 },
    Body            = { 19, 22, 24 },
    TitleBar        = { 26, 30, 33 },
    Container       = { 23, 25, 26 },
    ContainerBorder = { 46, 50, 52 },
    Rail            = { 20, 22, 23 },
    RailActive      = { 33, 36, 38 },
    Field           = { 17, 19, 20 },
    FieldBorder     = { 58, 63, 65 },
    Text            = { 190, 194, 195 },
    TextDim         = { 120, 125, 126 },
    TextBright      = { 242, 244, 244 },
}

-- Surfaces that are translucent by default. Anything absent is opaque.
-- The title bar is the only translucent surface by design: it sits outside the
-- body and shows the game directly, which is what makes it read as separate.
local TRANSPARENCY = {
    TitleBar  = 0.35,
    Container = 0.15,
    Rail      = 0.12,
    Selection = SELECTION_TRANSPARENCY,
}

local ACCENT_SEED = { 23, 184, 166 }

function Theme.hueAt(clock, speed)
    return (clock * speed) % 1
end

local function scale(color, factor)
    return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function shiftHue(color, amount)
    local hue, sat, val = color:ToHSV()
    return Color3.fromHSV((hue + amount) % 1, sat, val)
end

function Theme.new(opts)
    opts = opts or {}

    local stored = {}
    for key, rgb in pairs(STORED) do
        stored[key] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end

    local self = setmetatable({
        _stored = stored,
        _transparency = {},
        _derived = {},
        _bindings = {},
        _accentSpeed = opts.AccentSpeed or 0.15,
        _accentSat = opts.AccentSaturation or 0.86,
        _accentVal = opts.AccentValue or 0.72,
        _gradient = opts.Gradient ~= false,
    }, Theme)

    for key, value in pairs(TRANSPARENCY) do
        self._transparency[key] = value
    end

    self:setAccent(opts.Accent or "RGB")
    self:tick(0)
    return self
end

function Theme:isAnimated()
    return self._animated
end

function Theme:setAccent(accent)
    if accent == "RGB" then
        self._animated = true
        self._staticAccent = nil
    else
        self._animated = false
        self._staticAccent = accent
    end
    self:_recompute(self._clock or 0)
end

-- Mutates the stored palette only; existing bindings keep their old colour
-- until the caller calls apply().
-- Whether the outline runs a two-tone hue-shifted gradient or a single flat
-- colour. Independent of whether the accent animates: "RGB" decides whether the
-- hue moves over time, this decides whether the gradient's two ends differ at
-- any given instant.
function Theme:setGradient(enabled)
    self._gradient = enabled ~= false
    self:_recompute(self._clock or 0)
end

function Theme:isGradient()
    return self._gradient
end

function Theme:setAccentSpeed(speed)
    if type(speed) ~= "number" then return end
    self._accentSpeed = speed
    self:_recompute(self._clock or 0)
end

function Theme:setPalette(overrides)
    for key, value in pairs(overrides) do
        self._stored[key] = value
    end
end

-- Mutates the transparency table only; already-bound transparency writes are
-- not revisited, the caller must call apply() (or re-bind) to repaint.
function Theme:setTransparency(key, value)
    self._transparency[key] = value
end

function Theme:_recompute(clock)
    local accent
    if self._animated then
        local hue = Theme.hueAt(clock, self._accentSpeed)
        accent = Color3.fromHSV(hue, self._accentSat, self._accentVal)
    else
        accent = self._staticAccent or Color3.fromRGB(
            ACCENT_SEED[1], ACCENT_SEED[2], ACCENT_SEED[3])
    end

    local d = self._derived
    d.Accent = accent
    d.AccentDim = scale(accent, ACCENT_DIM_FACTOR)
    d.Selection = accent
    d.Glow = accent
    d.HairA = accent
    -- HairA and HairB are the two ends of the gradient on the window outline
    -- and the title bar's hairlines. Equal ends collapse it to a flat colour;
    -- that is the difference between Static and Gradient modes.
    if self._gradient then
        d.HairB = shiftHue(accent, HAIR_HUE_SHIFT)
    else
        d.HairB = accent
    end
end

-- Advance the clock. Cheap when the accent is static: recompute is skipped.
function Theme:tick(clock)
    self._clock = clock
    if self._animated then
        self:_recompute(clock)
    end
end

function Theme:get(key)
    local derived = self._derived[key]
    if derived ~= nil then return derived end
    return self._stored[key]
end

function Theme:transparency(key)
    return self._transparency[key] or 0
end

-- Registers a binding and paints it immediately, using the same diff check
-- apply() uses. This matters because the heartbeat only calls apply() while
-- the accent is animating; a static-accent surface would otherwise never be
-- coloured until something unrelated triggered a repaint.
-- If a fourth argument is given, it names a property to receive the key's
-- transparency. That write happens once, here, and is never re-diffed by
-- apply(): transparency values are static per key, so they are not added to
-- the binding list.
function Theme:bind(object, property, key, transparencyProperty)
    local binding = { object = object, property = property, key = key }
    table.insert(self._bindings, binding)

    local want = self:get(key)
    if want ~= nil and object[property] ~= want then
        object[property] = want
    end

    if transparencyProperty ~= nil then
        object[transparencyProperty] = self:transparency(key)
    end
end

function Theme:unbind(object)
    local kept = {}
    for i = 1, #self._bindings do
        local b = self._bindings[i]
        if b.object ~= object then table.insert(kept, b) end
    end
    self._bindings = kept
end

-- Writes every binding whose value has changed. The diff check is what makes an
-- animated accent nearly free: without it this writes hundreds of properties
-- per frame.
function Theme:apply()
    local bindings = self._bindings
    for i = 1, #bindings do
        local b = bindings[i]
        local want = self:get(b.key)
        if want ~= nil and b.object[b.property] ~= want then
            b.object[b.property] = want
        end
    end
end

function Theme:clearBindings()
    self._bindings = {}
end

return Theme
