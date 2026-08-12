-- A column: the pure width-distribution maths, plus (from a later task) the
-- ScrollingFrame that holds containers.
--
-- widths() is the ONLY place M2 computes a size by hand. Everything else is
-- AutomaticSize / AutomaticCanvasSize, because UIListLayout cannot express
-- ratios but can do everything else.
--
-- Lua 5.4 / Luau intersection: no compound assignment, no bitwise ops, no goto.

local M = {}

-- Distributes totalWidth across #weights columns separated by `gap` pixels.
-- The final column takes whatever integer pixels are left over, so the columns
-- always sum exactly to the available space rather than leaving a 1px seam.
function M.widths(weights, totalWidth, gap)
    local n = #weights
    if n == 0 then return {} end

    gap = gap or 0
    local space = totalWidth - gap * (n - 1)
    if space < 0 then space = 0 end

    local total = 0
    for i = 1, n do
        local w = weights[i]
        if type(w) == "number" and w > 0 then total = total + w end
    end

    local out = {}
    if total <= 0 then
        -- Every weight was zero or invalid: fall back to an even split rather
        -- than dividing by zero.
        for i = 1, n do out[i] = 1 end
        total = n
        weights = out
        out = {}
    end

    local used = 0
    for i = 1, n - 1 do
        local w = weights[i]
        if type(w) ~= "number" or w <= 0 then w = 0 end
        local px = math.floor(space * w / total)
        out[i] = px
        used = used + px
    end
    out[n] = space - used
    if out[n] < 0 then out[n] = 0 end
    return out
end

return M
