--!strict
-- Low-poly lobby props from plain blocks (flat colours, no text or logos): trees, lamps, the car
-- shop (cars on stands the client spins) and the upgrades garage. Stand-ins: the plaza, garage
-- and scenery threads replace them. Looks only for now: no shop or upgrade logic.

local CollectionService = game:GetService("CollectionService")

local LobbyProps = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
LobbyProps.part = part

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WOOD = rgb(140, 98, 60)
local DARK = rgb(45, 45, 52)
local LEAF = rgb(62, 140, 58)
local LEAF2 = rgb(84, 168, 70)
local CONCRETE = rgb(200, 198, 192)

-- A cylinder standing up (Roblox cylinders lie along x).
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.pi / 2)
end

-- Low-poly tree: brown trunk and two stacked green blocks turned 45 degrees.
function LobbyProps.tree(parent: Instance, x: number, z: number, size: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local s = size
	part(
		m,
		"Trunk",
		Vector3.new(1.2 * s, 1.2 * s, 1.2 * s) * Vector3.new(3, 1, 1),
		upright(CFrame.new(x, 1.8 * s, z)),
		WOOD,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Leaves",
		Vector3.new(5, 4, 5) * s,
		CFrame.new(x, 5 * s, z) * CFrame.Angles(0, math.pi / 4, 0),
		LEAF
	)
	part(
		m,
		"Top",
		Vector3.new(3.2, 3, 3.2) * s,
		CFrame.new(x, 7.8 * s, z) * CFrame.Angles(0, math.pi / 8, 0),
		LEAF2
	)
	m.Parent = parent
end

-- Street lamp: dark post, warm light box on top with a real light.
function LobbyProps.lamp(parent: Instance, x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	part(m, "Base", Vector3.new(1.4, 0.6, 1.4), CFrame.new(x, 0.3, z), CONCRETE)
	part(m, "Post", Vector3.new(0.5, 9, 0.5), CFrame.new(x, 4.8, z), DARK)
	part(m, "Cap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(x, 10.6, z), DARK)
	local glow =
		part(m, "Light", Vector3.new(1.2, 1.2, 1.2), CFrame.new(x, 9.8, z), rgb(255, 226, 150))
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = rgb(255, 214, 150)
	light.Parent = glow
	m.Parent = parent
end
-- A display car (body, cab, 4 wheels) standing on its floor point `cf`, `len` studs long.
local function displayCar(parent: Instance, cf: CFrame, len: number, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "DisplayCar"
	local k = len / 5.5
	part(m, "Body", Vector3.new(3, 1, 5.5) * k, cf * CFrame.new(0, 1.3 * k, 0), color)
	part(m, "Cab", Vector3.new(2.2, 0.9, 2.4) * k, cf * CFrame.new(0, 2.2 * k, 0.5 * k), DARK)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				m,
				"Wheel",
				Vector3.new(0.8, 1.6, 1.6) * k,
				cf * CFrame.new(sx * 1.6 * k, 0.8 * k, sz * 1.8 * k),
				rgb(30, 30, 34),
				Enum.PartType.Cylinder
			)
		end
	end
	m.Parent = parent
	return m
end

-- Box building with one open side. `cf` = floor middle, its look vector = the open side.
local function shed(
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	wall: Color3,
	roof: Color3
): Model
	local m = Instance.new("Model")
	m.Name = "Building"
	part(m, "Floor", Vector3.new(w, 0.4, d), cf * CFrame.new(0, 0.2, 0), CONCRETE)
	part(m, "Back", Vector3.new(w, h, 1), cf * CFrame.new(0, h / 2, d / 2 - 0.5), wall)
	for _, sx in { -1, 1 } do
		part(m, "Side", Vector3.new(1, h, d), cf * CFrame.new(sx * (w / 2 - 0.5), h / 2, 0), wall)
	end
	part(m, "Roof", Vector3.new(w + 2, 1.2, d + 2), cf * CFrame.new(0, h + 0.6, 0), roof)
	-- a coloured band over the open front
	part(m, "Band", Vector3.new(w + 2, 1.6, 0.6), cf * CFrame.new(0, h - 0.4, -d / 2 - 0.7), roof)
	m.Parent = parent
	return m
end

local function facing(x: number, z: number, fx: number, fz: number): CFrame
	-- floor point whose look vector points out of the open side
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + fx, 0, z + fz))
end

-- Car shop: blue roof, three round stands with cars on them (the client spins the stands).
function LobbyProps.carShop(parent: Instance, x: number, z: number, fx: number, fz: number)
	local cf = facing(x, z, fx, fz)
	local w, d = 28, 20
	local m = shed(parent, cf, w, d, 12, rgb(235, 235, 240), rgb(52, 104, 214))
	m.Name = "CarShop"
	local colors = { rgb(214, 48, 48), rgb(48, 96, 214), rgb(240, 196, 40) }
	for i, sx in { -8.5, 0, 8.5 } do
		local spot = cf * CFrame.new(sx, 0, 2)
		local stand = Instance.new("Model")
		stand.Name = "Stand"
		part(
			stand,
			"Disc",
			Vector3.new(1.2, 7, 7),
			upright(spot * CFrame.new(0, 0.9, 0)),
			DARK,
			Enum.PartType.Cylinder
		)
		local car = displayCar(
			stand,
			spot * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.pi / 5 * i, 0),
			5.5,
			colors[i]
		)
		car.Parent = stand
		stand.WorldPivot = spot
		stand.Parent = m
		CollectionService:AddTag(stand, "LobbySpin")
		-- a spot light above each stand
		local lamp = part(
			m,
			"ShowLight",
			Vector3.new(1, 0.3, 1),
			spot * CFrame.new(0, 11.2, 0),
			rgb(255, 250, 230)
		)
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 16
		light.Brightness = 2
		light.Parent = lamp
	end
