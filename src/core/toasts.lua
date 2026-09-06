-- Toasts: pure stackFor that decides where each toast sits, plus (from the
-- next task) the manager and rendering.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

local CORNERS = {
    ["top-right"] = true, ["top-left"] = true,
    ["bottom-right"] = true, ["bottom-left"] = true,
}

-- Positions for N toasts anchored to `corner`, with newest at index 1 at the
-- anchor corner and older toasts spaced toward the vertical centre.
--
-- toastSize = { w, h }, viewport = { w, h }. gap and margin are pixels.
-- An unknown corner falls back to top-right rather than erroring: the corner
-- is user-configured and a stale flag from an older Chroma should not crash.
function M.stackFor(count, corner, toastSize, gap, viewport, margin)
    if not CORNERS[corner] then corner = "top-right" end

    local out = {}
    if count <= 0 then return out end

    local isRight = corner == "top-right" or corner == "bottom-right"
    local isTop = corner == "top-right" or corner == "top-left"

    local x
    if isRight then
        x = viewport.w - margin - toastSize.w
    else
        x = margin
    end

    local step = toastSize.h + gap
    for i = 1, count do
        local offset = (i - 1) * step
        local y
        if isTop then
            y = margin + offset
        else
            y = viewport.h - margin - toastSize.h - offset
        end
        out[i] = { x = x, y = y }
    end

    return out
end

return M
