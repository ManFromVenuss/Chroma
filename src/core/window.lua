-- The window shell: translucent title bar, icon rail, body holding the
-- backdrop, drag, resize, and the open/close animation.
--
-- Layout, from the spec: title bar 24px, 4px gap to the body, rail 28px,
-- backdrop band 20px below where containers will sit.
local Anim = require("core/anim")
local Backdrop = require("core/backdrop")
local Cursor = require("core/cursor")
local Page = require("core/page")
local Popup = require("core/popup")
local Settings = require("core/settings")
local Tooltip = require("core/tooltip")

-- Resolved lazily in M.new: a module-scope game:GetService() runs on require.
local UserInputService

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

    opts = opts or {}
    local size = opts.Size or Vector2.new(640, 420)
    local theme = root.theme

    local self = setmetatable({
        _root = root,
        _theme = theme,
        _fullSize = size,
        _minSize = Vector2.new(MIN_WIDTH, MIN_HEIGHT),
        _layoutListeners = {},
    }, Window)

    -- Frame keeps AnchorPoint (0,0) forever: it is both the drag origin and
    -- the animation origin, so the two can't disagree.
    local viewport = workspace.CurrentCamera.ViewportSize
    -- ViewportSize is screen space; Position is parent (windowLayer) space.
    -- The layer's ScreenGui sets IgnoreGuiInset = true, so the layer's origin
    -- sits `inset` above the screen origin, and layer.AbsolutePosition.Y is
    -- that inset as a negative offset (e.g. -58). Subtracting it cancels the
    -- offset instead of hardcoding a GUI inset that isn't constant across
    -- setups (topbar height varies with platform/device).
    local frame = Instance.new("Frame")
    frame.Name = "window"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(root:toLayerSpace(
        math.floor(viewport.X / 2 - size.X / 2),
        math.floor(viewport.Y / 2 - size.Y / 2), root.windowLayer))
    frame.Size = UDim2.fromOffset(size.X, size.Y)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = root.windowLayer
    self._frame = root:keep(frame)

    -- No stroke on `frame`: its bounds enclose the title bar as well as the
    -- body, so a stroke here would outline the bar too, and the bar is meant
    -- to read as a detached strip defined only by its two gradient hairlines.
    -- The window's outline is the body's own stroke, added below.
    --
    -- A soft glow was tried and removed: Roblox has no real bloom, so it was
    -- stacked UIStrokes, which band into separate rings rather than a falloff.
    -- A genuine glow would need a 9-slice radial sprite as an image asset.

    --== title bar: its own strip, translucent, detached by a gap ==--
    local bar = Instance.new("Frame")
    bar.Name = "titlebar"
    bar.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
    bar.BorderSizePixel = 0
    bar.ZIndex = 20
    bar.Parent = frame
    theme:bind(bar, "BackgroundColor3", "TitleBar", "BackgroundTransparency")
    self._bar = bar

    -- No UIStroke on the bar. The two gradient hairlines below already define
    -- its top and bottom edges; a stroke drew a second, fainter accent line
    -- just beneath the bottom hairline. The bar is a floating strip, so its
    -- unbordered left and right edges read fine -- the body's own stroke is
    -- what outlines the window.

    -- White base colour: a UIGradient multiplies the element's colour, and a
    -- Frame defaults to grey (163,162,165), which would render the gradient
    -- at about 64% intensity.
    local hair = Instance.new("Frame")
    hair.Name = "hairline"
    hair.Size = UDim2.new(1, 0, 0, 2)
    hair.BackgroundColor3 = Color3.new(1, 1, 1)
    hair.BorderSizePixel = 0
    hair.ZIndex = 22
    hair.Parent = bar
    local hairGradient = Instance.new("UIGradient")
    hairGradient.Color = ColorSequence.new(theme:get("HairA"), theme:get("HairB"))
    hairGradient.Parent = hair
    self._hairGradient = hairGradient

    -- Mirrored along the bottom edge for symmetry: without it, the 1px stroke
    -- plus the top hairline made the top read as a bright ~3px band against a
    -- thin 1px bottom, unbalanced on a detached floating strip.
    local hairBottom = Instance.new("Frame")
    hairBottom.Name = "hairlineBottom"
    hairBottom.Size = UDim2.new(1, 0, 0, 2)
    hairBottom.Position = UDim2.new(0, 0, 1, -2)
    hairBottom.BackgroundColor3 = Color3.new(1, 1, 1)
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
    titleText.Size = UDim2.new(1, -16, 1, 0)
    titleText.Position = UDim2.fromOffset(8, 0)
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
    -- Inset by 1px on every side. A UIStroke draws outward from its element's
    -- bounds, and `contents` clips its descendants, so a body filling contents
    -- exactly has its stroke drawn into the clipped region and cut away. The
    -- 1px margin is exactly the stroke's thickness, so it reads as an outline
    -- on the window edge with no visible gap.
    body.Size = UDim2.new(1, -2, 1, -2)
    body.Position = UDim2.fromOffset(1, 1)
    -- Opaque: the backdrop fills it. Translucency here would show the game
    -- world behind the forest.
    body.BackgroundTransparency = 0
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.Parent = contents
    theme:bind(body, "BackgroundColor3", "Body")
    self._body = body

    -- The outline carries the same hue-shifted gradient as the title bar's
    -- hairlines, so the bar and the window read as one piece rather than two
    -- accent colours side by side. A UIGradient parented to a UIStroke tints
    -- the stroke; the stroke's own Color must stay white or it multiplies the
    -- gradient down, so this one is not theme-bound.
    local bodyStroke = Instance.new("UIStroke")
    bodyStroke.Thickness = 1
    bodyStroke.Color = Color3.new(1, 1, 1)
    bodyStroke.Parent = body

    local bodyStrokeGradient = Instance.new("UIGradient")
    bodyStrokeGradient.Color = ColorSequence.new(theme:get("HairA"), theme:get("HairB"))
    bodyStrokeGradient.Parent = bodyStroke
    self._bodyStrokeGradient = bodyStrokeGradient

    self._backdrop = Backdrop.new(root, body, opts.Backdrop)

    local rail = Instance.new("Frame")
    rail.Name = "rail"
    rail.Size = UDim2.new(0, RAIL_WIDTH, 1, 0)
    rail.BorderSizePixel = 0
    rail.ZIndex = 5
    rail.Parent = body
    theme:bind(rail, "BackgroundColor3", "Rail", "BackgroundTransparency")
    self._rail = rail

    local railLayout = Instance.new("UIListLayout")
    railLayout.FillDirection = Enum.FillDirection.Vertical
    railLayout.SortOrder = Enum.SortOrder.LayoutOrder
    railLayout.Padding = UDim.new(0, 2)
    railLayout.Parent = rail

    local railPad = Instance.new("UIPadding")
    railPad.PaddingTop = UDim.new(0, 6)
    railPad.Parent = rail

    -- A bottom strip for pinned entries, a sibling of the rail rather than a
    -- child of it: a UIListLayout arranges every child of its parent, so
    -- parenting this to the rail made the list lay it out as an ordinary item
    -- and the gear appeared at the top. Anchored over the rail's own
    -- footprint instead, it sits outside that layout's reach.
    --
    -- The footprint is shared implicitly: this lines up with the rail only
    -- because the rail sits at (0, 0) and spans the body's full height. Give
    -- the rail an offset and this drifts silently.
    local railBottom = Instance.new("Frame")
    railBottom.Name = "railBottom"
    railBottom.AnchorPoint = Vector2.new(0, 1)
    railBottom.Position = UDim2.new(0, 0, 1, 0)
    railBottom.Size = UDim2.fromOffset(RAIL_WIDTH, 36)
    railBottom.BackgroundTransparency = 1
    railBottom.BorderSizePixel = 0
    railBottom.ZIndex = 6
    railBottom.Parent = body
    self._railBottom = railBottom

    local railBottomLayout = Instance.new("UIListLayout")
    railBottomLayout.FillDirection = Enum.FillDirection.Vertical
    railBottomLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    railBottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    railBottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
    railBottomLayout.Padding = UDim.new(0, 5)
    railBottomLayout.Parent = railBottom

    -- A UIListLayout arranges every child, so the rule is part of the list
    -- rather than positioned over it -- the same trap that made the sub-tab
    -- rule eat its whole row in M2. LayoutOrder 0 puts it above the pinned
    -- buttons, separating it visually from the pages.
    local railRule = Instance.new("Frame")
    railRule.Name = "rule"
    railRule.Size = UDim2.new(1, -12, 0, 1)
    railRule.BorderSizePixel = 0
    railRule.LayoutOrder = 0
    railRule.ZIndex = 6
    railRule.Parent = railBottom
    theme:bind(railRule, "BackgroundColor3", "ContainerBorder")

    -- Everything right of the rail. Pages fill this and show one at a time.
    local pageArea = Instance.new("Frame")
    pageArea.Name = "pages"
    pageArea.Position = UDim2.fromOffset(RAIL_WIDTH, 0)
    pageArea.Size = UDim2.new(1, -RAIL_WIDTH, 1, 0)
    pageArea.BackgroundTransparency = 1
    pageArea.BorderSizePixel = 0
    pageArea.Parent = body
    self._pageArea = pageArea

    self._pages = {}
    self._activePage = nil

    -- The tooltip and popup managers are owned by the window and reached
    -- through root, so row.lua and every widget can use them without being
    -- handed one.
    root.tooltip = Tooltip.new(root)
    root.popup = Popup.new(root)
    root.popup:bindDismissal(self)

    --== drag and resize ==--
    self:_makeDragHandle(bar, function(delta, start)
        frame.Position = UDim2.fromOffset(start.X + delta.X, start.Y + delta.Y)
        self:_layoutChanged()
    end, function()
        -- Same space mismatch as above: reading AbsolutePosition here but
        -- writing Position teleported the window by the GUI inset on every
        -- mouse-down. Read from the same space that gets written to.
        return Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
    end)

    -- The grip is an L outline hugging the corner rather than a filled square:
    -- the TextButton keeps its size, position and drag wiring as the hit area
    -- but is fully transparent, and two thin accent bars drawn on top of it
    -- form the visible corner.
    local grip = Instance.new("TextButton")
    grip.Name = "grip"
    grip.Size = UDim2.fromOffset(12, 12)
    grip.Position = UDim2.new(1, -13, 1, -13)
    grip.BackgroundTransparency = 1
    grip.BorderSizePixel = 0
    grip.Text = ""
    grip.AutoButtonColor = false
    grip.ZIndex = 30
    grip.Parent = contents

    local gripBottom = Instance.new("Frame")
    gripBottom.Name = "gripBottom"
    gripBottom.Size = UDim2.new(1, 0, 0, 2)
    gripBottom.Position = UDim2.new(0, 0, 1, -2)
    gripBottom.BackgroundTransparency = 0.35
    gripBottom.BorderSizePixel = 0
    gripBottom.ZIndex = 30
    gripBottom.Parent = grip
    theme:bind(gripBottom, "BackgroundColor3", "Accent")

    local gripRight = Instance.new("Frame")
    gripRight.Name = "gripRight"
    gripRight.Size = UDim2.new(0, 2, 1, 0)
    gripRight.Position = UDim2.new(1, -2, 0, 0)
    gripRight.BackgroundTransparency = 0.35
    gripRight.BorderSizePixel = 0
    gripRight.ZIndex = 30
    gripRight.Parent = grip
    theme:bind(gripRight, "BackgroundColor3", "Accent")

    self:_makeDragHandle(grip, function(delta, start)
        -- Read the viewport at drag time, not construction: the player may
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
        local mx, my = root:mouseInGuiSpace()
        local origin, extent = frame.AbsolutePosition, frame.AbsoluteSize
        return Cursor.hitTest(mx, my, origin.X, origin.Y, extent.X, extent.Y)
    end)

    --== toggle key ==--
    -- gameProcessedEvent is ignored by default: games sink keys, and O is
    -- sunk in one of the target games. RespectGameProcessed opts into that.
    self._toggleKey = opts.ToggleKey or Enum.KeyCode.Insert
    local respect = opts.RespectGameProcessed == true
    root:keep(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if respect and gameProcessed then return end
        -- A Keybind capture owns the keyboard while it is open, or binding
        -- the toggle key would bind it and close the menu in one press.
        if root.capturing then return end
        local key = self._toggleKey
        if key == nil then return end
        if key.EnumType == Enum.UserInputType then
            if input.UserInputType == key then self:toggle() end
        elseif input.KeyCode == key then
            self:toggle()
        end
    end))

    -- Only one root:onFrame handler is allowed (Root:onFrame asserts on a
    -- second registration), so all per-frame window work lives here.
    root:onFrame(function(dt)
        self._backdrop:step(dt)
        local hairColor = ColorSequence.new(
            self._theme:get("HairA"), self._theme:get("HairB"))
        self._hairGradient.Color = hairColor
        self._hairGradientBottom.Color = hairColor
        self._bodyStrokeGradient.Color = hairColor
    end)

    -- Built before any consumer page exists; fine, because a pinned page
    -- never auto-activates. Opting out is one flag rather than a separate
    -- constructor, since a consumer who doesn't want it is the rare case.
    if opts.Settings ~= false then
        self._settingsPage = Settings.build(root, self)
    end

    self:setSize(size.X, size.Y)
    self._anim:_snap(false)
    self:open()

    return self
