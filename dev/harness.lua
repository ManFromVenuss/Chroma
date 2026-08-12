-- In-game verification harness. Not part of dist. Copy dist/main.lua into the
-- Potassium workspace with `python build/build.py --install`, then run this file
-- through the executor.
--
-- Kept out of src/ deliberately: it must not end up in the bundle.
local Chroma = loadstring(readfile("chroma_dist.lua"))()

if getgenv().__chromaDev then
    pcall(getgenv().__chromaDev)
end

local Win = Chroma:Window({
    Name = "CHROMA",
    Size = Vector2.new(640, 420),
    ToggleKey = Enum.KeyCode.Insert,
    Accent = "RGB",
    AccentSpeed = 0.15,
})

getgenv().__chromaDev = function() Chroma:Unload() end

print("[Chroma dev] version", Chroma.version)
print("[Chroma dev] parent kind:", Chroma.root.parentKind)
print("[Chroma dev] window created:", Win ~= nil)
