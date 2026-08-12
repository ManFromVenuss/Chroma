-- Window backdrop: cover-crop maths plus (from a later task) the image and star pool.
-- computeCover is pure and unit tested; keep it free of Instance calls.
-- Lua 5.4 / Luau intersection.

local M = {}

-- Returns the image size and vertical offset for a bottom-anchored cover crop.
--
-- The caller anchors the image at (0.5, 1) on the window's bottom edge and
-- applies offset as a downward Y offset. Oversizing by (1 + shift) and pushing
-- down by baseHeight * shift keeps the top edge exactly at the window top, so a
-- shift can never uncover the top of the window.
function M.computeCover(windowW, windowH, aspect, shift)
    shift = shift or 0
    -- A negative shift would shrink the oversize factor below the base size
    -- without moving the offset back up enough, uncovering the bottom edge
    -- (or the right edge on the width-bound branch). Clamp at 0: this
    -- function is the single source of truth for the covering invariant.
    if shift < 0 then shift = 0 end
    if windowW <= 0 or windowH <= 0 then return 0, 0, 0 end

    local baseW, baseH
    if (windowW / windowH) > aspect then
        baseW = windowW
        baseH = windowW / aspect
    else
        baseH = windowH
        baseW = windowH * aspect
    end

    return baseW * (1 + shift), baseH * (1 + shift), baseH * shift
end

return M
