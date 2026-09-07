# Chroma

A UI library for Roblox executor scripts, styled after gamesense: flat, near-black, 1px borders,
no corner radius, and an animated RGB accent.

Consumers load one generated file. There is nothing to install and no dependencies.

---

## Status

**Working, and in use. Not finished.** The API below is stable enough to build on, but Chroma is
still gaining features milestone by milestone and small breaking changes are possible until 1.0.

| | |
| --- | --- |
| Version | 0.1.0 |
| Widgets | Label, Separator, Toggle, Slider, Dropdown, TextBox, Button, Keybind, Colorpicker, ListBox |
| Tested against | Potassium |
| Unit tests | 97, covering every module that touches no Roblox instance |

### Progress

- [x] **Window shell** — separate translucent title bar, icon rail, drag, resize, two-stage open
      and close animation, custom cross cursor, forest backdrop with drifting star particles
- [x] **Layout** — pages, sub-tabs, independently scrolling columns, auto-sizing containers,
      `(?)` hover tooltips
- [x] **Widgets** — the ten above, a single-slot popup overlay, keybind capture, and a built-in
      settings page that configures Chroma itself
- [ ] **Config manager** — saving, loading and listing configs; saved colours in the colorpicker
- [ ] **Icons** — Lucide icons for rail entries and rows
- [ ] **Global search** — jump to any widget from the title bar

---

## Using it

```lua
local Chroma = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManFromVenuss/Chroma/main/dist/main.lua"))()

local Window = Chroma:Window({
    Name = "MY SCRIPT",
    Size = Vector2.new(640, 420),
    ToggleKey = Enum.KeyCode.Insert,
})

local page = Window:Page({ Name = "Combat" })
local left, right = page:Column(), page:Column()

local aimbot = left:Container("Aimbot")

aimbot:Toggle({
    Name = "Enabled",
    Default = true,
    Description = "Shown when you hover the (?) beside the name.",
    Callback = function(on) print("aimbot:", on) end,
})

aimbot:Slider({
    Name = "Field of view",
    Min = 0, Max = 90, Default = 20, Unit = "°",
    Callback = function(v) print("fov:", v) end,
})
```

Press `Insert` to show and hide the menu. Call `Chroma:Unload()` to remove it completely.

### Structure

A window holds pages, a page holds columns (or sub-tabs, which each hold columns), a column holds
containers, and a container holds widgets:

```lua
local page  = Window:Page({ Name = "Visuals" })   -- an entry in the icon rail
local tab   = page:Tab("Players")                 -- optional; omit for a simple page
local col   = tab:Column({ Weight = 2 })          -- Weight sets relative width, default 1
local box   = col:Container("ESP")                -- a titled, bordered group
box:Toggle({ Name = "Boxes" })
```

Columns scroll independently once their contents overflow. Add columns to the page directly when a
page has no sub-tabs; once it has them, add columns to a tab instead.

---

## Widgets

Every widget shares the same four methods:

```lua
local toggle = box:Toggle({ Name = "Boxes", Default = true })

toggle:Get()                       -- current value
toggle:Set(false)                  -- set it; Set(value, true) skips the callback
toggle:OnChanged(function(v) end)  -- add another listener
toggle:SetVisible(false)           -- hide the whole row
```

Every widget also takes `Name`, `Description` (adds the `(?)` icon and tooltip) and `Callback`.

### Examples

```lua
box:Label({ Text = "Plain text, no control." })
box:Separator({ Text = "Delays" })          -- Text is optional

box:Toggle({ Name = "Enabled", Default = true })

box:Slider({ Name = "Smoothing", Min = 0, Max = 100, Default = 62,
             Decimals = 0, Unit = "%" })    -- click the number to type a value

box:Button({ Text = "Rejoin", Callback = function() end })

box:TextBox({ Name = "Nickname", Placeholder = "anonymous", Default = "" })
box:TextBox({ Name = "Rounds", Numeric = true, Default = "30" })   -- Get() returns a number

local hitbox = box:Dropdown({ Name = "Hitbox",
    Options = { "Head", "Torso", "Legs" }, Default = "Head" })
hitbox:SetOptions({ "Head", "Neck" })       -- keeps the selection if it survives

box:Dropdown({ Name = "Hitboxes", Multi = true,
    Options = { "Head", "Torso", "Legs" }, Default = { "Head", "Torso" } })
                                            -- Get() returns an array

local key = box:Keybind({ Name = "Trigger",
    Default = Enum.KeyCode.C, Mode = "Hold" })   -- "Always", "Hold" or "Toggle"
key:IsHeld()                                -- what you poll each frame, not Get()

local colour = box:Colorpicker({ Name = "Box", Default = Color3.fromRGB(23, 184, 166) })
local c, a = colour:Get()                   -- Color3, then alpha
box:Colorpicker({ Name = "Fill", Default = Color3.new(1, 0, 0), Alpha = 0.4 })

local presets = box:ListBox({ Items = { "default", "legit" }, Rows = 6 })
presets:SetItems({ "default", "legit", "rage" })
```

**Keybinds** accept keyboard keys and mouse 1, 2 and 3. Side buttons are not available — Roblox
delivers no input event for them at all. Left-click a keybind to capture, Escape to clear, and
right-click for the Always/Hold/Toggle menu.

**Colorpickers** take hex or RGB in the text field: `#17B8A6`, `17b8a6`, `#17B8A6FF`, `#1B8`, or
`23, 184, 166` and `255, 0, 0, 0.5`. Unparseable input reverts.

---

## Window options

```lua
Chroma:Window({
    Name = "MY SCRIPT",              -- title bar text
    Size = Vector2.new(640, 420),
    ToggleKey = Enum.KeyCode.Insert,
    Accent = "RGB",                  -- "RGB" to cycle, or a Color3 to hold one
    AccentSpeed = 0.15,              -- hue rotations per second
    Animations = true,
    Settings = true,                 -- the built-in settings page; false to omit
    RespectGameProcessed = false,    -- true makes the toggle key ignore sunk input
    Backdrop = { Image = "rbxassetid://...", Count = 34 },
    Cursor = { Style = "Cross", Size = 7, Color = Color3.new(1, 1, 1) },
})
```

The built-in **Settings** page sits at the bottom of the rail behind a gear, and configures the
accent, animations, particle count, cursor and toggle key at runtime. It costs the consuming script
nothing, so appearance options don't have to be reinvented per script.

---

## Building

Only needed if you're changing Chroma itself.

```
python build/build.py            # bundle src/ into dist/main.lua
python build/build.py --install  # also copy the bundle and dev harness into the executor workspace
lua tests/run.lua                # unit tests
```

`dist/main.lua` is generated and committed — rebuild before committing a source change.

Modules whose logic touches no Roblox instance are written so they run under both Lua 5.4 and Luau,
which is what makes them testable outside the game. Everything else is verified in-game through
`dev/harness.lua`. See `CONTRIBUTING.md` for the conventions.
