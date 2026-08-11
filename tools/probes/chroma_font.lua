-- Chroma font probe. Re-run with: dofile("chroma_font.lua")
-- Also trials the separated, translucent title bar.

local G = getgenv()
if G.__chromaFont then pcall(G.__chromaFont) end

local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local junk = {}
local function reg(f) table.insert(junk, f) end
local function cleanup()
    for i = #junk, 1, -1 do pcall(junk[i]) end
    junk = {}
    G.__chromaFont = nil
end
G.__chromaFont = cleanup

local ACC = Color3.fromRGB(23, 184, 166)
local parent = (gethui and gethui()) or game:GetService("CoreGui")

-- Build a Roblox font-family JSON pointing at a local ttf, the way custom fonts
-- have to be loaded: FontFace wants a family descriptor, never a raw ttf.
local function customFamily(name, regular, bold)
    local faces = {
        { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(regular) },
    }
    if bold then
        table.insert(faces, { name = "Bold", weight = 700, style = "normal", assetId = getcustomasset(bold) })
    end
    local jsonPath = "chroma_font_" .. name:lower() .. ".json"
    writefile(jsonPath, HttpService:JSONEncode({ name = name, faces = faces }))
    return Font.new(getcustomasset(jsonPath), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end

local candidates = {}

local okV, resV = pcall(customFamily, "Verdana", "chroma_verdana.ttf", "chroma_verdanab.ttf")
table.insert(candidates, { label = "Verdana (custom ttf)", font = okV and resV or nil, err = not okV and tostring(resV) or nil })

local okT, resT = pcall(customFamily, "Tahoma", "chroma_tahoma.ttf", "chroma_tahomabd.ttf")
table.insert(candidates, { label = "Tahoma (custom ttf)", font = okT and resT or nil, err = not okT and tostring(resT) or nil })

for _, e in ipairs({ Enum.Font.Code, Enum.Font.SourceSans, Enum.Font.Arimo, Enum.Font.Ubuntu, Enum.Font.Gotham, Enum.Font.Arial }) do
    local ok, fnt = pcall(Font.fromEnum, e)
    table.insert(candidates, { label = e.Name .. " (built-in)", font = ok and fnt or nil, err = not ok and tostring(fnt) or nil })
end

print("[FONT] verdana ok:", okV, "tahoma ok:", okT)
if not okV then print("[FONT] verdana err:", resV) end

--==================== window ====================
local W = 560
local BAR = 24
local GAP = 4

local gui = Instance.new("ScreenGui")
gui.Name = "chromaFont"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483000
gui.Parent = parent
reg(function() gui:Destroy() end)

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(W, 30 + #candidates * 46 + BAR + GAP + 24)
root.Position = UDim2.new(0.5, -W // 2, 0.5, -260)
root.BackgroundTransparency = 1
root.Parent = gui

-- SEPARATED, translucent title bar: its own strip, its own fill, detached by a gap
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, BAR)
bar.BackgroundColor3 = Color3.fromRGB(26, 30, 33)
bar.BackgroundTransparency = 0.35
bar.BorderSizePixel = 0
bar.Parent = root
local barStroke = Instance.new("UIStroke")
barStroke.Color = ACC
barStroke.Transparency = 0.45
barStroke.Thickness = 1
barStroke.Parent = bar

local hair = Instance.new("Frame")
hair.Size = UDim2.new(1, 0, 0, 2)
hair.BorderSizePixel = 0
hair.ZIndex = 4
hair.Parent = bar
local hg = Instance.new("UIGradient")
hg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(216, 216, 74)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(126, 203, 122)),
    ColorSequenceKeypoint.new(1, ACC),
})
hg.Parent = hair

local barTitle = Instance.new("TextLabel")
barTitle.BackgroundTransparency = 1
barTitle.Size = UDim2.new(1, -16, 1, 0)
barTitle.Position = UDim2.fromOffset(8, 1)
barTitle.Font = Enum.Font.Code
barTitle.TextSize = 12
barTitle.TextXAlignment = Enum.TextXAlignment.Left
barTitle.TextColor3 = Color3.fromRGB(242, 244, 244)
barTitle.Text = "CHROMA   -   font candidates"
barTitle.ZIndex = 3
barTitle.Parent = bar

-- body, detached from the bar by GAP
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -(BAR + GAP))
body.Position = UDim2.fromOffset(0, BAR + GAP)
body.BackgroundColor3 = Color3.fromRGB(19, 22, 24)
body.BackgroundTransparency = 0.10
body.BorderSizePixel = 0
body.ClipsDescendants = true
body.Parent = root
local bodyStroke = Instance.new("UIStroke")
bodyStroke.Color = ACC
bodyStroke.Thickness = 1
bodyStroke.Parent = body

local SAMPLE = "Enabled  Silent aim  FOV 20deg  Hitchance 62  abcdeg 0123456789"

for i, cand in ipairs(candidates) do
    local y = 8 + (i - 1) * 46

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Size = UDim2.new(1, -16, 0, 12)
    name.Position = UDim2.fromOffset(10, y)
    name.Font = Enum.Font.Code
    name.TextSize = 11
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextColor3 = ACC
    name.Text = cand.label .. (cand.font and "" or "   [FAILED: " .. tostring(cand.err) .. "]")
    name.Parent = body

    if cand.font then
        for j, size in ipairs({ 11, 12, 13 }) do
            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(1, -20, 0, 11)
            row.Position = UDim2.fromOffset(16, y + 12 + (j - 1) * 11)
            row.FontFace = cand.font
            row.TextSize = size
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextColor3 = Color3.fromRGB(190, 194, 195)
            row.Text = size .. "px   " .. SAMPLE
            row.Parent = body
        end
    end

    local rule = Instance.new("Frame")
    rule.Size = UDim2.new(1, -20, 0, 1)
    rule.Position = UDim2.fromOffset(10, y + 42)
    rule.BackgroundColor3 = Color3.fromRGB(44, 48, 50)
    rule.BorderSizePixel = 0
    rule.Parent = body
end

-- drag by the bar
local dragging, startPos, startVal = false, nil, nil
bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        startPos = UIS:GetMouseLocation()
        startVal = root.AbsolutePosition
    end
end)
local c1 = UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = UIS:GetMouseLocation() - startPos
        root.Position = UDim2.fromOffset(startVal.X + d.X, startVal.Y + d.Y)
    end
end)
local c2 = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
reg(function() c1:Disconnect() c2:Disconnect() end)

local kc = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Delete then cleanup() end
end)
reg(function() kc:Disconnect() end)

print("[FONT] window up with", #candidates, "candidates. Delete to clear")
