-- A full-width bordered button with the label centred.
--
-- It takes the whole row rather than sitting in the control slot: a left label
-- with a small button on the right reads as broken.

local safecall = require("util/safecall")

local M = {}

-- No control slot. See label.lua for the rationale.
M.FullWidth = true

local Button = {}
Button.__index = Button

local ROW_HEIGHT = 22
local BOX_HEIGHT = 18

function M.new(root, row, opts)
    local theme = root.theme

    row.label.Text = ""
    row.setHeight(ROW_HEIGHT)

    local box = Instance.new("TextButton")
    box.Name = "button"
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.new(1, 0, 0, BOX_HEIGHT)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Ubuntu
    box.TextSize = 11
    box.Text = opts.Text or opts.Name or "Button"
    box.AutoButtonColor = false
    -- Above the row's own hit button (ZIndex 2), or the row swallows the click.
    box.ZIndex = 3
    box.Parent = row.frame
    theme:bind(box, "BackgroundColor3", "Field")
    theme:bind(box, "TextColor3", "Text")

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = box
    theme:bind(stroke, "Color", "FieldBorder")

    -- Rebind rather than write directly: theme:apply() runs every frame while
    -- the accent animates, so a binding keeps cycling instead of freezing at
    -- whatever hue was current on MouseEnter.
    root:keep(box.MouseEnter:Connect(function()
        theme:unbind(stroke)
        theme:unbind(box)
        theme:bind(stroke, "Color", "Accent")
        theme:bind(box, "BackgroundColor3", "Field")
        theme:bind(box, "TextColor3", "TextBright")
    end))

    root:keep(box.MouseLeave:Connect(function()
        theme:unbind(stroke)
        theme:unbind(box)
        theme:bind(stroke, "Color", "FieldBorder")
        theme:bind(box, "BackgroundColor3", "Field")
        theme:bind(box, "TextColor3", "Text")
    end))

    local self = setmetatable({
        _root = root,
        _row = row,
        _label = opts.Name or opts.Text or "Button",
        _callback = opts.Callback,
    }, Button)

    root:keep(box.Activated:Connect(function()
        safecall.call(self._label, self._callback)
    end))

    return self
end

-- A Button has no value. The methods exist anyway, for the same reason
-- Separator's do: a caller must not have to know which widgets have them.
function Button:Get() return nil end
function Button:Set() end
function Button:OnChanged() end
function Button:SetVisible(visible) self._row.frame.Visible = visible end

return M
