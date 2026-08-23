-- In-game verification harness. Not part of dist. Copy dist/main.lua into the
-- executor workspace with `python build/build.py --install`, then run this file
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

-- Every loadstring of the bundle returns a fresh Chroma module table, so an
-- external probe cannot reach THIS harness's Flags by re-loading the bundle.
-- Stashing the handle here means a probe can read Chroma.Flags directly.
getgenv().__chroma = Chroma

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
local combat = Win:Page({ Name = "Combat", Icon = "crosshair" })

local general = combat:Tab("General")
local gl, gr = general:Column(), general:Column()

local aim = gl:Container("Aimbot")
aim:Toggle({ Name = "Enabled", Flag = "aim_enabled", Default = true,
    Description = "Master switch. Hooks __namecall once at load, so toggling only flips a flag." })
aim:Toggle({ Name = "Silent aim", Flag = "aim_silent",
    Description = "Resolves the shot server-side without moving the camera." })
aim:Slider({ Name = "Field of view", Flag = "aim_fov", Min = 0, Max = 90, Default = 20, Unit = "°",
    Description = "Maximum angle from your crosshair that a target can be picked up at." })
aim:Slider({ Name = "Smoothing", Flag = "aim_smoothing", Min = 0, Max = 100, Default = 62 })
aim:Separator({ Text = "Delays" })
aim:Slider({ Name = "After kill", Flag = "aim_after_kill", Min = 0, Max = 1000, Default = 500, Unit = "ms" })

local target = gr:Container("Target")
target:Toggle({ Name = "Wall check", Flag = "target_wall_check", Default = true })
target:Toggle({ Name = "Target walkers", Flag = "target_walkers" })
target:Label({ Text = "Walkers are cheap to hit but rarely worth it." })
target:Slider({ Name = "Max distance", Flag = "target_max_distance", Min = 0, Max = 500, Default = 300 })

local weapons = combat:Tab("Weapons")
local wl = weapons:Column()
local pistols = wl:Container("Pistols")
pistols:Toggle({ Name = "Enabled", Flag = "pistols_enabled", Default = true })
pistols:Slider({ Name = "Hitchance", Flag = "pistols_hitchance", Min = 0, Max = 100, Default = 62, Unit = "%" })

--== page 2: no tabs, and a deliberately overfilled column to force scrolling ==--
local visuals = Win:Page({ Name = "Visuals", Icon = "eye" })
local vl, vr = visuals:Column(), visuals:Column()

-- 22 rows at 19px, plus the container title and padding, comes to roughly 450px
-- against ~374px of visible column at the default 640x420 window -- so this
-- genuinely overflows. 14 rows did not, which would have made the scrolling
-- check prove nothing.
local esp = vl:Container("Players")
for i = 1, 22 do
    esp:Toggle({ Name = "Option " .. i, Flag = "esp_option_" .. i, Default = i % 3 == 0,
        Description = i % 4 == 0 and ("Description for option " .. i ..
            ", long enough to wrap across more than one line in the tooltip.") or nil })
end

local world = vr:Container("World")
world:Toggle({ Name = "Fullbright", Flag = "world_fullbright", Default = true })
world:Slider({ Name = "Brightness", Flag = "world_brightness", Min = 0, Max = 10, Default = 2.5, Decimals = 1 })
world:Separator()
world:Toggle({ Name = "No fog", Flag = "world_no_fog" })

--== page 3: weighted columns ==--
local misc = Win:Page({ Name = "Misc", Icon = "boxes" })
local wide = misc:Column({ Weight = 2 })
local narrow = misc:Column()
wide:Container("Wide column"):Label({ Text = "This column has Weight = 2." })
narrow:Container("Narrow"):Label({ Text = "Weight = 1." })

--== page 4: M3 phase A widgets ==--
local m3 = Win:Page({ Name = "Widgets", Icon = "sliders-horizontal" })
local ml, mr = m3:Column(), m3:Column()

local picks = ml:Container("Dropdowns")
local hitbox = picks:Dropdown({ Name = "Hitbox", Flag = "m3_hitbox",
    Options = { "Head", "Torso", "Pelvis", "Arms", "Legs" },
    Default = "Head",
    Description = "Single-select: commits and closes on click." })
