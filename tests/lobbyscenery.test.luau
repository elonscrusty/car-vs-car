--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Lobby scenery")

local function build(origin)
	local world = Mock.new()
	local LobbyScenery = world.require("server/LobbyScenery")
	local folder = world.instance("Folder")
	LobbyScenery.build(folder, origin)
	return world, folder
end

local origin = Vector3.new(1000, 50, -300)

H.test("builds the folders and is not empty", function()
	local _, folder = build(origin)
	for _, n in { "FarScenery", "Scenery" } do
		local f = folder:FindFirstChild(n)
		truthy(f ~= nil, n)
		truthy(#f:GetChildren() > 0, n)
	end
end)

H.test("hills folder holds 8 hills", function()
	local _, folder = build(origin)
	eq(#folder:FindFirstChild("Hills"):GetChildren(), 8)
end)

H.test("grass plate top is under the plaza and it is the only solid part", function()
	local _, folder = build(origin)
	local plate = folder:FindFirstChild("GrassPlate")
	truthy(plate ~= nil)
	near(plate.Position.Y + plate.Size.Y / 2, origin.Y - 0.3, 1e-6)
	near(plate.Size.X, 760, 1e-6)
	local solid = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			solid += 1
			eq(d, plate)
		end
	end
	eq(solid, 1)
end)

H.test("nothing is built on the plaza", function()
	local _, folder = build(origin)
	for _, grp in { "Scenery", "FarScenery" } do
		for _, p in folder:FindFirstChild(grp):GetChildren() do
			local x, z = p.Position.X - origin.X, p.Position.Z - origin.Z
			truthy(not (math.abs(x) < 100 and z > -86 and z < 84), p.Name)
		end
	end
end)

H.test("part count stays low", function()
	local _, folder = build(origin)
	local n = Mock.extent(folder).parts
	truthy(n < 2500, tostring(n))
end)

H.test("clouds exist under terrain and are reused", function()
	local world, folder = build(origin)
	local c = world.workspace.Terrain:FindFirstChild("LobbyClouds")
	truthy(c ~= nil)
	near(c.Cover, 0.55, 1e-6)
	local LobbyScenery = world.require("server/LobbyScenery")
	LobbyScenery.build(world.instance("Folder"), origin)
	local count = 0
	for _, ch in world.workspace.Terrain:GetChildren() do
		if ch.Name == "LobbyClouds" then
			count += 1
		end
	end
	eq(count, 1)
end)
