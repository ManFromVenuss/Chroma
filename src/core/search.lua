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

local Search = {}
Search.__index = Search

function M.new(root, window)
    Icons = Icons or require("core/icons")
    lucideAssets = lucideAssets or require("core/lucide_assets")

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

-- Stub; the dropdown is added in the next task. Kept as a no-op so open/close
-- can be exercised now without a nil ref.
function Search:_refresh()
end

return M
