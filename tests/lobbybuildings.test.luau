--!nocheck
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy
local Vector3 = Mock.V3

print("Lobby buildings (customize, shop, boards)")

local ORIGIN = Vector3.new(1000, 5, -300)

local function setup()
	local world = Mock.new()
	local Layout = world.require("shared/LobbyLayout")
	local folder = world.instance("Folder")
	return world, Layout, folder
end

local function findPrompt(root, name)
	for _, d in root:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Name == name then
			return d
		end
	end
	return nil
end

local function checkPrompt(prompt, action, object)
	truthy(prompt ~= nil, "prompt exists")
	eq(prompt.KeyboardKeyCode.Name, "E")
	eq(prompt.Enabled, true)
	eq(prompt.ActionText, action)
	eq(prompt.ObjectText, object)
	eq(prompt.RequiresLineOfSight, false)
	eq(prompt.MaxActivationDistance, 22)
	eq(prompt.HoldDuration, 0)
end

-- every corner of every part must sit inside the building rectangle; parts named Sign* get +10
local function insideFootprint(root, b)
	local c, s = math.cos(math.rad(b.yawDeg)), math.sin(math.rad(b.yawDeg))
	local bad = 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			local margin = if string.sub(p.Name, 1, 4) == "Sign" then 10 else 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = p.CFrame
							* Vector3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)
						local dx, dz = q.X - ORIGIN.X - b.x, q.Z - ORIGIN.Z - b.z
						local u = dx * c - dz * s
						local v = dx * s + dz * c
						if math.abs(u) > b.w / 2 + margin or math.abs(v) > b.d / 2 + margin then
							bad += 1
						end
					end
				end
			end
		end
	end
	return bad
end

local function lookOnly(root)
	local bad = 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and (p.CanCollide or p.CanQuery or p.CanTouch) then
			bad += 1
		end
	end
	return bad
end

H.test("customize garage builds with turntable and prompt", function()
	local world, Layout, folder = setup()
	local r = world.require("server/LobbyCustomize").build(folder, ORIGIN)
	truthy(r.turntable:IsA("BasePart"))
	eq(r.turntable.Name, "Turntable")
	truthy(r.group ~= nil)
	eq(r.group.Name, "Customize")
	checkPrompt(findPrompt(folder, "CustomizePrompt"), "Customize", "Paint & Garage")
	eq(findPrompt(folder, "CustomizePrompt").Parent.Name, "CustomizeCounter")
	local e = Mock.extent(folder)
	truthy(e.maxY <= ORIGIN.Y + 32, "max height " .. e.maxY)
	truthy(e.parts < 500, "part count " .. e.parts)
	eq(insideFootprint(folder, Layout.customize), 0)
	eq(lookOnly(folder), 0)
	-- the turntable top centre is where the disc is, at the layout spot
	local b, T = Layout.customize, Layout.turntable
	local c, s = math.cos(math.rad(b.yawDeg)), math.sin(math.rad(b.yawDeg))
	near(r.turntableCF.Position.X, ORIGIN.X + b.x + T.u * c + T.v * s, 1e-4)
	near(r.turntableCF.Position.Z, ORIGIN.Z + b.z - T.u * s + T.v * c, 1e-4)
	near(r.turntable.Size.Y, T.radius * 2, 1e-6)
	truthy(r.turntableCF.Position.Y > ORIGIN.Y)
	local lights = 0
	for _, d in folder:GetDescendants() do
		if d.ClassName == "PointLight" then
			lights += 1
		end
	end
	truthy(lights <= 3, "point lights " .. lights)
end)

H.test("shop builds with prompt and three car spots", function()
	local world, Layout, folder = setup()
	local r = world.require("server/LobbyShop").build(folder, ORIGIN)
	eq(r.group.Name, "Shop")
	checkPrompt(findPrompt(folder, "StorePrompt"), "Open", "Shop")
	eq(findPrompt(folder, "StorePrompt").Parent.Name, "ShopCounter")
	eq(#r.carSpots, 3)
	local b = Layout.shop
	local c, s = math.cos(math.rad(b.yawDeg)), math.sin(math.rad(b.yawDeg))
	for i, cf in r.carSpots do
		local dx, dz = cf.Position.X - ORIGIN.X - b.x, cf.Position.Z - ORIGIN.Z - b.z
		local u = dx * c - dz * s
		local v = dx * s + dz * c
		near(u, Layout.shopCars[i].u, 1e-4)
		near(v, Layout.shopCars[i].v, 1e-4)
		truthy(math.abs(u) < b.w / 2 and math.abs(v) < b.d / 2, "spot inside the shop")
		-- the car faces the mouth: its look vector points along building +v
		local look = cf.LookVector
		near(look.X, s, 1e-4)
		near(look.Z, c, 1e-4)
	end
	local e = Mock.extent(folder)
	truthy(e.maxY <= ORIGIN.Y + 32, "max height " .. e.maxY)
	truthy(e.parts < 500, "part count " .. e.parts)
	eq(insideFootprint(folder, b), 0)
	eq(lookOnly(folder), 0)
end)

H.test("board frames sit where the layout says", function()
	local world, Layout, folder = setup()
	local r = world.require("server/LobbyBoards").build(folder, ORIGIN)
	for key, panel in { weekly = r.weekly, wins = r.wins } do
		local cfg = Layout.boards[key]
		truthy(panel:IsA("BasePart"))
		eq(panel.Name, "Board_" .. key)
		near(panel.Position.X, ORIGIN.X + cfg.x, 1e-4)
		near(panel.Position.Z, ORIGIN.Z + cfg.z, 1e-4)
		near(panel.Size.X, cfg.w, 1e-6)
		near(panel.Size.Y, cfg.h, 1e-6)
		near(panel.Size.Z, 0.6, 1e-6)
		near(panel.Position.Y - panel.Size.Y / 2, ORIGIN.Y + 4, 1e-6)
		-- no other part is centred over the panel face
		local covering = 0
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") and p ~= panel then
				local rel = panel.CFrame:PointToObjectSpace(p.Position)
				if math.abs(rel.X) < cfg.w / 2 - 0.1 and math.abs(rel.Y) < cfg.h / 2 - 0.1 then
					covering += 1
				end
			end
		end
		eq(covering, 0)
	end
	local e = Mock.extent(folder)
	truthy(e.maxY <= ORIGIN.Y + 32, "max height " .. e.maxY)
	eq(lookOnly(folder), 0)
end)
