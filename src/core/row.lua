-- A single 19px row: label on the left, optional (?) icon, and a fixed-width
-- right-aligned control slot that a widget renders into.
--
-- This is the boundary that keeps widget modules free of layout code: a widget
-- is handed `row.control` and knows nothing about rows, containers or columns.

local M = {}

M.HEIGHT = 19
M.CONTROL_WIDTH = 110   -- fits a 74px slider track plus its value text
M.ICON_SIZE = 11

-- opts: Name, Description, Height (optional override)
function M.new(root, parent, opts)
    local theme = root.theme
    local height = opts.Height or M.HEIGHT

    local row = Instance.new("Frame")
    row.Name = "row"
    row.Size = UDim2.new(1, 0, 0, height)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = parent
    root:keep(row)

    local hasIcon = opts.Description ~= nil and opts.Description ~= ""
    -- The icon sits immediately left of the control slot at a FIXED offset,
    -- rather than trailing the label text. Trailing would need TextBounds,
    -- which only settles a frame later -- the same timing trap that clips
    -- wrapped labels. Fixed placement also lines every icon in a column up
    -- vertically, which scans better than a ragged edge.
    local labelRight = M.CONTROL_WIDTH + (hasIcon and (M.ICON_SIZE + 8) or 0)

    local label = Instance.new("TextLabel")
    label.Name = "label"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(0, 0)
    label.Size = UDim2.new(1, -labelRight, 1, 0)
    label.Font = Enum.Font.Ubuntu
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Text = opts.Name or ""
    label.Parent = row
    theme:bind(label, "TextColor3", "Text")

    local icon
    if hasIcon then
        icon = Instance.new("TextButton")
        icon.Name = "help"
        icon.AnchorPoint = Vector2.new(1, 0.5)
        icon.Position = UDim2.new(1, -M.CONTROL_WIDTH, 0.5, 0)
        icon.Size = UDim2.fromOffset(M.ICON_SIZE, M.ICON_SIZE)
        icon.BackgroundTransparency = 1
        icon.AutoButtonColor = false
        icon.Font = Enum.Font.Ubuntu
        icon.TextSize = 10
        icon.Text = "?"
        icon.Parent = row
        theme:bind(icon, "TextColor3", "TextDim")

        local iconStroke = Instance.new("UIStroke")
        iconStroke.Thickness = 1
        iconStroke.Parent = icon
        theme:bind(iconStroke, "Color", "FieldBorder")

        -- Tint to the accent on hover, so the icon reads as interactive before
        -- the tooltip appears. Written directly rather than through theme:bind
        -- because the colour depends on hover state, not only on the palette:
        -- the hovered icon therefore holds one accent colour instead of
        -- cycling, which is fine for the second or so it is hovered.
        root:keep(icon.MouseEnter:Connect(function()
            icon.TextColor3 = theme:get("Accent")
            iconStroke.Color = theme:get("Accent")
        end))
        root:keep(icon.MouseLeave:Connect(function()
            icon.TextColor3 = theme:get("TextDim")
            iconStroke.Color = theme:get("FieldBorder")
        end))

        root.tooltip:attach(icon, opts.Description)
    end

    local control = Instance.new("Frame")
    control.Name = "control"
    control.AnchorPoint = Vector2.new(1, 0)
    control.Position = UDim2.new(1, 0, 0, 0)
    control.Size = UDim2.new(0, M.CONTROL_WIDTH, 1, 0)
    control.BackgroundTransparency = 1
    control.BorderSizePixel = 0
    control.Parent = row

    return { frame = row, label = label, icon = icon, control = control }
end

return M
