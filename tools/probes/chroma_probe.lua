-- Chroma design probe. Re-run with: dofile("chroma_probe.lua")
-- Cleans up its own previous instance via getgenv (Potassium does not share _G).

local G = getgenv()
if G.__chromaProbe then pcall(G.__chromaProbe) end

local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local junk = {}
local function reg(f) table.insert(junk, f) end
local function cleanup()
    for i = #junk, 1, -1 do pcall(junk[i]) end
    junk = {}
    G.__chromaProbe = nil
end
G.__chromaProbe = cleanup

local parent = (gethui and gethui()) or game:GetService("CoreGui")
local rng = Random.new()

--==================== tunables ====================
local CFG = {
    W = 360, H = 270,
    BAND = 20,              -- px of window below the containers, where the scene shows
    BOX_ALPHA = 0.15,       -- container transparency
    -- Fraction of image height to slide the backdrop DOWN. Kept at 0: the treeline
    -- reads through the translucent containers, so it does not need forcing into
    -- the band. Left as a knob in case a future backdrop needs recentring.
    BACKDROP_SHIFT = 0,
    STARS = 34,
    STAR_TOP_BIAS = 2.2,    -- higher = more tightly clustered at the top
    STAR_SPAN = 0.55,       -- stars occupy this fraction of window height
    STAR_MAX_SIZE = 3,
    BACKDROP = "rbxassetid://122415002143640",   -- uploaded night backdrop
    ACCENT = Color3.fromRGB(23, 184, 166),
}
--==================================================

local IMG_ASPECT = 1024 / 576
local ACC = CFG.ACCENT
-- accept either an uploaded decal id or a local workspace file
local asset = CFG.BACKDROP:match("^rbxassetid://") and CFG.BACKDROP or getcustomasset(CFG.BACKDROP)

local gui = Instance.new("ScreenGui")
gui.Name = "chromaProbe"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483000
gui.Parent = parent
reg(function() gui:Destroy() end)

local state = { w = CFG.W, h = CFG.H }

local f = Instance.new("Frame")
f.Size = UDim2.fromOffset(CFG.W, CFG.H)
f.Position = UDim2.new(0.5, -CFG.W // 2, 0.5, -CFG.H // 2)
f.BackgroundColor3 = Color3.fromRGB(14, 17, 19)
f.BorderSizePixel = 0
f.ClipsDescendants = true
f.Parent = gui

local bd = Instance.new("ImageLabel")
bd.BackgroundTransparency = 1
bd.Image = asset
bd.ScaleType = Enum.ScaleType.Stretch
bd.AnchorPoint = Vector2.new(0.5, 1)
bd.Position = UDim2.new(0.5, 0, 1, 0)
bd.ZIndex = 1
bd.Parent = f

local function fit(w, h)
    local iw, ih
    if (w / h) > IMG_ASPECT then iw, ih = w, w / IMG_ASPECT else iw, ih = h * IMG_ASPECT, h end
    -- Oversize by the shift amount, then push down by the same, so the top edge
    -- still lands exactly at the window top and nothing is left uncovered.
    local s = CFG.BACKDROP_SHIFT
    bd.Size = UDim2.fromOffset(math.ceil(iw * (1 + s)), math.ceil(ih * (1 + s)))
    bd.Position = UDim2.new(0.5, 0, 1, math.floor(ih * s))
end
fit(CFG.W, CFG.H)

--==================== stars ====================
local stars = {}

local function reseed(s, first)
    local r = rng:NextNumber()
    s.y = state.h * (r ^ CFG.STAR_TOP_BIAS) * CFG.STAR_SPAN
    s.x = rng:NextNumber() * state.w
    s.vx = rng:NextNumber(-2.2, 2.2)
    s.vy = -rng:NextNumber(1.0, 4.0)
    s.peak = 0.12 + rng:NextNumber() * 0.42
    s.tWait = rng:NextNumber(0.3, 4.5)
    s.tIn = rng:NextNumber(0.35, 1.3)
    s.tHold = rng:NextNumber(0.4, 3.0)
    s.tOut = rng:NextNumber(0.4, 1.6)
    if first then
        s.phase = rng:NextInteger(1, 4)
        s.clock = rng:NextNumber() * 2
    else
        s.phase = 1
        s.clock = 0
    end
end

for i = 1, CFG.STARS do
    local sz = rng:NextInteger(1, CFG.STAR_MAX_SIZE)
    local d = Instance.new("Frame")
    d.Size = UDim2.fromOffset(sz, sz)
    d.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    d.BackgroundTransparency = 1
    d.BorderSizePixel = 0
    d.ZIndex = 2
    d.Parent = f
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = d
    local s = { obj = d, sz = sz }
    reseed(s, true)
    stars[i] = s
end

--==================== chrome ====================
local st = Instance.new("UIStroke") st.Color = ACC st.Thickness = 1 st.Parent = f

local hair = Instance.new("Frame")
hair.Size = UDim2.new(1, 0, 0, 2)
hair.BorderSizePixel = 0
hair.ZIndex = 12
hair.Parent = f
local hg = Instance.new("UIGradient")
hg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(216, 216, 74)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(126, 203, 122)),
    ColorSequenceKeypoint.new(1, ACC),
})
hg.Parent = hair

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -14, 0, 20)
title.Position = UDim2.fromOffset(8, 5)
title.Font = Enum.Font.Code
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 242, 242)
title.Text = "CHROMA"
title.ZIndex = 11
title.Parent = f

