--!strict
-- Builds the racetrack lobby from plain parts (chunky low-poly, few parts, no meshes): a round
-- red-walled arena with a store, truck stage, claw machine, 4 match pads and an entrance gate.
-- Models swap in by name (ClawMachine from ServerStorage.Models; others are named placeholders).
-- Geometry numbers live in Shared.LobbyLayout; the origin comes from LobbyConfig.Lobby.origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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
	claw: Model?, -- the claw machine model, when imported
}

local Lobby = {}

local CLAW_YAW_DEG = 90 -- turns the imported claw machine so its front faces the middle of the lobby (it stands on the right)

local CYAN = Color3.fromRGB(60, 220, 255)
local GREEN = Color3.fromRGB(60, 235, 80)
local YELLOW = Color3.fromRGB(255, 205, 40)
local RED = Color3.fromRGB(215, 40, 40)
local FLOOR = Color3.fromRGB(70, 74, 86)
local DARK = Color3.fromRGB(28, 30, 38)
local GRAY = Color3.fromRGB(150, 152, 165)

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

-- The imported Heavy model (ServerStorage.Models.Car_Heavy, a MeshPart, nose toward +X), scaled to
-- `length` studs long, sitting on the anchor point. Returns a Model
-- you can PivotTo (the invisible "Anchor" part is its pivot), or nil when there is no model.
local function meshCar(
	parent: Instance,
	name: string,
	length: number,
	color: Color3,
	cf: CFrame
): Model?
	local models = ServerStorage:FindFirstChild("Models")
	local template = models and models:FindFirstChild("Car_Heavy")
	if not (template and template:IsA("MeshPart")) then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = name
	local anchor = part(m, "Anchor", Vector3.one, cf, color)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local visual = template:Clone()
	visual.Name = "Visual"
	visual.Size = template.Size * (length / template.Size.X)
	if visual.TextureID == "" then
		visual.Color = color
	end
	visual.Anchored = true
	visual.CanCollide = false
	visual.CFrame = cf * CFrame.new(0, visual.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(90), 0)
	visual.Parent = m
	m.PrimaryPart = anchor
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
	local R, WH = room.radius, room.wallHeight

	-- Floor: one big dark disc (a cylinder on its side), with a start line at the gate.
	part(
		folder,
		"Floor",
		Vector3.new(2, (R + 3) * 2, (R + 3) * 2),
		world(0, -1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		FLOOR,
		Enum.Material.Concrete,
		Enum.PartType.Cylinder
	)

	-- Floor tiles: thin darker lines in a grid (look only).
	for c = -50, 50, 10 do
		local len = 2 * math.sqrt(math.max(R * R - c * c, 0)) - 6
		if len > 4 then
			for _, rot in { 0, math.pi / 2 } do
				local line = part(
					folder,
					"FloorTile",
					Vector3.new(0.3, 0.05, len),
					world(0, 0.03, 0) * CFrame.Angles(0, rot, 0) * CFrame.new(c, 0, 0),
					Color3.fromRGB(52, 55, 66)
				)
				line.CanCollide = false
			end
		end
	end

	-- Round wall: red segments, with a dark post and a cyan light strip between them.
	-- The segment that would sit at the front is left out: that is the entrance gate.
	local segments = 32
	local segW = 2 * math.pi * R / segments * 1.04
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local px, pz = math.sin(a) * R, math.cos(a) * R
		if not (pz > 0 and math.abs(px) < room.wall + L.gate.halfOpening + 3) then
			local pos = Vector3.new(px, WH / 2, pz)
			local cf = CFrame.lookAt(origin + pos, origin + Vector3.new(0, WH / 2, 0))
			part(folder, "Wall", Vector3.new(segW, WH, room.wall), cf, RED)
			-- Dark brick-look panel on the inside, under the red cap.
			local panel = part(
				folder,
				"WallPanel",
				Vector3.new(segW * 0.98, WH * 0.6, 0.5),
				cf * CFrame.new(0, -WH * 0.2, -room.wall / 2 - 0.25),
				Color3.fromRGB(46, 49, 60),
				Enum.Material.Brick
			)
			panel.CanCollide = false
			if i % 2 == 0 then
				local strip = part(
					folder,
					"WallStrip",
					Vector3.new(segW * 0.6, 0.4, 0.4),
					cf * CFrame.new(0, -WH * 0.05, -room.wall / 2 - 0.55),
					CYAN,
					Enum.Material.Neon
				)
				strip.CanCollide = false
			else
				local post = part(
					folder,
					"WallPost",
					Vector3.new(2.4, WH + 3, room.wall + 1),
					cf * CFrame.new(0, 1.5, 0),
					DARK
				)
				glow(post, CYAN, 26, 0.6)
			end
		end
	end

	-- Entrance gate with the checkered start line (the spawn stands just inside).
	local gz = L.gate.z
	for _, sx in { -1, 1 } do
		local gpost = part(
			folder,
			"GatePost",
			Vector3.new(3, 9, 3),
			world(sx * (L.gate.halfOpening + 1.5), 4.5, gz),
			DARK
		)
		local gstrip = part(
			folder,
			"GateStrip",
			Vector3.new(0.5, 6, 0.5),
			world(sx * (L.gate.halfOpening - 0.2), 4.5, gz - 1.6),
			CYAN,
			Enum.Material.Neon
		)
		gstrip.CanCollide = false
		glow(gpost, CYAN, 24, 0.8)
	end
	for col = 1, 12 do
		for row = 1, 2 do
			local white = (col + row) % 2 == 0
			local tile = part(
				folder,
				"StartLine",
				Vector3.new(L.gate.halfOpening * 2 / 12, 0.1, 1.6),
				world(
					-L.gate.halfOpening + (col - 0.5) * L.gate.halfOpening * 2 / 12,
					0.05,
					gz - 2 + row * 1.6
				),
				if white then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(20, 20, 20)
			)
			tile.CanCollide = false
		end
	end

	-- Big CAR VS CAR sign on a red gantry at the back, with the "STAND TO PLAY" board under it.
	local backZ = -(R - 8)
	for _, sx in { -1, 1 } do
		part(folder, "GantryPost", Vector3.new(3, 22, 3), world(sx * 18, 11, backZ), RED)
	end
	part(folder, "GantryBeam", Vector3.new(40, 2.5, 3), world(0, 22, backZ), RED)
	-- Checkered flags on poles at the top of both gantry posts.
	for _, sx in { -1, 1 } do
		part(folder, "FlagPole", Vector3.new(0.4, 8, 0.4), world(sx * 18, 26, backZ + 1), GRAY)
		for col = 1, 3 do
			for row = 1, 3 do
				local flagTile = part(
					folder,
					"FlagTile",
					Vector3.new(1.2, 1.2, 0.2),
					world(sx * (18.2 + 1.2 * col - 0.6), 22.6 + 1.2 * row, backZ + 1.1),
					if (col + row) % 2 == 0
						then Color3.fromRGB(240, 240, 240)
						else Color3.fromRGB(20, 20, 20)
				)
				flagTile.CanCollide = false
			end
		end
	end
	local sign = part(
		folder,
		"WallSign",
		Vector3.new(30, 9, 1),
		CFrame.lookAt(origin + Vector3.new(0, 16.5, backZ + 1.6), origin + Vector3.new(0, 16.5, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(sign, Enum.NormalId.Front, "CAR VS CAR", YELLOW, Color3.fromRGB(20, 60, 150))
	glow(sign, CYAN, 40, 0.8)
	local board = part(
		folder,
		"StandToPlaySign",
		Vector3.new(22, 5, 1),
		CFrame.lookAt(origin + Vector3.new(0, 7, backZ + 8), origin + Vector3.new(0, 7, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(board, Enum.NormalId.Front, "STAND TO PLAY", YELLOW, DARK)
	local sub = part(
		folder,
		"StandToPlaySub",
		Vector3.new(22, 1.6, 1),
		CFrame.lookAt(origin + Vector3.new(0, 3.6, backZ + 8), origin + Vector3.new(0, 3.6, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(sub, Enum.NormalId.Front, "2 PLAYERS TO START", CYAN, DARK)

	-- Truck stage (back-right): raised platform with steps, a rail, and the spinning red truck.
	local sc = L.showcase
	part(
		folder,
		"ShowcaseStage",
		Vector3.new(sc.footprint - 2, 2, sc.footprint - 2),
		world(sc.x, 1, sc.z),
		DARK
	)
	part(
		folder,
		"ShowcaseSteps",
		Vector3.new(8, 1, 3),
		world(sc.x - sc.footprint / 2 + 1 - 1, 0.5, sc.z + sc.footprint / 2 - 0.5),
		GRAY
	)
	-- Yellow rails along the front and the middle-facing side (the steps stay open).
	local stageTop = 2
	local railLen = sc.footprint - 2 - 9
	local frontZ = sc.z + sc.footprint / 2 - 1.2
	local sideX = sc.x - sc.footprint / 2 + 1.2
	local railFront = part(
		folder,
		"StageRail",
		Vector3.new(railLen, 0.4, 0.4),
		world(sc.x + 4.5, stageTop + 1.6, frontZ),
		YELLOW
	)
	railFront.CanCollide = false
	local railSide = part(
		folder,
		"StageRail",
		Vector3.new(0.4, 0.4, sc.footprint - 6),
		world(sideX, stageTop + 1.6, sc.z - 2),
		YELLOW
	)
	railSide.CanCollide = false
	for _, rp in
		{
			Vector3.new(sc.x + 4.5 - railLen / 2, 0, frontZ),
			Vector3.new(sc.x + 4.5 + railLen / 2, 0, frontZ),
			Vector3.new(sideX, 0, sc.z - 2 - (sc.footprint - 6) / 2),
			Vector3.new(sideX, 0, sc.z - 2 + (sc.footprint - 6) / 2),
		}
	do
		local rpost = part(
			folder,
			"StageRailPost",
			Vector3.new(0.5, 1.8, 0.5),
			world(rp.X, stageTop + 0.9, rp.Z),
			YELLOW
		)
		rpost.CanCollide = false
	end
	local ring = part(
		folder,
		"ShowcaseRing",
		Vector3.new(sc.footprint - 3, 0.2, sc.footprint - 3),
		world(sc.x, 2.1, sc.z),
		CYAN,
		Enum.Material.Neon
	)
	ring.CanCollide = false
	glow(ring, CYAN, 28, 1.2)
	local showcaseColor = Color3.fromRGB(230, 50, 60)
	local pivot = world(sc.x, 5, sc.z)
	local showcaseCar = meshCar(folder, "ShowcaseCar", 15, showcaseColor, world(sc.x, 2.2, sc.z))
	if showcaseCar then
		pivot = world(sc.x, 2.2, sc.z)
	else
		showcaseCar = miniCar(folder, "ShowcaseCar", showcaseColor, 1.6, pivot)
	end
	local spinning: Model = showcaseCar
	local angle = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		angle = (angle + dt * 0.6) % (math.pi * 2)
		spinning:PivotTo(pivot * CFrame.Angles(0, angle, 0))
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)

	-- Claw machine (right wall). Placeholder box + the "Gacha" prompt; the imported model
	-- (ServerStorage.Models.ClawMachine) replaces the look and keeps the prompt.
	local g = L.gacha
	local gBase = part(
		folder,
		"GachaBody",
		Vector3.new(g.d, 10, g.w),
		world(g.x, 5, g.z),
		Color3.fromRGB(190, 40, 40)
	)
	local gSign = part(
		folder,
		"GachaSign",
		Vector3.new(0.6, 2.4, 8),
		CFrame.lookAt(
			origin + Vector3.new(g.x - g.d / 2 - 0.4, 11, g.z),
			origin + Vector3.new(0, 11, g.z)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(gSign, Enum.NormalId.Front, "CLAW", YELLOW, DARK)
	prompt(gBase, "GachaPrompt", "Play", "Claw Machine")

	local models = ServerStorage:FindFirstChild("Models")
	local clawModel: Model? = nil
	local clawTemplate = models and models:FindFirstChild("ClawMachine")
	if clawTemplate and clawTemplate:IsA("Model") then
		for _, child in folder:GetChildren() do
			if child ~= gBase and child.Name:sub(1, 5) == "Gacha" then
				child:Destroy()
			end
		end
		-- The placeholder box stays as an invisible anchor for "GachaPrompt".
		gBase.Transparency = 1
		gBase.CanCollide = false
		local claw = clawTemplate:Clone()
		claw.Name = "ClawMachine"
		for _, d in claw:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		-- Floor level, facing the middle of the lobby (-X from the right wall).
		claw:PivotTo(world(g.x, 0, g.z) * CFrame.Angles(0, math.rad(CLAW_YAW_DEG), 0))
		claw.Parent = folder
		clawModel = claw
	end

	-- Store booth (back-left): yellow counter with a shelf behind it.
	local s = L.store
	local counter = part(
		folder,
		"StoreCounter",
		Vector3.new(s.w, 4, 4),
		world(s.x, 2, s.z + s.d / 2 - 2),
		YELLOW
	)
	part(
		folder,
		"CounterTop",
		Vector3.new(s.w + 0.6, 0.5, 4.6),
		world(s.x, 4.25, s.z + s.d / 2 - 2),
		DARK
	)
	part(folder, "StoreBack", Vector3.new(s.w, 9, 1), world(s.x, 4.5, s.z - s.d / 2 + 0.5), DARK)
	for level = 1, 2 do
		part(
			folder,
			"Shelf",
			Vector3.new(s.w - 2, 0.5, 2.5),
			world(s.x, 2 + level * 2.6, s.z - s.d / 2 + 2),
			GRAY,
			Enum.Material.Metal
		)
	end
	-- Stock on the shelves: two tires (dark with a yellow hub) and colourful boxes.
	local boxColors = {
		Color3.fromRGB(235, 90, 60),
		Color3.fromRGB(70, 140, 240),
		Color3.fromRGB(255, 205, 40),
		Color3.fromRGB(80, 200, 110),
		Color3.fromRGB(190, 90, 255),
	}
	for level = 1, 2 do
		local shelfY = 2 + level * 2.6
		for k = 1, 5 do
			local ix = s.x - s.w / 2 + 3 + (k - 1) * (s.w - 6) / 4
			local iz = s.z - s.d / 2 + 2
			if level == 1 and k <= 2 then
				local tire = part(
					folder,
					"ShelfTire",
					Vector3.new(1.2, 3, 3),
					world(ix, shelfY + 1.75, iz) * CFrame.Angles(0, math.pi / 2, 0),
					Color3.fromRGB(22, 22, 26),
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
				tire.CanCollide = false
				local hub = part(
					folder,
					"ShelfHub",
					Vector3.new(1.3, 1.5, 1.5),
					world(ix, shelfY + 1.75, iz) * CFrame.Angles(0, math.pi / 2, 0),
					YELLOW,
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
				hub.CanCollide = false
			else
				local box = part(
					folder,
					"ShelfBox",
					Vector3.new(2, 1.3, 1.6),
					world(ix, shelfY + 0.9, iz),
					boxColors[(k + level) % #boxColors + 1]
				)
				box.CanCollide = false
			end
		end
	end
	local counterGlow = part(
		folder,
		"CounterGlow",
		Vector3.new(s.w - 2, 0.3, 0.3),
		world(s.x, 0.6, s.z + s.d / 2 + 0.2),
		YELLOW,
		Enum.Material.Neon
	)
	counterGlow.CanCollide = false
	part(folder, "StoreRoof", Vector3.new(s.w + 1, 1, s.d), world(s.x, 11, s.z), YELLOW)
	for _, sx in { -1, 1 } do
		part(
			folder,
			"StorePost",
			Vector3.new(1, 10, 1),
			world(s.x + sx * (s.w / 2 - 0.5), 5, s.z + s.d / 2 - 0.5),
			YELLOW
		)
	end
	local stSign = part(
		folder,
		"StoreSign",
		Vector3.new(10, 2.6, 0.6),
		CFrame.lookAt(
			origin + Vector3.new(s.x, 9.6, s.z + s.d / 2 + 0.4),
			origin + Vector3.new(s.x, 9.6, s.z + 40)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(stSign, Enum.NormalId.Front, "STORE", YELLOW, DARK)
	glow(stSign, YELLOW, 24, 1)
	prompt(counter, "StorePrompt", "Open", "Store")

	-- Three light chevrons on the floor between the pads, pointing at the back wall.
	for k = 0, 2 do
		for _, sx in { -1, 1 } do
			local chev = part(
				folder,
				"FloorChevron",
				Vector3.new(5, 0.06, 1.1),
				world(sx * 2.1, 0.05, 6 + k * 3.2) * CFrame.Angles(0, -sx * math.rad(35), 0),
				Color3.fromRGB(105, 110, 125)
			)
			chev.CanCollide = false
		end
	end

	-- Match pads: green slabs in a 2x2 grid. Each has a number badge and a "0/2 PLAYERS" board
	-- on its back edge (the board text is what LobbyService updates).
	local pads: { PadHandle } = {}
	for i, pp in L.pads do
		local size = L.padSize
		part(folder, "PadBase", Vector3.new(size, 0.8, size), world(pp.x, 0.4, pp.z), DARK)
		for _, cx in { -1, 1 } do
			for _, cz in { -1, 1 } do
				part(
					folder,
					"PadCorner",
					Vector3.new(2, 1.2, 2),
					world(pp.x + cx * (size / 2 - 1), 0.6, pp.z + cz * (size / 2 - 1)),
					YELLOW
				)
			end
		end
		local padPart = part(
			folder,
			"MatchPad" .. i,
			Vector3.new(size - 4, 0.4, size - 4),
			world(pp.x, 1, pp.z),
			GREEN,
			Enum.Material.Neon
		)
		padPart.Transparency = 0.15
		-- Two white "person" icons on the pad (flat discs: head and shoulders).
		for _, ix in { -2.6, 2.6 } do
			local head = part(
				folder,
				"PadIconHead",
				Vector3.new(0.1, 1.6, 1.6),
				world(pp.x + ix, 1.25, pp.z - 1.4) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(245, 245, 245),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			head.CanCollide = false
			local body = part(
				folder,
				"PadIconBody",
				Vector3.new(0.1, 3.4, 3.4),
				world(pp.x + ix, 1.25, pp.z + 1.2) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(245, 245, 245),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			body.CanCollide = false
		end
		glow(padPart, GREEN, 18, 1)
		local badge = part(
			folder,
			"PadNumber" .. i,
			Vector3.new(2.6, 2.4, 0.6),
			CFrame.lookAt(
				origin + Vector3.new(pp.x - size / 2 + 1.6, 3, pp.z - size / 2),
				origin + Vector3.new(pp.x - size / 2 + 1.6, 3, pp.z + 10)
			),
			YELLOW
		)
		label(badge, Enum.NormalId.Front, string.format("%02d", i), DARK, nil)
		local pboard = part(
			folder,
			"PadSign" .. i,
			Vector3.new(8, 2.4, 0.6),
			CFrame.lookAt(
				origin + Vector3.new(pp.x + 2, 3, pp.z - size / 2),
				origin + Vector3.new(pp.x + 2, 3, pp.z + 10)
			),
			Color3.fromRGB(14, 12, 24)
		)
		local title =
			label(pboard, Enum.NormalId.Front, "0/2 PLAYERS", GREEN, Color3.fromRGB(10, 80, 40))
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

	-- Scenery: bench, tire stack, cones and plants (left), plants by the claw. No collision on the
	-- small stuff so nobody gets stuck.
	part(folder, "Bench", Vector3.new(3, 2.2, 8), world(-52, 1.1, 8), RED)
	part(folder, "BenchBack", Vector3.new(0.8, 3, 8), world(-53.4, 3, 8), RED)
	for k = 0, 2 do
		part(
			folder,
			"Tire",
			Vector3.new(2.2, 4.4, 4.4),
			world(-50, 1.1 + k * 2.2, 22) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			nil,
			Enum.PartType.Cylinder
		)
	end
	for _, cp in { Vector3.new(-44, 0, 28), Vector3.new(-41, 0, 31) } do
		local cone = part(
			folder,
			"Cone",
			Vector3.new(1.6, 3, 1.6),
			world(cp.X, 1.5, cp.Z),
			Color3.fromRGB(255, 120, 30)
		)
		cone.CanCollide = false
		part(
			folder,
			"ConeBase",
			Vector3.new(2.4, 0.3, 2.4),
			world(cp.X, 0.15, cp.Z),
			Color3.fromRGB(30, 30, 35)
		).CanCollide =
			false
	end
	for _, pp in
		{
			Vector3.new(-52, 0, -6),
			Vector3.new(-48, 0, 38),
			Vector3.new(54, 0, -6),
			Vector3.new(50, 0, 32),
		}
	do
		part(folder, "Planter", Vector3.new(4, 2, 4), world(pp.X, 1, pp.Z), GRAY)
		part(
			folder,
			"Plant",
			Vector3.new(3, 3, 3),
			world(pp.X, 3.5, pp.Z),
			Color3.fromRGB(60, 170, 60)
		)
	end

	-- Spawn: just inside the gate, looks at the middle of the pads.
	local sp = L.spawn
	local spawnPos = origin + Vector3.new(sp.x, 0.5, sp.z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(sp.size, 1, sp.size)
	spawn.CFrame = CFrame.lookAt(spawnPos, origin + Vector3.new(0, 0.5, 0))
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Material = Enum.Material.Neon
	spawn.Color = YELLOW
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	folder.Parent = workspace
	return { spawn = spawn, pads = pads, folder = folder, claw = clawModel }
end

return Lobby
