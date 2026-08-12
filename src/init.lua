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
end

return Chroma