end

-- Anything that reflows or replaces the view. The popup manager is the only
-- subscriber today; a list means the next one doesn't have to rewrite this.
function Window:onLayoutChanged(fn)
    table.insert(self._layoutListeners, fn)
end

function Window:_layoutChanged()
    for i = 1, #self._layoutListeners do
        self._layoutListeners[i]()
    end
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

    -- Column widths are explicit pixels, so they must be recomputed whenever
    -- the window changes size.
    if self._pages then
        for i = 1, #self._pages do
            self._pages[i]:relayout()
        end
    end
    self:_layoutChanged()
end

function Window:Page(opts)
    local page = Page.new(self._root, self, opts or {})
    table.insert(self._pages, page)
    -- A pinned page must never become the default view. The settings page is
    -- built before any consumer page exists, so plain "first page wins" would
    -- open the menu on Settings every time.
    if not self._activePage and not page.pinned then
        self:setActivePage(page)
    else
        page:setActive(page == self._activePage)
    end
    return page
end

function Window:setActivePage(page)
    self._activePage = page
    for i = 1, #self._pages do
        self._pages[i]:setActive(self._pages[i] == page)
    end
    page:relayout()
    self:_layoutChanged()
end

function Window:getActivePage()
    return self._activePage
end

function Window:open()
    self._backdrop:setPaused(false)
    self._anim:open(self._animate)
    UserInputService.ModalEnabled = true
end

function Window:close()
    self:_layoutChanged()
    self._anim:close(self._animate)
    UserInputService.ModalEnabled = false
    -- Stars keep no state worth preserving, so pausing while hidden is free.
    -- +0.01 is a one-frame margin so the pause lands just after the final
    -- tween completes rather than racing it.
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

-- Accepts a KeyCode, a bindable UserInputType, or nil for no toggle at all.
-- The settings page's Keybind writes here.
function Window:setToggleKey(key)
    self._toggleKey = key
end

function Window:setAnimations(on)
    self._animate = on ~= false
end

function Window:setGradient(enabled)
    self._theme:setGradient(enabled)
    self._theme:apply()
end

function Window:setAccentSpeed(speed)
    self._theme:setAccentSpeed(speed)
    self._theme:apply()
end

function Window:setCursor(opts)
    self._cursor:setConfig(opts)
end

function Window:setParticleCount(count)
    self._backdrop:setCount(count)
end

M.Window = Window
return M
