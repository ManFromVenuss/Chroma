-- Colorpicker: the pure text parsing, plus the swatch, the HSV square, the hue
-- and alpha strips and the text field.
--
-- parseColor and toHex are unit tested, so keep them in the Lua 5.4 / Luau
-- intersection: no compound assignment, no bitwise ops, no goto. That also
-- means no Color3 construction here -- these deal in plain numbers, and the
-- Instance half converts.

local M = {}

-- Channels are 0..255 and alpha is 0..1, matching how each is written by hand.
local function clampByte(n)
    n = math.floor(n + 0.5)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

-- Returns r, g, b, a or nil. Unparseable input is user error at runtime, not a
-- programming mistake, so the caller reverts silently rather than erroring --
-- exactly as the slider's typed value does.
function M.parseColor(text)
    if type(text) ~= "string" then return nil end

    local s = text:gsub("%s", "")
    if s == "" then return nil end

    -- Sniffed on the comma rather than by asking the caller which format it is:
    -- the whole point of one field is that it takes either.
    if s:find(",", 1, true) then
        local parts = {}
        for piece in s:gmatch("[^,]+") do
            table.insert(parts, tonumber(piece))
        end
        if #parts < 3 or #parts > 4 then return nil end
        for i = 1, #parts do
            if parts[i] == nil then return nil end
        end

        local a = parts[4]
        if a == nil then
            a = 1
        elseif a > 1 then
            -- 255,0,0,255 means opaque. Clamping is what they meant; rejecting
            -- it would be pedantic about a format nobody agreed on.
            a = 1
        elseif a < 0 then
            a = 0
        end
        return clampByte(parts[1]), clampByte(parts[2]), clampByte(parts[3]), a
    end

    local hex = s:gsub("^#", "")
    if hex:match("^%x+$") == nil then return nil end

    local n = #hex
    if n == 3 or n == 4 then
        -- Each digit doubles: F -> FF, which is 15 * 17 = 255.
        local r = tonumber(hex:sub(1, 1), 16) * 17
        local g = tonumber(hex:sub(2, 2), 16) * 17
        local b = tonumber(hex:sub(3, 3), 16) * 17
        local a = 1
        if n == 4 then a = tonumber(hex:sub(4, 4), 16) * 17 / 255 end
        return r, g, b, a
    end
    if n == 6 or n == 8 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = 1
        if n == 8 then a = tonumber(hex:sub(7, 8), 16) / 255 end
        return r, g, b, a
    end
    return nil
end

-- Hex is the display format, being the compact one. Alpha is appended only when
-- the picker has an alpha strip at all.
function M.toHex(r, g, b, a)
    if a == nil then
        return string.format("#%02X%02X%02X", clampByte(r), clampByte(g), clampByte(b))
    end
    return string.format("#%02X%02X%02X%02X",
        clampByte(r), clampByte(g), clampByte(b), clampByte(a * 255))
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local safecall = require("util/safecall")

-- Resolved lazily: a module-scope game:GetService() executes on require, and
-- the harness requires this file to reach parseColor.
local UserInputService

local Colorpicker = {}
Colorpicker.__index = Colorpicker

local PAD = 7
local INNER = 162
local WIDTH = INNER + PAD * 2   -- 176
local SQUARE_H = 96
local STRIP_H = 10
local STRIP_GAP = 6
local FIELD_H = 16
local FIELD_GAP = 7
local CHEQUER = 5   -- chequerboard cell, in pixels

local SWATCH = 12
local SWATCH_GAP = 3
local SWATCH_ROW_GAP = 6

local function popupHeight(hasAlpha)
    local strips = hasAlpha and 2 or 1
    return PAD + SQUARE_H + strips * (STRIP_GAP + STRIP_H)
        + FIELD_GAP + FIELD_H
        + SWATCH_ROW_GAP + SWATCH
        + PAD
end

