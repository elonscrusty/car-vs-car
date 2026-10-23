--!strict
-- The car shop on the plaza: a white box with a blue roof, open at the front, three round
-- turntables with a display car each under spot lights, and a counter at the back.
-- Looks only (no buying yet), flat colours, no text. Built by PlazaBuilder.
-- Local space: origin = middle of the spot on the floor, -Z = the open front, x across it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshProps = require(script.Parent.Parent.MeshProps)

local Shop = {}

local WHITE = Color3.fromRGB(238, 238, 242)
local FLOOR = Color3.fromRGB(214, 216, 222)
local BLUE = Color3.fromRGB(38, 104, 214)
local BLUE_DARK = Color3.fromRGB(26, 70, 150)
local STAND = Color3.fromRGB(66, 68, 76)
local STAND_TOP = Color3.fromRGB(150, 152, 160)
local TYRE = Color3.fromRGB(30, 30, 34)
local CHASSIS = Color3.fromRGB(56, 58, 64)
local LIGHT = Color3.fromRGB(255, 250, 235)
-- the three display cars (made-up toys, Meshy models can swap in later)
local CARS =
	{ Color3.fromRGB(214, 48, 44), Color3.fromRGB(40, 110, 220), Color3.fromRGB(246, 196, 40) }

local H = 11 -- wall height
local BACK = 14 -- back wall (local z)
local FRONT = -8 -- open front edge (the rest of the spot in front stays open paving)

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- an upright disc (Roblox cylinders run along x, so turn it on its side)
local function disc(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	cf: CFrame,
	color: Color3
): Part
	local p =
		block(parent, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local CAR_LEN = 5 -- display car length, studs
local STAND_D = 7 -- turntable width
local FLOOR_TOP = 0.4 -- the shop floor's top

-- carter's RockCrawler truck (ReplicatedStorage.CarSkins, the drivable car's skin), CAR_LEN long,
-- wheels on `cf`, nose to its -Z. nil when it isn't in the place.
local function crawler(parent: Instance, cf: CFrame): Model?
	local skins = ReplicatedStorage:FindFirstChild("CarSkins")
	local t = skins and skins:FindFirstChild("RockCrawler")
	if not (t and t:IsA("Model")) then
		return nil
	end
	local m = t:Clone()
	m.Name = "DisplayCar"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local _, size = m:GetBoundingBox()
	if size.Z > 0 then
		m:ScaleTo(m:GetScale() * CAR_LEN / size.Z)
	end
	-- pivot = middle of the bottom, nose (+Z after import) turned to -Z
	local box, sized = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, sized.Y / 2, 0))
		* CFrame.Angles(0, math.pi, 0)
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- carter's Meshy turntable (ServerStorage.LobbyMeshes), STAND_D wide, standing on `at`.
-- Returns it and the height of its top, or nil when it isn't imported.
local function meshStand(parent: Instance, at: CFrame): (Model?, number)
	local m = MeshProps.place(parent, "Turntable", at, 1)
	if not m then
		return nil, 0
	end
	local _, size = m:GetBoundingBox()
	local wide = math.max(size.X, size.Z)
	if wide > 0 then
		m:ScaleTo(m:GetScale() * STAND_D / wide) -- the pivot is the bottom middle: stays put
	end
	local _, sized = m:GetBoundingBox()
	return m, sized.Y
end

