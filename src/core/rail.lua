-- Rail: pure easeExpand for the hover tween, plus (from the next task) the
-- hover watcher and instance-side tween.
--
-- Pure: Lua 5.4 / Luau intersection.

local M = {}

-- Ease-out quart. Chosen to match the window's own open animation, which uses
-- Enum.EasingStyle.Quint / EasingDirection.Out via TweenService; a quart here
-- is close enough that the two motions read as belonging to the same UI.
--
-- The TweenService codepath is what actually runs in-game; this exists so a
-- caller that wants to sample the curve outside a Tween has one endpoint.
function M.easeExpand(from, to, t)
    if t <= 0 then return from end
    if t >= 1 then return to end
    local eased = 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t)
    return from + (to - from) * eased
end

return M
