-- A page: one rail button, an optional sub-tab row, and one or more tabs, each
-- holding columns.
--
-- There is no tab.lua on purpose. A tab is a named list of columns and this
-- file already owns switching between them; a file existing to hold one table
-- is a boundary that costs more than it earns.

local Column = require("core/column")

local M = {}

local Page = {}
Page.__index = Page

local Tab = {}
Tab.__index = Tab

local SUBTAB_HEIGHT = 24
local COLUMN_GAP = 8
local PADDING = 8

--== Tab ==--

function Tab.new(root, page, name)
    local holder = Instance.new("Frame")
    holder.Name = "tab_" .. name
    holder.Size = UDim2.fromScale(1, 1)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Visible = false
    holder.Parent = page._columnArea
    root:keep(holder)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, COLUMN_GAP)
    layout.Parent = holder

    local self = setmetatable({
        _root = root,
        _page = page,
        _columns = {},
        name = name,
        holder = holder,
    }, Tab)

    -- AbsoluteSize is (0, 0) until the holder has rendered once, so columns
    -- created in the same frame as their page would all be assigned zero width
    -- -- the same trap that seeded every star particle at the origin in M1.
    -- Re-laying out whenever the holder's size actually changes is self-healing:
    -- it covers first render, window resize and page switching in one line,
    -- without anyone having to remember to call relayout().
    root:keep(holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_layout()
    end))

    return self
end

function Tab:Column(opts)
    local column = Column.new(self._root, self.holder, opts)
    column.frame.LayoutOrder = #self._columns + 1
    table.insert(self._columns, column)
    self:_layout()
    return column
end

-- UIListLayout cannot express ratios, so widths are assigned explicitly. The
-- available width is the column area minus the gaps between columns.
function Tab:_layout()
    local n = #self._columns
    if n == 0 then return end
    local weights = {}
    for i = 1, n do weights[i] = self._columns[i].weight end
    local total = self.holder.AbsoluteSize.X
    local px = Column.widths(weights, total, COLUMN_GAP)
    for i = 1, n do
        self._columns[i]:setWidth(px[i])
    end
end

--== Page ==--

function M.new(root, window, opts)
    local theme = root.theme
    local name = opts.Name or "Page"

    --== rail button ==--
    local button = Instance.new("TextButton")
    button.Name = "railButton"
    button.Size = UDim2.new(1, 0, 0, 28)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = window._rail
    root:keep(button)

    local marker = Instance.new("Frame")
    marker.Name = "marker"
    -- Overhangs the button by 1px top and bottom: flush with the button, the
    -- marker reads visibly shorter than the RailActive highlight beside it.
    -- The 1px each side sits in the 2px gap the rail layout leaves between
    -- buttons, so it cannot collide with a neighbour.
    marker.Size = UDim2.new(0, 2, 1, 2)
    marker.Position = UDim2.fromOffset(0, -1)
    marker.BorderSizePixel = 0
    marker.Visible = false
    marker.Parent = button
    theme:bind(marker, "BackgroundColor3", "Accent")

    -- Lucide icon baking is a later milestone. An rbxassetid works for free
    -- because it is just an Image; anything else falls back to the page name's
    -- first letter, which is the fallback the library spec already documents.
    local glyph
    if type(opts.Icon) == "string" and opts.Icon:match("^rbxassetid://") then
        glyph = Instance.new("ImageLabel")
        glyph.Image = opts.Icon
        glyph.Size = UDim2.fromOffset(14, 14)
        glyph.BackgroundTransparency = 1
    else
        glyph = Instance.new("TextLabel")
        glyph.Text = name:sub(1, 1):upper()
        glyph.Font = Enum.Font.Ubuntu
        glyph.TextSize = 12
        glyph.Size = UDim2.fromOffset(14, 14)
        glyph.BackgroundTransparency = 1
        theme:bind(glyph, "TextColor3", "TextDim")
    end
    glyph.Name = "glyph"
    glyph.AnchorPoint = Vector2.new(0.5, 0.5)
    glyph.Position = UDim2.fromScale(0.5, 0.5)
    glyph.Parent = button

    --== page body ==--
    local body = Instance.new("Frame")
    body.Name = "page_" .. name
    body.Size = UDim2.fromScale(1, 1)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Visible = false
    body.Parent = window._pageArea
    root:keep(body)

    local subtabBar = Instance.new("Frame")
    subtabBar.Name = "subtabs"
    subtabBar.Size = UDim2.new(1, 0, 0, SUBTAB_HEIGHT)
    subtabBar.BackgroundTransparency = 1
    subtabBar.BorderSizePixel = 0
    subtabBar.Visible = false
    subtabBar.Parent = body

    local subtabRule = Instance.new("Frame")
    subtabRule.Name = "rule"
    subtabRule.AnchorPoint = Vector2.new(0, 1)
    subtabRule.Position = UDim2.new(0, 0, 1, 0)
    subtabRule.Size = UDim2.new(1, 0, 0, 1)
    subtabRule.BorderSizePixel = 0
    subtabRule.Parent = subtabBar
    theme:bind(subtabRule, "BackgroundColor3", "ContainerBorder")

    -- The buttons get their own frame because a UIListLayout arranges EVERY
    -- child of its parent -- including the 1px rule, which is full width and
    -- would consume the whole row and push the buttons off the end.
    local subtabList = Instance.new("Frame")
    subtabList.Name = "list"
    subtabList.Size = UDim2.fromScale(1, 1)
    subtabList.BackgroundTransparency = 1
    subtabList.BorderSizePixel = 0
    subtabList.Parent = subtabBar

    local subtabPad = Instance.new("UIPadding")
    subtabPad.PaddingLeft = UDim.new(0, PADDING)
    subtabPad.Parent = subtabList

    local subtabLayout = Instance.new("UIListLayout")
    subtabLayout.FillDirection = Enum.FillDirection.Horizontal
    subtabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    subtabLayout.Padding = UDim.new(0, 14)
    subtabLayout.Parent = subtabList

    local columnArea = Instance.new("Frame")
    columnArea.Name = "columns"
    columnArea.Position = UDim2.fromOffset(PADDING, PADDING)
    columnArea.Size = UDim2.new(1, -PADDING * 2, 1, -PADDING * 2)
    columnArea.BackgroundTransparency = 1
    columnArea.BorderSizePixel = 0
    columnArea.Parent = body

    local self = setmetatable({
        _root = root,
        _window = window,
        _theme = theme,
        _tabs = {},
        _tabButtons = {},
        _activeTab = nil,
        _implicit = nil,
        _subtabBar = subtabBar,
        _subtabList = subtabList,
        _columnArea = columnArea,
        _button = button,
        _marker = marker,
        _glyph = glyph,
        name = name,
        body = body,
    }, Page)

    root:keep(button.Activated:Connect(function()
        window:setActivePage(self)
    end))

    return self
