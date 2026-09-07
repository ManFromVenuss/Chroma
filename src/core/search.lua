-- Global widget search. Pure ranking function first; the Instance side lives
-- below and never runs under the 5.4 test harness.
--
-- Ranking rule (documented in the spec): exact < prefix < word-start < any
-- substring, ties broken alphabetically. Path is displayed but not searched --
-- searching paths made every widget on the Aimbot page match "aim", which is
-- noise. Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops,
-- no goto.

local M = {}

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
    local self = setmetatable({
        _root = root,
        _window = window,
        _entries = {},   -- flat list of {label, path, page, tab, column, row, widget}
    }, Search)
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

return M
