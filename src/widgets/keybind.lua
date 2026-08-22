-- Keybind: the pure display-name mapping, plus capture, the mode menu, and
-- IsHeld.
--
-- formatKey is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto. That also means no Enum
-- values at module scope -- the harness has no `Enum` global.

local M = {}

-- The only bindable mouse inputs there are. Roblox delivers no event at all for
-- side buttons 4 and 5, and Enum.KeyCode.MouseBackButton is a dead legacy entry
-- InputBegan never fires. Proven in-game with a logger.
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

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local Field = require("core/field")
local safecall = require("util/safecall")

-- Resolved lazily: a module-scope game:GetService() executes on require, and
-- the harness requires this file to reach formatKey.
local UserInputService

local Keybind = {}
Keybind.__index = Keybind

local MODES = { "Always", "Hold", "Toggle" }
local MODE_WIDTH = 72
local MODE_HEIGHT = 16

local function isMouseBind(bind)
    return typeof(bind) == "EnumItem" and bind.EnumType == Enum.UserInputType
end

local function describe(bind)
    if bind == nil then return M.formatKey(nil, nil) end
    if isMouseBind(bind) then return M.formatKey(bind.Name, nil) end
    return M.formatKey(nil, bind.Name)
end

function M.new(root, row, opts)
    UserInputService = UserInputService or game:GetService("UserInputService")

    local theme = root.theme
    local field = Field.new(root, row.control, {})
    -- Right-aligned: a keybind is read as a value, like the slider's number,
    -- not as a caption.
    field.label.TextXAlignment = Enum.TextXAlignment.Right
    field.label.Size = UDim2.new(1, -8, 1, 0)

    --== the right-click mode menu, in the popup layer ==--
    local menu = Instance.new("Frame")
    menu.Name = "keybindModes"
    menu.Size = UDim2.fromOffset(MODE_WIDTH, MODE_HEIGHT * #MODES)
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ZIndex = 10
    menu.Parent = root.popupLayer
    root:keep(menu)
    theme:bind(menu, "BackgroundColor3", "Window")

    local menuStroke = Instance.new("UIStroke")
    menuStroke.Thickness = 1
    menuStroke.Parent = menu
    theme:bind(menuStroke, "Color", "Accent")

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.FillDirection = Enum.FillDirection.Vertical
    menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    menuLayout.Parent = menu

    local self = setmetatable({
        _root = root,
        _row = row,
        _theme = theme,
        _field = field,
        _menu = menu,
        _modeButtons = {},
        _bind = nil,
        _mode = "Always",
        _down = false,
        _toggled = false,
        _capturing = false,
        _label = opts.Name or "Keybind",
        _callback = opts.Callback,
        _listeners = {},
    }, Keybind)

    for i = 1, #MODES do
        local mode = MODES[i]
        local button = Instance.new("TextButton")
        button.Name = "mode_" .. mode
        button.Size = UDim2.new(1, 0, 0, MODE_HEIGHT)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Font = Enum.Font.Ubuntu
        button.TextSize = 11
        button.Text = mode
        button.AutoButtonColor = false
        button.LayoutOrder = i
        button.ZIndex = 11
        button.Parent = menu

        self._modeButtons[mode] = button

        root:keep(button.Activated:Connect(function()
            self:SetMode(mode)
            root.popup:close()
        end))
    end

    -- Activated fires on button release, and that matters: starting capture from
    -- InputBegan would let the very same MouseButton1 press reach the capture
    -- handler below and instantly bind MOUSE1.
    -- Binding a mouse button on the field consumes the press down in _capture,
    -- but its release still arrives as a click event on the field -- Activated
    -- for button 1, MouseButton2Click for button 2. Unguarded, binding MOUSE1
    -- flashed the bind and went straight back to listening, and binding MOUSE2
    -- popped the mode menu open. One press produces only one of the two events,
    -- so a single one-shot flag shared by both handlers is enough.
    local function swallowed()
        if self._swallowActivated then
            self._swallowActivated = false
            return true
        end
        return false
    end

    root:keep(field.frame.Activated:Connect(function()
        if swallowed() then return end
        self:_beginCapture()
    end))

    root:keep(field.frame.MouseButton2Click:Connect(function()
        if swallowed() then return end
        self:_openModeMenu()
    end))

    -- One InputBegan connection serving both capture and hold/toggle tracking.
    root:keep(UserInputService.InputBegan:Connect(function(input)
        if self._capturing then
            self:_capture(input)
            return
        end
        if not self:_matches(input) then return end
        self._down = true
        if self._mode == "Toggle" then
            self._toggled = not self._toggled
        end
    end))

    root:keep(UserInputService.InputEnded:Connect(function(input)
        if self:_matches(input) then
            self._down = false
        end
    end))

    self:SetMode(opts.Mode or "Always")
    self:Set(opts.Default, true)
    return self
end

function Keybind:_matches(input)
    local bind = self._bind
    if bind == nil then return false end
    if isMouseBind(bind) then
        return input.UserInputType == bind
    end
    return input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == bind
end

function Keybind:_beginCapture()
    if self._capturing then return end
    self._capturing = true
    -- A global lock, not just a local flag: the window's toggle handler reads
    -- it. Without this, binding the menu's own toggle key would bind the key
    -- and close the menu in one press. The same applies to any key the game
    -- sinks, since the toggle deliberately ignores gameProcessedEvent.
    self._root.capturing = true
    self._field.setActive(true)
    self._field.label.Text = "..."
end

function Keybind:_endCapture()
    self._capturing = false
    self._field.setActive(false)
    self:_paint()
    -- Release the global lock a frame later. The window's toggle handler is a
    -- separate InputBegan connection and Roblox guarantees no ordering between
    -- them, so clearing it inside the same event could still let the key that
    -- was just bound close the menu.
    task.defer(function()
        if not self._root:isAlive() then return end
        self._root.capturing = false
    end)
end

function Keybind:_capture(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Escape then
            self:Set(nil)   -- Escape clears the bind
        else
            self:Set(input.KeyCode)
        end
        self:_endCapture()
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.MouseButton3 then
        -- A mouse button binds only when the click lands ON the field. Anywhere
        -- else is "click away to cancel", which is the other half of the spec
        -- and would otherwise be unreachable for MOUSE1.
        local mx, my = self._root:mouseInGuiSpace()
        local p, s = self._field.frame.AbsolutePosition, self._field.frame.AbsoluteSize
        if mx >= p.X and mx <= p.X + s.X and my >= p.Y and my <= p.Y + s.Y then
            self:Set(input.UserInputType)
            -- This press will still deliver an Activated on release; that must
            -- not restart capture. See the Activated handler in M.new.
            self._swallowActivated = true
        end
        self:_endCapture()
        return
    end

    -- Anything else -- a wheel tick, a gamepad button, a touch -- matches
    -- neither branch above. Treat it as a cancel rather than falling through:
    -- an unhandled input type must not be able to leave _capturing (and the
    -- global root.capturing lock the window's toggle handler reads) stuck on,
    -- since that failure is silent and takes out the toggle key for the rest
    -- of the session. InputBegan never fires for mouse movement (that's
    -- InputChanged), so this cannot cancel capture on a pointer twitch.
    self:_endCapture()
end

function Keybind:_openModeMenu()
    local popup = self._root.popup
    if popup:isOpen(self) then
        popup:close()
        return
    end
    self:_paintModes()
    popup:open(self, self._menu, self._field.frame)
end

function Keybind:_paintModes()
    for i = 1, #MODES do
        local mode = MODES[i]
        local button = self._modeButtons[mode]
        self._theme:unbind(button)
        if mode == self._mode then
            self._theme:bind(button, "BackgroundColor3", "Selection", "BackgroundTransparency")
            self._theme:bind(button, "TextColor3", "Accent")
        else
            button.BackgroundTransparency = 1
            self._theme:bind(button, "TextColor3", "Text")
        end
    end
end

function Keybind:_paint()
    self._field.label.Text = describe(self._bind)
    self._theme:unbind(self._field.label)
    self._theme:bind(self._field.label, "TextColor3",
        self._bind == nil and "TextDim" or "Text")
end

function Keybind:_fire()
    safecall.call(self._label, self._callback, self._bind, self._mode)
    for i = 1, #self._listeners do
        safecall.call(self._label, self._listeners[i], self._bind, self._mode)
    end
end

function Keybind:Get()
    return self._bind
end

function Keybind:Set(bind, silent)
    local changed = bind ~= self._bind
    self._bind = bind
    -- A cleared or replaced bind must not leave a Hold reading as held or a
    -- Toggle latched on.
    self._down = false
    self._toggled = false
    self:_paint()
    if silent or not changed then return end
    self:_fire()
end

function Keybind:GetMode()
    return self._mode
end

function Keybind:SetMode(mode)
    if mode ~= "Always" and mode ~= "Hold" and mode ~= "Toggle" then
        error("chroma: keybind Mode must be Always, Hold or Toggle, got "
            .. tostring(mode), 2)
    end
    self._mode = mode
    self._toggled = false
    self:_paintModes()
end

-- The extension to the shared four-method contract, and the only one in the
-- library. A consumer's aimbot reads this every frame, not Get.
function Keybind:IsHeld()
    if self._bind == nil then return false end
    if self._mode == "Always" then return true end
    if self._mode == "Toggle" then return self._toggled end
    return self._down
end

-- Get() returns only the bind, but the mode is state as well, so the config
-- manager takes both through Save/Load rather than widening the shared contract
-- for the two widgets that need it.
function Keybind:Save()
    return { bind = self._bind, mode = self._mode }
end

function Keybind:Load(t)
    if type(t) ~= "table" then return end
    if t.mode ~= nil then self:SetMode(t.mode) end
    self:Set(t.bind)
end

function Keybind:OnChanged(fn)
    table.insert(self._listeners, fn)
end

function Keybind:SetVisible(visible)
    self._row.frame.Visible = visible
end

return M
