-- Custom cross cursor. hitTest is pure and unit tested; the DrawingImmediate
-- rendering is added in a later task.
-- hitTest must stay in the Lua 5.4 / Luau intersection.

local M = {}

function M.hitTest(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

--== Drawing side. Never runs under Lua 5.4. ==--

-- Resolved lazily inside M.new. A module-scope game:GetService() would execute
-- on require, and this file is required by the Lua 5.4 test harness to reach
-- hitTest, where the `game` global does not exist.
local UserInputService

local Cursor = {}
Cursor.__index = Cursor

local DEFAULTS = {
    Style = "Cross",
    Color = Color3.fromRGB(255, 255, 255),
    Size = 7,
    Thickness = 1,
    Gap = 0,
    Outline = true,
    ClickFeedback = true,
}

-- isOver() must be supplied by the caller: it decides when Chroma owns the
-- pointer. Chroma hides the OS cursor only while that returns true.
function M.new(root, opts, isOver)
    opts = opts or {}
    UserInputService = UserInputService or game:GetService("UserInputService")
    local cfg = {}
    for key, value in pairs(DEFAULTS) do
        cfg[key] = opts[key]
        if cfg[key] == nil then cfg[key] = value end
    end

    local self = setmetatable({
        _root = root,
        _cfg = cfg,
        _isOver = isOver,
        _held = false,
        _hidden = false,
    }, Cursor)

    if cfg.Style == false or not DrawingImmediate then
        if cfg.Style ~= false then
            root:degrade("cursor", "DrawingImmediate missing: OS cursor retained")
        end
        return self
    end

    -- Restoring the pointer must be unconditional. The one genuinely bad failure
    -- here is leaving the user unable to see where they are clicking.
    root:keep(function()
        UserInputService.MouseIconEnabled = true
    end)

    if cfg.ClickFeedback then
        root:keep(UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self._held = true
            end
        end))
        root:keep(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self._held = false
            end
        end))
    end

    local paint = DrawingImmediate.GetPaint(1000)
    root:keep(paint:Connect(function()
        self:_paint()
    end))

    return self
end

function Cursor:_paint()
    local over = self._isOver()

    -- _hidden records whether WE have hidden the OS pointer. Write only on a
    -- transition; comparing with == instead of ~= rewrites the property on every
    -- frame the pointer is off the window.
    if over ~= self._hidden then
        UserInputService.MouseIconEnabled = not over
        self._hidden = over
    end

    if not over then return end

    local cfg = self._cfg
    local pos = UserInputService:GetMouseLocation()
    local arm = cfg.Size
    if self._held then
        arm = math.max(2, arm - 2)
    end
    local gap = cfg.Gap
    local thin = cfg.Thickness

    local function line(from, to, color, thickness)
        DrawingImmediate.Line(from, to, color, 1, thickness)
    end

    local segments
    if gap > 0 then
        segments = {
            { Vector2.new(pos.X, pos.Y - arm), Vector2.new(pos.X, pos.Y - gap) },
            { Vector2.new(pos.X, pos.Y + gap), Vector2.new(pos.X, pos.Y + arm) },
            { Vector2.new(pos.X - arm, pos.Y), Vector2.new(pos.X - gap, pos.Y) },
            { Vector2.new(pos.X + gap, pos.Y), Vector2.new(pos.X + arm, pos.Y) },
        }
    else
        segments = {
            { Vector2.new(pos.X, pos.Y - arm), Vector2.new(pos.X, pos.Y + arm) },
            { Vector2.new(pos.X - arm, pos.Y), Vector2.new(pos.X + arm, pos.Y) },
        }
    end

    -- Outline first, underneath. Without it a coloured cross over a bright
    -- background disappears.
    if cfg.Outline then
        local black = Color3.new(0, 0, 0)
        for i = 1, #segments do
            line(segments[i][1], segments[i][2], black, thin + 2)
        end
    end
    for i = 1, #segments do
        line(segments[i][1], segments[i][2], cfg.Color, thin)
    end
end

function Cursor:setConfig(opts)
    for key, value in pairs(opts) do
        self._cfg[key] = value
    end
end

return M
