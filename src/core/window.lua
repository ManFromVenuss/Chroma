-- The window shell: separate translucent title bar, icon rail, body holding the
-- backdrop, drag, resize, and the open/close animation.
--
-- Layout, from the spec: title bar 24px, 4px gap to the body, rail 28px,
-- backdrop band 20px below where containers will sit.
local Anim = require("core/anim")
local Backdrop = require("core/backdrop")
local Cursor = require("core/cursor")

-- Resolved lazily in M.new: a module-scope game:GetService() executes on require.
local UserInputService
local GuiService

local M = {}

local Window = {}
Window.__index = Window

local BAR_HEIGHT = 24
local BAR_GAP = 4
local RAIL_WIDTH = 28
local MIN_WIDTH = 240
local MIN_HEIGHT = 190

function M.new(root, opts)
    UserInputService = UserInputService or game:GetService("UserInputService")
    GuiService = GuiService or game:GetService("GuiService")

    opts = opts or {}
    local size = opts.Size or Vector2.new(640, 420)
    local theme = root.theme

    local self = setmetatable({
        _root = root,
        _theme = theme,
        _fullSize = size,
        _minSize = Vector2.new(MIN_WIDTH, MIN_HEIGHT),
    }, Window)

    -- Frame keeps AnchorPoint (0,0) forever: it is the drag origin AND the
    -- animation origin, so the two can never disagree.
    local viewport = workspace.CurrentCamera.ViewportSize
    -- ViewportSize is screen space; Position is parent (windowLayer) space.
    -- The layer's ScreenGui sets IgnoreGuiInset = true, so the layer's origin
    -- sits `inset` above the screen origin, and layer.AbsolutePosition.Y is
    -- that inset as a negative offset (e.g. -58). Subtracting it here cancels
    -- the offset instead of hardcoding a GUI inset that isn't constant across
    -- setups (topbar height varies with platform/device).
    local layerOffset = root.windowLayer.AbsolutePosition
    local frame = Instance.new("Frame")
    frame.Name = "window"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(
        math.floor(viewport.X / 2 - size.X / 2 - layerOffset.X),
        math.floor(viewport.Y / 2 - size.Y / 2 - layerOffset.Y))
    frame.Size = UDim2.fromOffset(size.X, size.Y)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = root.windowLayer
    self._frame = root:keep(frame)

    --== title bar: its own strip, translucent, detached by a gap ==--
    local bar = Instance.new("Frame")
    bar.Name = "titlebar"
    bar.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
    bar.BorderSizePixel = 0
    bar.ZIndex = 20
    bar.Parent = frame
    theme:bind(bar, "BackgroundColor3", "TitleBar", "BackgroundTransparency")
    self._bar = bar

    local barStroke = Instance.new("UIStroke")
    barStroke.Transparency = 0.45
    barStroke.Thickness = 1
    barStroke.Parent = bar
    theme:bind(barStroke, "Color", "Accent")

    local hair = Instance.new("Frame")
    hair.Name = "hairline"
    hair.Size = UDim2.new(1, 0, 0, 2)
    hair.BorderSizePixel = 0
    hair.ZIndex = 22
    hair.Parent = bar
    local hairGradient = Instance.new("UIGradient")
    hairGradient.Color = ColorSequence.new(theme:get("HairA"), theme:get("HairB"))
    hairGradient.Parent = hair
    self._hairGradient = hairGradient

    -- Mirrored along the bottom edge so the bar reads symmetrically: without
    -- this the 1px stroke plus the top hairline made the top read as a bright
    -- ~3px band against a thin 1px bottom, which looked unbalanced on a
    -- detached floating strip.
    local hairBottom = Instance.new("Frame")
    hairBottom.Name = "hairlineBottom"
    hairBottom.Size = UDim2.new(1, 0, 0, 2)
    hairBottom.Position = UDim2.new(0, 0, 1, -2)
    hairBottom.BorderSizePixel = 0
    hairBottom.ZIndex = 22
    hairBottom.Parent = bar
    local hairGradientBottom = Instance.new("UIGradient")
    hairGradientBottom.Color = ColorSequence.new(theme:get("HairA"), theme:get("HairB"))
    hairGradientBottom.Parent = hairBottom
    self._hairGradientBottom = hairGradientBottom

    local titleText = Instance.new("TextLabel")
    titleText.Name = "title"
    titleText.BackgroundTransparency = 1
    titleText.Size = UDim2.new(1, -16, 1, -2)
    titleText.Position = UDim2.fromOffset(8, 2)
    titleText.Font = Enum.Font.Ubuntu
    titleText.TextSize = 12
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Text = opts.Name or "Chroma"
    titleText.ZIndex = 21
    titleText.Parent = bar
    theme:bind(titleText, "TextColor3", "TextBright")

    --== contents: everything that slides in from the left ==--
    local contents = Instance.new("Frame")
    contents.Name = "contents"
    contents.Position = UDim2.fromOffset(0, BAR_HEIGHT + BAR_GAP)
    contents.Size = UDim2.new(1, 0, 1, -(BAR_HEIGHT + BAR_GAP))
    contents.BackgroundTransparency = 1
    contents.BorderSizePixel = 0
    contents.ClipsDescendants = true
    contents.ZIndex = 2
    contents.Parent = frame
    self._contents = contents

    local body = Instance.new("Frame")
    body.Name = "body"
    body.Size = UDim2.fromScale(1, 1)
    -- Opaque: the backdrop fills it. Translucency here would show the game world
    -- behind the forest, which reads as a bug.
    body.BackgroundTransparency = 0
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.Parent = contents
    theme:bind(body, "BackgroundColor3", "Body")
    self._body = body

    local bodyStroke = Instance.new("UIStroke")
    bodyStroke.Thickness = 1
    bodyStroke.Parent = body
    theme:bind(bodyStroke, "Color", "Accent")

    self._backdrop = Backdrop.new(root, body, opts.Backdrop)

    local rail = Instance.new("Frame")
    rail.Name = "rail"
    rail.Size = UDim2.new(0, RAIL_WIDTH, 1, 0)
    rail.BorderSizePixel = 0
    rail.ZIndex = 5
    rail.Parent = body
    theme:bind(rail, "BackgroundColor3", "Rail", "BackgroundTransparency")
    self._rail = rail

    --== drag and resize ==--
    self:_makeDragHandle(bar, function(delta, start)
        frame.Position = UDim2.fromOffset(start.X + delta.X, start.Y + delta.Y)
    end, function()
        -- AbsolutePosition is screen space; Position is parent space. With
        -- IgnoreGuiInset = true the window layer sits `inset` above the
        -- screen origin, so those two spaces differ by the GUI inset. Reading
        -- AbsolutePosition here but writing Position above teleported the
        -- window by the inset on every mouse-down. Read from the same space
        -- we write to instead.
        return Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
    end)

    local grip = Instance.new("TextButton")
    grip.Name = "grip"
    grip.Size = UDim2.fromOffset(12, 12)
    grip.Position = UDim2.new(1, -13, 1, -13)
    grip.BackgroundTransparency = 0.35
    grip.BorderSizePixel = 0
    grip.Text = ""
    grip.AutoButtonColor = false
    grip.ZIndex = 30
    grip.Parent = contents
    theme:bind(grip, "BackgroundColor3", "Accent")

    self:_makeDragHandle(grip, function(delta, start)
        -- Read the viewport at drag time, not at construction: the player may
        -- resize or fullscreen the Roblox window mid-session.
        local liveViewport = workspace.CurrentCamera.ViewportSize
        local maxW = math.max(self._minSize.X, liveViewport.X)
        local maxH = math.max(self._minSize.Y, liveViewport.Y)
        self:setSize(
            math.clamp(start.X + delta.X, self._minSize.X, maxW),
            math.clamp(start.Y + delta.Y, self._minSize.Y, maxH))
    end, function() return frame.AbsoluteSize end)

    --== animation ==--
    self._anim = Anim.new(root, {
        frame = frame,
        contents = contents,
        barHeight = BAR_HEIGHT,
        fullSize = function() return self._fullSize end,
    })
    self._animate = opts.Animations ~= false

    --== cursor ==--
    self._cursor = Cursor.new(root, opts.Cursor, function()
        if not self._anim:isOpen() then return false end
        local pos = UserInputService:GetMouseLocation()
        -- GetMouseLocation() is true-screen space, but AbsolutePosition is
        -- measured below the GUI inset (the window layer's ScreenGui sets
        -- IgnoreGuiInset = true, so AbsolutePosition sits `inset` above the
        -- screen origin). Comparing them raw offsets the hit rect vertically
        -- by the inset height (cross stays active above the top edge, dies
        -- early at the bottom). Add the inset back to shift the rect into
        -- the mouse's space. Read it every call, not once: it changes when
        -- the topbar is hidden, on fullscreen toggles, and across devices.
        local inset = GuiService:GetGuiInset()
        local origin = frame.AbsolutePosition + inset
        local extent = frame.AbsoluteSize
        return Cursor.hitTest(pos.X, pos.Y, origin.X, origin.Y, extent.X, extent.Y)
    end)

    --== toggle key ==--
    -- gameProcessedEvent is IGNORED by default: games sink keys, and O is sunk
    -- in one of the target games. RespectGameProcessed opts into politeness.
    local toggleKey = opts.ToggleKey or Enum.KeyCode.Insert
    local respect = opts.RespectGameProcessed == true
    root:keep(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if respect and gameProcessed then return end
        if input.KeyCode == toggleKey then
            self:toggle()
        end
    end))

    root:onFrame(function(dt)
        self._backdrop:step(dt)
        local hairColor = ColorSequence.new(
            self._theme:get("HairA"), self._theme:get("HairB"))
        self._hairGradient.Color = hairColor
        self._hairGradientBottom.Color = hairColor
    end)

    self:setSize(size.X, size.Y)
    self._anim:_snap(false)
    self:open()

    return self
