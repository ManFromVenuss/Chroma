-- Global widget search. Pure ranking function first; the Instance side lives
-- below and never runs under the 5.4 test harness.
--
-- Ranking rule (documented in the spec): exact < prefix < word-start < any
-- substring, ties broken alphabetically. Path is displayed but not searched --
-- searching paths made every widget on the Aimbot page match "aim", which is
-- noise. Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops,
-- no goto.

local M = {}

-- Instance-side requires. Kept below the pure section's `local M = {}` so the
-- 5.4 harness never touches them.
local Icons
local lucideAssets

local function scoreOne(query, label)
    local lower = string.lower(label)
    if lower == query then return 0 end
    local idx = string.find(lower, query, 1, true)  -- plain-text, not pattern
    if idx == nil then return nil end
    if idx == 1 then return 1 end
    local prev = string.sub(lower, idx - 1, idx - 1)
    if prev == " " or prev == "_" then return 2 end
    return 3
end

function M.rank(query, entries)
    query = string.lower(query)
    query = query:gsub("^%s+", "")
    query = query:gsub("%s+$", "")
    if query == "" then return {} end

    local scored = {}
    for i = 1, #entries do
        local e = entries[i]
        local score = scoreOne(query, e.label)
        if score ~= nil then
            table.insert(scored, { entry = e, score = score })
        end
    end

    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.entry.label < b.entry.label
    end)

    local out = {}
    for i = 1, #scored do out[i] = scored[i].entry end
    return out
end

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local TweenService   -- lazy: `game` is nil under the 5.4 test harness

local ROW_HEIGHT = 19
local MAX_VISIBLE_ROWS = 8
local FLASH_DURATION = 0.8

local Search = {}
Search.__index = Search

