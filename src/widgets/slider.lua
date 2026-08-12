-- Slider: the pure value/fraction maths, plus (from a later task) the 2px track.
-- The maths half is unit tested, so keep it in the Lua 5.4 / Luau intersection:
-- no compound assignment, no bitwise ops, no goto.

local M = {}

-- Where `value` sits on the track, as 0..1. Clamped, and safe when min == max.
function M.fractionOf(value, min, max)
    if max <= min then return 0 end
    local f = (value - min) / (max - min)
    if f < 0 then return 0 end
    if f > 1 then return 1 end
    return f
end

-- The value at 0..1 along the track, rounded to `decimals` places.
-- Note: `mult` is a float, so borderline values can round the "wrong" way
-- -- e.g. 0.145 at 2 decimals yields 0.14, since 0.145 * 100 + 0.5 evaluates
-- to 14.999999999999998 rather than 15. Fixing this needs decimal
-- arithmetic; not worth it for a slider label being one ulp out.
function M.valueAt(fraction, min, max, decimals)
    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end
    local raw = min + (max - min) * fraction
    -- Decimals is consumer-supplied, so normalise rather than trusting it:
    -- a negative value would invert the rounding and a fractional one would
    -- silently produce nonsense.
    decimals = math.floor(decimals or 0)
    if decimals < 0 then decimals = 0 end
    local mult = 10 ^ decimals
    -- floor(x + 0.5) rounds .5 up for positives and, for negatives, toward
    -- zero -- which is what a slider should do: dragging to the middle of
    -- -9..0 lands on -4, not -5.
    return math.floor(raw * mult + 0.5) / mult
end

function M.format(value, decimals, unit)
    -- Decimals is consumer-supplied, so normalise rather than trusting it: a
    -- negative or fractional value produces an invalid format specification
    -- and would throw at runtime.
    decimals = math.floor(decimals or 0)
    if decimals < 0 then decimals = 0 end
    local s = string.format("%." .. tostring(decimals) .. "f", value)
    if unit and unit ~= "" then s = s .. unit end
    return s
end

return M
