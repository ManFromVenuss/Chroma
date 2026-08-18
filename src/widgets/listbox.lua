-- An inline bordered box of rows with one selected, scrolling past `Rows`.
--
-- Inline rather than a popup, which is the whole difference from Dropdown: this
-- is the presets box from the gamesense reference, something you look at while
-- doing something else, not something you open and dismiss. M4's config manager
-- is its first real consumer.

local safecall = require("util/safecall")

local M = {}

-- No control slot: a list of names needs the full width.
M.FullWidth = true

local ListBox = {}
ListBox.__index = ListBox

local ITEM_HEIGHT = 15
local DEFAULT_ROWS = 6

function M.new(root, row, opts)
    local theme = root.theme

    row.label.Text = ""

    local rows = opts.Rows or DEFAULT_ROWS
    if type(rows) ~= "number" or rows < 1 then rows = DEFAULT_ROWS end
    rows = math.floor(rows)

    -- The row's height is the box plus a 1px margin each side, so the box's
    -- outward-drawing stroke is not clipped by the container's padding.
    local boxHeight = rows * ITEM_HEIGHT
    row.setHeight(boxHeight + 2)

    local box = Instance.new("ScrollingFrame")
    box.Name = "listbox"
    box.Position = UDim2.fromOffset(0, 1)
    box.Size = UDim2.new(1, 0, 0, boxHeight)
    box.BorderSizePixel = 0
    box.CanvasSize = UDim2.new()
    -- The PROPERTY is AutomaticCanvasSize, but its type is Enum.AutomaticSize.
    box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    box.ScrollBarThickness = 2
    box.ScrollingDirection = Enum.ScrollingDirection.Y
    box.ElasticBehavior = Enum.ElasticBehavior.Never
    -- Above the row's own hit button (ZIndex 2), or the row swallows clicks and
    -- scrolling both.
    box.ZIndex = 3
    box.Parent = row.frame
    theme:bind(box, "BackgroundColor3", "Field")
    theme:bind(box, "ScrollBarImageColor3", "Accent")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = box
    theme:bind(stroke, "Color", "FieldBorder")

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = box

    local self = setmetatable({
        _root = root,
        _row = row,
        _theme = theme,
        _box = box,
        _entries = {},
        _items = opts.Items or {},
        _value = nil,
        _label = opts.Name or "ListBox",
        _callback = opts.Callback,
        _listeners = {},
    }, ListBox)

    self:_rebuild()
    self:Set(opts.Default, true)
    return self
end

function ListBox:_has(value)
    for i = 1, #self._items do
        if self._items[i] == value then return true end
    end
    return false
end

function ListBox:_rebuild()
    local theme = self._theme
    for i = 1, #self._entries do
        local e = self._entries[i]
        -- Destroying an Instance does NOT remove its theme bindings: apply()
        -- would keep writing to a destroyed object every frame, and the binding
        -- list would grow without bound on every SetItems call.
        theme:unbind(e.button)
        theme:unbind(e.label)
        e.button:Destroy()
    end
    self._entries = {}

    for i = 1, #self._items do
        local text = self._items[i]

        local button = Instance.new("TextButton")
        button.Name = "item"
        button.Size = UDim2.new(1, 0, 0, ITEM_HEIGHT)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.LayoutOrder = i
        button.ZIndex = 4
        button.Parent = self._box

        local label = Instance.new("TextLabel")
        label.Name = "text"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(5, 0)
        label.Size = UDim2.new(1, -10, 1, 0)
        label.Font = Enum.Font.Ubuntu
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Text = tostring(text)
        label.ZIndex = 5
        label.Parent = button

        self._entries[i] = { button = button, label = label, text = text }

        -- Tied to the button's own lifetime rather than root:keep: SetItems
        -- destroys and rebuilds these, and a keep per rebuild would grow the
        -- teardown list every time a consumer refreshes the list.
        button.Activated:Connect(function()
            self:Set(text)
        end)
    end

    self:_paint()
end

function ListBox:_paint()
    local theme = self._theme
    for i = 1, #self._entries do
        local e = self._entries[i]
        theme:unbind(e.button)
        theme:unbind(e.label)
        if e.text == self._value then
            theme:bind(e.button, "BackgroundColor3", "Selection", "BackgroundTransparency")
            theme:bind(e.label, "TextColor3", "Accent")
        else
            e.button.BackgroundTransparency = 1
            theme:bind(e.label, "TextColor3", "Text")
        end
    end
end

function ListBox:Get()
    return self._value
end

function ListBox:Set(value, silent)
    -- An unknown value is ignored rather than erroring: the usual caller is a
    -- config restore holding a preset that has since been deleted.
    if value ~= nil and not self:_has(value) then return end
    local changed = value ~= self._value
    self._value = value
    self:_paint()
    if silent or not changed then return end
    safecall.call(self._label, self._callback, value)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], value)
    end
end

-- Replaces the contents, keeping the selection if it survived.
function ListBox:SetItems(list)
    self._items = list or {}
    if self._value ~= nil and not self:_has(self._value) then
        self._value = nil
    end
    self:_rebuild()
end

function ListBox:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function ListBox:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