function M.new(root, window)
    Icons = Icons or require("core/icons")
    lucideAssets = lucideAssets or require("core/lucide_assets")
    TweenService = TweenService or game:GetService("TweenService")

    local self = setmetatable({
        _root = root,
        _window = window,
        _entries = {},   -- flat list of {label, path, page, tab, column, row, widget}
    }, Search)

    local theme = root.theme
    local bar = window._bar
    local titleText = window._titleText

    -- 12x12 icon anchored to the right edge of the title bar. Uses ImageButton
    -- so the click hit-region matches the visible glyph.
    local searchIcon = Instance.new("ImageButton")
    searchIcon.Name = "searchIcon"
    searchIcon.AnchorPoint = Vector2.new(1, 0.5)
    searchIcon.Position = UDim2.new(1, -8, 0.5, 0)
    searchIcon.Size = UDim2.fromOffset(12, 12)
    searchIcon.BackgroundTransparency = 1
    searchIcon.AutoButtonColor = false
    searchIcon.Image = Icons.resolveIcon("search", lucideAssets).value
    searchIcon.ZIndex = 22
    searchIcon.Parent = bar
    root:keep(searchIcon)
    theme:bind(searchIcon, "ImageColor3", "TextDim")
    self._icon = searchIcon

    -- TextBox occupies the same rectangle the title text does. Hidden until
    -- the search is open; the title label hides in step so the two never
    -- overlap.
    local input = Instance.new("TextBox")
    input.Name = "searchInput"
    input.BackgroundTransparency = 1
    input.Size = UDim2.new(1, -32, 1, 0)   -- 24px reserved on the right: 8px margin, 12px icon, 4px gap
    input.Position = UDim2.fromOffset(8, 0)
    input.Font = Enum.Font.Ubuntu
    input.TextSize = 12
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.PlaceholderText = "Search widgets..."
    input.Text = ""
    input.ClearTextOnFocus = false
    input.Visible = false
    input.ZIndex = 21
    input.Parent = bar
    root:keep(input)
    theme:bind(input, "TextColor3", "TextBright")
    theme:bind(input, "PlaceholderColor3", "TextDim")
    self._input = input

    self._open = false
    self._iconHovered = false

    root:keep(searchIcon.MouseEnter:Connect(function()
        self._iconHovered = true
        self:_paintIcon()
    end))
    root:keep(searchIcon.MouseLeave:Connect(function()
        self._iconHovered = false
        self:_paintIcon()
    end))
    root:keep(searchIcon.Activated:Connect(function()
        self:toggle()
    end))

    -- Dropdown lives on the overlay layer so it renders above the window's
    -- own body without being clipped by the window frame.
    local drop = Instance.new("ScrollingFrame")
    drop.Name = "searchDropdown"
    drop.BackgroundTransparency = 0
    drop.BorderSizePixel = 0
    drop.ScrollBarThickness = 2
    drop.ScrollingDirection = Enum.ScrollingDirection.Y
    drop.ElasticBehavior = Enum.ElasticBehavior.Never
    drop.CanvasSize = UDim2.new()
    drop.AutomaticCanvasSize = Enum.AutomaticSize.Y
    drop.Visible = false
    drop.ZIndex = 40
    drop.Parent = root.overlayLayer
    root:keep(drop)
    theme:bind(drop, "BackgroundColor3", "Body")
    theme:bind(drop, "ScrollBarImageColor3", "Accent")
    self._drop = drop

    local dropStroke = Instance.new("UIStroke")
    dropStroke.Thickness = 1
    dropStroke.Color = Color3.new(1, 1, 1)
    dropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    dropStroke.Parent = drop

    local dropStrokeGradient = Instance.new("UIGradient")
    dropStrokeGradient.Color = ColorSequence.new(
        theme:get("HairA"), theme:get("HairB"))
    dropStrokeGradient.Parent = dropStroke
    self._dropStrokeGradient = dropStrokeGradient

    local RunService = game:GetService("RunService")
    root:keep(RunService.Heartbeat:Connect(function()
        if not root:isAlive() then return end
        self._dropStrokeGradient.Color = ColorSequence.new(
            theme:get("HairA"), theme:get("HairB"))
    end))

    local dropLayout = Instance.new("UIListLayout")
    dropLayout.FillDirection = Enum.FillDirection.Vertical
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Padding = UDim.new(0, 0)
    dropLayout.Parent = drop

    self._rows = {}     -- reusable row frames, indexed 1..N
    self._results = {}  -- current filtered entries in display order
    self._selected = 0  -- 1-based index into _results, 0 when no selection
    self._lastSelected = 0

    -- Repositions the dropdown flush under the title bar. Called on layout
    -- change and every open.
    self._anchor = function()
        local titleBar = window._bar
        local pos = titleBar.AbsolutePosition
        local sz = titleBar.AbsoluteSize
        local layer = root.overlayLayer
        -- toLayerSpace converts AbsolutePosition (screen space) into Position
        -- offset relative to the overlay layer's origin.
        drop.Position = UDim2.fromOffset(
            root:toLayerSpace(pos.X, pos.Y + sz.Y, layer))
        drop.Size = UDim2.new(0, sz.X, 0, 0)   -- height set per-refresh
    end

    -- Reposition when the window moves or resizes; the window fires
    -- _layoutChanged for both.
    window:onLayoutChanged(function()
        if self._open then self._anchor() end
    end)

    -- Live filter as the user types.
    root:keep(input:GetPropertyChangedSignal("Text"):Connect(function()
        if self._open then self:_refresh() end
    end))

    local UserInputService = game:GetService("UserInputService")

    root:keep(input.FocusLost:Connect(function(enterPressed)
        -- Enter activates the selected result. Escape and click-outside both
        -- close via the window-level handler (wired in Task 9).
        if enterPressed and self._open then
            local pick = self._results[self._selected]
            if pick then self:_activate(pick) end
        end
    end))

    root:keep(UserInputService.InputBegan:Connect(function(input_, gameProcessed)
        if not self._open then return end
        if #self._results == 0 then return end
        if input_.KeyCode == Enum.KeyCode.Down then
            self._selected = self._selected % #self._results + 1
            self:_paintSelection()
        elseif input_.KeyCode == Enum.KeyCode.Up then
            self._selected = self._selected - 1
            if self._selected < 1 then self._selected = #self._results end
            self:_paintSelection()
        end
    end))

    return self