-- A chunky toy crawler, about 5 long, nose to local -Z of `cf` (which sits on the stand top).
-- Block stand-in for when the RockCrawler model is missing.
local function displayCar(parent: Instance, cf: CFrame, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "DisplayCar"
	local body = block(m, "Body", Vector3.new(2.6, 1.1, 4.4), cf * CFrame.new(0, 2.05, 0), color)
	block(m, "Chassis", Vector3.new(1.6, 0.5, 4.2), cf * CFrame.new(0, 1.25, 0), CHASSIS)
	block(m, "Cab", Vector3.new(2.2, 0.9, 2), cf * CFrame.new(0, 3.05, 0.5), color)
	block(
		m,
		"Glass",
		Vector3.new(2.25, 0.6, 0.2),
		cf * CFrame.new(0, 3.05, -0.5),
		Color3.fromRGB(40, 44, 54)
	)
	block(m, "Bumper", Vector3.new(2.4, 0.4, 0.3), cf * CFrame.new(0, 1.5, -2.3), CHASSIS)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = block(
				m,
				"Wheel",
				Vector3.new(0.9, 1.9, 1.9),
				cf * CFrame.new(sx * 1.45, 0.95, sz * 1.45),
				TYRE
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- A round turntable with a car on it, a spot light above and a soft glow from below. The top +
-- car spin together as one model tagged LobbySpin (the client turns it slowly). Uses carter's
-- Meshy turntable and RockCrawler when they are in the place, blocks otherwise.
local function stand(
	parent: Instance,
	origin: CFrame,
	x: number,
	z: number,
	turn: number,
	color: Color3
)
	local at = origin * CFrame.new(x, 0, z)
	local base = Instance.new("Model")
	base.Name = "Turntable"
	local spin = Instance.new("Model")
	spin.Name = "Spin"
	local mesh, top = meshStand(spin, at * CFrame.new(0, FLOOR_TOP, 0))
	local ringY = FLOOR_TOP + 0.08
	if mesh then
		top += FLOOR_TOP
	else
		ringY = 0.55
		disc(base, "Base", STAND_D, 0.8, at * CFrame.new(0, 0.4, 0), STAND)
		disc(spin, "Top", STAND_D - 0.6, 0.3, at * CFrame.new(0, 0.95, 0), STAND_TOP)
		top = 1.1
	end
	-- glowing blue ring round the foot (stays still)
	local ring = disc(base, "Ring", STAND_D + 0.2, 0.15, at * CFrame.new(0, ringY, 0), BLUE)
	ring.Material = Enum.Material.Neon
	ring.CanCollide = false
	local carAt = at * CFrame.new(0, top, 0) * CFrame.Angles(0, math.rad(turn), 0)
	if not crawler(spin, carAt) then
		displayCar(spin, carAt, color)
	end
	spin.WorldPivot = at -- upright, so the client's turn spins it about the vertical
	spin.Parent = base
	CollectionService:AddTag(spin, "LobbySpin")

	-- spot light in the ceiling right above
	local lamp = disc(base, "Spot", 1.8, 0.2, at * CFrame.new(0, H - 0.1, 0), LIGHT)
	lamp.Material = Enum.Material.Neon
	lamp.CanCollide = false
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Left -- the disc is on its side: local -X points down
	beam.Angle = 45
	beam.Range = 16
	beam.Brightness = 3
	beam.Color = LIGHT
	beam.Shadows = true
	beam.Parent = lamp
	-- soft blue glow from the ring, so the car's sides light up too
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 170, 255)
	glow.Range = 7
	glow.Brightness = 1.5
	glow.Parent = ring
	base.Parent = parent
end

function Shop.build(parent: Instance, origin: CFrame, _width: number?, _depth: number?)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local inside = BACK - FRONT
	local midZ = (BACK + FRONT) / 2

	block(parent, "Floor", Vector3.new(28, 0.4, inside), at(0, 0.2, midZ), FLOOR)
	block(parent, "Step", Vector3.new(28, 0.2, 1), at(0, 0.1, FRONT - 0.5), STAND_TOP)
	block(parent, "BackWall", Vector3.new(28, H, 1), at(0, H / 2, BACK - 0.5), WHITE)
	block(parent, "BackStripe", Vector3.new(26, 1, 0.2), at(0, 5, BACK - 1.1), BLUE)
	for _, side in { -1, 1 } do
		block(parent, "SideWall", Vector3.new(1, H, inside), at(side * 13.5, H / 2, midZ), WHITE)
		-- blue panel wrapping the front edge of each side wall, and a white pillar inside it
		block(
			parent,
			"SidePanel",
			Vector3.new(1.4, H, 2.4),
			at(side * 13.6, H / 2, FRONT + 1.2),
			BLUE
		)
		block(
			parent,
			"SideBand",
			Vector3.new(0.2, 1.4, inside - 2.4),
			at(side * 14.1, H - 1.4, midZ + 1.2),
			BLUE
		)
	end

	-- blue roof with a little overhang, a deep blue lip at the front and a light strip under it
	block(parent, "Roof", Vector3.new(30, 1.6, inside + 3), at(0, H + 0.8, midZ - 0.5), BLUE)
	block(
		parent,
		"RoofTop",
		Vector3.new(29, 0.4, inside + 1.6),
		at(0, H + 1.8, midZ - 0.3),
		BLUE_DARK
	)
	block(parent, "Lip", Vector3.new(30, 3, 1.4), at(0, H + 0.4, FRONT - 1.3), BLUE)
	local strip =
		block(parent, "LightStrip", Vector3.new(27, 0.25, 0.6), at(0, H - 1.2, FRONT - 1), LIGHT)
	strip.Material = Enum.Material.Neon
	strip.CanCollide = false

	-- three turntables: two at the back, one forward in the middle (like the picture)
	stand(parent, origin, -8.5, 6.5, 35, CARS[1])
	stand(parent, origin, 0, -1, -20, CARS[2])
	stand(parent, origin, 8.5, 6.5, -35, CARS[3])

	-- a small counter in the back corner
	block(parent, "Counter", Vector3.new(2, 3, 6), at(-11.5, 1.5, 9.5), BLUE)
	block(parent, "CounterTop", Vector3.new(2.6, 0.3, 6.6), at(-11.5, 3.15, 9.5), WHITE)
	-- carter's RC remote and a battery pack on the counter (when imported), facing the shop
	local counterTop = 3.3
	local face = CFrame.Angles(0, math.rad(-90), 0) -- front toward the middle of the shop (+x)
	MeshProps.place(parent, "RCRemote", at(-11.5, counterTop, 8) * face, 0.8)
	MeshProps.place(parent, "Battery", at(-11.5, counterTop, 11) * face, 0.5)
end

return Shop
