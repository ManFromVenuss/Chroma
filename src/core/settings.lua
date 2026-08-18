-- The built-in settings page: a pinned rail entry that configures Chroma itself.
--
-- Everything here writes through knobs that already existed -- setAccent,
-- setPalette, the cursor config, the Animations flag -- so this file adds no
-- infrastructure, only a surface. Settings are NOT persisted in M3; M4's config
-- manager adds that.

local M = {}

-- U+2699. Verified in-game to render as a real gear in both Ubuntu and Code,
-- so no image asset is needed; M5 can pass a Lucide asset id here instead
-- without touching anything else.
local GEAR = "\u{2699}"

function M.build(root, window)
    local theme = root.theme

    local page = window:Page({ Name = "Settings", Icon = GEAR, Pinned = true })
    local left, right = page:Column(), page:Column()

    --== accent ==--
    local accent = left:Container("Accent")

    -- The colorpicker is created before the mode dropdown so the dropdown's
    -- callback can reach it. A static accent is only meaningful alongside a
    -- colour, so the two are deliberately adjacent.
    local colour
    local mode = accent:Dropdown({
        Name = "Mode",
        Options = { "RGB", "Static" },
        Default = theme:isAnimated() and "RGB" or "Static",
        Description = "RGB animates the accent through the hue wheel. Static holds the colour below.",
        Callback = function(value)
            if value == "RGB" then
                window:setAccent("RGB")
            else
                window:setAccent(colour:Get())
            end
        end,
    })

    colour = accent:Colorpicker({
        Name = "Colour",
        Default = theme:get("Accent"),
        Description = "Used when Mode is Static.",
        Callback = function(value)
            if mode:Get() == "Static" then
                window:setAccent(value)
            end
        end,
    })

    accent:Slider({
        Name = "Speed", Min = 0, Max = 1, Default = 0.15, Decimals = 2,
        Description = "Hue rotations per second while Mode is RGB.",
        Callback = function(value)
            window:setAccentSpeed(value)
        end,
    })

    --== window ==--
    local shell = left:Container("Window")

    shell:Toggle({
        Name = "Animations", Default = true,
        Description = "The two-stage open and close slide. Turn off for an instant show and hide.",
        Callback = function(value)
            window:setAnimations(value)
        end,
    })

    shell:Slider({
        Name = "Particles", Min = 0, Max = 80, Default = 34,
        Description = "Drifting stars over the backdrop.",
        Callback = function(value)
            window:setParticleCount(value)
        end,
    })

    shell:Keybind({
        Name = "Toggle key", Default = window._toggleKey, Mode = "Always",
        Description = "Right-click for the mode menu. Escape while capturing clears the bind.",
        Callback = function(bind)
            window:setToggleKey(bind)
        end,
    })

    --== cursor ==--
    local pointer = right:Container("Cursor")

    pointer:Dropdown({
        Name = "Style", Options = { "Cross", "None" }, Default = "Cross",
        Description = "None restores the operating system pointer over the menu.",
        Callback = function(value)
            window:setCursor({ Style = value })
        end,
    })

    pointer:Colorpicker({
        Name = "Colour", Default = Color3.fromRGB(255, 255, 255),
        Callback = function(value)
            window:setCursor({ Color = value })
        end,
    })

    pointer:Slider({
        Name = "Size", Min = 3, Max = 14, Default = 7,
        Callback = function(value)
            window:setCursor({ Size = value })
        end,
    })

    pointer:Slider({
        Name = "Gap", Min = 0, Max = 6, Default = 0,
        Description = "Opens a hole at the centre of the cross.",
        Callback = function(value)
            window:setCursor({ Gap = value })
        end,
    })

    pointer:Toggle({
        Name = "Outline", Default = true,
        Description = "A black border under the cross, so it stays visible over bright ground.",
        Callback = function(value)
            window:setCursor({ Outline = value })
        end,
    })

    return page
end

return M
