-- A column: the pure width-distribution maths, plus the ScrollingFrame that
-- holds containers.
--
-- widths() is the only place a size is computed by hand. Everything else is
-- AutomaticSize / AutomaticCanvasSize, because UIListLayout cannot express
-- ratios but can do everything else.
--
-- Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops, no goto.

local M = {}

-- Distributes totalWidth across #weights columns separated by `gap` pixels.
-- The final column takes whatever integer pixels are left over, so the columns
-- always sum exactly to the available space rather than leaving a 1px seam.
function M.widths(weights, totalWidth, gap)
    local n = #weights
    if n == 0 then return {} end

    gap = gap or 0
    local space = totalWidth - gap * (n - 1)
    if space < 0 then space = 0 end

    local total = 0
    for i = 1, n do
        local w = weights[i]
        if type(w) == "number" and w > 0 then total = total + w end
    end

    local out = {}
    if total <= 0 then
        -- Every weight was zero or invalid: fall back to an even split rather
        -- than dividing by zero.
        for i = 1, n do out[i] = 1 end
        total = n
        weights = out
        out = {}
    end

    local used = 0
    for i = 1, n - 1 do
        local w = weights[i]
        if type(w) ~= "number" or w <= 0 then w = 0 end
        local px = math.floor(space * w / total)
        out[i] = px
        used = used + px
    end
    out[n] = space - used
    if out[n] < 0 then out[n] = 0 end
    return out
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local Container = require("core/container")

local Column = {}
Column.__index = Column

function M.new(root, parent, opts)
    opts = opts or {}
    local theme = root.theme

    local frame = Instance.new("ScrollingFrame")
    frame.Name = "column"
    frame.Size = UDim2.new(0, 0, 1, 0)   -- width assigned by the owning tab
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.CanvasSize = UDim2.new()
    -- The property is AutomaticCanvasSize, but its type is Enum.AutomaticSize.
    -- There is no Enum.AutomaticCanvasSize.
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollBarThickness = 2
    frame.ScrollingDirection = Enum.ScrollingDirection.Y
    frame.ElasticBehavior = Enum.ElasticBehavior.Never
    frame.Parent = parent
    root:keep(frame)
    theme:bind(frame, "ScrollBarImageColor3", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame

    return setmetatable({
        _root = root,
        _order = 0,
        frame = frame,
        weight = opts.Weight or 1,
    }, Column)
end

function Column:Container(title)
    self._order = self._order + 1
    local container = Container.new(self._root, self.frame, title)
    container.holder.LayoutOrder = self._order
    return container
end

function Column:setWidth(px)
    self.frame.Size = UDim2.new(0, px, 1, 0)
end

return M
