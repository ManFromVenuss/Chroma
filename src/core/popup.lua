-- Popup: the pure placement maths, plus (from the next task) the single-slot
-- overlay manager.
--
-- place() is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

M.GAP = 2       -- pixels between the control slot and the popup
M.MARGIN = 6    -- minimum distance from any screen edge

-- Places a popup against the rect of the control that opened it.
--
-- Popups align to the RIGHT edge of the control slot and extend leftward. The
-- colorpicker is 176px against a 110px slot, so left-aligning would hang it out
-- over the neighbouring column; right-aligning keeps it inside the window.
--
-- Everything here is in the anchor's coordinate space, exactly as Tooltip.place
-- is -- GetMouseLocation never enters the calculation, so the GUI-inset
-- mismatch that caused four earlier bugs cannot happen.
function M.place(anchor, size, viewport, gap, margin)
    gap = gap or M.GAP
    margin = margin or M.MARGIN

    local x = anchor.x + anchor.w - size.w
    if x + size.w > viewport.w - margin then
        x = viewport.w - margin - size.w
    end
    if x < margin then x = margin end

    local y = anchor.y + anchor.h + gap
    if y + size.h > viewport.h - margin then
        -- Flip ABOVE the anchor rather than clamping upward: clamping would
        -- slide the popup over the control that opened it, which reads as the
        -- menu having eaten the row.
        y = anchor.y - size.h - gap
    end
    if y < margin then y = margin end

    return x, y
end

return M
