-- The 110x14 bordered field shared by Dropdown, TextBox and Keybind.
--
-- Three consumers with identical chrome, and the accent-on-open border
-- treatment has to match across them or the widgets read as three different
-- components. This is widget chrome, not row layout: the row still owns the
-- slot, and this renders into it.

local M = {}

M.HEIGHT = 14

-- opts: Glyph (a trailing character), Editable (caption is a TextBox),
-- Placeholder (Editable only).
function M.new(root, parent, opts)
    opts = opts or {}
    local theme = root.theme

    local frame = Instance.new("TextButton")
    frame.Name = "field"
    frame.AnchorPoint = Vector2.new(1, 0.5)
    frame.Position = UDim2.new(1, 0, 0.5, 0)
    frame.Size = UDim2.new(1, 0, 0, M.HEIGHT)
    frame.BorderSizePixel = 0
    frame.Text = ""
    frame.AutoButtonColor = false
    frame.Parent = parent
    theme:bind(frame, "BackgroundColor3", "Field")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = frame
    theme:bind(stroke, "Color", "FieldBorder")

    -- A TextBox kept non-editable until clicked, rather than a label swapped for
    -- an input: the proven pattern from the slider's value field, where nothing
    -- moves between the two states.
    local caption = Instance.new(opts.Editable and "TextBox" or "TextLabel")
    caption.Name = "caption"
    caption.BackgroundTransparency = 1
    caption.Position = UDim2.fromOffset(4, 0)
    caption.Size = UDim2.new(1, -(opts.Glyph and 16 or 8), 1, 0)
    caption.Font = Enum.Font.Ubuntu
    caption.TextSize = 11
    caption.TextXAlignment = Enum.TextXAlignment.Left
    caption.TextTruncate = Enum.TextTruncate.AtEnd
    caption.Text = ""
    caption.Parent = frame
    theme:bind(caption, "TextColor3", "Text")

    if opts.Editable then
        caption.TextEditable = false
        caption.ClearTextOnFocus = false
        caption.PlaceholderText = opts.Placeholder or ""
        theme:bind(caption, "PlaceholderColor3", "TextDim")
    end

    local api = { frame = frame, stroke = stroke, label = caption }

    if opts.Glyph then
        local glyph = Instance.new("TextLabel")
        glyph.Name = "glyph"
        glyph.AnchorPoint = Vector2.new(1, 0.5)
        glyph.Position = UDim2.new(1, -4, 0.5, 0)
        glyph.Size = UDim2.fromOffset(8, 10)
        glyph.BackgroundTransparency = 1
        glyph.Font = Enum.Font.Ubuntu
        glyph.TextSize = 8
        glyph.Text = opts.Glyph
        glyph.Parent = frame
        theme:bind(glyph, "TextColor3", "TextDim")
        api.glyph = glyph
    end

    -- The border tracks the accent while the field is live: popup open,
    -- capturing a key, or being typed into. Rebind rather than write directly --
    -- theme:apply() runs every frame while the accent animates, so a binding
    -- keeps cycling with it instead of freezing at the hue it had on click.
    function api.setActive(active)
        theme:unbind(stroke)
        theme:bind(stroke, "Color", active and "Accent" or "FieldBorder")
    end

    return api
end

return M