end

-- Called from Container as each widget is registered. Path is derived here so
-- Container does not need to know it exists.
function Search:add(widget, row, container)
    local column = container._column
    if column == nil then return end
    local tab = column._tab
    if tab == nil then return end
    local page = tab._page
    if page == nil then return end

    local label = widget._label
    if type(label) ~= "string" or label == "" then return end

    local pathBits = { page.name }
    if container._title ~= "" then table.insert(pathBits, container._title) end
    local path = table.concat(pathBits, " > ")

    table.insert(self._entries, {
        label = label,
        path = path,
        page = page,
        tab = tab,
        column = column,
        row = row,
        widget = widget,
    })
end

function Search:open()
    if self._open then return end
    self._open = true
    self._window._titleText.Visible = false
    self._input.Visible = true
    self._input.Text = ""
    self._input:CaptureFocus()
    -- Icon swaps to `x` so the same button also closes the search.
    self._icon.Image = Icons.resolveIcon("x", lucideAssets).value
    self:_paintIcon()
    self:_refresh()   -- populates the dropdown; stub for now
end

function Search:close()
    if not self._open then return end
    self._open = false
    self._input:ReleaseFocus()
    self._input.Visible = false
    self._input.Text = ""
    self._window._titleText.Visible = true
    self._icon.Image = Icons.resolveIcon("search", lucideAssets).value
    self:_paintIcon()
    self:_refresh()
end

function Search:toggle()
    if self._open then self:close() else self:open() end
end

-- Icon reads bright when hovered OR when the search is open, dim otherwise.
-- Centralised so open()/close() and the hover handlers can't fall out of sync.
function Search:_paintIcon()
    local theme = self._root.theme
    theme:unbind(self._icon)
    local key = (self._open or self._iconHovered) and "TextBright" or "TextDim"
    theme:bind(self._icon, "ImageColor3", key)
end

-- Ensures at least `n` rows exist in the reusable pool, creating any missing
-- ones. Rows are hidden by default; _refresh sets visibility per result.
function Search:_ensureRows(n)
    local theme = self._root.theme
    for i = #self._rows + 1, n do
        local row = Instance.new("TextButton")
        row.Name = "result" .. i
        row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
        row.BackgroundTransparency = 1
        row.AutoButtonColor = false
        row.Text = ""
        row.LayoutOrder = i
        row.ZIndex = 41
        row.Visible = false
        row.Parent = self._drop

        local label = Instance.new("TextLabel")
        label.Name = "label"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(8, 0)
        label.Size = UDim2.new(0.55, -8, 1, 0)
        label.Font = Enum.Font.Ubuntu
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.ZIndex = 42
        label.Parent = row
        theme:bind(label, "TextColor3", "TextBright")

        local path = Instance.new("TextLabel")
        path.Name = "path"
        path.BackgroundTransparency = 1
        path.AnchorPoint = Vector2.new(1, 0)
        path.Position = UDim2.new(1, -8, 0, 0)
        path.Size = UDim2.new(0.45, -8, 1, 0)
        path.Font = Enum.Font.Ubuntu
        path.TextSize = 12
        path.TextXAlignment = Enum.TextXAlignment.Right
        path.TextTruncate = Enum.TextTruncate.AtEnd
        path.ZIndex = 42
        path.Parent = row
        theme:bind(path, "TextColor3", "TextDim")

        root:keep(row.MouseEnter:Connect(function()
            if not self._open then return end
            -- Only sync to results we're actually showing; the footer "+N more"
            -- row has no result behind it.
            if i <= #self._results then
                self._selected = i
                self:_paintSelection()
            end
        end))

        root:keep(row.Activated:Connect(function()
            if not self._open then return end
            if i <= #self._results then
                self._selected = i
                self:_activate(self._results[i])
            end
        end))

        self._rows[i] = { frame = row, label = label, path = path }
    end
end

