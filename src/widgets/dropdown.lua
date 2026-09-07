-- A field in the control slot that opens a list in the popup layer.
--
-- Single-select commits and closes on click. Multi-select ticks a 7px checkbox
-- matching Toggle's -- so "this is a thing you tick" reads the same everywhere
-- -- and stays open, because picking several is the point.

local Field = require("core/field")
local safecall = require("util/safecall")

local M = {}

local Dropdown = {}
Dropdown.__index = Dropdown

local ENTRY_HEIGHT = 16
local MAX_VISIBLE = 8   -- past this the list scrolls; more than ~8 rows floating
                        -- over the menu stops reading as a menu
local WIDTH = 110       -- matches Row.CONTROL_WIDTH, so the popup lines up with
                        -- the field it came from

function M.new(root, row, opts)
    local theme = root.theme

    -- U+25BC. If this ever renders as a box in-game, fall back to "v" in
    -- Enum.Font.Code.
    local field = Field.new(root, row.control, { Glyph = "\u{25BC}" })

    local popup = Instance.new("Frame")
    popup.Name = "dropdown"
    popup.Size = UDim2.fromOffset(WIDTH, ENTRY_HEIGHT)   -- real height set by _rebuild
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

    local list = Instance.new("ScrollingFrame")
    list.Name = "list"
    list.Size = UDim2.fromScale(1, 1)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.CanvasSize = UDim2.new()
    -- The property is AutomaticCanvasSize, but its type is Enum.AutomaticSize.
    -- There is no Enum.AutomaticCanvasSize.
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollBarThickness = 2
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ElasticBehavior = Enum.ElasticBehavior.Never
    list.ZIndex = 11
    list.Parent = popup
    theme:bind(list, "ScrollBarImageColor3", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list

    local multi = opts.Multi == true
    local self = setmetatable({
        _root = root,
        _row = row,
        _theme = theme,
        _field = field,
        _popup = popup,
        _list = list,
        _entries = {},
        _options = opts.Options or {},
        _multi = multi,
        _selected = {},
        _value = nil,
        _label = opts.Name or "Dropdown",
        _callback = opts.Callback,
        _listeners = {},
    }, Dropdown)

    self:_rebuild()

    root:keep(field.frame.Activated:Connect(function()
        self:_toggle()
    end))

    -- A Default that is not in Options can only be a typo, and silently
    -- selecting nothing hides it.
    local default = opts.Default
    if default ~= nil then
        if multi then
            if type(default) ~= "table" then
                error(string.format(
                    "chroma: multi dropdown '%s' needs an array Default, got %s",
                    tostring(opts.Name), type(default)), 2)
            end
            for i = 1, #default do
                if not self:_has(default[i]) then
                    error(string.format(
                        "chroma: dropdown '%s' Default '%s' is not in Options",
                        tostring(opts.Name), tostring(default[i])), 2)
                end
            end
        elseif not self:_has(default) then
            error(string.format(
                "chroma: dropdown '%s' Default '%s' is not in Options",
                tostring(opts.Name), tostring(default)), 2)
        end
    end

    self:Set(default, true)
    return self
end

function Dropdown:_has(value)
    for i = 1, #self._options do
        if self._options[i] == value then return true end
    end
    return false
end

function Dropdown:_rebuild()
    local theme = self._theme
    for i = 1, #self._entries do
        local e = self._entries[i]
        -- Destroying an Instance does NOT remove its theme bindings: apply()
        -- would keep writing to a destroyed object every frame, and the binding
        -- list would grow without bound on every SetOptions call.
        theme:unbind(e.button)
        theme:unbind(e.label)
        if e.box then
            theme:unbind(e.box)
            theme:unbind(e.boxStroke)
        end
        e.button:Destroy()
    end
    self._entries = {}

    for i = 1, #self._options do
        local text = self._options[i]

        local button = Instance.new("TextButton")
        button.Name = "entry"
        button.Size = UDim2.new(1, 0, 0, ENTRY_HEIGHT)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.LayoutOrder = i
        button.ZIndex = 12
        button.Parent = self._list

        local box, boxStroke
        local textX = 5
        if self._multi then
            box = Instance.new("Frame")
            box.Name = "box"
            box.AnchorPoint = Vector2.new(0, 0.5)
            box.Position = UDim2.new(0, 5, 0.5, 0)
            box.Size = UDim2.fromOffset(7, 7)
            box.BorderSizePixel = 0
            box.ZIndex = 13
            box.Parent = button

            boxStroke = Instance.new("UIStroke")
            boxStroke.Thickness = 1
            boxStroke.Parent = box

            textX = 17   -- 5 padding + 7 box + 5 gap
        end

        local label = Instance.new("TextLabel")
        label.Name = "text"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(textX, 0)
        label.Size = UDim2.new(1, -(textX + 5), 1, 0)
        label.Font = Enum.Font.Ubuntu
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Text = tostring(text)
        label.ZIndex = 13
        label.Parent = button

        self._entries[i] = {
            button = button, label = label, box = box,
            boxStroke = boxStroke, text = text,
        }

        -- Entries are destroyed and rebuilt by SetOptions, so their connections
        -- must die with them. Parenting the connection to the button's own
        -- lifetime (rather than root:keep) is what stops the junk list growing
        -- every time a consumer refreshes the options.
        button.Activated:Connect(function()
            self:_choose(text)
        end)
    end

    -- An explicit pixel height, not AutomaticSize: the popup manager reads
    -- Size.Y.Offset to place the frame before it has ever rendered.
    local visible = #self._options
    if visible > MAX_VISIBLE then visible = MAX_VISIBLE end
    if visible < 1 then visible = 1 end
    self._popup.Size = UDim2.fromOffset(WIDTH, visible * ENTRY_HEIGHT)

    self:_paint()
end

function Dropdown:_caption()
    if not self._multi then
        -- "none" rather than a blank field: an empty control reads as broken
        -- rather than as an empty selection, and it matches what multi-select
        -- already shows for the same state. An option literally named "none"
        -- displays identically; that collision is accepted rather than escaped,
        -- since Get() still returns the real value and nothing else here
        -- reserves the string.
        return self._value ~= nil and tostring(self._value) or "none"
    end
    local n, only = 0, nil
    for i = 1, #self._options do
        if self._selected[self._options[i]] then
            n = n + 1
            if only == nil then only = self._options[i] end
        end
    end
    if n == 0 then return "none" end
    -- One pick reads better as its own name than as "1 selected". Past that a
    -- comma list truncates uselessly at 110px, so a count is the honest summary.
    if n == 1 then return tostring(only) end
    return tostring(n) .. " selected"
end

function Dropdown:_paint()
    local theme = self._theme
    for i = 1, #self._entries do
        local e = self._entries[i]
        if self._multi then
            local on = self._selected[e.text] == true
            theme:unbind(e.box)
            theme:unbind(e.boxStroke)
            theme:bind(e.box, "BackgroundColor3", on and "Accent" or "Field")
            theme:bind(e.boxStroke, "Color", on and "Accent" or "FieldBorder")
        else
            local on = self._value == e.text
            theme:unbind(e.button)
            theme:unbind(e.label)
            if on then
                theme:bind(e.button, "BackgroundColor3", "Selection", "BackgroundTransparency")
                theme:bind(e.label, "TextColor3", "Accent")
            else
                e.button.BackgroundTransparency = 1
                theme:bind(e.label, "TextColor3", "Text")
            end
        end
    end
    self._field.label.Text = self:_caption()
end

function Dropdown:_toggle()
    local popup = self._root.popup
    if popup:isOpen(self) then
        popup:close()
        return
    end
    self._field.setActive(true)
    popup:open(self, self._popup, self._field.frame, function()
        self._field.setActive(false)
    end)
end

function Dropdown:_choose(text)
    if self._multi then
        if self._selected[text] then
            self._selected[text] = nil
        else
            self._selected[text] = true
        end
        self:_paint()
        self:_fire()
        -- Deliberately stays open.
    else
        self:Set(text)
        self._root.popup:close()
    end
end

function Dropdown:_fire()
    local value = self:Get()
    safecall.call(self._label, self._callback, value)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], value)
    end