function M.new(root, row, opts)
    UserInputService = UserInputService or game:GetService("UserInputService")

    local theme = root.theme

    local default = opts.Default or Color3.fromRGB(255, 255, 255)
    if typeof(default) ~= "Color3" then
        -- A non-Color3 Default can only be a typo, and silently falling back to
        -- white hides it.
        error(string.format("chroma: colorpicker '%s' Default must be a Color3, got %s",
            tostring(opts.Name), typeof(default)), 2)
    end

    local hasAlpha = type(opts.Alpha) == "number"

    --== closed state: a 110px swatch filling the control slot ==--
    -- A small square leaves dead space beside it and is a poor click target.
    local swatch = Instance.new("TextButton")
    swatch.Name = "swatch"
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, 0, 0.5, 0)
    swatch.Size = UDim2.new(1, 0, 0, 14)
    swatch.BorderSizePixel = 0
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.Parent = row.control

    local swatchStroke = Instance.new("UIStroke")
    swatchStroke.Thickness = 1
    swatchStroke.Parent = swatch
    theme:bind(swatchStroke, "Color", "FieldBorder")

    --== the popup ==--
    local popup = Instance.new("Frame")
    popup.Name = "colorpicker"
    popup.Size = UDim2.fromOffset(WIDTH, popupHeight(hasAlpha))
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.ZIndex = 10
    popup.Parent = root.popupLayer
    root:keep(popup)
    theme:bind(popup, "BackgroundColor3", "Window")

    local popupStroke = Instance.new("UIStroke")
    popupStroke.Thickness = 1
    popupStroke.Parent = popup
    theme:bind(popupStroke, "Color", "Accent")

    -- The saturation/value square: a pure-hue base with a white gradient across
    -- it and a black gradient down it. Roblox has no HSV picker primitive, and
    -- two gradients reproduce one exactly -- no image asset, no upload to
    -- moderate, and it recolours by writing one BackgroundColor3.
    local square = Instance.new("Frame")
    square.Name = "square"
    square.Position = UDim2.fromOffset(PAD, PAD)
    square.Size = UDim2.fromOffset(INNER, SQUARE_H)
    square.BorderSizePixel = 0
    square.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
    square.ZIndex = 11
    square.Parent = popup

    local satLayer = Instance.new("Frame")
    satLayer.Name = "saturation"
    satLayer.Size = UDim2.fromScale(1, 1)
    satLayer.BackgroundColor3 = Color3.new(1, 1, 1)
    satLayer.BorderSizePixel = 0
    satLayer.ZIndex = 12
    satLayer.Parent = square
    local satGradient = Instance.new("UIGradient")
    satGradient.Transparency = NumberSequence.new(0, 1)
    satGradient.Parent = satLayer

    local valLayer = Instance.new("Frame")
    valLayer.Name = "value"
    valLayer.Size = UDim2.fromScale(1, 1)
    valLayer.BackgroundColor3 = Color3.new(0, 0, 0)
    valLayer.BorderSizePixel = 0
    valLayer.ZIndex = 13
    valLayer.Parent = square
    local valGradient = Instance.new("UIGradient")
    valGradient.Rotation = 90
    valGradient.Transparency = NumberSequence.new(1, 0)
    valGradient.Parent = valLayer

    local squareMarker = Instance.new("Frame")
    squareMarker.Name = "marker"
    squareMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    squareMarker.Size = UDim2.fromOffset(7, 7)
    squareMarker.BackgroundTransparency = 1
    squareMarker.BorderSizePixel = 0
    squareMarker.ZIndex = 14
    squareMarker.Parent = square
    local markerCorner = Instance.new("UICorner")
    markerCorner.CornerRadius = UDim.new(1, 0)
    markerCorner.Parent = squareMarker
    local markerStroke = Instance.new("UIStroke")
    markerStroke.Thickness = 1
    markerStroke.Color = Color3.new(1, 1, 1)
    markerStroke.Parent = squareMarker

    local function makeStrip(name, y)
        local strip = Instance.new("Frame")
        strip.Name = name
        strip.Position = UDim2.fromOffset(PAD, y)
        strip.Size = UDim2.fromOffset(INNER, STRIP_H)
        strip.BorderSizePixel = 0
        strip.BackgroundColor3 = Color3.new(1, 1, 1)
        strip.ZIndex = 11
        strip.Parent = popup

        local marker = Instance.new("Frame")
        marker.Name = "marker"
        marker.AnchorPoint = Vector2.new(0.5, 0.5)
        marker.Position = UDim2.fromScale(0, 0.5)
        marker.Size = UDim2.fromOffset(2, STRIP_H + 4)
        marker.BackgroundColor3 = Color3.new(1, 1, 1)
        marker.BorderSizePixel = 0
        marker.ZIndex = 15
        marker.Parent = strip
        local outline = Instance.new("UIStroke")
        outline.Thickness = 1
        outline.Color = Color3.new(0, 0, 0)
        outline.Transparency = 0.4
        outline.Parent = marker

        return strip, marker
    end

    local hueY = PAD + SQUARE_H + STRIP_GAP
    local hueStrip, hueMarker = makeStrip("hue", hueY)
    -- A UIGradient multiplies its element's colour, which is why the strip's own
    -- BackgroundColor3 is white above.
    local hueGradient = Instance.new("UIGradient")
    hueGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
    })
    hueGradient.Parent = hueStrip

    local alphaStrip, alphaMarker, alphaGradient
    if hasAlpha then
        alphaStrip, alphaMarker = makeStrip("alpha", hueY + STRIP_H + STRIP_GAP)

        -- The chequerboard is built from plain Frames rather than a tiled image:
        -- an image would mean uploading and moderating an asset for a 162x10
        -- strip, and only half the cells need drawing over a flat base. It is
        -- the honest way to show transparency and the only textured element in
        -- an otherwise flat UI.
        local base = Instance.new("Frame")
        base.Name = "chequer"
        base.Size = UDim2.fromScale(1, 1)
        base.BackgroundColor3 = Color3.fromRGB(58, 63, 65)
        base.BorderSizePixel = 0
        base.ClipsDescendants = true
        base.ZIndex = 11
        base.Parent = alphaStrip

        local cols = math.ceil(INNER / CHEQUER)
        local rows = math.ceil(STRIP_H / CHEQUER)
        for cx = 0, cols - 1 do
            for cy = 0, rows - 1 do
                if (cx + cy) % 2 == 0 then
                    local cell = Instance.new("Frame")
                    cell.Name = "cell"
                    cell.Position = UDim2.fromOffset(cx * CHEQUER, cy * CHEQUER)
                    cell.Size = UDim2.fromOffset(CHEQUER, CHEQUER)
                    cell.BackgroundColor3 = Color3.fromRGB(34, 40, 42)
                    cell.BorderSizePixel = 0
                    cell.ZIndex = 11
                    cell.Parent = base
                end
            end
        end

        local wash = Instance.new("Frame")
        wash.Name = "wash"
        wash.Size = UDim2.fromScale(1, 1)
        wash.BackgroundColor3 = Color3.new(1, 1, 1)
        wash.BorderSizePixel = 0
        wash.ZIndex = 12
        wash.Parent = alphaStrip
        alphaGradient = Instance.new("UIGradient")
        alphaGradient.Transparency = NumberSequence.new(1, 0)
        alphaGradient.Parent = wash

        alphaMarker.ZIndex = 15
    end

    --== the one text field, taking hex or RGB(A) ==--
    local input = Instance.new("TextBox")
    input.Name = "input"
    input.Position = UDim2.fromOffset(PAD, popupHeight(hasAlpha) - PAD - FIELD_H)
    input.Size = UDim2.fromOffset(INNER, FIELD_H)
    input.BorderSizePixel = 0
    input.Font = Enum.Font.Ubuntu
    input.TextSize = 11
    input.ClearTextOnFocus = false
    input.Text = ""
    input.ZIndex = 12
    input.Parent = popup
    theme:bind(input, "BackgroundColor3", "Field")
    theme:bind(input, "TextColor3", "Text")

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Thickness = 1
    inputStroke.Parent = input
    theme:bind(inputStroke, "Color", "FieldBorder")

    --== saved colours ==--
    -- Eleven cells across 162px: ten swatches and a + to save the current
    -- colour. Left-click applies, right-click deletes.
    local swatchRow = Instance.new("Frame")
    swatchRow.Name = "swatches"
    swatchRow.Position = UDim2.fromOffset(PAD, popupHeight(hasAlpha) - PAD - SWATCH)
    swatchRow.Size = UDim2.fromOffset(INNER, SWATCH)
    swatchRow.BackgroundTransparency = 1
    swatchRow.BorderSizePixel = 0
    swatchRow.ZIndex = 12
    swatchRow.Parent = popup

    local swatchLayout = Instance.new("UIListLayout")
    swatchLayout.FillDirection = Enum.FillDirection.Horizontal
    swatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
    swatchLayout.Padding = UDim.new(0, SWATCH_GAP)
    swatchLayout.Parent = swatchRow

    local addButton = Instance.new("TextButton")
    addButton.Name = "add"
    addButton.Size = UDim2.fromOffset(SWATCH, SWATCH)
    addButton.BorderSizePixel = 0
    addButton.Font = Enum.Font.Ubuntu
    addButton.TextSize = 11
    addButton.Text = "+"
    addButton.AutoButtonColor = false
    addButton.LayoutOrder = 999
    addButton.ZIndex = 13
    addButton.Parent = swatchRow
    theme:bind(addButton, "BackgroundColor3", "Field")
    theme:bind(addButton, "TextColor3", "TextDim")

    local addStroke = Instance.new("UIStroke")
    addStroke.Thickness = 1
    addStroke.Parent = addButton
    theme:bind(addStroke, "Color", "FieldBorder")

    local h0, s0, v0 = default:ToHSV()
    local self = setmetatable({
        _root = root,
        _row = row,
        _theme = theme,
        _swatch = swatch,
        _popup = popup,
        _square = square,
        _squareMarker = squareMarker,
        _hueMarker = hueMarker,
        _alphaMarker = alphaMarker,
        _alphaGradient = alphaGradient,
        _input = input,
        _hasAlpha = hasAlpha,
        _editing = false,
        _h = h0, _s = s0, _v = v0,
        _a = hasAlpha and opts.Alpha or 1,
        _label = opts.Name or "Colorpicker",
        _callback = opts.Callback,
        _listeners = {},
        _swatches = {},
        _swatchRow = swatchRow,
    }, Colorpicker)

    root:keep(swatch.Activated:Connect(function()
        self:_toggle()
    end))

    -- Drag handling mirrors the slider's: press to jump, InputChanged to track,
    -- InputEnded to release. One shared `self._dragging` target rather than
    -- three flags, so two areas can never both think they are being dragged.
    -- Kept on self, not as an upvalue, so _toggle's popup onClose (below) can
    -- reach in and cancel a drag that outlives the popup that started it.
    self._dragging = nil

    local function applyFromMouse()
        if self._dragging == nil then return end
        local mx, my = root:mouseInGuiSpace()
        if self._dragging == "square" then
            local p, size = square.AbsolutePosition, square.AbsoluteSize
            local fx = size.X > 0 and (mx - p.X) / size.X or 0
            local fy = size.Y > 0 and (my - p.Y) / size.Y or 0
            self._s = math.clamp(fx, 0, 1)
            self._v = 1 - math.clamp(fy, 0, 1)
        elseif self._dragging == "hue" then
            local p, size = hueStrip.AbsolutePosition, hueStrip.AbsoluteSize
            local fx = size.X > 0 and (mx - p.X) / size.X or 0
            self._h = math.clamp(fx, 0, 1)
        elseif self._dragging == "alpha" and alphaStrip then
            local p, size = alphaStrip.AbsolutePosition, alphaStrip.AbsoluteSize
            local fx = size.X > 0 and (mx - p.X) / size.X or 0
            self._a = math.clamp(fx, 0, 1)
        end
        self:_paint()
        self:_fire()
    end

    local function grab(target, instance)
        root:keep(instance.InputBegan:Connect(function(input2)
            if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                self._dragging = target
                applyFromMouse()
            end
        end))
    end

    grab("square", square)
    grab("hue", hueStrip)
    if alphaStrip then grab("alpha", alphaStrip) end

    root:keep(UserInputService.InputChanged:Connect(function(input2)
        if self._dragging and input2.UserInputType == Enum.UserInputType.MouseMovement then
            applyFromMouse()
        end
    end))

    root:keep(UserInputService.InputEnded:Connect(function(input2)
        if input2.UserInputType == Enum.UserInputType.MouseButton1 then
            self._dragging = nil
        end
    end))

    root:keep(input.Focused:Connect(function()
        self._editing = true
    end))

    root:keep(input.FocusLost:Connect(function()
        self._editing = false
        local r, g, b, a = M.parseColor(input.Text)
        if r == nil then
            -- Unparseable input reverts, exactly as the slider does. This is
            -- user input at runtime, not a programming mistake.
            self:_paint()
            return
        end
        local colour = Color3.fromRGB(r, g, b)
        self._h, self._s, self._v = colour:ToHSV()
        if self._hasAlpha then self._a = a end
        self:_paint()
        self:_fire()
    end))

    root:keep(addButton.Activated:Connect(function()
        root.palette:Add(self:_colour())
    end))

    -- Every colorpicker shares one palette, so each redraws when it changes.
    root.palette:onChanged(function()
        if not root:isAlive() then return end
        self:_paintSwatches()
    end)

    self:_paintSwatches()

    self:_paint()
    return self
