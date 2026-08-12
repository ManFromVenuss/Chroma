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
-- fullWidth: true for widgets with no control slot (Label, Separator), which
-- span the whole row. The row must handle this itself rather than a widget
-- resizing row.label after the fact -- a widget must not resize the row it
-- was handed, that would put layout logic back inside widget modules.
function M.new(root, parent, opts, fullWidth)
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
    if fullWidth then
        -- No control slot to reserve space for; the icon (if any) still needs
        -- its own space carved out of the label's width.
        if hasIcon then
            label.Size = UDim2.new(1, -(M.ICON_SIZE + 8), 1, 0)
        else
            label.Size = UDim2.new(1, 0, 1, 0)
        end
    else
        label.Size = UDim2.new(1, -labelRight, 1, 0)
    end
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
        if fullWidth then
            -- No control slot to sit left of; anchor to the row's own edge.
            icon.Position = UDim2.new(1, 0, 0.5, 0)
        else
            icon.Position = UDim2.new(1, -M.CONTROL_WIDTH, 0.5, 0)
        end
        icon.Size = UDim2.fromOffset(M.ICON_SIZE, M.ICON_SIZE)
        icon.BackgroundTransparency = 1
        icon.AutoButtonColor = false
        icon.Font = Enum.Font.Ubuntu
        icon.TextSize = 10
        icon.Text = "?"
        -- Above the hit button (2) so hover/tooltips still resolve against it.
        icon.ZIndex = 4
        icon.Parent = row
        theme:bind(icon, "TextColor3", "TextDim")

        local iconStroke = Instance.new("UIStroke")
        iconStroke.Thickness = 1
        iconStroke.Parent = icon
        theme:bind(iconStroke, "Color", "FieldBorder")

        -- Tint to the accent on hover, so the icon reads as interactive before
        -- the tooltip appears. Rebind rather than write directly: theme:apply()
        -- runs every frame off the window's heartbeat while the accent
        -- animates, so a binding keeps cycling with it for free instead of
        -- freezing at whatever hue was current on MouseEnter. bind() paints
        -- immediately, so there is no flash between unbinding and rebinding.
        root:keep(icon.MouseEnter:Connect(function()
            theme:unbind(icon)
            theme:unbind(iconStroke)
            theme:bind(icon, "TextColor3", "Accent")
            theme:bind(iconStroke, "Color", "Accent")
        end))
        root:keep(icon.MouseLeave:Connect(function()
            theme:unbind(icon)
            theme:unbind(iconStroke)
            theme:bind(icon, "TextColor3", "TextDim")
            theme:bind(iconStroke, "Color", "FieldBorder")
        end))

        root.tooltip:attach(icon, opts.Description)
    end

    local control
    if not fullWidth then
        control = Instance.new("Frame")
        control.Name = "control"
        control.AnchorPoint = Vector2.new(1, 0)
        control.Position = UDim2.new(1, 0, 0, 0)
        control.Size = UDim2.new(0, M.CONTROL_WIDTH, 1, 0)
        control.BackgroundTransparency = 1
        control.BorderSizePixel = 0
        -- Above the hit button (2) so widgets inside it (a slider track, for
        -- instance) receive their own input instead of the row swallowing it.
        control.ZIndex = 3
        control.Parent = row
    end

    -- A transparent, full-row click target. Widgets that want "click anywhere
    -- on the row" ask for it via onActivated() below rather than parenting
    -- their own button into row.frame -- every widget doing that would defeat
    -- the boundary the control slot exists to enforce. It sits ABOVE the
    -- label but BELOW the help icon and control slot: ZIndex 2, deliberately
    -- between icon (4) and control (3) on one side and the label's default of
    -- 1 on the other. Getting this ordering wrong is exactly how the row used
    -- to swallow hover input meant for the (?) icon and silently kill
    -- tooltips -- do not "fix" this back to matching or exceeding 3/4.
    local hit = Instance.new("TextButton")
    hit.Name = "hit"
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 2
    hit.Parent = row

    local api = { frame = row, label = label, icon = icon, control = control }

    -- Widgets that need a different row height ask for it rather than writing
    -- to row.frame themselves. Reaching into Instances the row owns is what
    -- the control-slot boundary exists to prevent.
    function api.setHeight(px)
        row.Size = UDim2.new(1, 0, 0, px)
    end

    -- Widgets that want "click anywhere on the row" ask for it here rather than
    -- parenting a button into row.frame themselves. The row owns the layering:
    -- the hit button deliberately sits BELOW the help icon and the control
    -- slot, or it would swallow their input and silently kill tooltips.
    function api.onActivated(fn)
        root:keep(hit.Activated:Connect(fn))
    end

    return api
end

return M
