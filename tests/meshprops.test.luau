--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3, CFrame = Mock.V3, Mock.CF

print("Low-poly junk props (ServerStorage.Models.Junk)")

-- carter's 8 props as Studio imports them: a Model holding one MeshPart, sized like the FBX
local SIZES = {
	Container = Vector3.new(1.05, 0.4, 0.43),
	Crane = Vector3.new(1.07, 0.56, 0.43),
	Crate = Vector3.new(0.8, 0.78, 0.8),
	LightTower = Vector3.new(0.5, 1.09, 0.31),
	PlayPad = Vector3.new(1.15, 0.22, 1.15),
	RedBarrel = Vector3.new(0.72, 0.97, 0.72),
	ScrapPile = Vector3.new(0.89, 0.53, 0.88),
	TireWall = Vector3.new(1.13, 0.46, 0.3),
}

local function world()
	local w = Mock.new()
	w.quiet = true
	local models = w.instance("Folder")
	models.Name = "Models"
	models.Parent = w.service("ServerStorage")
	local junk = w.instance("Folder")
	junk.Name = "Junk"
	junk.Parent = models
	for name, size in SIZES do
		local m = w.instance("Model")
		m.Name = name
		local p = w.instance("MeshPart")
		p.Name = name
		p.Size = size
		p.Parent = m
		m.Parent = junk
	end
	return w
end

local function named(folder, name)
	local n = 0
	for _, d in folder:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

H.test("a missing model gives nil, so the Part prop stays", function()
	local w = Mock.new()
	local MeshProps = w.require("server/MeshProps")
	eq(MeshProps.has("Crane"), false)
	eq(MeshProps.place("Crane", w.instance("Folder"), CFrame.new(), 10), nil)
end)

H.test("place scales to the height, feet on the spot, look only", function()
	local w = world()
	local MeshProps = w.require("server/MeshProps")
	local m = MeshProps.place("LightTower", w.instance("Folder"), CFrame.new(10, 2, 0), 46)
	local p = m.PrimaryPart
	near(p.Size.Y, 46, 0.01)
	near(p.Size.X, 46 / 1.09 * 0.5, 0.01)
	near(p.Position.Y, 2 + 23, 0.01)
	eq(p.Anchored, true)
	eq(p.CanCollide, false)
	eq(p.CanTouch, false)
	local flat = MeshProps.place("PlayPad", w.instance("Folder"), CFrame.new(), 2.4, 1.1)
	near(flat.PrimaryPart.Size.Y, 1.1, 0.01)
end)

H.test("the bowl uses the models: tire wall ring, containers, piles, towers, cranes", function()
	local w = world()
	local BowlMap = w.require("server/BowlMap")
	local folder = w.instance("Folder")
	BowlMap.build(folder, Vector3.new(6000, 40, 0), {})
	eq(named(folder, "TireHigh"), 0)
	truthy(named(folder.Tires, "TireWall") >= 30, "tire wall pieces")
	eq(named(folder.FarScenery, "Container"), 24)
	eq(named(folder.FarScenery, "ScrapPile"), 16)
	eq(named(folder.FarScenery, "LightTower"), 4)
	eq(named(folder.FarScenery, "Crane"), 2)
	for _, m in folder.Breakables:GetChildren() do
		if m.Name == "BoomBarrel" then
			truthy(m:FindFirstChild("RedBarrel"), "red barrel model")
			eq(m.PrimaryPart.Transparency, 1)
			eq(m.PrimaryPart.CanTouch, true)
		end
	end
	local parts = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print("       bowl parts with models: " .. parts)
	truthy(parts <= 720, "too many parts: " .. parts)
end)

H.test("the lobby pads stand on the play pad model", function()
	local w = world()
	local Pads = w.require("server/LobbyPads")
	local folder = w.instance("Folder")
	Pads.build(folder, Vector3.new(0, 3, 500))
	local n = 0
	for _, pad in folder.Pads:GetChildren() do
		n += 1
		truthy(pad:FindFirstChild("PlayPad"), pad.Name)
		eq(pad:FindFirstChild("Rim").Transparency, 1)
	end
	truthy(n >= 1)
end)
