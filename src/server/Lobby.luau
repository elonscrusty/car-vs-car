--!strict
-- Builds the lobby, a huge race HQ warehouse, from plain parts first (walls, roof, skylights,
-- mezzanine, floor zones, the store, claw machine, truck stage, 4 match pads and a bay door).
-- LobbyProps then swaps in the Blender models by name and places the prop clusters; LobbyLife
-- adds the moving and glowing bits. Plain parts stay as the fallback when a model is missing.
-- Geometry numbers live in Shared.LobbyLayout; the origin comes from LobbyConfig.Lobby.origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyLife = require(script.Parent.LobbyLife)
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
	local HW, HL, WH, UH = room.halfW, room.halfL, room.wallHeight, room.upper
	local top = WH + UH -- underside of the roof

	-- Floor: one big dark concrete slab.
	part(
		folder,
		"Floor",
		Vector3.new(HW * 2 + 4, 2, HL * 2 + 4),
		world(0, -1, 0),
		FLOOR,
		Enum.Material.Concrete
	)
	-- A flat painted mark on the floor (look only).
	local function mark(
		name: string,
		w: number,
		d: number,
		x: number,
		z: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = part(folder, name, Vector3.new(w, 0.05, d), world(x, 0.04, z), color, material)
		p.CanCollide = false
		p.CanQuery = false
		return p
	end
	-- A rectangle outline of four thin lines.
	local function outline(
		name: string,
		w: number,
		d: number,
		x: number,
		z: number,
		thick: number,
		color: Color3,
		material: Enum.Material?
	)
		mark(name, w, thick, x, z - d / 2, color, material)
		mark(name, w, thick, x, z + d / 2, color, material)
		mark(name, thick, d, x - w / 2, z, color, material)
		mark(name, thick, d, x + w / 2, z, color, material)
	end

	-- Zones on the floor: darker patches with yellow edges for the garage and the claw corner, a
	-- dark apron under the pads, a cyan frame around the hero stage, and lane lines from the door.
	local sc = L.showcase
	mark("GarageFloor", 34, 92, -HW + 17, 8, Color3.fromRGB(52, 55, 64))
	outline("GarageEdge", 34, 92, -HW + 17, 8, 0.6, YELLOW)
	mark("ClawFloor", 26, 56, HW - 13, -30, Color3.fromRGB(52, 55, 64))
	outline("ClawEdge", 26, 56, HW - 13, -30, 0.6, YELLOW)
	mark("PadApron", 112, 26, 0, L.pads[1].z, Color3.fromRGB(45, 48, 58))
	outline("PadEdge", 112, 26, 0, L.pads[1].z, 0.6, YELLOW)
	outline(
		"PlazaFrame",
		sc.footprint + 14,
		sc.footprint + 14,
		sc.x,
		sc.z,
		0.8,
		Color3.fromRGB(70, 130, 150),
		Enum.Material.SmoothPlastic
	)
	for z = L.gate.z - 4, L.pads[1].z + 16, -6 do
		mark("FloorDash", 0.8, 3.2, 0, z, YELLOW)
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

	-- Walls: a red lower wall (the Blender panels go in front), a tall concrete upper wall with
	-- tall windows that glow, steel columns. The front wall is open in the middle: the bay door.
	local CONCRETE = Color3.fromRGB(62, 65, 74)
	local STEEL = RED -- red steel columns and bracing
	local WALL_GRAY = Color3.fromRGB(48, 51, 60)
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
				part(folder, "Wall", Vector3.new(segW + 0.1, WH, room.wall), cf, WALL_GRAY)
				local panel = part(
					folder,
					"WallPanel",
					Vector3.new(segW * 0.98, WH * 0.6, 0.5),
					cf * CFrame.new(0, -WH * 0.2, -room.wall / 2 - 0.25),
					Color3.fromRGB(38, 41, 50),
					Enum.Material.Brick
				)
				panel.CanCollide = false
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
				elseif name == "L" or name == "R" then
					-- A tall window of glowing glass between the columns.
					local win = part(
						folder,
						"WindowGlass",
						Vector3.new(segW * 0.7, 14, 0.3),
						ucf * CFrame.new(0, 2, -room.wall / 2 - 0.2),
						Color3.fromRGB(205, 190, 160),
						Enum.Material.Neon
					)
					win.CanCollide = false
					win.CanQuery = false
					local light = Instance.new("SurfaceLight")
					light.Face = Enum.NormalId.Front
					light.Range = 36
					light.Brightness = 0.7
					light.Angle = 150
					light.Color = Color3.fromRGB(255, 232, 195)
					light.Shadows = false
					light.Parent = win
					for _, tilt in { -1, 1 } do
						local brace = part(
							folder,
							"XBrace",
							Vector3.new(math.sqrt(segW * segW + UH * UH) * 0.96, 0.7, 0.7),
							ucf
								* CFrame.new(0, 0, -room.wall / 2 - 0.6)
								* CFrame.Angles(0, 0, math.atan2(UH, segW) * tilt),
							STEEL,
							Enum.Material.Metal
						)
						brace.CanCollide = false
						brace.CanQuery = false
					end
					for _, mx in { -0.25, 0.25 } do
						local mull = part(
							folder,
							"WindowBar",
							Vector3.new(0.5, 14.4, 0.4),
							ucf * CFrame.new(segW * 0.7 * mx, 2, -room.wall / 2 - 0.3),
							DARK
						)
						mull.CanCollide = false
						mull.CanQuery = false
					end
				end
			end
		end
	end
	-- Corner posts (dark, with a cyan glow) full height.
	for _, cx in { -HW, HW } do
		for _, cz in { -HL, HL } do
			part(
				folder,
				"WallPost",
				Vector3.new(4, top, 4),
				world(cx + (if cx < 0 then -1 else 1), top / 2, cz + (if cz < 0 then -1 else 1)),
				DARK
			)
		end
	end
	-- Above the bay door: a lintel with the rolled-up roller door under it.
	local lintelW = gap * 2
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
		Vector3.new(L.gate.halfOpening * 2 + 2, 2.6, 2.6),
		world(0, WH - 1, HL - 1.6),
		Color3.fromRGB(150, 153, 163),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	roll.CanCollide = false

	-- Roof: dark steel deck, long steel beams, a few cross beams (the Blender trusses go over the
	-- rest), glowing skylights and hanging lamps.
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
	for _, bx in { -60, -30, 0, 30, 60 } do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(1.4, 1.8, HL * 2),
			world(bx, top - 0.9, 0),
			DARK,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
		local strip = part(
			folder,
			"BeamNeon",
			Vector3.new(0.5, 0.3, HL * 2),
			world(bx, top - 1.9, 0),
			CYAN,
			Enum.Material.Neon
		)
		strip.CanCollide = false
		strip.CanQuery = false
	end
	for _, bz in { -60, -12, 12, 60 } do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(HW * 2, 1.8, 1.4),
			world(0, top - 0.9, bz),
			DARK,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
		local strip = part(
			folder,
			"BeamNeon",
			Vector3.new(HW * 2, 0.3, 0.5),
			world(0, top - 1.9, bz),
			CYAN,
			Enum.Material.Neon
		)
		strip.CanCollide = false
		strip.CanQuery = false
	end
	-- Skylights: bright panels in the roof that pour light on the zones below.
	for _, sk in
		{
			{ 0, sc.z, 34, 10 },
			{ 0, L.pads[1].z, 100, 6 },
			{ -HW + 14, 8, 10, 56 },
			{ HW - 12, -28, 10, 40 },
			{ HW - 14, 38, 10, 22 },
			{ 0, L.spawn.z, 40, 6 },
		}
	do
		local panel = part(
			folder,
			"Skylight",
			Vector3.new(sk[3], 0.5, sk[4]),
			world(sk[1], top - 0.3, sk[2]),
			Color3.fromRGB(226, 214, 188),
			Enum.Material.Neon
		)
		panel.CanCollide = false
		panel.CanQuery = false
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 48
		light.Brightness = 0.9
		light.Angle = 160
		light.Color = Color3.fromRGB(255, 244, 222)
		light.Shadows = false
		light.Parent = panel
	end
	-- Hanging lamps on long cords, grouped over the zones.
	local lampY = top - 15
	for _, lp in
		{
			{ -36, L.pads[1].z },
			{ -12, L.pads[1].z },
			{ 12, L.pads[1].z },
			{ 36, L.pads[1].z },
			{ -20, sc.z - 14 },
			{ 20, sc.z - 14 },
			{ -20, sc.z + 14 },
			{ 20, sc.z + 14 },
			{ -78, -2 },
			{ -78, 22 },
			{ -78, 46 },
			{ 78, -44 },
			{ 78, -16 },
			{ 78, 34 },
			{ 78, 48 },
			{ -18, 58 },
			{ 18, 58 },
		}
	do
		local cord = part(
			folder,
			"LampCord",
			Vector3.new(0.25, top - lampY, 0.25),
			world(lp[1], (top + lampY) / 2, lp[2]),
			DARK
		)
		cord.CanCollide = false
		cord.CanQuery = false
		local shade = part(
			folder,
			"LampShade",
			Vector3.new(5, 0.8, 2.2),
			world(lp[1], lampY + 0.5, lp[2]),
			Color3.fromRGB(60, 62, 70),
			Enum.Material.Metal
		)
		shade.CanCollide = false
		shade.CanQuery = false
		local bulb = part(
			folder,
			"LampGlow",
			Vector3.new(4.4, 0.3, 1.6),
			world(lp[1], lampY, lp[2]),
			Color3.fromRGB(255, 244, 200),
			Enum.Material.Neon
		)
		bulb.CanCollide = false
		bulb.CanQuery = false
		glow(bulb, Color3.fromRGB(255, 244, 200), 40, 0.7)
	end

	-- Big gate: two cyan posts with a checkered start line across the way in.
	local gz = L.gate.z
	for _, sx in { -1, 1 } do
		local gpost = part(
			folder,
			"GatePost",
			Vector3.new(3, 12, 3),
			world(sx * (L.gate.halfOpening + 1.5), 6, gz),
			DARK
		)
		local gstrip = part(
			folder,
			"GateStrip",
			Vector3.new(0.5, 9, 0.5),
			world(sx * (L.gate.halfOpening - 0.2), 6, gz - 1.6),
			Color3.fromRGB(70, 130, 150),
			Enum.Material.SmoothPlastic
		)
		gstrip.CanCollide = false
		glow(gpost, CYAN, 24, 0.3)
	end
	local startW = gap * 2
	for col = 1, 32 do
		for row = 1, 2 do
			local white = (col + row) % 2 == 0
			local tile = part(
				folder,
				"StartLine",
				Vector3.new(startW / 32, 0.1, 1.6),
				world(-startW / 2 + (col - 0.5) * startW / 32, 0.05, gz - 2 + row * 1.6),
				if white then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(20, 20, 20)
			)
			tile.CanCollide = false
		end
	end

	-- The giant CAR VS CAR sign on the back wall, with a glowing frame.
	local sign = part(
		folder,
		"WallSign",
		Vector3.new(64, 14, 1),
		CFrame.lookAt(origin + Vector3.new(0, 31, -HL + 1.6), origin + Vector3.new(0, 31, 0)),
		Color3.fromRGB(14, 12, 24)
	)
	label(sign, Enum.NormalId.Front, "CAR VS CAR", YELLOW, Color3.fromRGB(20, 60, 150))
	glow(sign, CYAN, 60, 0.35)
	for _, fr in
		{
			{ 66, 0.8, 0, 38.4 },
			{ 66, 0.8, 0, 23.6 },
			{ 0.8, 15.6, -33, 31 },
			{ 0.8, 15.6, 33, 31 },
		}
	do
		local f = part(
			folder,
			"SignFrame",
			Vector3.new(fr[1], fr[2], 0.6),
			world(fr[3], fr[4], -HL + 1.2),
			Color3.fromRGB(70, 130, 150),
			Enum.Material.SmoothPlastic
		)
		f.CanCollide = false
	end

	for _, fx in { -40, 40 } do
		for col = 1, 4 do
			for row = 1, 3 do
				local flag = part(
					folder,
					"SignFlag",
					Vector3.new(2, 2, 0.4),
					world(fx + (col - 2.5) * 2, 33 - row * 2, -HL + 1.2),
					if (col + row) % 2 == 0
						then Color3.fromRGB(240, 240, 240)
						else Color3.fromRGB(20, 20, 20)
				)
				flag.CanCollide = false
			end
		end
	end

	-- Mezzanine: a raised walkway along the back wall (look down on the stage), up two ramps.
	local mz = L.mezzanine
	local deckTop = mz.height
	local mzFront = mz.z + mz.d / 2
	part(
		folder,
		"MezzDeck",
		Vector3.new(mz.w, 1, mz.d),
		world(mz.x, deckTop - 0.5, mz.z),
		Color3.fromRGB(60, 64, 74),
		Enum.Material.Metal
	)
	local mzEdge = part(
		folder,
		"MezzEdge",
		Vector3.new(mz.w, 0.4, 0.5),
		world(mz.x, deckTop - 0.9, mzFront),
		Color3.fromRGB(235, 190, 40),
		Enum.Material.SmoothPlastic
	)
	mzEdge.CanCollide = false
	for cx = -mz.w / 2 + 4, mz.w / 2 - 4, (mz.w - 8) / 6 do
		part(
			folder,
			"MezzColumn",
			Vector3.new(1.6, deckTop - 1, 1.6),
			world(mz.x + cx, (deckTop - 1) / 2, mzFront - 1),
			STEEL,
			Enum.Material.Metal
		)
	end
	-- Railing along the front, between the ramps.
	local railTop = deckTop + 3.2
	for rx = -mz.w / 2 + 6, mz.w / 2 - 6, 5 do
		local post = part(
			folder,
			"MezzRailPost",
			Vector3.new(0.4, 3.2, 0.4),
			world(mz.x + rx, deckTop + 1.6, mzFront - 0.4),
			YELLOW
		)
		post.CanCollide = false
	end
	for _, ry in { railTop, deckTop + 1.6 } do
		local rail = part(
			folder,
			"MezzRail",
			Vector3.new(mz.w - 12, 0.3, 0.3),
			world(mz.x, ry, mzFront - 0.4),
			YELLOW
		)
		rail.CanCollide = false
	end
	-- The ramps up to it (wide, gentle, with a glowing edge).
	for _, rm in L.ramps do
		local lowZ = rm.z + rm.d / 2
		local highZ = rm.z - rm.d / 2
		local lo = origin + Vector3.new(rm.x, 0, lowZ)
		local hi = origin + Vector3.new(rm.x, deckTop, highZ)
		local len = (hi - lo).Magnitude
		local rcf = CFrame.lookAt((lo + hi) / 2, hi) * CFrame.new(0, -0.4, 0)
		part(
			folder,
			"MezzRamp",
			Vector3.new(rm.w, 0.8, len),
			rcf,
			Color3.fromRGB(70, 74, 84),
			Enum.Material.Metal
		)
		for _, ex in { -1, 1 } do
			local edge = part(
				folder,
				"MezzRampEdge",
				Vector3.new(0.4, 0.4, len),
				rcf * CFrame.new(ex * (rm.w / 2 - 0.2), 0.5, 0),
				Color3.fromRGB(235, 190, 40),
				Enum.Material.SmoothPlastic
			)
			edge.CanCollide = false
		end
	end

	-- Truck stage in the middle: raised platform and the spinning red truck.
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
	local railBase = 2
	local railLen = sc.footprint - 2 - 9
	local frontZ = sc.z + sc.footprint / 2 - 1.2
	local sideX = sc.x - sc.footprint / 2 + 1.2
	local railFront = part(
		folder,
		"StageRail",
		Vector3.new(railLen, 0.4, 0.4),
		world(sc.x + 4.5, railBase + 1.6, frontZ),
		YELLOW
	)
	railFront.CanCollide = false
	local railSide = part(
		folder,
		"StageRail",
		Vector3.new(0.4, 0.4, sc.footprint - 6),
		world(sideX, railBase + 1.6, sc.z - 2),
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
			world(rp.X, railBase + 0.9, rp.Z),
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
	glow(ring, CYAN, 28, 0.3)
	local showcaseColor = Color3.fromRGB(230, 50, 60)
	-- The Blender stage (LobbyProps) is taller than the plain one, so the truck rides higher.
	local modelsFolder = ServerStorage:FindFirstChild("Models")
	local propsFolder = if modelsFolder then modelsFolder:FindFirstChild("Props") else nil
	local stageModel = if propsFolder then propsFolder:FindFirstChild("truck_stage") else nil
	local stageTop = if stageModel then 4.4 * sc.footprint / 24 + 0.2 else 2.2
	local carY = stageTop - 3.4 -- the deck sits below the railing top
	local pivot = world(sc.x, carY + 4, sc.z)
	local showcaseCar = meshCar(folder, "ShowcaseCar", 24, showcaseColor, world(sc.x, carY, sc.z))
	if showcaseCar then
		pivot = world(sc.x, carY, sc.z)
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
		Color3.fromRGB(235, 190, 40),
		Enum.Material.SmoothPlastic
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
	glow(stSign, YELLOW, 24, 0.4)
	prompt(counter, "StorePrompt", "Open", "Store")

	-- Three light chevrons on the floor between the door and the pads, pointing at the pads.
	for k = 0, 4 do
		for _, sx in { -1, 1 } do
			local chev = part(
				folder,
				"FloorChevron",
				Vector3.new(5, 0.06, 1.1),
				world(sx * 2.1, 0.05, 47 - k * 3),
				Color3.fromRGB(240, 240, 240)
			)
			chev.CFrame = world(sx * 2.1, 0.05, 47 - k * 3)
				* CFrame.Angles(0, -sx * math.rad(35), 0)
			chev.CanCollide = false
		end
	end

	-- "STAND TO PLAY" board hung from the roof over the pad row (no posts, so the stage stays visible).
	local gantryZ = L.pads[1].z
	for _, sx in { -1, 1 } do
		local rod = part(
			folder,
			"BoardRod",
			Vector3.new(0.4, 10, 0.4),
			world(sx * 13, 34.5, gantryZ + 1.6),
			DARK
		)
		rod.CanCollide = false
	end
	local board = part(
		folder,
		"StandToPlaySign",
		Vector3.new(30, 5, 1),
		CFrame.lookAt(
			origin + Vector3.new(0, 27, gantryZ + 1.6),
			origin + Vector3.new(0, 27, gantryZ + 10)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(board, Enum.NormalId.Front, "STAND TO PLAY", YELLOW, DARK)
	board.CanCollide = false
	glow(board, YELLOW, 24, 0.25)
	local sub = part(
		folder,
		"StandToPlaySub",
		Vector3.new(30, 2, 1),
		CFrame.lookAt(
			origin + Vector3.new(0, 23.3, gantryZ + 1.6),
			origin + Vector3.new(0, 23.3, gantryZ + 10)
		),
		Color3.fromRGB(14, 12, 24)
	)
	label(sub, Enum.NormalId.Front, "2 PLAYERS TO START", CYAN, DARK)
	sub.CanCollide = false

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
			Color3.fromRGB(40, 150, 70),
			Enum.Material.SmoothPlastic
		)
		padPart.Transparency = 0
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
		glow(padPart, GREEN, 18, 0.25)
		local under = part(
			folder,
			"PadUnderglow",
			Vector3.new(size + 1, 0.2, size + 1),
			world(pp.x, 0.1, pp.z),
			CYAN,
			Enum.Material.Neon
		)
		under.CanCollide = false
		under.CanQuery = false
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

	LobbyProps.build(folder, origin)
	LobbyLife.build(folder, origin, Vector3.new(L.showcase.x, 0, L.showcase.z), stageTop)

	-- Invisible wall across the bay door so nobody walks out into the empty world.
	local keepIn = part(
		folder,
		"GateBarrier",
		Vector3.new(L.gate.halfOpening * 2 + 2, 40, 1),
		world(0, 20, L.gate.z + 1),
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
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = YELLOW
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	folder.Parent = workspace
	return { spawn = spawn, pads = pads, folder = folder, claw = clawModel }
end

return Lobby
