local Root = require("core/root")
local WindowModule = require("core/window")

local Chroma = {}

Chroma.version = "0.1.0"

function Chroma:Window(opts)
    if self.root then
        error("chroma: a window already exists; call Chroma:Unload() first", 2)
    end
    self.root = Root.new(opts)
    self.window = WindowModule.new(self.root, opts)
    -- The same table the config manager maintains, not a copy: a consumer
    -- polling Chroma.Flags.foo every frame reads live state.
    self.Flags = self.root.config.Flags
    return self.window
end

function Chroma:Unload()
    local UserInputService = game:GetService("UserInputService")
    UserInputService.ModalEnabled = false
    UserInputService.MouseIconEnabled = true
    if self.root then
        self.root:Unload()
        self.root = nil
    end
    self.window = nil
    self.Flags = nil
end

return Chroma
