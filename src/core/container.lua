-- A titled section: the title sits OUTSIDE a bordered box, on the backdrop,
-- as gamesense does. The box height is derived from its rows via
-- AutomaticSize -- nothing here computes a height.

local Row = require("core/row")
local widgets = require("widgets/init")

local M = {}

local Container = {}
Container.__index = Container

function M.new(root, parent, title)
    local theme = root.theme

    local holder = Instance.new("Frame")
    holder.Name = "container"
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Parent = parent
    root:keep(holder)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = holder

    local heading = Instance.new("TextLabel")
    heading.Name = "title"
    heading.BackgroundTransparency = 1
    heading.Size = UDim2.new(1, 0, 0, 14)
    heading.Font = Enum.Font.Ubuntu
    heading.TextSize = 12
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.Text = title or ""
    heading.LayoutOrder = 1
    heading.Parent = holder
    theme:bind(heading, "TextColor3", "TextBright")

    local box = Instance.new("Frame")
    box.Name = "box"
    box.Size = UDim2.new(1, 0, 0, 0)
    box.AutomaticSize = Enum.AutomaticSize.Y
    box.BorderSizePixel = 0
    box.LayoutOrder = 2
    box.Parent = holder
    theme:bind(box, "BackgroundColor3", "Container", "BackgroundTransparency")

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Parent = box
    theme:bind(boxStroke, "Color", "ContainerBorder")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.PaddingBottom = UDim.new(0, 5)
    pad.PaddingLeft = UDim.new(0, 7)
    pad.PaddingRight = UDim.new(0, 7)
    pad.Parent = box

    local rows = Instance.new("UIListLayout")
    rows.FillDirection = Enum.FillDirection.Vertical
    rows.SortOrder = Enum.SortOrder.LayoutOrder
    rows.Padding = UDim.new(0, 0)
    rows.Parent = box

    return setmetatable({
        _root = root,
        _box = box,
        _order = 0,
        holder = holder,
    }, Container)
end

-- One method per registered widget, generated rather than written out, so this
-- file has no per-widget knowledge.
for name, widget in pairs(widgets) do
    Container[name] = function(self, opts)
        opts = opts or {}
        self._order = self._order + 1
        -- widget.FullWidth is a declared property, not a hardcoded list, so
        -- this stays widget-agnostic.
        local row = Row.new(self._root, self._box, opts, widget.FullWidth)
        row.frame.LayoutOrder = self._order
        return widget.new(self._root, row, opts)
    end
end

return M
