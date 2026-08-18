-- Keybind: the pure display-name mapping, plus (from the next task) capture,
-- the mode menu, and IsHeld.
--
-- formatKey is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto. That also means NO Enum
-- values at module scope -- the harness has no `Enum` global.

local M = {}

-- The only bindable mouse inputs there are. Roblox delivers no event at all for
-- side buttons 4 and 5, and Enum.KeyCode.MouseBackButton is a dead legacy entry
-- InputBegan never fires. Proven in-game with a logger; see the M3 spec.
local MOUSE = {
    MouseButton1 = "MOUSE1",
    MouseButton2 = "MOUSE2",
    MouseButton3 = "MOUSE3",
}

-- Anything that would overflow the field at 11px, or reads badly upper-cased.
local SHORT = {
    LeftShift = "LSHIFT",   RightShift = "RSHIFT",
    LeftControl = "LCTRL",  RightControl = "RCTRL",
    LeftAlt = "LALT",       RightAlt = "RALT",
    LeftSuper = "LWIN",     RightSuper = "RWIN",
    CapsLock = "CAPS",      Backspace = "BACK",
    Return = "ENTER",       Escape = "ESC",
    Delete = "DEL",         PageUp = "PGUP",
    PageDown = "PGDN",      Space = "SPACE",
}

-- Takes NAMES rather than EnumItems so it can be tested without a Roblox
-- environment. The caller unwraps .Name.
function M.formatKey(inputTypeName, keyCodeName)
    if inputTypeName ~= nil and MOUSE[inputTypeName] ~= nil then
        return MOUSE[inputTypeName]
    end
    if keyCodeName == nil or keyCodeName == "" or keyCodeName == "Unknown" then
        return "NONE"
    end
    if SHORT[keyCodeName] ~= nil then
        return SHORT[keyCodeName]
    end
    return string.upper(keyCodeName)
end

return M
