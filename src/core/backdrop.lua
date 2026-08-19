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

--== Instance side. Never runs under Lua 5.4; Luau syntax is fine here. ==--

local IMAGE_ASPECT = 1024 / 576
-- "forest background" -- the IMAGE (AssetTypeId 1), not the Decal that wraps it.
--
-- Use the texture id, never the decal id. Uploading an image to Roblox creates
-- two assets: a Decal (type 13) and the Image (type 1) it points at. An
-- ImageLabel needs the Image. The Creator Store page shows the decal id; the
-- "copy texture ID" button gives this one. Recoverable in-game too, via
-- getobjects("rbxassetid://<decal>")[1].Texture.
--
-- The two are moderated SEPARATELY, and the decal clears first: at the time of
-- writing the decal reported Completed while this image was still Pending. A
-- Pending image renders blank, which is what made the first upload look broken.
local DEFAULT_IMAGE = "rbxassetid://109006147881359"

local Backdrop = {}
Backdrop.__index = Backdrop

-- opts: Image, Shift, Count, TopBias, Span, MaxSize
function M.new(root, holder, opts)
    opts = opts or {}

    local self = setmetatable({
        _root = root,
        _holder = holder,
        _shift = opts.Shift or 0,
        _aspect = opts.Aspect or IMAGE_ASPECT,
        _topBias = opts.TopBias or 2.2,
        _span = opts.Span or 0.55,
        _rng = Random.new(),
        _stars = {},
        _w = holder.AbsoluteSize.X,
        _h = holder.AbsoluteSize.Y,
        _paused = false,
    }, Backdrop)

    local image = Instance.new("ImageLabel")
    image.Name = "backdrop"
    image.BackgroundTransparency = 1
    image.Image = opts.Image or DEFAULT_IMAGE
    image.ScaleType = Enum.ScaleType.Stretch
    image.AnchorPoint = Vector2.new(0.5, 1)
    image.Position = UDim2.new(0.5, 0, 1, 0)
    image.ZIndex = 1
    image.Parent = holder
    self._image = image
    root:keep(image)

    self._maxSize = opts.MaxSize or 3

    -- ONE cleanup closure covering the whole pool, registered once. A keep per
    -- star would grow the junk list every time setCount raises the count from
    -- the settings slider -- and the per-star keeps were always redundant, since
    -- every dot is a descendant of the ScreenGui that Unload destroys anyway.
    root:keep(function()
        for i = 1, #self._stars do
            self._stars[i].obj:Destroy()
        end
        self._stars = {}
    end)

    self:setCount(opts.Count or 34)

    self:resize(self._w, self._h)
    return self
end

function Backdrop:_addStar()
    local size = self._rng:NextInteger(1, self._maxSize)
    local dot = Instance.new("Frame")
    dot.Name = "star"
    dot.Size = UDim2.fromOffset(size, size)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BackgroundTransparency = 1
    dot.BorderSizePixel = 0
    dot.ZIndex = 2
    dot.Parent = self._holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    local star = { obj = dot, size = size }
    self:_reseed(star, true)
    table.insert(self._stars, star)
end

-- Grows or shrinks the pool. Called at construction and by the settings slider.
function Backdrop:setCount(count)
    if type(count) ~= "number" then return end
    count = math.floor(count)
    if count < 0 then count = 0 end

    while #self._stars > count do
        local star = table.remove(self._stars)
        star.obj:Destroy()
    end
    while #self._stars < count do
        self:_addStar()
    end
end

function Backdrop:_reseed(star, first)
    local rng = self._rng
    star.y = self._h * (rng:NextNumber() ^ self._topBias) * self._span
    star.x = rng:NextNumber() * self._w
    star.vx = rng:NextNumber(-2.2, 2.2)
    star.vy = -rng:NextNumber(1.0, 4.0)
    star.peak = 0.12 + rng:NextNumber() * 0.42
    star.tWait = rng:NextNumber(0.3, 4.5)
    star.tIn = rng:NextNumber(0.35, 1.3)
    star.tHold = rng:NextNumber(0.4, 3.0)
    star.tOut = rng:NextNumber(0.4, 1.6)
    if first then
        -- Stagger initial phases, otherwise every star fades in together on the
        -- first frame and the randomness is invisible for the first cycle.
        star.phase = rng:NextInteger(1, 4)
        star.clock = rng:NextNumber() * 2
    else
        star.phase = 1
        star.clock = 0
    end
end

function Backdrop:setImage(image)
    self._image.Image = image
end

function Backdrop:setShift(shift)
    self._shift = shift
    self:resize(self._w, self._h)
end

function Backdrop:resize(w, h)
    local prevW, prevH = self._w, self._h
    self._w, self._h = w, h
    local iw, ih, offset = M.computeCover(w, h, self._aspect, self._shift)
    self._image.Size = UDim2.fromOffset(math.ceil(iw), math.ceil(ih))
    self._image.Position = UDim2.new(0.5, 0, 1, math.floor(offset))

    -- AbsoluteSize is (0, 0) until the holder has been rendered at least once,
    -- so the star pool in M.new is always seeded against zeros. The first real
    -- resize (called with the holder's actual size) is what actually places
    -- the stars; reseed them fresh instead of trying to scale up from 0.
    if prevW == 0 or prevH == 0 then
        for i = 1, #self._stars do
            self:_reseed(self._stars[i], true)
        end
    else
        local sx = w / prevW
        local sy = h / prevH
        for i = 1, #self._stars do
            local s = self._stars[i]
            s.x = s.x * sx
            s.y = s.y * sy
        end
    end
end

function Backdrop:setPaused(paused)
    if self._paused == paused then return end
    self._paused = paused
    if paused then
        for i = 1, #self._stars do
            self._stars[i].obj.BackgroundTransparency = 1
        end
    end
end

-- Four-phase cycle: 1 waiting (invisible), 2 fading in, 3 holding, 4 fading out.
function Backdrop:step(dt)
    if self._paused then return end
    local stars = self._stars
    for i = 1, #stars do
        local s = stars[i]
        s.clock = s.clock + dt

        if s.phase == 1 then
            s.obj.BackgroundTransparency = 1
            if s.clock >= s.tWait then
                s.clock = 0
                s.phase = 2
            end
        elseif s.phase == 2 then
            local k = math.min(s.clock / s.tIn, 1)
            s.obj.BackgroundTransparency = 1 - (1 - s.peak) * k
            if k >= 1 then
                s.clock = 0
                s.phase = 3
            end
        elseif s.phase == 3 then
            s.obj.BackgroundTransparency = s.peak
            if s.clock >= s.tHold then
                s.clock = 0
                s.phase = 4
            end
        else
            local k = math.min(s.clock / s.tOut, 1)
            s.obj.BackgroundTransparency = s.peak + (1 - s.peak) * k
            if k >= 1 then
                self:_reseed(s, false)
            end
        end

        if s.phase > 1 then
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            if s.x < -s.size then
                s.x = self._w
            elseif s.x > self._w then
                s.x = -s.size
            end
            if s.y < -s.size then
                self:_reseed(s, false)
            end
        end

        s.obj.Position = UDim2.fromOffset(s.x, s.y)
    end
end

return M