-- Switch to the page and tab that host the entry, scroll the row into view,
-- flash it briefly with the accent colour, then close the search.
function Search:_activate(entry)
    if entry == nil then return end
    local window = self._window

    if window:getActivePage() ~= entry.page then
        window:setActivePage(entry.page)
    end
    if entry.page._activeTab ~= entry.tab then
        entry.page:setActiveTab(entry.tab)
    end

    entry.column:scrollTo(entry.row)
    self:_flash(entry.row)
    self:close()
end

-- Tween a row from Accent-tinted to fully transparent over FLASH_DURATION.
-- The row's background is normally transparent, so setting it directly is
-- fine -- no other code writes to row.frame.BackgroundColor3.
function Search:_flash(row)
    local frame = row and row.frame
    if frame == nil then return end
    frame.BackgroundColor3 = self._root.theme:get("Accent")
    frame.BackgroundTransparency = 0.4
    local tween = TweenService:Create(frame,
        TweenInfo.new(FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 })
    tween:Play()
end

-- Rebuild the dropdown from the current input. Empty query hides the drop.
function Search:_refresh()
    local drop = self._drop
    if not self._open then
        drop.Visible = false
        return
    end

    local query = self._input.Text or ""
    self._results = M.rank(query, self._entries)
    self._selected = #self._results > 0 and 1 or 0

    if query == "" or #self._results == 0 then
        -- No dropdown for empty query or zero matches. A "no results" line
        -- reads as noise on a menu where the widget list is small.
        drop.Visible = false
        return
    end

    local shown = math.min(#self._results, MAX_VISIBLE_ROWS)
    local hasMore = #self._results > MAX_VISIBLE_ROWS
    self:_ensureRows(shown + (hasMore and 1 or 0))

    -- Clear leftover selection paint on every row: a prior refresh may have
    -- left a RailActive binding on rows that are about to fall out of the
    -- results range, and _paintSelection only touches the two rows that
    -- change now.
    local theme = self._root.theme
    for i = 1, #self._rows do
        local frame = self._rows[i].frame
        frame.Visible = false
        frame.BackgroundTransparency = 1
        theme:unbind(frame)
    end
    self._lastSelected = 0

    for i = 1, shown do
        local entry = self._results[i]
        local row = self._rows[i]
        row.label.Text = entry.label
        row.path.Text = entry.path
        row.frame.Visible = true
    end

    -- Footer `+N more` row if the total exceeds the cap. Not clickable, not
    -- part of _results (so selection can't land on it).
    if hasMore then
        local footer = self._rows[shown + 1]
        footer.label.Text = "+" .. tostring(#self._results - shown) .. " more"
        footer.path.Text = ""
        footer.frame.Visible = true
        footer.frame.AutoButtonColor = false
    end

    self._anchor()
    -- Clamp the outer frame height to what we want to show (cap * row height
    -- + footer row when present).
    local visibleRows = shown + (hasMore and 1 or 0)
    local width = drop.AbsoluteSize.X ~= 0 and drop.AbsoluteSize.X
        or self._window._bar.AbsoluteSize.X
    drop.Size = UDim2.new(0, width, 0,
        math.min(visibleRows, MAX_VISIBLE_ROWS + (hasMore and 1 or 0)) * ROW_HEIGHT)

    drop.Visible = true
    self:_paintSelection()
end

-- Only re-paints the row that gained and the row that lost selection; the
-- rest are already correct from a prior _refresh. Called on every keystroke
-- and every arrow key, so touching only two rows keeps theme rebinds off the
-- hot path.
function Search:_paintSelection()
    local theme = self._root.theme
    local prev = self._lastSelected or 0
    local next_ = self._selected or 0

    if prev == next_ then return end

    if prev > 0 and self._rows[prev] then
        local frame = self._rows[prev].frame
        frame.BackgroundTransparency = 1
        theme:unbind(frame)
    end
    if next_ > 0 and self._rows[next_] then
        local frame = self._rows[next_].frame
        frame.BackgroundTransparency = 0
        theme:unbind(frame)
        theme:bind(frame, "BackgroundColor3", "RailActive")
    end

    self._lastSelected = next_
end

return M