end

function Colorpicker:_colour()
    return Color3.fromHSV(self._h, self._s, self._v)
end

function Colorpicker:_paint()
    local colour = self:_colour()

    self._swatch.BackgroundColor3 = colour
    if self._hasAlpha then
        self._swatch.BackgroundTransparency = 1 - self._a
    end

    self._square.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
    self._squareMarker.Position = UDim2.fromScale(self._s, 1 - self._v)
    self._hueMarker.Position = UDim2.fromScale(self._h, 0.5)

    if self._hasAlpha then
        self._alphaMarker.Position = UDim2.fromScale(self._a, 0.5)
        -- The wash fades from transparent to the current colour, so the strip
        -- always previews the actual alpha range for what is selected.
        self._alphaGradient.Color = ColorSequence.new(colour, colour)
    end

    -- Leave the text alone mid-edit, or a live drag would overwrite what is
    -- being typed.
    if not self._editing then
        local r = math.floor(colour.R * 255 + 0.5)
        local g = math.floor(colour.G * 255 + 0.5)
        local b = math.floor(colour.B * 255 + 0.5)
        self._input.Text = M.toHex(r, g, b, self._hasAlpha and self._a or nil)
    end
end

-- Rebuilt wholesale rather than diffed: at most ten cells, and the palette
-- changes only on an explicit add or delete.
function Colorpicker:_paintSwatches()
    for i = 1, #self._swatches do
        -- Destroying an Instance does not remove its theme bindings, so apply()
        -- would keep writing to a destroyed object every frame.
        self._theme:unbind(self._swatches[i])
        self._swatches[i]:Destroy()
    end
    self._swatches = {}

    local colours = self._root.palette:Get()
    for i = 1, #colours do
        local cell = Instance.new("TextButton")
        cell.Name = "swatch"
        cell.Size = UDim2.fromOffset(12, 12)
        cell.BackgroundColor3 = colours[i]
        cell.BorderSizePixel = 0
        cell.Text = ""
        cell.AutoButtonColor = false
        cell.LayoutOrder = i
        cell.ZIndex = 13
        cell.Parent = self._swatchRow

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Parent = cell
        self._theme:bind(stroke, "Color", "FieldBorder")

        local colour = colours[i]
        local index = i

        -- Tied to the cell's lifetime rather than root:keep, because the row is
        -- rebuilt on every palette change and a keep per rebuild would grow the
        -- teardown list forever.
        cell.Activated:Connect(function()
            self:Set(colour)
        end)
        cell.MouseButton2Click:Connect(function()
            self._root.palette:Remove(index)
        end)

        table.insert(self._swatches, cell)
    end
