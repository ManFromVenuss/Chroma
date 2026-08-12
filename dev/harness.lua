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

-- The default backdrop decal (rbxassetid://122415002143640) does not resolve.
-- Verified in-game: it renders blank while a local file and a known-good asset
-- both render. Until that is sorted, dev runs against the local PNG.
-- getcustomasset is per-machine, so this override belongs here, never in src/.
local backdrop = nil
if isfile and isfile("chroma_bd_night.png") then
    backdrop = getcustomasset("chroma_bd_night.png")
end

local Win = Chroma:Window({
    Name = "CHROMA",
    Size = Vector2.new(640, 420),
    ToggleKey = Enum.KeyCode.Insert,
    Accent = "RGB",
    AccentSpeed = 0.15,
    Backdrop = backdrop and { Image = backdrop } or nil,
})

print("[Chroma dev] version", Chroma.version)
print("[Chroma dev] parent kind:", Chroma.root.parentKind)
print("[Chroma dev] window created:", Win ~= nil)
