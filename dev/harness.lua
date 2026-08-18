-- In-game verification harness. Not part of dist. Copy dist/main.lua into the
-- Potassium workspace with `python build/build.py --install`, then run this file
-- through the executor.
--
-- Kept out of src/ deliberately: it must not end up in the bundle.
local Chroma = loadstring(readfile("chroma_dist.lua"))()

if getgenv().__chromaDev then
    pcall(getgenv().__chromaDev)
end

-- Register the unload handle BEFORE constructing. If Chroma:Window throws part
-- way through, Root has already created a ScreenGui, and without a handle there
-- is no way to reach it -- the first in-game run leaked exactly that way.
getgenv().__chromaDev = function() pcall(function() Chroma:Unload() end) end

-- No Backdrop override: the library's own default asset is verified working, so
-- dev runs on exactly what a consumer would get. Confirmed in-game by rendering
-- the image id, its wrapping decal id and the local PNG side by side -- the
-- image id and the local file matched, the decal id was blank.
local Win = Chroma:Window({
    Name = "CHROMA",
    Size = Vector2.new(640, 420),
    ToggleKey = Enum.KeyCode.Insert,
    Accent = "RGB",
    AccentSpeed = 0.15,
})

--== page 1: sub-tabs, both widget types, descriptions ==--
local combat = Win:Page({ Name = "Combat" })

local general = combat:Tab("General")
local gl, gr = general:Column(), general:Column()

local aim = gl:Container("Aimbot")
aim:Toggle({ Name = "Enabled", Default = true,
    Description = "Master switch. Hooks __namecall once at load, so toggling only flips a flag." })
aim:Toggle({ Name = "Silent aim",
    Description = "Resolves the shot server-side without moving the camera." })
aim:Slider({ Name = "Field of view", Min = 0, Max = 90, Default = 20, Unit = "°",
    Description = "Maximum angle from your crosshair that a target can be picked up at." })
aim:Slider({ Name = "Smoothing", Min = 0, Max = 100, Default = 62 })
aim:Separator({ Text = "Delays" })
aim:Slider({ Name = "After kill", Min = 0, Max = 1000, Default = 500, Unit = "ms" })

local target = gr:Container("Target")
target:Toggle({ Name = "Wall check", Default = true })
target:Toggle({ Name = "Target walkers" })
target:Label({ Text = "Walkers are cheap to hit but rarely worth it." })
target:Slider({ Name = "Max distance", Min = 0, Max = 500, Default = 300 })

local weapons = combat:Tab("Weapons")
local wl = weapons:Column()
local pistols = wl:Container("Pistols")
pistols:Toggle({ Name = "Enabled", Default = true })
pistols:Slider({ Name = "Hitchance", Min = 0, Max = 100, Default = 62, Unit = "%" })

--== page 2: no tabs, and a deliberately overfilled column to force scrolling ==--
local visuals = Win:Page({ Name = "Visuals" })
local vl, vr = visuals:Column(), visuals:Column()

-- 22 rows at 19px, plus the container title and padding, comes to roughly 450px
-- against ~374px of visible column at the default 640x420 window -- so this
-- genuinely overflows. 14 rows did not, which would have made the scrolling
-- check prove nothing.
local esp = vl:Container("Players")
for i = 1, 22 do
    esp:Toggle({ Name = "Option " .. i, Default = i % 3 == 0,
        Description = i % 4 == 0 and ("Description for option " .. i ..
            ", long enough to wrap across more than one line in the tooltip.") or nil })
end

local world = vr:Container("World")
world:Toggle({ Name = "Fullbright", Default = true })
world:Slider({ Name = "Brightness", Min = 0, Max = 10, Default = 2.5, Decimals = 1 })
world:Separator()
world:Toggle({ Name = "No fog" })

--== page 3: weighted columns ==--
local misc = Win:Page({ Name = "Misc" })
local wide = misc:Column({ Weight = 2 })
local narrow = misc:Column()
wide:Container("Wide column"):Label({ Text = "This column has Weight = 2." })
narrow:Container("Narrow"):Label({ Text = "Weight = 1." })

--== page 4: M3 phase A widgets ==--
local m3 = Win:Page({ Name = "Widgets" })
local ml, mr = m3:Column(), m3:Column()

local picks = ml:Container("Dropdowns")
local hitbox = picks:Dropdown({ Name = "Hitbox", Options = { "Head", "Torso", "Pelvis", "Arms", "Legs" },
    Default = "Head",
    Description = "Single-select: commits and closes on click." })
local parts = picks:Dropdown({ Name = "Hitboxes", Multi = true,
    Options = { "Head", "Torso", "Pelvis", "Arms", "Legs" },
    Default = { "Head", "Torso" },
    Description = "Multi-select: ticks a checkbox and stays open." })
-- Ten options forces the 8-row scroll limit.
picks:Dropdown({ Name = "Long list", Options = {
    "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" } })

local entry = mr:Container("Text and buttons")
local name = entry:TextBox({ Name = "Nickname", Placeholder = "anonymous", Default = "venuss" })
local count = entry:TextBox({ Name = "Rounds", Numeric = true, Default = "30" })
entry:Button({ Text = "Print widget state", Callback = function()
    print("[Chroma dev] hitbox:", hitbox:Get())
    print("[Chroma dev] parts:", table.concat(parts:Get(), ", "))
    print("[Chroma dev] name:", name:Get(), "count:", count:Get(), type(count:Get()))
end })
entry:Button({ Text = "Swap dropdown options", Callback = function()
    hitbox:SetOptions({ "Head", "Neck", "Chest" })
end })

print("[Chroma dev] version", Chroma.version)
print("[Chroma dev] parent kind:", Chroma.root.parentKind)
print("[Chroma dev] pages:", #Win._pages)
