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
local LobbyDetail = require(script.Parent.LobbyDetail)
local LobbyProps = require(script.Parent.LobbyProps)

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
	local HW, HL, WH = room.halfW, room.halfL, room.wallHeight

	-- Floor: one long dark slab with a grid of darker tile lines.
	part(
		folder,
		"Floor",
		Vector3.new(HW * 2 + 4, 2, HL * 2 + 4),
		world(0, -1, 0),
		FLOOR,
		Enum.Material.Concrete
	)
	for x = -HW + 12, HW - 12, 12 do
		local line = part(
			folder,
			"FloorTile",
			Vector3.new(0.3, 0.05, HL * 2 - 2),
			world(x, 0.03, 0),
			Color3.fromRGB(52, 55, 66)
		)
		line.CanCollide = false
	end
	for z = -HL + 12, HL - 12, 12 do
		local line = part(
			folder,
			"FloorTile",
			Vector3.new(HW * 2 - 2, 0.05, 0.3),
			world(0, 0.03, z),
			Color3.fromRGB(52, 55, 66)
		)
		line.CanCollide = false
	end

	-- A spot on a wall (side "L", "R", "B" back or "F" front): `along` is the z (L, R) or x (B, F)
	-- position, `inset` studs inside the inner wall face. Its -Z side faces the middle of the hall.
	local function wallAt(side: string, along: number, inset: number, y: number): CFrame
		local p: Vector3
		local inward: Vector3
		if side == "L" then
			p, inward = Vector3.new(-HW + inset, y, along), Vector3.xAxis
		elseif side == "R" then
			p, inward = Vector3.new(HW - inset, y, along), -Vector3.xAxis
		elseif side == "B" then
			p, inward = Vector3.new(along, y, -HL + inset), Vector3.zAxis
		else
			p, inward = Vector3.new(along, y, HL - inset), -Vector3.zAxis
		end
		return CFrame.lookAt(origin + p, origin + p + inward)
	end

	-- Walls: a red lower wall (brick panel and cyan lights on the inside), a concrete upper wall,
	-- steel columns. The front wall has a gap for the roller door (the lintel closes it above).
	local CONCRETE = Color3.fromRGB(112, 115, 124)
	local STEEL = Color3.fromRGB(85, 88, 98)
	local UH = 15 -- height of the upper wall
	local top = WH + UH
	local gap = L.gate.halfOpening + 1
	local sides = {
		{ "L", Vector3.new(-HW, 0, -HL), Vector3.new(-HW, 0, HL) },
		{ "R", Vector3.new(HW, 0, -HL), Vector3.new(HW, 0, HL) },
		{ "B", Vector3.new(-HW, 0, -HL), Vector3.new(HW, 0, -HL) },
		{ "F", Vector3.new(-HW, 0, HL), Vector3.new(HW, 0, HL) },
	}
	for _, sd in sides do
		local name = sd[1] :: string
		local a, b = sd[2] :: Vector3, sd[3] :: Vector3
		local len = (b - a).Magnitude
		local count = math.floor(len / 12 + 0.5)
		local segW = len / count
		local dir = (b - a).Unit
		for i = 0, count - 1 do
			local center = a + dir * ((i + 0.5) * segW)
			local along = if name == "L" or name == "R" then center.Z else center.X
			if not (name == "F" and math.abs(along) < gap) then
				local base = wallAt(name, along, -room.wall / 2, 0)
				local cf = base * CFrame.new(0, WH / 2, 0)
				part(folder, "Wall", Vector3.new(segW + 0.1, WH, room.wall), cf, RED)
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
				end
				local ucf = base * CFrame.new(0, WH + UH / 2, 0)
				part(
					folder,
					"GarageWall",
					Vector3.new(segW + 0.1, UH, room.wall),
					ucf,
					CONCRETE,
					Enum.Material.Concrete
				)
				local band = part(
					folder,
					"GarageBand",
					Vector3.new(segW, 0.9, 0.3),
					ucf * CFrame.new(0, -UH / 2 + 0.6, -room.wall / 2 - 0.15),
					YELLOW
				)
				band.CanCollide = false
				if i % 2 == 1 then
					part(
						folder,
						"GarageColumn",
						Vector3.new(2, UH, room.wall + 1.2),
						ucf,
						STEEL,
						Enum.Material.Metal
					)
				end
			end
		end
	end
	-- Corner posts (dark, with a cyan glow) full height.
	for _, cx in { -HW, HW } do
		for _, cz in { -HL, HL } do
			local post = part(
				folder,
				"WallPost",
				Vector3.new(4, top, 4),
				world(cx + (if cx < 0 then -1 else 1), top / 2, cz + (if cz < 0 then -1 else 1)),
				DARK
			)
			glow(post, CYAN, 24, 0.5)
		end
	end
	-- Above the entrance: a lintel with the rolled-up roller door under it.
	local lintelW = gap * 2 + 2
	part(
		folder,
		"GateLintel",
		Vector3.new(lintelW, UH, room.wall),
		world(0, WH + UH / 2, HL + room.wall / 2),
		CONCRETE,
		Enum.Material.Concrete
	)
	local lintelBand = part(
		folder,
		"GateHazard",
		Vector3.new(lintelW - 2, 0.9, 0.3),
		world(0, WH + 0.5, HL - 0.15),
		YELLOW
	)
	lintelBand.CanCollide = false
	local roll = part(
		folder,
		"RollerDoorRoll",
		Vector3.new(L.gate.halfOpening * 2 + 2, 2.2, 2.2),
		world(0, WH - 0.8, HL - 1.4),
		Color3.fromRGB(150, 153, 163),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	roll.CanCollide = false
	-- The wall between the door posts and the first full wall piece is covered by the lintel; the
	-- gap below it stays open (that is the way in).

	-- Roof: dark steel deck, cross beams and hanging lamps.
	local roof = part(
		folder,
		"GarageRoof",
		Vector3.new(HW * 2 + room.wall * 2 + 2, 1, HL * 2 + room.wall * 2 + 2),
		world(0, top + 0.5, 0),
		Color3.fromRGB(38, 40, 48),
		Enum.Material.Metal
	)
	roof.CanCollide = false
	roof.CanQuery = false
	for z = -HL + 6, HL - 6, 12 do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(HW * 2, 1.6, 1.2),
			world(0, top - 0.8, z),
			STEEL,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
	end
	for _, bx in { -24, 0, 24 } do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(1.2, 1.6, HL * 2),
			world(bx, top - 0.8, 0),
			STEEL,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
	end
	for _, lx in { -24, -8, 8, 24 } do
		for lz = -54, 54, 18 do
			local cord =
				part(folder, "LampCord", Vector3.new(0.2, 5, 0.2), world(lx, top - 3.4, lz), DARK)
			cord.CanCollide = false
			cord.CanQuery = false
			local shade = part(
				folder,
				"LampShade",
				Vector3.new(5, 0.8, 2.2),
				world(lx, top - 6, lz),
				Color3.fromRGB(60, 62, 70),
				Enum.Material.Metal
			)
			shade.CanCollide = false
			shade.CanQuery = false
			local bulb = part(
				folder,
				"LampGlow",
				Vector3.new(4.4, 0.3, 1.6),
				world(lx, top - 6.5, lz),
				Color3.fromRGB(255, 244, 200),
				Enum.Material.Neon
			)
			bulb.CanCollide = false
			bulb.CanQuery = false
			if math.abs(lx) == 8 and lz % 36 == 0 then
				glow(bulb, Color3.fromRGB(255, 244, 200), 45, 0.6)
			end
		end
	end

	-- Closed roller doors on the long walls (look only).
	for _, dd in { { "L", -30 }, { "R", -34 } } do
		local dcf = wallAt(dd[1] :: string, dd[2] :: number, 0.8, 5.8)
		local frame = part(folder, "RollerDoorFrame", Vector3.new(15, 11.6, 0.4), dcf, YELLOW)
		frame.CanCollide = false
		local panel = part(
			folder,
			"RollerDoor",
			Vector3.new(13.4, 10.4, 0.4),
			dcf * CFrame.new(0, 0, -0.2),
			Color3.fromRGB(150, 153, 163),
			Enum.Material.Metal
		)
		panel.CanCollide = false
		for k = 1, 7 do
			local slat = part(
				folder,
				"RollerSlat",
				Vector3.new(13.4, 0.18, 0.2),
				dcf * CFrame.new(0, -5.2 + k * 1.3, -0.5),
				Color3.fromRGB(105, 108, 118)
			)
			slat.CanCollide = false
		end
	end

	-- Tool walls beside the entrance: a workbench (left) and a tool cabinet with oil drums (right).
	for _, side in { -1, 1 } do
		local wcf = wallAt("F", side * 24, 0.6, 5.5)
		local peg =
			part(folder, "ToolWall", Vector3.new(14, 6.5, 0.4), wcf, Color3.fromRGB(52, 56, 66))
		peg.CanCollide = false
		local toolColors = { RED, YELLOW, CYAN, Color3.fromRGB(220, 220, 225) }
		for k = 1, 8 do
			local tool = part(
				folder,
				"Tool",
				Vector3.new(0.5, 2.6 - (k % 3) * 0.5, 0.3),
				wcf * CFrame.new(-5.6 + (k - 1) * 1.6, 0.4 - (k % 2) * 0.8, -0.35),
				toolColors[k % #toolColors + 1]
			)
			tool.CanCollide = false
		end
		local benchCf = wcf * CFrame.new(0, -2.3, -2.2)
		if side == -1 then
			part(
				folder,
				"Workbench",
				Vector3.new(12, 0.6, 3.4),
				benchCf,
				Color3.fromRGB(150, 110, 70),
				Enum.Material.Wood
			)
			for _, lx in { -5.4, 5.4 } do
				part(
					folder,
					"WorkbenchLeg",
					Vector3.new(0.6, 3.2, 3),
					benchCf * CFrame.new(lx, -1.9, 0),
					STEEL,
					Enum.Material.Metal
				)
			end
			local toolbox = part(
				folder,
				"Toolbox",
				Vector3.new(2.6, 1.4, 1.4),
				benchCf * CFrame.new(-3, 1, 0),
				RED
			)
			toolbox.CanCollide = false
		else
			part(
				folder,
				"ToolCabinet",
				Vector3.new(5, 6, 3),
				wcf * CFrame.new(-3.5, -2.5, -2.2),
				RED
			)
			part(
				folder,
				"ToolCabinetTop",
				Vector3.new(5.2, 0.4, 3.2),
				wcf * CFrame.new(-3.5, 0.7, -2.2),
				DARK
			)
			for k = 0, 2 do
				part(
					folder,
					"OilDrum",
					Vector3.new(4, 2.8, 2.8),
					wcf * CFrame.new(2.2 + k * 3.2, -2.1, -2.2) * CFrame.Angles(0, 0, math.pi / 2),
					if k == 1 then YELLOW else Color3.fromRGB(40, 90, 200),
					Enum.Material.Metal,
					Enum.PartType.Cylinder
				)
			end
		end
	end

	-- Oil stains on the floor (look only).
	for _, st in
		{
			Vector3.new(-4, 0, 36),
			Vector3.new(8, 0, 6),
			Vector3.new(-6, 0, -22),
			Vector3.new(14, 0, 46),
			Vector3.new(-12, 0, 18),
		}
	do
		local stain = part(
			folder,
			"OilStain",
			Vector3.new(0.04, 6 + (st.X % 4), 6 + (st.X % 4)),
			world(st.X, 0.045, st.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(26, 26, 30),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		stain.Transparency = 0.3
		stain.CanCollide = false
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
	local backZ = -(HL - 8)
	for _, sx in { -1, 1 } do
		part(folder, "GantryPost", Vector3.new(3, 22, 3), world(sx * 24, 11, backZ), RED)
	end
	part(folder, "GantryBeam", Vector3.new(52, 2.5, 3), world(0, 22, backZ), RED)
	-- Checkered flags on poles at the top of both gantry posts.
	for _, sx in { -1, 1 } do
		part(folder, "FlagPole", Vector3.new(0.4, 8, 0.4), world(sx * 24, 26, backZ + 1), GRAY)
		for col = 1, 3 do
			for row = 1, 3 do
				local flagTile = part(
					folder,
					"FlagTile",
					Vector3.new(1.2, 1.2, 0.2),
					world(sx * (24.2 + 1.2 * col - 0.6), 22.6 + 1.2 * row, backZ + 1.1),
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
		Vector3.new(36, 10, 1),
		CFrame.lookAt(origin + Vector3.new(0, 16.5, backZ + 1.6), origin + Vector3.new(0, 16.5, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(sign, Enum.NormalId.Front, "CAR VS CAR", YELLOW, Color3.fromRGB(20, 60, 150))
	glow(sign, CYAN, 40, 0.8)
	local board = part(
		folder,
		"StandToPlaySign",
		Vector3.new(22, 5, 1),
		CFrame.lookAt(origin + Vector3.new(0, 8.5, backZ + 8), origin + Vector3.new(0, 8.5, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(board, Enum.NormalId.Front, "STAND TO PLAY", YELLOW, DARK)
	local sub = part(
		folder,
		"StandToPlaySub",
		Vector3.new(22, 1.6, 1),
		CFrame.lookAt(origin + Vector3.new(0, 5.7, backZ + 8), origin + Vector3.new(0, 5.7, 0)),
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

	-- Three light chevrons on the floor ahead of the pads, pointing at the back wall.
	for k = 0, 2 do
		for _, sx in { -1, 1 } do
			local chev = part(
				folder,
				"FloorChevron",
				Vector3.new(5, 0.06, 1.1),
				world(sx * 2.1, 0.05, -34 + k * 3.2) * CFrame.Angles(0, -sx * math.rad(35), 0),
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
		glow(padPart, GREEN, 18, 0.6)
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

	-- Scenery: bench, tire stack and cones (front right), plants along the walls. No collision on the
	-- small stuff so nobody gets stuck.
	part(folder, "Bench", Vector3.new(3, 2.2, 8), world(33, 1.1, 40), RED)
	part(folder, "BenchBack", Vector3.new(0.8, 3, 8), world(34.4, 3, 40), RED)
	for k = 0, 2 do
		part(
			folder,
			"Tire",
			Vector3.new(2.2, 4.4, 4.4),
			world(33, 1.1 + k * 2.2, 32) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			nil,
			Enum.PartType.Cylinder
		)
	end
	for _, cp in { Vector3.new(27, 0, 34), Vector3.new(24, 0, 37) } do
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
			Vector3.new(-33, 0, -24),
			Vector3.new(-33, 0, 38),
			Vector3.new(33, 0, 28),
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

	LobbyDetail.build(folder, origin, { part = part, label = label, glow = glow, wallAt = wallAt })
	LobbyProps.build(folder, origin)

	-- Invisible wall across the gate so nobody walks out of the garage into the empty world.
	local keepIn = part(
		folder,
		"GateBarrier",
		Vector3.new(L.gate.halfOpening * 2 + 2, 30, 1),
		world(0, 15, L.gate.z + 1),
		DARK
	)
	keepIn.Transparency = 1
	keepIn.CanQuery = false

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