end

function Page:setActive(active)
    self.body.Visible = active
    self._marker.Visible = active
    self._button.BackgroundTransparency = active and 0 or 1
    if active then
        self._theme:unbind(self._button)
        self._theme:bind(self._button, "BackgroundColor3", "RailActive")
    else
        self._theme:unbind(self._button)
    end
    if self._glyph:IsA("TextLabel") then
        self._theme:unbind(self._glyph)
        self._theme:bind(self._glyph, "TextColor3", active and "TextBright" or "TextDim")
    end
end

function Page:Tab(name)
    -- A page is either tabbed or it is not. Columns added straight to the page
    -- live in an implicit tab that has no button, so a real tab created
    -- afterwards would strand them the moment the user switches -- with no way
    -- back. Nothing sensible to do but refuse.
    if self._implicit then
        error(string.format(
            "chroma: page '%s' already has columns added directly; call :Tab() " ..
            "before adding any columns, or use :Column() throughout",
            tostring(self.name)), 2)
    end

    local tab = Tab.new(self._root, self, name)
    self._tabs[#self._tabs + 1] = tab

    local button = Instance.new("TextButton")
    button.Name = "subtab_" .. name
    button.Size = UDim2.new(0, 0, 1, 0)
    button.AutomaticSize = Enum.AutomaticSize.X
    button.BackgroundTransparency = 1
    button.Font = Enum.Font.Ubuntu
    button.TextSize = 12
    button.Text = name
    button.AutoButtonColor = false
    button.LayoutOrder = #self._tabs
    button.Parent = self._subtabList
    self._root:keep(button)

    local underline = Instance.new("Frame")
    underline.Name = "underline"
    underline.AnchorPoint = Vector2.new(0, 1)
    underline.Position = UDim2.new(0, 0, 1, 0)
    underline.Size = UDim2.new(1, 0, 0, 2)
    underline.BorderSizePixel = 0
    underline.Visible = false
    underline.ZIndex = 2
    underline.Parent = button
    self._theme:bind(underline, "BackgroundColor3", "Accent")

    self._tabButtons[tab] = { button = button, underline = underline }

    self._root:keep(button.Activated:Connect(function()
        self:setActiveTab(tab)
    end))

    -- The bar only appears once a page has real tabs; an implicit tab has none.
    self._subtabBar.Visible = true
    self._columnArea.Position = UDim2.fromOffset(PADDING, SUBTAB_HEIGHT + PADDING)
    self._columnArea.Size = UDim2.new(1, -PADDING * 2, 1, -(SUBTAB_HEIGHT + PADDING * 2))

    -- Restyle every tab, not just the first: setActiveTab is what binds each
    -- button's colour, so a tab added later would otherwise keep Roblox's
    -- default TextButton colour until something else triggered a restyle.
    self:setActiveTab(self._activeTab or tab)
    return tab
end

function Page:setActiveTab(tab)
    self._activeTab = tab
    for i = 1, #self._tabs do
        local t = self._tabs[i]
        local parts = self._tabButtons[t]
        local active = t == tab
        t.holder.Visible = active
        if parts then
            parts.underline.Visible = active
            self._theme:unbind(parts.button)
            self._theme:bind(parts.button, "TextColor3",
                active and "TextBright" or "TextDim")
        end
        if active then t:_layout() end
    end
end

-- Pages without tabs proxy straight to an implicit one, so a simple page needs
-- no throwaway :Tab("Main") call.
function Page:Column(opts)
    if not self._activeTab then
        self._implicit = Tab.new(self._root, self, "__implicit")
        self._tabs[#self._tabs + 1] = self._implicit
        self._activeTab = self._implicit
        self._implicit.holder.Visible = true
    elseif not self._implicit then
        -- Real tabs exist, so a bare :Column() would land in whichever tab is
        -- currently active -- fine when there is one, ambiguous when there are
        -- several, and invisible either way. Make the caller say which.
        error(string.format(
            "chroma: page '%s' has sub-tabs; add columns to a tab, not the page",
            tostring(self.name)), 2)
    end
    return self._activeTab:Column(opts)
end

function Page:relayout()
    for i = 1, #self._tabs do
        self._tabs[i]:_layout()
    end
end

return M
