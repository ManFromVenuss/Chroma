-- Custom cross cursor. hitTest is pure and unit tested, so it stays in the
-- Lua 5.4 / Luau intersection; the DrawingImmediate rendering below does not.

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

    -- Only a missing DrawingImmediate is fatal here. A Style of false or "None"
    -- still connects the paint loop, because the settings page can turn the
    -- cursor back on -- and it cannot do that if the connection was never made.
    if not DrawingImmediate then
        root:degrade("cursor", "DrawingImmediate missing: OS cursor retained")
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
    -- Style is read per frame rather than once at construction: the settings
    -- page changes it live, and "off" has to also restore the OS pointer, which
    -- the transition write below already does for free.
    local off = self._cfg.Style == false or self._cfg.Style == "None"
    local over = (not off) and self._isOver()

    -- _hidden records whether Chroma has hidden the OS pointer.
    --
    -- This re-asserts while the pointer is over the menu rather than writing
    -- only on the transition. A transition-only write is enough on a baseplate,
    -- but a real game that manages its own pointer sets MouseIconEnabled back
    -- to true every frame and simply wins -- the OS arrow and Chroma's cross
    -- then draw on top of each other. Reading the property first keeps this to
    -- one write per frame only while something is actually fighting us.
    if over then
        if UserInputService.MouseIconEnabled then
            UserInputService.MouseIconEnabled = false
        end
        self._hidden = true
    elseif self._hidden then
        UserInputService.MouseIconEnabled = true
        self._hidden = false
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
