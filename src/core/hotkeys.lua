-- Hotkeys: pure formatRow that produces a display string per opted-in Keybind,
-- plus (from the next task) the overlay panel.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Always-mode reads as permanently active regardless of a bind. Any other mode
-- shows its key label -- which is "NONE" when the bind is unset (from
-- Keybind.formatKey).
function M.formatRow(name, mode, keyLabel)
    if mode == "Always" then
        return "[always] " .. tostring(name)
    end
    return "[" .. tostring(keyLabel) .. "] " .. tostring(name)
end

return M