local rail = Instance.new("Frame")
rail.Size = UDim2.new(0, 28, 0, CFG.H - CFG.BAND - 28)
rail.Position = UDim2.fromOffset(0, 28)
rail.BackgroundColor3 = Color3.fromRGB(20, 22, 23)
rail.BackgroundTransparency = 0.12
rail.BorderSizePixel = 0
rail.ZIndex = 5
rail.Parent = f
for i = 1, 5 do
    local d = Instance.new("Frame")
    d.Size = UDim2.fromOffset(10, 10)
    d.Position = UDim2.fromOffset(9, 8 + (i - 1) * 17)
    d.BackgroundColor3 = (i == 1) and ACC or Color3.fromRGB(104, 110, 112)
    d.BorderSizePixel = 0
    d.ZIndex = 6
    d.Parent = rail
end

local box = Instance.new("Frame")
box.Size = UDim2.new(1, -46, 0, CFG.H - CFG.BAND - 40)
box.Position = UDim2.fromOffset(36, 30)
box.BackgroundColor3 = Color3.fromRGB(23, 25, 26)
box.BackgroundTransparency = CFG.BOX_ALPHA
box.BorderSizePixel = 0
box.ClipsDescendants = true
box.ZIndex = 6
box.Parent = f
local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(46, 50, 52) bs.Thickness = 1 bs.Parent = box

for i, name in ipairs({ "Enabled", "Silent aim", "Wall check", "Auto fire", "Randomize", "Only armed", "Target walkers" }) do
    local r = Instance.new("TextLabel")
    r.BackgroundTransparency = 1
    r.Size = UDim2.new(1, -14, 0, 15)
    r.Position = UDim2.fromOffset(7, 4 + (i - 1) * 19)
    r.Font = Enum.Font.Code
    r.TextSize = 12
    r.TextXAlignment = Enum.TextXAlignment.Left
    r.TextColor3 = Color3.fromRGB(190, 194, 195)
    r.Text = name
    r.ZIndex = 7
    r.Parent = box
    local cb = Instance.new("Frame")
    cb.Size = UDim2.fromOffset(7, 7)
    cb.Position = UDim2.new(1, -14, 0, 8 + (i - 1) * 19)
    cb.BorderSizePixel = 0
    cb.ZIndex = 7
    cb.BackgroundColor3 = (i % 2 == 1) and ACC or Color3.fromRGB(37, 41, 43)
    cb.Parent = box
end

--==================== drag + resize ====================
local function makeDrag(handle, onMove)
    local dragging, startPos, startVal = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startPos = UIS:GetMouseLocation()
            startVal = onMove(nil, nil)
        end
    end)
    local c1 = UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            onMove(UIS:GetMouseLocation() - startPos, startVal)
        end
    end)
    local c2 = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    reg(function() c1:Disconnect() c2:Disconnect() end)
end

local titleBar = Instance.new("TextButton")
titleBar.Size = UDim2.new(1, 0, 0, 26)
titleBar.BackgroundTransparency = 1
titleBar.Text = ""
titleBar.AutoButtonColor = false
titleBar.ZIndex = 10
titleBar.Parent = f
makeDrag(titleBar, function(delta, start)
    if not delta then return f.AbsolutePosition end
    f.Position = UDim2.fromOffset(start.X + delta.X, start.Y + delta.Y)
end)

local grip = Instance.new("TextButton")
grip.Size = UDim2.fromOffset(12, 12)
grip.Position = UDim2.new(1, -13, 1, -13)
grip.BackgroundColor3 = ACC
grip.BackgroundTransparency = 0.35
grip.BorderSizePixel = 0
grip.Text = ""
grip.AutoButtonColor = false
grip.ZIndex = 13
grip.Parent = f
makeDrag(grip, function(delta, start)
    if not delta then return f.AbsoluteSize end
    local nw = math.clamp(start.X + delta.X, 240, 900)
    local nh = math.clamp(start.Y + delta.Y, 190, 620)
    f.Size = UDim2.fromOffset(nw, nh)
    state.w, state.h = nw, nh
    rail.Size = UDim2.new(0, 28, 0, nh - CFG.BAND - 28)
    box.Size = UDim2.new(1, -46, 0, nh - CFG.BAND - 40)
    fit(nw, nh)
end)

--==================== star lifecycle ====================
local conn = RS.RenderStepped:Connect(function(dt)
    for _, s in ipairs(stars) do
        s.clock += dt
        if s.phase == 1 then
            s.obj.BackgroundTransparency = 1
            if s.clock >= s.tWait then s.clock = 0 s.phase = 2 end
        elseif s.phase == 2 then
            local k = math.min(s.clock / s.tIn, 1)
            s.obj.BackgroundTransparency = 1 - (1 - s.peak) * k
            if k >= 1 then s.clock = 0 s.phase = 3 end
        elseif s.phase == 3 then
            s.obj.BackgroundTransparency = s.peak
            if s.clock >= s.tHold then s.clock = 0 s.phase = 4 end
        else
            local k = math.min(s.clock / s.tOut, 1)
            s.obj.BackgroundTransparency = s.peak + (1 - s.peak) * k
            if k >= 1 then reseed(s, false) end
        end
        if s.phase > 1 then
            s.x += s.vx * dt
            s.y += s.vy * dt
        end
        s.obj.Position = UDim2.fromOffset(s.x, s.y)
    end
end)
reg(function() conn:Disconnect() end)

local kc = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Delete then cleanup() end
end)
reg(function() kc:Disconnect() end)

print(string.format("[CP] probe up. band=%d of %d, box alpha=%.2f, %d stars. drag title to move, corner to resize, Delete to clear",
    CFG.BAND, CFG.H, CFG.BOX_ALPHA, CFG.STARS))
