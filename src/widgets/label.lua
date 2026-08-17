-- A single line of static text spanning the whole row.
--
-- Deliberately NOT wrappable. A wrapped label under-sizes its parent because
-- height only re-syncs when TextBounds fires, and inside an auto-sizing
-- container that clips the entire section. Two lines means two Labels.

local M = {}

-- Declared for the container: a Label has no control, so the row is built
-- full-width and no control slot is created. A widget must never resize the
-- row itself -- that is layout, and layout belongs to row.lua.
M.FullWidth = true

local Label = {}
Label.__index = Label

function M.new(root, row, opts)
    local theme = root.theme

    row.label.Text = opts.Text or ""
    row.label.TextTruncate = Enum.TextTruncate.AtEnd
    theme:unbind(row.label)
    theme:bind(row.label, "TextColor3", opts.Dim and "TextDim" or "Text")

    return setmetatable({ _row = row }, Label)
end

function Label:Get()
    return self._row.label.Text
end

function Label:Set(text)
    self._row.label.Text = tostring(text)
end

function Label:OnChanged()
    -- A label has no user-driven changes; accepted for contract symmetry.
end

function Label:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