end

-- Upgrades garage: orange and dark, a car up on a lift, a tool bench, tyre stacks.
function LobbyProps.garage(parent: Instance, x: number, z: number, fx: number, fz: number)
	local cf = facing(x, z, fx, fz)
	local m = shed(parent, cf, 28, 20, 12, rgb(60, 60, 68), rgb(232, 121, 45))
	m.Name = "Garage"
	-- lift: two posts and a platform with a car on it
	local lift = cf * CFrame.new(-3, 0, 2)
	for _, sx in { -3.6, 3.6 } do
		part(
			m,
			"LiftPost",
			Vector3.new(0.8, 7, 0.8),
			lift * CFrame.new(sx, 3.5, 0),
			rgb(232, 121, 45)
		)
	end
	part(m, "LiftDeck", Vector3.new(6, 0.4, 7), lift * CFrame.new(0, 3, 0), DARK)
	displayCar(m, lift * CFrame.new(0, 3.2, 0), 5.5, rgb(240, 196, 40))
	-- bench with tools on the back wall
	local bench = cf * CFrame.new(7, 0, 7.5)
	part(m, "Bench", Vector3.new(7, 0.4, 2.4), bench * CFrame.new(0, 3, 0), WOOD)
	for _, sx in { -3, 3 } do
		part(m, "BenchLeg", Vector3.new(0.4, 3, 2), bench * CFrame.new(sx, 1.5, 0), DARK)
	end
	part(m, "ToolBoard", Vector3.new(7, 3.5, 0.3), bench * CFrame.new(0, 6, 1.2), rgb(90, 90, 98))
	for i = 0, 4 do
		part(
			m,
			"Tool",
			Vector3.new(0.3, 1.6, 0.2),
			bench * CFrame.new(-2.4 + i * 1.2, 6, 1),
			rgb(190, 190, 200)
		)
	end
	-- tyre stacks, inside by the door and outside by the wall
	for _, spot in
		{ cf * CFrame.new(11, 0, -6), cf * CFrame.new(-11, 0, -6), cf * CFrame.new(15.8, 0, -8) }
	do
		for i = 0, 2 do
			part(
				m,
				"Tyre",
				Vector3.new(1, 2.4, 2.4),
				upright(spot * CFrame.new(0, 0.5 + i * 1, 0)),
				rgb(28, 28, 32),
				Enum.PartType.Cylinder
			)
		end
	end
end

return LobbyProps