end

-- A string for single-select, a fresh array in Options order for multi.
function Dropdown:Get()
    if not self._multi then return self._value end
    local out = {}
    for i = 1, #self._options do
        if self._selected[self._options[i]] then
            table.insert(out, self._options[i])
        end
    end
    return out
end

function Dropdown:Set(value, silent)
    if self._multi then
        local set = {}
        if type(value) == "table" then
            for i = 1, #value do set[value[i]] = true end
        end
        self._selected = set
        self:_paint()
        -- No change detection for multi: comparing two sets to decide whether to
        -- fire costs more than the spurious callback it would save.
        if silent then return end
        self:_fire()
        return
    end

    -- An unknown value at RUNTIME is not the same as a bad Default: a consumer
    -- restoring a stale config should be ignored, not crashed.
    if value ~= nil and not self:_has(value) then return end
    local changed = value ~= self._value
    self._value = value
    self:_paint()
    if silent or not changed then return end
    self:_fire()
end

-- Replaces the contents, keeping any still-valid selection.
function Dropdown:SetOptions(list)
    self._options = list or {}
    if self._multi then
        local kept = {}
        for i = 1, #self._options do
            if self._selected[self._options[i]] then kept[self._options[i]] = true end
        end
        self._selected = kept
    elseif self._value ~= nil and not self:_has(self._value) then
        self._value = nil
    end
    self:_rebuild()
end

function Dropdown:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function Dropdown:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