end

function Window:_makeDragHandle(handle, onMove, readStart)
    local dragging, startMouse, startValue = false, nil, nil

    self._root:keep(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startMouse = UserInputService:GetMouseLocation()
            startValue = readStart()
        end
    end))

    self._root:keep(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            onMove(UserInputService:GetMouseLocation() - startMouse, startValue)
        end
    end))

    self._root:keep(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

function Window:setSize(width, height)
    self._fullSize = Vector2.new(width, height)
    if self._anim:isOpen() then
        self._frame.Size = UDim2.fromOffset(width, height)
    end
    self._backdrop:resize(width, height - (BAR_HEIGHT + BAR_GAP))
end

function Window:open()
    self._backdrop:setPaused(false)
    self._anim:open(self._animate)
    UserInputService.ModalEnabled = true
end

function Window:close()
    self._anim:close(self._animate)
    UserInputService.ModalEnabled = false
    -- Stars keep no state worth preserving, so pausing while hidden is free.
    -- +0.01 is a deliberate one-frame margin so the pause lands just after the
    -- final tween completes rather than racing it.
    task.delay(Anim.closeDuration() + 0.01, function()
        if not self._root:isAlive() then return end
        if not self._anim:isOpen() then
            self._backdrop:setPaused(true)
        end
    end)
end

function Window:toggle()
    if self._anim:isOpen() then
        self:close()
    else
        self:open()
    end
end

function Window:isOpen()
    return self._anim:isOpen()
end

function Window:setAccent(accent)
    self._theme:setAccent(accent)
    self._theme:apply()
end

M.Window = Window
return M
