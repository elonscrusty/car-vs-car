--!strict
-- Builds the night neon garage lobby from plain parts (chunky low-poly, few parts, no meshes).
-- Geometry numbers live in Shared.LobbyLayout; the origin comes from LobbyConfig.Lobby.origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

export type PadHandle = {
	part: BasePart,
	prompt: ProximityPrompt,
	setStatus: (text: string) -> (),
}

export type LobbyHandle = {
	spawn: SpawnLocation,
	pads: { PadHandle },
	folder: Folder,
}

local Lobby = {}

local PINK = Color3.fromRGB(255, 60, 170)
local BLUE = Color3.fromRGB(60, 170, 255)
local GREEN = Color3.fromRGB(70, 255, 130)
local YELLOW = Color3.fromRGB(255, 205, 40)
local CONCRETE = Color3.fromRGB(70, 74, 86)
local DARK = Color3.fromRGB(28, 30, 38)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function glow(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- Puts a real TextLabel on one face of a part. Returns the label.
local function label(
	p: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	strokeColor: Color3?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Parent = gui
	if strokeColor then
		local s = Instance.new("UIStroke")
		s.Color = strokeColor
		s.Thickness = 4
		s.Parent = t
	end
	return t
end

local function prompt(
	parent: BasePart,
	name: string,
	action: string,
	object: string
): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.RequiresLineOfSight = false
	pp.MaxActivationDistance = 16
	pp.HoldDuration = 0
	pp.Parent = parent
	return pp
end

-- A simple chunky car from boxes, facing -Z. Used for the showcase and the toy shelf.
local function miniCar(
	parent: Instance,
	name: string,
	color: Color3,
	scale: number,
	cf: CFrame
): Model
	local m = Instance.new("Model")
	m.Name = name
	local s = scale
	local body = part(m, "Body", Vector3.new(4, 1.2, 7) * s, cf, color)
	part(
		m,
		"Cabin",
		Vector3.new(3, 1, 3.4) * s,
		cf * CFrame.new(0, 1.1 * s, 0.6 * s),
		color:Lerp(Color3.new(1, 1, 1), 0.25)
	)
	part(
		m,
		"Glass",
		Vector3.new(3.1, 0.6, 2.2) * s,
		cf * CFrame.new(0, 1.2 * s, 0.4 * s),
		Color3.fromRGB(30, 45, 70),
		Enum.Material.Glass
	)
	part(m, "Bumper", Vector3.new(4.2, 0.6, 0.6) * s, cf * CFrame.new(0, -0.1 * s, -3.6 * s), DARK)
	for _, wx in { -2.1, 2.1 } do
		for _, wz in { -2.3, 2.3 } do
			part(
				m,
				"Wheel",
				Vector3.new(1.4, 1.4, 1.4) * s,
				cf * CFrame.new(wx * s, -0.5 * s, wz * s) * CFrame.Angles(0, 0, math.pi / 2),
				DARK,
				nil,
				Enum.PartType.Cylinder
			)
		end
	end
	local light = part(
		m,
		"Headlight",
		Vector3.new(2.6, 0.4, 0.2) * s,
		cf * CFrame.new(0, 0.2 * s, -3.55 * s),
		Color3.fromRGB(255, 255, 200),
		Enum.Material.Neon
	)
	light.CanCollide = false
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

function Lobby.build(): LobbyHandle
	local L = LobbyLayout
	local origin: Vector3 = LobbyConfig.Lobby.origin
	local at = CFrame.new(origin)
	local function world(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end

	-- A leftover Lobby (e.g. built in edit mode) would overlap this one and flicker.
	for _, old in workspace:GetChildren() do
		if old.Name == "Lobby" then
			old:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local room = L.room
	local W, D, H, T = room.halfW * 2, room.halfD * 2, room.height, room.wall

	-- Floor: dark and wet-shiny, with neon edge strips.
	local floor = part(
		folder,
		"Floor",
		Vector3.new(W + 2 * T, 2, D + 2 * T),
		world(0, -1, 0),
		Color3.fromRGB(34, 36, 48),
		Enum.Material.Concrete
	)
	floor.Reflectance = 0.18
	for _, sx in { -1, 1 } do
		local strip = part(
			folder,
			"FloorStrip",
			Vector3.new(0.6, 0.1, D - 4),
			world(sx * (room.halfW - 2), 0.05, 0),
			BLUE,
			Enum.Material.Neon
		)
		strip.CanCollide = false
	end

	-- Walls (concrete), roof slab, roof beams.
	local wallColor = CONCRETE
	part(
		folder,
		"WallBack",
		Vector3.new(W + 2 * T, H, T),
		world(0, H / 2, -room.halfD - T / 2),
		wallColor,
		Enum.Material.Concrete
	)
	part(
		folder,
		"WallFront",
		Vector3.new(W + 2 * T, H, T),
		world(0, H / 2, room.halfD + T / 2),
		wallColor,
		Enum.Material.Concrete
	)
	part(
		folder,
		"WallLeft",
		Vector3.new(T, H, D),
		world(-room.halfW - T / 2, H / 2, 0),
		wallColor,
		Enum.Material.Concrete
	)
	part(
		folder,
		"WallRight",
		Vector3.new(T, H, D),
		world(room.halfW + T / 2, H / 2, 0),
		wallColor,
		Enum.Material.Concrete
	)
	part(
		folder,
		"Roof",
		Vector3.new(W + 2 * T, 1, D + 2 * T),
		world(0, H + 0.5, 0),
		DARK,
		Enum.Material.Concrete
	)
	for i = -3, 3 do
		part(
			folder,
			"Beam",
			Vector3.new(W, 2, 2),
			world(0, H - 1, i * 14),
			Color3.fromRGB(45, 48, 60),
			Enum.Material.Metal
		)
		if i % 2 == 0 then
			local tube = part(
				folder,
				"CeilingLight",
				Vector3.new(24, 0.4, 1),
				world(0, H - 2.2, i * 14 + 3),
				Color3.fromRGB(235, 245, 255),
				Enum.Material.Neon
			)
			tube.CanCollide = false
			glow(tube, Color3.fromRGB(190, 210, 255), 38, 0.8)
		end
	end

	-- Garage doors on the front wall (inside face), slatted, with a neon frame.
	for _, dx in { -34, 34 } do
		local doorCf = world(dx, 9, room.halfD - 0.3)
		part(
			folder,
			"GarageDoor",
			Vector3.new(24, 18, 0.6),
			doorCf,
			Color3.fromRGB(120, 126, 140),
			Enum.Material.Metal
		)
		for k = 1, 5 do
			part(
				folder,
				"DoorSlat",
				Vector3.new(24, 0.4, 0.9),
				world(dx, k * 3, room.halfD - 0.6),
				Color3.fromRGB(80, 86, 100),
				Enum.Material.Metal
			)
		end
		local frame = part(
			folder,
			"DoorFrame",
			Vector3.new(25, 0.5, 0.5),
			world(dx, 18.3, room.halfD - 0.8),
			PINK,
			Enum.Material.Neon
		)
		frame.CanCollide = false
	end

	-- Big neon wall sign on the back wall.
	local sign = part(
		folder,
		"WallSign",
		Vector3.new(46, 11, 1),
		CFrame.lookAt(
			origin + Vector3.new(0, 19, -room.halfD + 0.6),
			origin + Vector3.new(0, 19, 0)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(sign, Enum.NormalId.Front, "CAR VS CAR", PINK, BLUE)
	local signTrim = part(
		folder,
		"WallSignTrim",
		Vector3.new(48, 0.5, 0.5),
		world(0, 24.8, -room.halfD + 0.9),
		BLUE,
		Enum.Material.Neon
	)
	signTrim.CanCollide = false
	glow(signTrim, PINK, 45, 1.5)
	local signTrim2 = part(
		folder,
		"WallSignTrim",
		Vector3.new(48, 0.5, 0.5),
		world(0, 13.2, -room.halfD + 0.9),
		PINK,
		Enum.Material.Neon
	)
	signTrim2.CanCollide = false

	-- Showcase: glowing round platform with a slowly spinning car.
	local sc = L.showcase
	local platform = part(
		folder,
		"ShowcasePlatform",
		Vector3.new(1, sc.radius * 2, sc.radius * 2),
		world(sc.x, 0.5, sc.z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(25, 30, 45),
		nil,
		Enum.PartType.Cylinder
	)
	platform.Reflectance = 0.1
	local ring = part(
		folder,
		"ShowcaseRing",
		Vector3.new(0.3, sc.radius * 2 + 1.5, sc.radius * 2 + 1.5),
		world(sc.x, 0.2, sc.z) * CFrame.Angles(0, 0, math.pi / 2),
		BLUE,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.CanCollide = false
	glow(ring, BLUE, 28, 1.5)
	local pivot = world(sc.x, 2.6, sc.z)
	local showcaseCar = miniCar(folder, "ShowcaseCar", Color3.fromRGB(230, 50, 60), 1.6, pivot)
	local angle = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		angle = (angle + dt * 0.6) % (math.pi * 2)
		showcaseCar:PivotTo(pivot * CFrame.Angles(0, angle, 0))
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)

	-- Gacha machine: yellow body, glass dome full of capsule balls, sign, prompt.
	local g = L.gacha
	local gBase = part(folder, "GachaBody", Vector3.new(7, 7, 7), world(g.x, 3.5, g.z), YELLOW)
	part(folder, "GachaSlot", Vector3.new(3, 1.6, 0.4), world(g.x + 3.5, 2.2, g.z), DARK)
	local dome = part(
		folder,
		"GachaDome",
		Vector3.new(9, 9, 9),
		world(g.x, 11, g.z),
		Color3.fromRGB(200, 230, 255),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	dome.Transparency = 0.6
	dome.CanCollide = false
	local ballColors =
		{ PINK, BLUE, GREEN, YELLOW, Color3.fromRGB(255, 120, 40), Color3.fromRGB(190, 90, 255) }
	for i = 1, 12 do
		local a = i * 2.4
		local r = 1 + (i % 3) * 1.1
		local ball = part(
			folder,
			"Capsule",
			Vector3.new(1.8, 1.8, 1.8),
			world(g.x + math.cos(a) * r, 9.6 + (i % 4) * 0.9, g.z + math.sin(a) * r),
			ballColors[i % #ballColors + 1],
			nil,
			Enum.PartType.Ball
		)
		ball.CanCollide = false
	end
	local gSign = part(
		folder,
		"GachaSign",
		Vector3.new(0.6, 3, 8),
		CFrame.lookAt(
			origin + Vector3.new(g.x + 0.1, 17.5, g.z),
			origin + Vector3.new(g.x + 10, 17.5, g.z)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(gSign, Enum.NormalId.Front, "GACHA", YELLOW, PINK)
	glow(gSign, YELLOW, 24, 1.2)
	prompt(gBase, "GachaPrompt", "Open", "Gacha")

	-- Store counter: blue desk with a shelf of toy cars, sign, prompt.
	local s = L.store
	local counter = part(
		folder,
		"StoreCounter",
		Vector3.new(s.w, 4, s.d),
		world(s.x, 2, s.z),
		Color3.fromRGB(40, 110, 220)
	)
	part(
		folder,
		"CounterTop",
		Vector3.new(s.w + 0.6, 0.5, s.d + 0.6),
		world(s.x, 4.25, s.z),
		Color3.fromRGB(230, 235, 245)
	)
	local shelfX = s.x - s.w / 2 + 0.8
	part(folder, "ShelfBack", Vector3.new(0.6, 9, s.d), world(-room.halfW + 0.5, 8.5, s.z), DARK)
	local carColors = { "Heavy", "Light", "Ramp", "Spike" }
	for level = 1, 2 do
		part(
			folder,
			"Shelf",
			Vector3.new(3, 0.5, s.d - 2),
			world(-room.halfW + 2, 5 + level * 4, s.z),
			Color3.fromRGB(150, 150, 165),
			Enum.Material.Metal
		)
		for k = 1, 3 do
			local id = carColors[(level + k) % #carColors + 1]
			local c = CarConfig.Cars[id].rgb
			miniCar(
				folder,
				"ToyCar",
				Color3.fromRGB(c[1], c[2], c[3]),
				0.28,
				world(-room.halfW + 2, 6.3 + level * 4, s.z + (k - 2) * 7)
					* CFrame.Angles(0, math.pi / 2, 0)
			)
		end
	end
	local stSign = part(
		folder,
		"StoreSign",
		Vector3.new(0.6, 3, 8),
		CFrame.lookAt(
			origin + Vector3.new(shelfX + 2, 16.5, s.z),
			origin + Vector3.new(shelfX + 12, 16.5, s.z)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(stSign, Enum.NormalId.Front, "STORE", BLUE, Color3.fromRGB(20, 60, 150))
	glow(stSign, BLUE, 24, 1.2)
	prompt(counter, "StorePrompt", "Open", "Store")

	-- Match pads: glowing green discs with an upright "0/2 PLAYERS" sign behind each.
	local pads: { PadHandle } = {}
	for i, pp in L.pads do
		local padPart = part(
			folder,
			"MatchPad" .. i,
			Vector3.new(0.6, L.padSize - 2, L.padSize - 2),
			world(pp.x, 0.3, pp.z) * CFrame.Angles(0, 0, math.pi / 2),
			GREEN,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		padPart.Transparency = 0.15
		glow(padPart, GREEN, 18, 1.2)
		local padRing = part(
			folder,
			"PadRing",
			Vector3.new(0.2, L.padSize, L.padSize),
			world(pp.x, 0.1, pp.z) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			nil,
			Enum.PartType.Cylinder
		)
		padRing.CanCollide = false
		local board = part(
			folder,
			"PadSign" .. i,
			Vector3.new(10, 4, 0.6),
			CFrame.lookAt(origin + Vector3.new(pp.x + 7, 7, pp.z), origin + Vector3.new(0, 7, pp.z)),
			Color3.fromRGB(14, 12, 24)
		)
		part(folder, "PadSignPost", Vector3.new(0.8, 5, 0.8), world(pp.x + 7.2, 2.5, pp.z), DARK)
		local title =
			label(board, Enum.NormalId.Front, "0/2 PLAYERS", GREEN, Color3.fromRGB(10, 80, 40))
		local pr = prompt(padPart, "PadPrompt", "Join", "Match Pad")
		pr:SetAttribute("PadIndex", i)
		padPart:SetAttribute("PadIndex", i)
		pads[i] = {
			part = padPart,
			prompt = pr,
			setStatus = function(text: string)
				title.Text = text
			end,
		}
	end

	-- Spawn: faces the showcase car.
	local sp = L.spawn
	local spawnPos = origin + Vector3.new(sp.x, 0.5, sp.z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(sp.size, 1, sp.size)
	spawn.CFrame = CFrame.lookAt(spawnPos, origin + Vector3.new(L.showcase.x, 0.5, L.showcase.z))
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Material = Enum.Material.Neon
	spawn.Color = PINK
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	folder.Parent = workspace
	return { spawn = spawn, pads = pads, folder = folder }
end

return Lobby
