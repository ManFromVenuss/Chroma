-- Watermark: pure clampToViewport plus (from the next task) the pill widget
-- and its drag lifecycle.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Keeps a saved pill position inside the viewport after a resize. The
-- degenerate case (viewport smaller than the pill) collapses to the
-- top-left corner + padding, which is at least visible.
function M.clampToViewport(pos, size, viewport, padding)
    local maxX = viewport.w - size.w - padding
    local maxY = viewport.h - size.h - padding

    -- If the pill doesn't fit on either axis, don't half-fit it on the other:
    -- collapse both axes to the top-left corner so the whole pill stays put
    -- and visible, rather than pinning one edge while the rest hangs off.
    if maxX < padding or maxY < padding then
        return { x = padding, y = padding }
    end

    local x = pos.x
    if x > maxX then x = maxX end
    if x < padding then x = padding end

    local y = pos.y
    if y > maxY then y = maxY end
    if y < padding then y = padding end

    return { x = x, y = y }
end

return M
