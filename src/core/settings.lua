-- The built-in settings page: a pinned rail entry that configures Chroma itself.
--
-- Everything here writes through knobs that already existed -- setAccent,
-- setPalette, the cursor config, the Animations flag -- so this file adds no
-- infrastructure, only a surface. Settings are not persisted yet.

local M = {}
local ConfigUI = require("core/configui")

-- U+2699. Verified in-game to render as a real gear in both Ubuntu and Code,
-- so no image asset is needed; a Lucide asset id could replace it here
-- without touching anything else.
local GEAR = "\u{2699}"

function M.build(root, window)
    local theme = root.theme

    local page = window:Page({ Name = "Settings", Icon = GEAR, Pinned = true })

    -- Sub-tabs rather than one long page: the two halves have nothing to do
    -- with each other, and appearance is the one people open repeatedly.
    local appearance = page:Tab("Appearance")
    local left, right = appearance:Column(), appearance:Column()

    --== accent ==--
    local accent = left:Container("Accent")

    -- The colorpicker is created before the mode dropdown so the dropdown's
    -- callback can reach it. A static accent is only meaningful alongside a
    -- colour, so the two are deliberately adjacent.
    -- Three modes over two axes: whether the hue animates, and whether the
    -- window outline runs a two-tone gradient. Gradient is the interesting one
    -- and was found by accident -- an unanimated accent still hue-shifted the
    -- outline's far end, which reads as a static sheen rather than a bug.
    local colour
    local mode = accent:Dropdown({
        Name = "Mode",
        Flag = "chroma_accent_mode",
        Options = { "RGB", "Gradient", "Static" },
        -- Read from the theme rather than assuming: a window constructed with
        -- Gradient = false and a static accent would otherwise boot showing
        -- "Gradient" while rendering flat hairlines.
        Default = theme:isAnimated() and "RGB"
            or (theme:isGradient() and "Gradient" or "Static"),
        Description = "RGB cycles the hue. Gradient holds one colour but keeps " ..
            "the two-tone sheen on the outline. Static is a single flat colour.",
        Callback = function(value)
            if value == "RGB" then
                window:setAccent("RGB")
            else
                window:setAccent(colour:Get())
            end
            window:setGradient(value ~= "Static")
        end,
    })

    colour = accent:Colorpicker({
        Name = "Colour",
        Flag = "chroma_accent_colour",
        Default = theme:get("Accent"),
        Description = "Used by Gradient and Static; RGB picks its own hue.",
        Callback = function(value)
            if mode:Get() ~= "RGB" then
                window:setAccent(value)
            end
        end,
    })

    accent:Slider({
        Name = "Speed", Flag = "chroma_accent_speed", Min = 0, Max = 1, Default = 0.15, Decimals = 2,
        Description = "Hue rotations per second while Mode is RGB.",
        Callback = function(value)
            window:setAccentSpeed(value)
        end,
    })

    --== window ==--
    local shell = left:Container("Window")

    shell:Toggle({
        Name = "Animations", Flag = "chroma_animations", Default = true,
        Description = "The two-stage open and close slide. Turn off for an instant show and hide.",
        Callback = function(value)
            window:setAnimations(value)
        end,
    })

    shell:Slider({
        Name = "Particles", Flag = "chroma_particles", Min = 0, Max = 80, Default = 34,
        Description = "Drifting stars over the backdrop.",
        Callback = function(value)
            window:setParticleCount(value)
        end,
    })

    shell:Keybind({
        Name = "Toggle key", Flag = "chroma_toggle_key", Default = window._toggleKey, Mode = "Always",
        Description = "Right-click for the mode menu. Escape while capturing clears the bind.",
        Callback = function(bind)
            window:setToggleKey(bind)
        end,
    })

    --== cursor ==--
    local pointer = right:Container("Cursor")

    pointer:Dropdown({
        Name = "Style", Flag = "chroma_cursor_style", Options = { "Cross", "None" }, Default = "Cross",
        Description = "None restores the operating system pointer over the menu.",
        Callback = function(value)
            window:setCursor({ Style = value })
        end,
    })

    pointer:Colorpicker({
        Name = "Colour", Flag = "chroma_cursor_colour", Default = Color3.fromRGB(255, 255, 255),
        Callback = function(value)
            window:setCursor({ Color = value })
        end,
    })

    pointer:Slider({
        Name = "Size", Flag = "chroma_cursor_size", Min = 3, Max = 14, Default = 7,
        Callback = function(value)
            window:setCursor({ Size = value })
        end,
    })

    pointer:Slider({
        Name = "Gap", Flag = "chroma_cursor_gap", Min = 0, Max = 6, Default = 0,
        Description = "Opens a hole at the centre of the cross.",
        Callback = function(value)
            window:setCursor({ Gap = value })
        end,
    })

    pointer:Toggle({
        Name = "Outline", Flag = "chroma_cursor_outline", Default = true,
        Description = "A black border under the cross, so it stays visible over bright ground.",
        Callback = function(value)
            window:setCursor({ Outline = value })
        end,
    })

    ConfigUI.build(root, window, page:Tab("Configs"))

    return page
end

return M
