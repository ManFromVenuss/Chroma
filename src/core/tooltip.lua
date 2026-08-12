-- Tooltip: the pure placement maths, plus (from a later task) the single reused
-- frame in the tooltip layer.
--
-- place() is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

M.GAP = 8       -- pixels between the anchor and the tooltip
M.MARGIN = 8    -- minimum distance from any screen edge

-- Anchored placement beside `anchor`, flipping left and clamping up as needed.
--
-- Everything here is in one coordinate space -- the anchor's -- which is the
-- quiet advantage of anchoring over following the cursor: GetMouseLocation
-- never enters the calculation, so the GUI-inset mismatch that caused two M1
-- bugs cannot happen.
function M.place(anchor, tip, viewport, gap, margin)
    gap = gap or M.GAP
    margin = margin or M.MARGIN

    local x = anchor.x + anchor.w + gap
    if x + tip.w > viewport.w - margin then
        x = anchor.x - tip.w - gap
    end
    if x < margin then x = margin end

    local y = anchor.y - 3
    if y + tip.h > viewport.h - margin then
        y = viewport.h - margin - tip.h
    end
    if y < margin then y = margin end

    return x, y
end

return M
