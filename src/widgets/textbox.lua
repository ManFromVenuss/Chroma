-- A click-to-edit text field in the control slot.
--
-- Non-editable until clicked, then selects its whole contents: the proven
-- pattern from the slider's value field, where nothing moves between the two
-- states and typing replaces rather than appends.

local Field = require("core/field")
local safecall = require("util/safecall")

local M = {}

local TextBox = {}
TextBox.__index = TextBox

function M.new(root, row, opts)
    local field = Field.new(root, row.control, {
        Editable = true,
        Placeholder = opts.Placeholder,
    })
    local box = field.label

    local self = setmetatable({
        _root = root,
        _row = row,
        _field = field,
        _box = box,
        _numeric = opts.Numeric == true,
        _value = "",
        _editing = false,
        _editStart = "",
        _label = opts.Name or "TextBox",
        _callback = opts.Callback,
        _listeners = {},
    }, TextBox)

    root:keep(field.frame.Activated:Connect(function()
        if self._editing then return end
        self._editing = true
        -- Captured so FocusLost can restore it explicitly on Escape, rather
        -- than trusting Roblox to have already put it back in box.Text.
        self._editStart = self._value
        box.TextEditable = true
        field.setActive(true)
        box:CaptureFocus()
        -- Select everything: the common case is replacing the value, not
        -- editing one character of it.
        box.CursorPosition = #box.Text + 1
        box.SelectionStart = 1
    end))

    root:keep(box.FocusLost:Connect(function(enterPressed, inputThatCausedFocusLoss)
        self._editing = false
        box.TextEditable = false
        field.setActive(false)

        -- Whether Roblox restores the pre-edit text on Escape is not
        -- documented and not something to bet a revert on -- if it doesn't,
        -- this would silently COMMIT the edit instead, the opposite of the
        -- spec. Escape is therefore handled explicitly using the value
        -- captured when editing began. inputThatCausedFocusLoss may be nil
        -- (e.g. focus lost by clicking elsewhere), so it is guarded before
        -- indexing.
        if inputThatCausedFocusLoss ~= nil
            and inputThatCausedFocusLoss.KeyCode == Enum.KeyCode.Escape then
            box.Text = self._editStart
            return
        end

        local text = box.Text
        if self._numeric and tonumber(text) == nil then
            -- Rejected on COMMIT rather than by filtering keystrokes: filtering
            -- fights paste and IME, and a half-typed "-" or "1e" is legitimate
            -- mid-edit. Unparseable input is user error at runtime, so it
            -- reverts silently rather than erroring.
            box.Text = self._value
            return
        end
        self:Set(text)
    end))

    self:Set(opts.Default or "", true)
    return self
end

-- A number when Numeric is set -- that is what the flag is for -- and the raw
-- string otherwise.
function TextBox:Get()
    if self._numeric then return tonumber(self._value) end
    return self._value
end

function TextBox:Set(value, silent)
    local text = tostring(value)
    local changed = text ~= self._value
    self._value = text
    -- Leave the text alone mid-edit, or a programmatic Set would overwrite what
    -- is being typed.
    if not self._editing then
        self._box.Text = text
    end
    if silent or not changed then return end
    local out = self:Get()
    safecall.call(self._label, self._callback, out)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], out)
    end
end

function TextBox:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function TextBox:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
