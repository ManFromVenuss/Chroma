-- A 7px checkbox in the row's control slot. Clicking anywhere on the row
-- flips it, which is far easier to hit than the box itself.

local safecall = require("util/safecall")

local M = {}

local Toggle = {}
Toggle.__index = Toggle

local BOX = 7

function M.new(root, row, opts)
    local theme = root.theme

    local box = Instance.new("Frame")
    box.Name = "box"
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.fromOffset(BOX, BOX)
    box.BorderSizePixel = 0
    box.Parent = row.control
    theme:bind(box, "BackgroundColor3", "Field")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = box
    theme:bind(stroke, "Color", "FieldBorder")

    -- A transparent button over the whole row: a 7px target is unusable.
    local hit = Instance.new("TextButton")
    hit.Name = "hit"
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 3
    hit.Parent = row.frame

    local self = setmetatable({
        _root = root,
        _row = row,
        _box = box,
        _stroke = stroke,
        _theme = theme,
        _label = opts.Name or "Toggle",
        _callback = opts.Callback,
        _listeners = {},
        _value = false,
    }, Toggle)

    root:keep(hit.Activated:Connect(function()
        self:Set(not self._value)
    end))

    self:Set(opts.Default == true, true)
    return self
end

function Toggle:_paint()
    -- Rebind rather than write directly, so the ON state keeps tracking the
    -- animated accent instead of freezing at the colour it had when clicked.
    self._theme:unbind(self._box)
    self._theme:unbind(self._stroke)
    if self._value then
        self._theme:bind(self._box, "BackgroundColor3", "Accent")
        self._theme:bind(self._stroke, "Color", "Accent")
    else
        self._theme:bind(self._box, "BackgroundColor3", "Field")
        self._theme:bind(self._stroke, "Color", "FieldBorder")
    end
end

function Toggle:Get()
    return self._value
end

function Toggle:Set(value, silent)
    value = value == true
    local changed = value ~= self._value
    self._value = value
    self:_paint()
    if silent or not changed then return end
    safecall.call(self._label, self._callback, value)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], value)
    end
end

function Toggle:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function Toggle:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
