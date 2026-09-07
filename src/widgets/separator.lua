-- A 1px rule across the row, optionally with inline centred text.

local M = {}

-- No control slot: a separator spans the row. See label.lua for the rationale.
M.FullWidth = true

-- Nothing to persist: a separator has no value.
M.Stateless = true

local Separator = {}
Separator.__index = Separator

function M.new(root, row, opts)
    local theme = root.theme
    local text = opts.Text

    row.label.Text = ""
    row.setHeight(text and 16 or 9)

    local function rule(name)
        local line = Instance.new("Frame")
        line.Name = name
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Position = UDim2.new(0, 0, 0.5, 0)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.BorderSizePixel = 0
        line.Parent = row.frame
        theme:bind(line, "BackgroundColor3", "ContainerBorder")
        return line
    end

    local obj = setmetatable({ _row = row }, Separator)

    if not text then
        rule("line")
        return obj
    end

    -- With text: two short rules either side of a centred caption.
    local left = rule("lineLeft")
    local right = rule("lineRight")

    local caption = Instance.new("TextLabel")
    caption.Name = "caption"
    caption.BackgroundTransparency = 1
    caption.AnchorPoint = Vector2.new(0.5, 0.5)
    caption.Position = UDim2.fromScale(0.5, 0.5)
    caption.Size = UDim2.new(0, 0, 1, 0)
    caption.AutomaticSize = Enum.AutomaticSize.X
    caption.Font = Enum.Font.Ubuntu
    caption.TextSize = 11
    caption.Text = " " .. text .. " "
    caption.ZIndex = 2
    caption.Parent = row.frame
    theme:bind(caption, "TextColor3", "TextDim")

    -- Size the rules once the caption has measured itself. AbsoluteSize is
    -- zero until a render pass has run, so a single deferred measurement is
    -- not enough -- if the row is still zero-width at that moment (e.g. a
    -- whole menu built before anything has rendered), half computes to 0 and
    -- both rules stay invisible forever, since nothing would re-measure.
    -- Instead, measure now and re-measure every time the row's actual width
    -- changes (first render, window resize, page switch), so it self-heals.
    local function measure()
        if not caption.Parent then return end
        local half = math.max(0, (row.frame.AbsoluteSize.X - caption.AbsoluteSize.X) / 2)
        left.Size = UDim2.new(0, half, 0, 1)
        right.Size = UDim2.new(0, half, 0, 1)
        right.AnchorPoint = Vector2.new(1, 0.5)
        right.Position = UDim2.new(1, 0, 0.5, 0)
    end

    measure()
    root:keep(row.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure))

    return obj
end

function Separator:Get() return nil end
function Separator:Set() end
function Separator:OnChanged() end
function Separator:SetVisible(visible) self._row.frame.Visible = visible end

return M
