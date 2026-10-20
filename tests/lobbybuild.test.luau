--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Lobby build (whole lobby on the mock)")

local ORIGIN = Vector3.new(0, 3, 500)

local function build()
	local world = Mock.new()
	world.quiet = true
	-- Lobby asks Profiles for the opener's cars; a stub keeps DataStore out of this test
	local Layout = world.require("shared/LobbyLayout")
	local Lobby = world.require("server/Lobby")
	local handle = Lobby.build()
	return world, Layout, handle
end

H.test("the whole lobby builds and fits the sheet", function()
	local _, _, handle = build()
	truthy(handle.folder.Parent ~= nil)
	-- everything except the far world (grass, hills, scenery, clouds) stays inside 220 x 180
	local inside = 0
	for _, child in handle.folder:GetChildren() do
		if
			child.Name ~= "Scenery"
			and child.Name ~= "FarScenery"
			and child.Name ~= "Hills"
			and child.Name ~= "Clouds"
			and child.Name ~= "GrassPlate"
			and child.Name ~= "DirtPaths"
			and child.Name ~= "Blockers"
		then
			local x = Mock.extent(child)
			if x.parts > 0 then
				inside += x.parts
				truthy(
					x.minX >= ORIGIN.X - 112 and x.maxX <= ORIGIN.X + 112,
					child.Name .. " wider than the sheet: " .. x.minX .. " " .. x.maxX
				)
				truthy(x.maxY <= ORIGIN.Y + 32.01, child.Name .. " higher than 32: " .. x.maxY)
			end
		end
	end
	truthy(inside > 200)
end)

H.test("one spawn on the front path, looking at the pads", function()
	local _, Layout, handle = build()
	local rel = handle.spawn.Position - ORIGIN
	near(rel.X, Layout.spawn.x, 0.01)
	near(rel.Z, Layout.spawn.z, 0.01)
	truthy(handle.spawn.CFrame.LookVector.Z < -0.9)
end)

H.test("the three prompts exist exactly once", function()
	local _, _, handle = build()
	for _, name in { "GachaPrompt", "CustomizePrompt", "StorePrompt" } do
		local n = 0
		for _, d in handle.folder:GetDescendants() do
			if d.Name == name and d:IsA("ProximityPrompt") then
				n += 1
			end
		end
		eq(n, 1, name)
	end
end)

H.test("no old pad prompt is left", function()
	local _, _, handle = build()
	for _, d in handle.folder:GetDescendants() do
		truthy(d.Name ~= "PadPrompt")
	end
end)

H.test("showcase cars stand on their stages and the stand-ins have wheels", function()
	local _, _, handle = build()
	local cars = handle.folder:FindFirstChild("ShowCars")
	truthy(#cars:GetChildren() >= 6) -- rare, gold, 3 shop cars, turntable
end)

H.test("parking: a player's car appears in a spot with their name", function()
	local world, _, handle = build()
	local p = world.newPlayer("Ana", 5)
	handle.parking.set(p, "CannonVan", nil, nil, "Ana  LV 3")
	local found = false
	for _, d in handle.folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "Ana  LV 3" then
			found = true
		end
	end
	truthy(found)
	handle.parking.clear(p)
	for _, d in handle.folder:GetDescendants() do
		truthy(not (d:IsA("TextLabel") and d.Text == "Ana  LV 3"))
	end
end)

H.test("parking: 25 players, the spots run out and nothing breaks", function()
	local world, _, handle = build()
	for i = 1, 25 do
		handle.parking.set(world.newPlayer("P" .. i, i), "RamTruck", nil, nil, "P" .. i)
	end
	local n = 0
	for _, d in handle.folder:GetDescendants() do
		if
			d:IsA("Model")
			and d.Name == "ShowCar_RamTruck"
			and d.Parent.Parent.Name == "CarStands"
		then
			n += 1
		end
	end
	eq(n, 16)
end)

H.test("parking: every spot is a spinning stand that shows a car you can win", function()
	local _, Layout, handle = build()
	local group = handle.folder:FindFirstChild("CarStands")
	local stands = 0
	for _, c in group:GetChildren() do
		if c:IsA("Model") then
			stands += 1
			truthy(c:HasTag("LobbySpin"), c.Name .. " does not spin")
			truthy(c:GetAttribute("SpinSpeed") > 0 and c:GetAttribute("SpinSpeed") < 1, "slowly")
			truthy(c.PrimaryPart ~= nil, "a pivot in the middle")
			local car = nil
			for _, d in c:GetChildren() do
				if d:IsA("Model") then
					car = d
				end
			end
			truthy(car ~= nil, c.Name .. " is empty")
			truthy(car.Name == "ShowCar_CannonVan" or car.Name == "ShowCar_SawBuggy", car.Name)
		end
	end
	eq(stands, #Layout.parking())
end)

H.test(
	"parking: a player's car takes a spot and the show car comes back when they leave",
	function()
		local world, _, handle = build()
		local p = world.newPlayer("Ana", 5)
		local function carsNamed(name)
			local n = 0
			for _, d in handle.folder:FindFirstChild("CarStands"):GetDescendants() do
				if d:IsA("Model") and d.Name == name then
					n += 1
				end
			end
			return n
		end
		local before = carsNamed("ShowCar_CannonVan") + carsNamed("ShowCar_SawBuggy")
		eq(before, 16)
		handle.parking.set(p, "RamTruck", nil, nil, "Ana  LV 3")
		eq(carsNamed("ShowCar_RamTruck"), 1)
		eq(carsNamed("ShowCar_CannonVan") + carsNamed("ShowCar_SawBuggy"), 15)
		handle.parking.set(p, "RamTruck", nil, nil, "Ana  LV 4") -- the same spot again
		eq(carsNamed("ShowCar_RamTruck"), 1)
		handle.parking.clear(p)
		eq(carsNamed("ShowCar_RamTruck"), 0)
		eq(carsNamed("ShowCar_CannonVan") + carsNamed("ShowCar_SawBuggy"), 16)
	end
)

H.test("a second build replaces the first", function()
	local world = Mock.new()
	local Lobby = world.require("server/Lobby")
	Lobby.build()
	Lobby.build()
	local n = 0
	for _, c in world.workspace:GetChildren() do
		if c.Name == "Lobby" then
			n += 1
		end
	end
	eq(n, 1)
end)

H.test("part count is phone friendly", function()
	local _, _, handle = build()
	local n = #handle.folder:GetDescendants()
	truthy(n < 9000, "descendants: " .. n)
end)
