-- The Configs sub-tab of the settings page.
--
-- Split out of settings.lua, which is already a long surface file, and because
-- this half is the only part that talks to the config manager.

local M = {}

function M.build(root, window, tab)
    local config = root.config
    local column = tab:Column()

    local box = column:Container("Configs")

    if not config:isAvailable() then
        -- The executor has no writefile. Say so once, plainly, rather than
        -- offering buttons that quietly do nothing.
        box:Label({ Text = "Configs need writefile, which this executor" })
        box:Label({ Text = "does not provide." })
        return
    end

    local list, nameField, autoToggle

    local function refresh(select)
        local names = config:List()
        list:SetItems(names)
        if select ~= nil then
            list:Set(select)
        end
        -- The toggle tracks the selected entry, so it has to be re-read
        -- whenever the selection or the list changes.
        local current = list:Get()
        autoToggle:Set(current ~= nil and current == config:GetAutoload(), true)
    end

    -- All three take Flag = false: they are the config browser, not settings.
    -- Saving them would mean loading a config moved this UI around.
    list = box:ListBox({
        Flag = false,
        Items = config:List(),
        Rows = 6,
        Default = config:GetAutoload(),
        Callback = function(name)
            autoToggle:Set(name ~= nil and name == config:GetAutoload(), true)
            nameField:Set(name or "")
        end,
    })

    nameField = box:TextBox({
        Name = "Name",
        Flag = false,
        Placeholder = "config name",
        Default = config:GetAutoload() or "",
    })

    box:Button({
        Text = "Save",
        Callback = function()
            local ok, result = config:Save(nameField:Get())
            if ok then
                refresh(result)
            else
                warn("[Chroma] save failed: " .. tostring(result))
            end
        end,
    })

    box:Button({
        Text = "Load",
        Callback = function()
            local name = list:Get()
            if name == nil then return end
            local ok, result = config:Load(name)
            if not ok then
                warn("[Chroma] load failed: " .. tostring(result))
            end
        end,
    })

    box:Button({
        Text = "Delete",
        Callback = function()
            local name = list:Get()
            if name == nil then return end
            if config:GetAutoload() == name then
                config:SetAutoload(nil)
            end
            local ok, result = config:Delete(name)
            if ok then
                refresh(nil)
            else
                warn("[Chroma] delete failed: " .. tostring(result))
            end
        end,
    })

    box:Button({ Text = "Refresh", Callback = function() refresh(list:Get()) end })

    box:Separator()

    -- A toggle rather than a label showing the current autoload, because no
    -- widget offers a label that can be rewritten cleanly. It reflects the
    -- SELECTED config, so it changes meaning as the selection moves.
    autoToggle = box:Toggle({
        Name = "Autoload selected",
        Flag = false,
        Description = "Loads the selected config the next time this script runs.",
        Callback = function(on)
            local name = list:Get()
            if on and name ~= nil then
                config:SetAutoload(name)
            elseif not on then
                config:SetAutoload(nil)
            end
        end,
    })

    refresh(config:GetAutoload())
end

return M