local parts = picks:Dropdown({ Name = "Hitboxes", Flag = "m3_hitboxes", Multi = true,
    Options = { "Head", "Torso", "Pelvis", "Arms", "Legs" },
    Default = { "Head", "Torso" },
    Description = "Multi-select: ticks a checkbox and stays open." })
-- Ten options forces the 8-row scroll limit.
picks:Dropdown({ Name = "Long list", Flag = "m3_long_list", Options = {
    "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" } })

local entry = mr:Container("Text and buttons")
local name = entry:TextBox({ Name = "Nickname", Flag = "m3_nickname", Placeholder = "anonymous", Default = "venuss" })
local count = entry:TextBox({ Name = "Rounds", Flag = "m3_rounds", Numeric = true, Default = "30" })
entry:Button({ Text = "Print widget state", Callback = function()
    print("[Chroma dev] hitbox:", hitbox:Get())
    print("[Chroma dev] parts:", table.concat(parts:Get(), ", "))
    print("[Chroma dev] name:", name:Get(), "count:", count:Get(), type(count:Get()))
end })
entry:Button({ Text = "Swap dropdown options", Callback = function()
    hitbox:SetOptions({ "Head", "Neck", "Chest" })
end })

local binds = ml:Container("Keybinds")
local trigger = binds:Keybind({ Name = "Trigger", Flag = "m3_trigger", Default = Enum.KeyCode.C, Mode = "Hold",
    Description = "Left-click to capture, Escape to clear, right-click for the mode menu." })
local aimKey = binds:Keybind({ Name = "Aim", Flag = "m3_aim", Default = Enum.UserInputType.MouseButton2,
    Mode = "Hold" })

local paint = mr:Container("Colours")
local boxColour = paint:Colorpicker({ Name = "Box", Flag = "m3_box_colour", Default = Color3.fromRGB(23, 184, 166),
    Description = "No alpha strip: this one has no Alpha option." })
local fillColour = paint:Colorpicker({ Name = "Fill", Flag = "m3_fill_colour", Default = Color3.fromRGB(255, 64, 64),
    Alpha = 0.4, Description = "Alpha strip enabled, with the chequerboard behind it." })

local presets = mr:Container("Presets")
presets:Label({ Text = "M4 wires this to real configs." })
local slots = presets:ListBox({ Flag = "m3_preset", Items = { "default", "legit", "rage", "hvh", "closet", "test", "spare" },
    Rows = 6, Default = "default" })
presets:Button({ Text = "Report", Callback = function()
    print("[Chroma dev] trigger:", tostring(trigger:Get()), trigger:GetMode(), "held:", trigger:IsHeld())
    print("[Chroma dev] aim held:", aimKey:IsHeld())
    print("[Chroma dev] box:", tostring(boxColour:Get()))
    local c, a = fillColour:Get()
    print("[Chroma dev] fill:", tostring(c), "alpha:", a)
    print("[Chroma dev] preset:", slots:Get())
end })

--== config manager ==--
local cfg = mr:Container("Config test")
cfg:Button({ Text = "Save 'probe'", Callback = function()
    print("[Chroma dev] save:", Win:SaveConfig("probe"))
end })
cfg:Button({ Text = "Load 'probe'", Callback = function()
    print("[Chroma dev] load:", Win:LoadConfig("probe"))
end })
cfg:Button({ Text = "List configs", Callback = function()
    print("[Chroma dev] configs:", table.concat(Win:ListConfigs(), ", "))
end })
cfg:Button({ Text = "Dump flags", Callback = function()
    print("[Chroma dev] hitbox:", Chroma.Flags.m3_hitbox,
        "rounds:", Chroma.Flags.m3_rounds,
        "trigger:", tostring(Chroma.Flags.m3_trigger))
    print("[Chroma dev] trigger held:", Win:Flag("m3_trigger"):IsHeld())
end })

-- Deliberately mistyped: the branch that warns and falls back to a letter.
Win:Page({ Name = "Fake", Icon = "not-a-real-icon" })

print("[Chroma dev] version", Chroma.version)
print("[Chroma dev] parent kind:", Chroma.root.parentKind)
print("[Chroma dev] pages:", #Win._pages)
