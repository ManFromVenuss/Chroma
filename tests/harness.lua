-- Test harness: a require shim matching the one build.py emits, plus the
-- Roblox datatypes the pure modules need. Lua 5.4 compatible.
local M = {}

local function repoRoot()
    -- tests/harness.lua -> repo root is one level up from this file
    local src = debug.getinfo(1, "S").source:sub(2)
    return (src:gsub("[/\\]tests[/\\]harness%.lua$", ""))
end

M.root = repoRoot()

-- Source files are written as bare module bodies referencing require(...) as a
-- free variable, exactly as build.py wraps them. Wrap identically here so the
-- same text runs in both places.
local function loadModule(path)
    local file = M.root .. "/src/" .. path .. ".lua"
    local fh = io.open(file, "rb")
    if not fh then return nil end
    local text = fh:read("a")
    fh:close()
    local chunk, err = load("return function(require) " .. text .. " end", "@" .. file)
    if not chunk then error(err, 0) end
    return chunk()
end

function M.makeRequire()
    local cache = {}
    local function req(path)
        if cache[path] ~= nil then return cache[path] end
        local factory = loadModule(path)
        if not factory then
            error("chroma: unknown module '" .. path .. "'", 2)
        end
        local result = factory(req)
        cache[path] = result
        return result
    end
    return req
end

--== Roblox datatype stubs ==--

local Color3 = {}
Color3.__index = Color3

local function newColor(r, g, b)
    return setmetatable({ R = r, G = g, B = b }, Color3)
end

function Color3.new(r, g, b) return newColor(r or 0, g or 0, b or 0) end
function Color3.fromRGB(r, g, b) return newColor(r / 255, g / 255, b / 255) end

function Color3.fromHSV(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local m = i % 6
    if m == 0 then return newColor(v, t, p) end
    if m == 1 then return newColor(q, v, p) end
    if m == 2 then return newColor(p, v, t) end
    if m == 3 then return newColor(p, q, v) end
    if m == 4 then return newColor(t, p, v) end
    return newColor(v, p, q)
end

function Color3:ToHSV()
    local r, g, b = self.R, self.G, self.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local v = max
    local d = max - min
    local s = 0
    if max > 0 then s = d / max end
    local h = 0
    if d > 0 then
        if max == r then h = ((g - b) / d) % 6
        elseif max == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end

Color3.__eq = function(a, b)
    return math.abs(a.R - b.R) < 1e-9
       and math.abs(a.G - b.G) < 1e-9
       and math.abs(a.B - b.B) < 1e-9
end

Color3.__tostring = function(c)
    return string.format("Color3(%.3f, %.3f, %.3f)", c.R, c.G, c.B)
end

M.Color3 = Color3
_G.Color3 = Color3

-- Minimal stand-in for a Roblox instance: a plain table that records writes.
function M.fakeInstance(fields)
    local t = {}
    for k, v in pairs(fields or {}) do t[k] = v end
    t.__writes = 0
    return setmetatable(t, {
        __index = function(_, k) return nil end,
        __newindex = function(tbl, k, v)
            rawset(tbl, k, v)
            rawset(tbl, "__writes", rawget(tbl, "__writes") + 1)
        end,
    })
end

--== Enum and typeof stubs ==--
-- Roblox dispatches on typeof(), so the pure encoder does too. Providing it
-- here is the same bargain as the Color3 stub above: the module under test runs
-- unmodified, and the stub only has to be faithful for the types Chroma stores.

local EnumItem = {}
EnumItem.__index = EnumItem

-- Enum objects don't have a Name property in real Roblox -- tostring(enum)
-- returns just the group name (e.g. "KeyCode"). The stub matches that: an
-- earlier version exposed .Name and the resulting test-only success hid a
-- real bug in serialise.encode that only surfaced in-game.
local EnumType = {}
EnumType.__index = EnumType
EnumType.__tostring = function(self) return rawget(self, "_name") end

-- Items are created on demand, so a test can name any key without the stub
-- carrying Roblox's full enum list.
local function makeEnum(enumName)
    local self = setmetatable({ _name = enumName, _items = {} }, EnumType)
    return setmetatable({}, {
        __index = function(_, key)
            local items = rawget(self, "_items")
            if items[key] == nil then
                items[key] = setmetatable({ Name = key, EnumType = self }, EnumItem)
            end
            return items[key]
        end,
    })
end

M.Enum = { KeyCode = makeEnum("KeyCode"), UserInputType = makeEnum("UserInputType") }
_G.Enum = M.Enum

-- Vector2 stub. Enough for serialise.lua's round trip; nothing beyond the
-- fields the code actually reads.
local Vector2 = { __index = {} }
Vector2.__tostring = function(v) return string.format("Vector2(%g, %g)", v.X, v.Y) end
Vector2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function Vector2.new(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end
M.Vector2 = Vector2
_G.Vector2 = Vector2

function _G.typeof(value)
    if type(value) == "table" then
        local mt = getmetatable(value)
        if mt == Color3 then return "Color3" end
        if mt == EnumItem then return "EnumItem" end
        if mt == Vector2 then return "Vector2" end
    end
    return type(value)
end

--== assertions ==--

local function fail(msg, level)
    error(msg, (level or 2) + 1)
end

function M.assertEqual(got, want)
    if got ~= want then
        fail(string.format("expected %s, got %s", tostring(want), tostring(got)))
    end
end

function M.assertSame(a, b)
    if a ~= b then fail("expected the same object") end
end

function M.assertNear(got, want, tol)
    tol = tol or 1e-6
    if type(got) ~= "number" then
        fail("expected a number, got " .. type(got) .. " (" .. tostring(got) .. ")")
    end
    if math.abs(got - want) > tol then
        fail(string.format("expected %.9f +/- %.9f, got %.9f", want, tol, got))
    end
end

function M.assertMatch(text, pattern)
    if not tostring(text):find(pattern, 1, true) then
        fail(string.format("expected %q to contain %q", tostring(text), pattern))
    end
end

function M.assertTrue(v)
    if not v then fail("expected truthy, got " .. tostring(v)) end
end

function M.assertFalse(v)
    if v then fail("expected falsy, got " .. tostring(v)) end
end

if _G.warn == nil then
    _G.warn = function(...) io.stderr:write("[warn] ", tostring((...)), "\n") end
end

return M