end

function Colorpicker:_toggle()
    local popup = self._root.popup
    if popup:isOpen(self) then
        popup:close()
        return
    end
    -- The popup can close from things other than the swatch click that opened
    -- it -- bindDismissal routes window drag/reflow straight to popup:close().
    -- Without this, a hex edit left focused keeps engine-side focus while
    -- hidden (FocusLost never fires, so _editing never clears and _paint stops
    -- updating the hex text), and a drag left in progress keeps applying
    -- against the hidden popup's stale geometry, still firing the callback.
    popup:open(self, self._popup, self._swatch, function()
        self._input:ReleaseFocus()
        self._dragging = nil
    end)
end

function Colorpicker:_fire()
    local colour = self:_colour()
    safecall.call(self._label, self._callback, colour, self._a)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], colour, self._a)
    end
end

-- Returns the Color3 and, as a second value, the alpha. Two returns rather than
-- a table: a consumer that only wants the colour writes `local c = cp:Get()`
-- and is done.
function Colorpicker:Get()
    return self:_colour(), self._a
end

function Colorpicker:Set(colour, silent)
    if typeof(colour) ~= "Color3" then return end
    local h, s, v = colour:ToHSV()
    local changed = h ~= self._h or s ~= self._s or v ~= self._v
    self._h, self._s, self._v = h, s, v
    self:_paint()
    if silent or not changed then return end
    self:_fire()
end

function Colorpicker:SetAlpha(a, silent)
    if type(a) ~= "number" or not self._hasAlpha then return end
    a = math.clamp(a, 0, 1)
    local changed = a ~= self._a
    self._a = a
    self:_paint()
    if silent or not changed then return end
    self:_fire()
end

-- Alpha is state that Get() returns second, so it travels alongside the colour.
function Colorpicker:Save()
    return { colour = self:_colour(), alpha = self._a }
end

function Colorpicker:Load(t)
    if type(t) ~= "table" then return end
    if t.alpha ~= nil then self:SetAlpha(t.alpha, true) end
    self:Set(t.colour)
end

function Colorpicker:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function Colorpicker:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
