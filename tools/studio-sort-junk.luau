-- Run in Studio's command bar (Edit mode) after importing the 8 low-poly props from
-- assets/lowpoly/props (Container Crane Crate LightTower PlayPad RedBarrel ScrapPile TireWall).
-- Moves each one from Workspace into ServerStorage.Models.Junk, where MeshProps finds it.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage:FindFirstChild("Models") or Instance.new("Folder")
models.Name = "Models"
models.Parent = ServerStorage
local junk = models:FindFirstChild("Junk") or Instance.new("Folder")
junk.Name = "Junk"
junk.Parent = models

local moved = {}
for n in string.gmatch("Container Crane Crate LightTower PlayPad RedBarrel ScrapPile TireWall", "%S+") do
	local m = workspace:FindFirstChild(n)
	if m then
		local old = junk:FindFirstChild(n)
		if old then
			old:Destroy()
		end
		m.Parent = junk
		table.insert(moved, n)
	end
end
print("Junk props moved: " .. #moved .. " (" .. table.concat(moved, ", ") .. ")")
