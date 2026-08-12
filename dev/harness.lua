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

print("[Chroma dev] version", Chroma.version)
print("[Chroma dev] parent kind:", Chroma.root.parentKind)
print("[Chroma dev] window created:", Win ~= nil)
