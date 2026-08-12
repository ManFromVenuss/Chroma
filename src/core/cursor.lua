-- Custom cross cursor. hitTest is pure and unit tested; the DrawingImmediate
-- rendering is added in a later task.
-- hitTest must stay in the Lua 5.4 / Luau intersection.

local M = {}

function M.hitTest(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

return M
