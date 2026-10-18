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

local CLAW_SCALE = 1.5 -- the imported claw is about 7 studs wide; it stands on a 20 stud platform
local CLAW_YAW_DEG = 180 -- turns the imported claw machine so its front faces the hall (it stands by the back wall)

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
		Vector3.new((HW + L.bay.w) * 2 + 4, 2, HL * 2 + 4), -- also under the garages
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
	for i, pp in L.pads do
		mark("PadApron" .. i, L.padSize + 6, L.padSize + 6, pp.x, pp.z, Color3.fromRGB(45, 48, 58))
		outline("PadEdge" .. i, L.padSize + 6, L.padSize + 6, pp.x, pp.z, 0.5, YELLOW)
	end
	-- Spawn pad and the cyan lane up the middle to the stage.
	local sp0 = L.spawn
	mark("SpawnApron", sp0.size + 6, sp0.size + 6, sp0.x, sp0.z, Color3.fromRGB(45, 48, 58))
	outline("SpawnEdge", sp0.size + 6, sp0.size + 6, sp0.x, sp0.z, 0.5, CYAN, Enum.Material.Neon)
	local lane = L.lane
	local laneLen = lane.fromZ - lane.toZ
	for _, sx in { -1, 1 } do
		mark(
			"LaneLine",
			0.6,
			laneLen,
			sx * lane.halfWidth,
			(lane.fromZ + lane.toZ) / 2,
			CYAN,
			Enum.Material.Neon
		)
	end
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

	-- Garage bays: an open stall for each player down the side walls. Floor plate with a yellow
	-- frame and a number, a low back wall with a red band, and a light bar. LobbyBays puts the
	-- player's car, sign and "Customize" prompt in it.
	local bayBox = L.bay
	local BH = WH - 0.4 -- garage height: just under the lower wall top
	for i, b in L.bays do
		local inward = b.face
		mark("BayFloor" .. i, bayBox.w, bayBox.d, b.x, b.z, Color3.fromRGB(78, 82, 98))
		outline("BayEdge" .. i, bayBox.w, bayBox.d, b.x, b.z, 0.5, YELLOW)
		local number = mark("BayNumber" .. i, 3, 3, b.x + inward * (bayBox.w / 2 - 3), b.z, DARK)
		label(number, Enum.NormalId.Top, tostring(i), YELLOW, nil).Rotation = if inward == 1
			then 90
			else -90
		-- Side dividers (low walls) and the red band on the wall behind.
		for _, side in { -1, 1 } do
			local divider = part(
				folder,
				"BayDivider",
				Vector3.new(bayBox.w, BH, 0.8),
				world(b.x, BH / 2, b.z + side * (bayBox.d / 2 + 0.4)),
				Color3.fromRGB(60, 64, 76),
				Enum.Material.Metal
			)
			divider.Color = Color3.fromRGB(60, 64, 76)
			local cap = part(
				folder,
				"BayDividerCap",
				Vector3.new(bayBox.w, 0.4, 1.0),
				world(b.x, BH + 0.1, b.z + side * (bayBox.d / 2 + 0.4)),
				YELLOW
			)
			cap.CanCollide = false
		end
		local backX = b.x - inward * (bayBox.w / 2 - 0.4)
		part(
			folder,
			"BayBack",
			Vector3.new(0.8, BH, bayBox.d),
			world(backX, BH / 2, b.z),
			Color3.fromRGB(120, 126, 146),
			Enum.Material.Metal
		)
		local band = part(
			folder,
			"BayBand",
			Vector3.new(0.9, 1.6, bayBox.d),
			world(backX + inward * 0.1, BH - 2.8, b.z),
			RED
		)
		band.CanCollide = false
		-- Back wall detail: dark panel seams, a pegboard of tools and a pipe along the top.
		for k = -2, 2 do
			local seam = part(
				folder,
				"BayBackSeam",
				Vector3.new(0.3, BH - 2.4, 0.4),
				world(backX + inward * 0.5, (BH - 2.4) / 2, b.z + k * (bayBox.d / 5)),
				Color3.fromRGB(70, 75, 92)
			)
			seam.CanCollide = false
		end
		local pegboard = part(
			folder,
			"BayPegboard",
			Vector3.new(0.3, 5, bayBox.d * 0.4),
			world(backX + inward * 0.6, 11.2, b.z),
			Color3.fromRGB(190, 150, 90),
			Enum.Material.Wood
		)
		pegboard.CanCollide = false
		for k, tc in { RED, YELLOW, CYAN, Color3.fromRGB(235, 235, 240), RED, YELLOW } do
			local tool = part(
				folder,
				"BayTool",
				Vector3.new(0.4, 2.4, 0.5),
				world(backX + inward * 0.9, 11.2, b.z + (k - 3.5) * (bayBox.d * 0.4 / 7)),
				tc
			)
			tool.CanCollide = false
		end
		local pipe = part(
			folder,
			"BayPipe",
			Vector3.new(bayBox.d - 1, 1, 1),
			world(backX + inward * 0.9, BH - 1.4, b.z) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(170, 174, 186),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		pipe.CanCollide = false
		local bar = part(
			folder,
			"BayLight",
			Vector3.new(0.6, 0.6, bayBox.d - 4),
			world(b.x - inward * (bayBox.w / 2 - 6), BH - 0.6, b.z),
			Color3.fromRGB(255, 244, 220),
			Enum.Material.Neon
		)
		bar.CanCollide = false
		glow(bar, Color3.fromRGB(255, 244, 220), 40, 3)
		-- A navy ceiling over the bay, so it reads as a recessed garage.
		part(
			folder,
			"BayCeiling",
			Vector3.new(bayBox.w, 0.6, bayBox.d + 1.6),
			world(b.x, BH + 0.2, b.z),
			Color3.fromRGB(26, 36, 78)
		)
		-- The red portal at the front: two columns, a beam and the A1 / B1 header sign.
		local frontX = b.x + inward * (bayBox.w / 2)
		for _, side in { -1, 1 } do
			part(
				folder,
				"BayPortalPost",
				Vector3.new(1.8, BH + 1, 1.8),
				world(frontX, (BH + 1) / 2, b.z + side * (bayBox.d / 2 + 0.9)),
				RED,
				Enum.Material.Metal
			)
		end
		part(
			folder,
			"BayPortalBeam",
			Vector3.new(1.8, 1.8, bayBox.d + 3.6),
			world(frontX, BH - 0.2, b.z),
			RED,
			Enum.Material.Metal
		)
		local header = part(
			folder,
			"BayHeader" .. i,
			Vector3.new(16, 5.2, 0.6),
			CFrame.lookAt(
				origin + Vector3.new(frontX + inward * 1.1, BH + 3.6, b.z),
				origin + Vector3.new(frontX + inward * 10, BH + 3.6, b.z)
			),
			Color3.fromRGB(14, 16, 32)
		)
		label(header, Enum.NormalId.Front, L.bayName(i), Color3.fromRGB(245, 245, 250), nil)
		-- Tool clutter in the back corners: a red toolbox and a stack of tires.
		local cornerX = b.x - inward * (bayBox.w / 2 - 2.2)
		local box = part(
			folder,
			"BayToolbox",
			Vector3.new(2.6, 2.2, 3.4),
			world(cornerX, 1.1, b.z + bayBox.d / 2 - 2.4),
			RED
		)
		box.CanCollide = false
		local lid = part(
			folder,
			"BayToolboxLid",
			Vector3.new(2.8, 0.4, 3.6),
			world(cornerX, 2.4, b.z + bayBox.d / 2 - 2.4),
			YELLOW
		)
		lid.CanCollide = false
		for k = 0, 2 do
			local tire = part(
				folder,
				"BayTire",
				Vector3.new(1.3, 3, 3),
				world(cornerX, 0.65 + k * 1.3, b.z - bayBox.d / 2 + 2.4)
					* CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(22, 22, 26),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			tire.CanCollide = false
		end
	end

	-- Big "GARAGES" signs high on the side walls, with cyan neon on both sides.
	for _, side in { -1, 1 } do
		local wx = side * (HW - 1.4)
		local gs = part(
			folder,
			"GaragesSign",
			Vector3.new(26, 6, 0.6),
			CFrame.lookAt(origin + Vector3.new(wx, 26, -22), origin + Vector3.new(0, 26, -22)),
			Color3.fromRGB(14, 16, 32)
		)
		label(gs, Enum.NormalId.Front, "GARAGES", Color3.fromRGB(245, 245, 250), nil)
		for _, dz in { -1, 1 } do
			local neon = part(
				folder,
				"GaragesNeon",
				Vector3.new(0.5, 0.6, 14),
				world(wx - side * 0.1, 26, -22 + dz * 21),
				CYAN,
				Enum.Material.Neon
			)
			neon.CanCollide = false
		end
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
	local CONCRETE = Color3.fromRGB(26, 36, 78) -- navy upper walls
	local STEEL = RED -- red steel columns and bracing
	local WALL_GRAY = Color3.fromRGB(96, 102, 122)
	local gap = L.gate.halfOpening + 1
	local openEnd = L.bays[4].z + L.bay.d / 2 -- the garages open the side walls up to here
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
				-- The lower side wall stops where the garages are (they are cut into the wall).
				local lowerAlong, lowerW = along, segW
				if name == "L" or name == "R" then
					local lo = math.max(along - segW / 2, openEnd)
					local hi = along + segW / 2
					lowerAlong, lowerW = (lo + hi) / 2, hi - lo
				end
				if lowerW > 0.5 then
					local lbase = wallAt(name, lowerAlong, -room.wall / 2, 0)
					local cf = lbase * CFrame.new(0, WH / 2, 0)
					part(folder, "Wall", Vector3.new(lowerW + 0.1, WH, room.wall), cf, WALL_GRAY)
					local panel = part(
						folder,
						"WallPanel",
						Vector3.new(lowerW * 0.98, WH * 0.6, 0.5),
						cf * CFrame.new(0, -WH * 0.2, -room.wall / 2 - 0.25),
						Color3.fromRGB(38, 41, 50),
						Enum.Material.Brick
					)
					panel.CanCollide = false
					-- Wall detail, a different one per segment: poster, tool board, pipes, vent.
					if lowerW >= 8 then
						local hall = -room.wall / 2 - 0.7 -- in front of the wall panel (toward the hall)
						local function onWall(
							partName: string,
							size: Vector3,
							x: number,
							y: number,
							color: Color3,
							material: Enum.Material?,
							shape: Enum.PartType?
						): Part
							local d = part(
								folder,
								partName,
								size,
								lbase * CFrame.new(x, y, hall),
								color,
								material,
								shape
							)
							d.CanCollide = false
							d.CanQuery = false
							return d
						end
						local kind = i % 4
						if kind == 0 then
							local posters = {
								{ "RACE\nDAY!", Color3.fromRGB(235, 60, 60) },
								{ "TURBO", Color3.fromRGB(255, 200, 40) },
								{ "WIN!", Color3.fromRGB(60, 200, 255) },
							}
							local pick = posters[(i // 4) % #posters + 1]
							for k = -1, 1, 2 do
								onWall(
									"PosterFrame",
									Vector3.new(6.4, 8.4, 0.3),
									k * lowerW * 0.22,
									10,
									Color3.fromRGB(245, 245, 250)
								)
								local art = onWall(
									"Poster",
									Vector3.new(5.6, 7.6, 0.3),
									k * lowerW * 0.22,
									10,
									pick[2] :: Color3
								)
								art.CFrame = art.CFrame * CFrame.new(0, 0, -0.1)
								label(
									art,
									Enum.NormalId.Front,
									pick[1] :: string,
									DARK,
									Color3.new(1, 1, 1)
								)
							end
						elseif kind == 1 then
							onWall(
								"ToolBoard",
								Vector3.new(lowerW * 0.7, 6, 0.3),
								0,
								9,
								Color3.fromRGB(190, 150, 90),
								Enum.Material.Wood
							)
							local colors = { RED, YELLOW, CYAN, Color3.fromRGB(235, 235, 240) }
							for k = 1, 9 do
								onWall(
									"BoardTool",
									Vector3.new(0.6, 3.2 + (k % 3) * 0.6, 0.4),
									(k - 5) * lowerW * 0.7 / 10,
									9 + ((k % 3) - 1) * 0.3,
									colors[k % 4 + 1]
								)
							end
						elseif kind == 2 then
							for _, py in { 5, 13.5 } do
								onWall(
									"WallPipe",
									Vector3.new(lowerW * 0.96, 1, 1),
									0,
									py,
									Color3.fromRGB(165, 170, 184),
									Enum.Material.Metal,
									Enum.PartType.Cylinder
								)
							end
							for k = -1, 1 do
								onWall(
									"PipeClamp",
									Vector3.new(0.5, 1.6, 1.6),
									k * lowerW * 0.3,
									5,
									YELLOW,
									nil,
									Enum.PartType.Cylinder
								)
							end
						else
							onWall(
								"VentFrame",
								Vector3.new(6, 5, 0.3),
								0,
								10,
								Color3.fromRGB(40, 43, 54)
							)
							for k = -2, 2 do
								onWall(
									"VentSlat",
									Vector3.new(5.2, 0.5, 0.5),
									0,
									10 + k * 0.9,
									Color3.fromRGB(150, 154, 168)
								)
							end
						end
						-- Yellow / black hazard strip along the bottom.
						onWall("WallHazard", Vector3.new(lowerW * 0.98, 0.8, 0.3), 0, 0.6, YELLOW)
						for k = 0, math.floor(lowerW / 2) - 1 do
							onWall(
								"WallHazardStripe",
								Vector3.new(0.9, 0.8, 0.35),
								(k + 0.5) * 2 - lowerW / 2,
								0.6,
								DARK
							)
						end
					end
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
	-- Clean red steel: four long beams down the hall and three across, plus two cyan strips.
	for _, bx in { -48, -16, 16, 48 } do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(2, 2.6, HL * 2),
			world(bx, top - 1.3, 0),
			RED,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
	end
	for _, bz in { -40, 0, 40 } do
		local beam = part(
			folder,
			"RoofBeam",
			Vector3.new(HW * 2, 2.6, 2),
			world(0, top - 1.3, bz),
			RED,
			Enum.Material.Metal
		)
		beam.CanCollide = false
		beam.CanQuery = false
	end
	for _, nx in { -32, 32 } do
		local strip = part(
			folder,
			"BeamNeon",
			Vector3.new(0.7, 0.4, HL * 2),
			world(nx, top - 0.5, 0),
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
			{ 0, 8, 70, 6 },
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
		panel.Transparency = 1 -- only the light stays; the square lamps are what you see
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
			{ -27, -4 },
			{ 27, -4 },
			{ -27, 20 },
			{ 27, 20 },
			{ 0, 8 },
			{ -20, sc.z - 14 },
			{ 20, sc.z - 14 },
			{ -20, sc.z + 14 },
			{ 20, sc.z + 14 },
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
			Vector3.new(5.6, 0.6, 5.6),
			world(lp[1], lampY + 0.5, lp[2]),
			Color3.fromRGB(60, 62, 70),
			Enum.Material.Metal
		)
		shade.CanCollide = false
		shade.CanQuery = false
		local bulb = part(
			folder,
			"LampGlow",
			Vector3.new(4.8, 0.3, 4.8),
			world(lp[1], lampY, lp[2]),
			Color3.fromRGB(255, 244, 200),
			Enum.Material.Neon
		)
		bulb.CanCollide = false
		bulb.CanQuery = false
		glow(bulb, Color3.fromRGB(255, 244, 200), 40, 0.7)
	end

	-- Ceiling detail: steel truss webs under the cross beams, two big ducts with bands, strings
	-- of pennants and cable trays. Look only.
	local function ceil(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local c = part(folder, name, size, cf, color, material, shape)
		c.CanCollide = false
		c.CanQuery = false
		return c
	end
	local TRUSS = Color3.fromRGB(190, 40, 40)
	for _, bz in { -40, 0, 40 } do
		ceil(
			"TrussChord",
			Vector3.new(HW * 2, 0.7, 0.7),
			world(0, top - 4.6, bz),
			TRUSS,
			Enum.Material.Metal
		)
		for k = 0, 31 do
			local x = -HW + 2 + k * 4
			local flip = if k % 2 == 0 then 1 else -1
			ceil(
				"TrussWeb",
				Vector3.new(0.5, 3.2, 0.5),
				world(x + 2, top - 3.5, bz) * CFrame.Angles(0, 0, flip * math.rad(40)),
				TRUSS,
				Enum.Material.Metal
			)
		end
	end
	for _, dx in { -40, 40 } do
		ceil(
			"Duct",
			Vector3.new(HL * 2 - 6, 3.4, 3.4),
			world(dx, top - 7.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(170, 176, 190),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		for k = -4, 4 do
			ceil(
				"DuctBand",
				Vector3.new(0.9, 3.9, 3.9),
				world(dx, top - 7.2, k * 14) * CFrame.Angles(0, math.pi / 2, 0),
				YELLOW,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
	end
	for _, tz in { -22, 24 } do
		ceil("PennantCable", Vector3.new(HW * 2 - 8, 0.2, 0.2), world(0, top - 10, tz), DARK)
		local colors = { RED, Color3.fromRGB(250, 250, 250), YELLOW, CYAN }
		for k = 0, 21 do
			ceil(
				"Pennant",
				Vector3.new(2, 2, 0.15),
				world(-HW + 6 + k * 5.4, top - 11.3, tz) * CFrame.Angles(0, 0, math.pi / 4),
				colors[k % 4 + 1]
			)
		end
	end
	for _, tx in { -8, 8 } do
		ceil(
			"CableTray",
			Vector3.new(2.2, 0.5, HL * 2 - 4),
			world(tx, top - 3, 0),
			Color3.fromRGB(60, 64, 76),
			Enum.Material.Metal
		)
		ceil(
			"CableTrayLip",
			Vector3.new(0.3, 0.9, HL * 2 - 4),
			world(tx - 1.1, top - 2.8, 0),
			YELLOW
		)
		ceil(
			"CableTrayLip",
			Vector3.new(0.3, 0.9, HL * 2 - 4),
			world(tx + 1.1, top - 2.8, 0),
			YELLOW
		)
	end

	-- The bay door is shut (players start inside): a roller door of steel slats with a yellow
	-- hazard edge and a lit sign, so no gap shows the world outside.
	part(
		folder,
		"GateDoor",
		Vector3.new(gap * 2, WH, 1),
		world(0, WH / 2, HL + 0.5),
		Color3.fromRGB(150, 154, 168),
		Enum.Material.Metal
	)
	for k = 1, math.floor(WH / 1.5) do
		local rib = part(
			folder,
			"GateRib",
			Vector3.new(gap * 2, 0.35, 0.3),
			world(0, k * 1.5 - 0.4, HL - 0.15),
			Color3.fromRGB(96, 100, 114),
			Enum.Material.Metal
		)
		rib.CanCollide = false
	end
	local doorSign = part(
		folder,
		"GateSign",
		Vector3.new(30, 5, 0.4),
		CFrame.lookAt(origin + Vector3.new(0, 10, HL - 0.5), origin + Vector3.new(0, 10, 0)),
		Color3.fromRGB(14, 12, 40)
	)
	label(doorSign, Enum.NormalId.Front, "RACE HQ", YELLOW, Color3.fromRGB(20, 40, 140))
	doorSign.CanCollide = false
	glow(doorSign, YELLOW, 24, 0.4)
	for _, sx in { -1, 1 } do
		local edge = part(
			folder,
			"GateEdge",
			Vector3.new(1.2, WH, 0.5),
			world(sx * (gap - 0.6), WH / 2, HL - 0.3),
			YELLOW
		)
		edge.CanCollide = false
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

	-- The giant CAR VS CAR marquee on the back wall: a navy board in a thick red frame with a ring
	-- of bulbs, and fat letters made of stacked layers (bright in front, darker behind) so they
	-- look carved out and standing off the board.
	local SIGN_Y = 31
	local sign = part(
		folder,
		"WallSign",
		Vector3.new(64, 16, 1),
		CFrame.lookAt(
			origin + Vector3.new(0, SIGN_Y, -HL + 1.2),
			origin + Vector3.new(0, SIGN_Y, 0)
		),
		Color3.fromRGB(14, 12, 40)
	)
	glow(sign, CYAN, 60, 0.35)
	for _, fr in
		{
			{ 67, 1.6, 0, SIGN_Y + 8.6 },
			{ 67, 1.6, 0, SIGN_Y - 8.6 },
			{ 1.6, 19.8, -33.2, SIGN_Y },
			{ 1.6, 19.8, 33.2, SIGN_Y },
		}
	do
		local f = part(
			folder,
			"SignFrame",
			Vector3.new(fr[1], fr[2], 2),
			world(fr[3], fr[4], -HL + 1.6),
			RED,
			Enum.Material.Metal
		)
		f.CanCollide = false
	end
	local bulbN = 0
	local function bulb(x: number, y: number)
		bulbN += 1
		local c = if bulbN % 3 == 0
			then Color3.fromRGB(255, 255, 255)
			elseif bulbN % 3 == 1 then Color3.fromRGB(255, 215, 60)
			else Color3.fromRGB(255, 120, 60)
		local bb = part(
			folder,
			"SignBulb",
			Vector3.one,
			world(x, y, -HL + 2.7),
			c,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		bb.CanCollide = false
	end
	for k = -13, 13 do
		bulb(k * 2.4, SIGN_Y + 8.6)
		bulb(k * 2.4, SIGN_Y - 8.6)
	end
	for k = -3, 3 do
		bulb(-33.2, SIGN_Y + k * 2.6)
		bulb(33.2, SIGN_Y + k * 2.6)
	end
	local LETTER_LAYERS = 7
	for k = 0, LETTER_LAYERS - 1 do
		local depth = k / (LETTER_LAYERS - 1) -- 0 = front, 1 = back
		local layer = part(
			folder,
			"SignLetters",
			Vector3.new(58, 11, 0.05),
			CFrame.lookAt(
				origin + Vector3.new(0, SIGN_Y, -HL + 1.9 + (LETTER_LAYERS - 1 - k) * 0.3),
				origin + Vector3.new(0, SIGN_Y, 0)
			),
			DARK
		)
		layer.Transparency = 0.98
		layer.CanCollide = false
		layer.CanQuery = false
		local face = if k == 0
			then YELLOW
			else Color3.fromRGB(190, 70, 20):Lerp(Color3.fromRGB(30, 14, 10), depth)
		label(
			layer,
			Enum.NormalId.Front,
			"CAR VS CAR",
			face,
			if k == 0 then Color3.fromRGB(20, 40, 140) else nil
		)
	end
	local underglow = part(
		folder,
		"SignUnderglow",
		Vector3.new(60, 0.5, 1),
		world(0, SIGN_Y - 9.8, -HL + 2),
		CYAN,
		Enum.Material.Neon
	)
	underglow.CanCollide = false

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

	-- Truck stage in the middle: a round raised platform with a glowing cyan edge, and the
	-- spinning red truck.
	local stageD = sc.footprint - 4
	local stageBase = part(
		folder,
		"ShowcaseStage",
		Vector3.new(2, stageD, stageD),
		world(sc.x, 1, sc.z) * CFrame.Angles(0, 0, math.pi / 2),
		DARK,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	stageBase.CanCollide = true
	local stageGlow = part(
		folder,
		"ShowcaseRing",
		Vector3.new(0.6, stageD + 2.4, stageD + 2.4),
		world(sc.x, 0.3, sc.z) * CFrame.Angles(0, 0, math.pi / 2),
		CYAN,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	stageGlow.CanCollide = false
	glow(stageGlow, CYAN, 28, 0.4)
	local stageTopDisc = part(
		folder,
		"ShowcaseTop",
		Vector3.new(0.1, stageD - 6, stageD - 6),
		world(sc.x, 2.05, sc.z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(52, 58, 76),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	stageTopDisc.CanCollide = false
	local showcaseColor = Color3.fromRGB(230, 50, 60)
	-- The Blender stage (LobbyProps) is taller than the plain one, so the truck rides higher.
	local stageTop = 2.2
	local carY = stageTop + 0.1 -- the truck stands on the stage
	local pivot = world(sc.x, carY + 4, sc.z)
	local showcaseCar = meshCar(folder, "ShowcaseCar", 30, showcaseColor, world(sc.x, carY, sc.z))
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
	-- The claw gets its own round feature platform by the back wall, with a glowing ring, two
	-- posts and a big arch sign.
	local platform = part(
		folder,
		"GachaPlatform",
		Vector3.new(0.6, g.w + 4, g.w + 4),
		world(g.x, 0.3, g.z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(34, 38, 56),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	platform.CanCollide = false
	local platformRing = part(
		folder,
		"GachaRing",
		Vector3.new(0.3, g.w + 5.4, g.w + 5.4),
		world(g.x, 0.1, g.z) * CFrame.Angles(0, 0, math.pi / 2),
		YELLOW,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	platformRing.CanCollide = false
	glow(platformRing, YELLOW, 26, 0.5)
	for _, px in { -1, 1 } do
		local post = part(
			folder,
			"GachaPost",
			Vector3.new(1.2, 15, 1.2),
			world(g.x + px * (g.w / 2 + 1.5), 7.5, g.z + g.d / 2 + 0.5),
			RED,
			Enum.Material.Metal
		)
		post.CanCollide = false
	end
	local gSign = part(
		folder,
		"GachaSign",
		Vector3.new(g.w + 5, 4, 0.8),
		CFrame.lookAt(
			origin + Vector3.new(g.x, 15, g.z + g.d / 2 + 0.5),
			origin + Vector3.new(g.x, 15, g.z + 20)
		),
		Color3.fromRGB(14, 12, 40)
	)
	label(gSign, Enum.NormalId.Front, "PRIZE CLAW", YELLOW, Color3.fromRGB(20, 40, 140))
	glow(gSign, YELLOW, 30, 0.5)
	prompt(gBase, "GachaPrompt", "Play", "Claw Machine")

	local models = ServerStorage:FindFirstChild("Models")
	local clawModel: Model? = nil
	local propModels = models and models:FindFirstChild("Props")
	local clawTemplate = (propModels and propModels:FindFirstChild("claw_machine"))
		or (models and models:FindFirstChild("ClawMachine"))
	if clawTemplate and clawTemplate:IsA("Model") then
		-- The placeholder box stays as an invisible anchor for "GachaPrompt"; the platform, posts
		-- and sign stay too.
		gBase.Transparency = 1
		gBase.CanCollide = false
		local claw = clawTemplate:Clone()
		claw.Name = "ClawMachine"
		for _, d in claw:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				if d.Name:find("glass") then
					d.Transparency = 0.6
					d.Material = Enum.Material.Glass
					d.CanCollide = false
				end
			end
		end
		claw:ScaleTo(claw:GetScale() * CLAW_SCALE)
		-- Floor level (on the platform), facing the hall.
		claw:PivotTo(world(g.x, 0.6, g.z) * CFrame.Angles(0, math.rad(CLAW_YAW_DEG), 0))
		claw.Parent = folder
		clawModel = claw
	end

	-- Store booth (front left): yellow counter with a shelf behind it. Built facing +z around its
	-- centre, then the whole booth is turned toward the lane.
	local storeFrom = #folder:GetChildren()
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
	do
		local centre = origin + Vector3.new(s.x, 0, s.z)
		local turn = CFrame.new(centre) * CFrame.Angles(0, math.rad(s.yaw), 0) * CFrame.new(-centre)
		local made = folder:GetChildren()
		for k = storeFrom + 1, #made do
			local item = made[k]
			if item:IsA("BasePart") then
				item.CFrame = turn * item.CFrame
			end
		end
	end

	for k = storeFrom + 1, #folder:GetChildren() do
		folder:GetChildren()[k]:SetAttribute("Booth", "store")
	end
	local paintFrom = #folder:GetChildren()

	-- Paint / customize booth (front right): cyan counter, paint cans and a tool wall. Built in its
	-- own frame (+z = the front) and turned toward the lane.
	do
		local pb = L.paint
		local frame = CFrame.new(origin + Vector3.new(pb.x, 0, pb.z))
			* CFrame.Angles(0, math.rad(pb.yaw), 0)
		local function bp(
			name: string,
			size: Vector3,
			x: number,
			y: number,
			z: number,
			color: Color3,
			material: Enum.Material?,
			shape: Enum.PartType?
		): Part
			return part(folder, name, size, frame * CFrame.new(x, y, z), color, material, shape)
		end
		local counter2 = bp("PaintCounter", Vector3.new(pb.w, 4, 4), 0, 2, pb.d / 2 - 2, CYAN)
		bp("PaintCounterTop", Vector3.new(pb.w + 0.6, 0.5, 4.6), 0, 4.25, pb.d / 2 - 2, DARK)
		bp("PaintBack", Vector3.new(pb.w, 9, 1), 0, 4.5, -pb.d / 2 + 0.5, DARK)
		local glowStrip = bp(
			"PaintGlow",
			Vector3.new(pb.w - 2, 0.3, 0.3),
			0,
			0.6,
			pb.d / 2 + 0.2,
			CYAN,
			Enum.Material.Neon
		)
		glowStrip.CanCollide = false
		local canColors = {
			Color3.fromRGB(235, 60, 60),
			Color3.fromRGB(70, 140, 240),
			Color3.fromRGB(80, 200, 110),
			Color3.fromRGB(255, 205, 40),
			Color3.fromRGB(190, 90, 255),
		}
		for level = 1, 2 do
			local shelfY = 2.2 + level * 2.6
			bp(
				"PaintShelf",
				Vector3.new(pb.w / 2 - 1, 0.5, 2.5),
				-pb.w / 4,
				shelfY,
				-pb.d / 2 + 2,
				GRAY,
				Enum.Material.Metal
			)
			for k = 1, 5 do
				local can = bp(
					"PaintCan",
					Vector3.new(1.4, 1.3, 1.3),
					-pb.w / 2 + 2.5 + (k - 1) * 1.8,
					shelfY + 1,
					-pb.d / 2 + 2,
					canColors[(k + level) % #canColors + 1],
					nil,
					Enum.PartType.Cylinder
				)
				can.CFrame = can.CFrame * CFrame.Angles(0, 0, math.pi / 2)
				can.CanCollide = false
			end
		end
		bp(
			"ToolWall",
			Vector3.new(7, 4.5, 0.3),
			pb.w / 4 + 1,
			6.4,
			-pb.d / 2 + 1.1,
			Color3.fromRGB(40, 44, 58)
		)
		for k = 1, 4 do
			local tool = bp(
				"ToolBar",
				Vector3.new(0.35, 3, 0.25),
				pb.w / 4 - 1.2 + k * 1.2,
				6.4,
				-pb.d / 2 + 1.3,
				Color3.fromRGB(190, 195, 205)
			)
			tool.CanCollide = false
		end
		bp("PaintRoof", Vector3.new(pb.w + 1, 1, pb.d), 0, 11, 0, CYAN)
		for _, sx in { -1, 1 } do
			bp("PaintPost", Vector3.new(1, 10, 1), sx * (pb.w / 2 - 0.5), 5, pb.d / 2 - 0.5, CYAN)
		end
		local pSign = bp(
			"PaintSign",
			Vector3.new(14, 2.6, 0.6),
			0,
			9.6,
			pb.d / 2 + 0.4,
			Color3.fromRGB(14, 12, 24)
		)
		pSign.CFrame = frame
			* CFrame.lookAt(Vector3.new(0, 9.6, pb.d / 2 + 0.4), Vector3.new(0, 9.6, pb.d / 2 + 40))
		label(pSign, Enum.NormalId.Front, "PAINT / CUSTOMIZE", CYAN, DARK)
		glow(pSign, CYAN, 24, 0.4)
		prompt(counter2, "CustomizePrompt", "Customize", "Paint & Garage")
	end
	for k = paintFrom + 1, #folder:GetChildren() do
		folder:GetChildren()[k]:SetAttribute("Booth", "paint")
	end

	-- Red barriers with yellow frames, tire stacks and a cone by the spawn (like the reference).
	for _, sx in { -1, 1 } do
		-- A low red barrier on two dark legs with a yellow top rail, sitting flat on the floor.
		local bx = sx * 26
		part(folder, "SpawnBarrier", Vector3.new(12, 1.5, 1.6), world(bx, 1.6, 50), RED)
		local rail = part(
			folder,
			"SpawnBarrierRail",
			Vector3.new(12.4, 0.35, 1.9),
			world(bx, 2.5, 50),
			YELLOW
		)
		rail.CanCollide = false
		for _, lx in { -4.5, 4.5 } do
			part(
				folder,
				"SpawnBarrierLeg",
				Vector3.new(1.2, 1.7, 1.2),
				world(bx + lx, 0.85, 50),
				DARK
			)
		end
		for k = 0, 2 do
			local tire = part(
				folder,
				"SpawnTire",
				Vector3.new(1.4, 3.4, 3.4),
				world(sx * 40, 0.7 + k * 1.4, 52) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(22, 22, 26),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			tire.CanCollide = false
		end
	end

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

	-- Match pads: green slabs in a 2x2 grid. Each has a number badge and a "0/2 PLAYERS" board
	-- on its back edge (the board text is what LobbyService updates).
	local pads: { PadHandle } = {}
	for i, pp in L.pads do
		local size = L.padSize
		-- A flat dark pad with a thick green glowing outline and its number painted on it.
		part(
			folder,
			"PadBase",
			Vector3.new(size, 0.3, size),
			world(pp.x, 0.15, pp.z),
			Color3.fromRGB(30, 34, 44)
		)
		for _, e in { -1, 1 } do
			local across = part(
				folder,
				"PadOutline",
				Vector3.new(size, 0.2, 0.9),
				world(pp.x, 0.4, pp.z + e * (size / 2 - 0.45)),
				GREEN,
				Enum.Material.Neon
			)
			across.CanCollide = false
			local along = part(
				folder,
				"PadOutline",
				Vector3.new(0.9, 0.2, size - 1.8),
				world(pp.x + e * (size / 2 - 0.45), 0.4, pp.z),
				GREEN,
				Enum.Material.Neon
			)
			along.CanCollide = false
		end
		local padPart = part(
			folder,
			"MatchPad" .. i,
			Vector3.new(size - 2.4, 0.3, size - 2.4),
			world(pp.x, 0.35, pp.z),
			Color3.fromRGB(38, 42, 54),
			Enum.Material.SmoothPlastic
		)
		label(
			padPart,
			Enum.NormalId.Top,
			string.format("%02d", i),
			Color3.fromRGB(235, 238, 245),
			nil
		)
		glow(padPart, GREEN, 18, 0.25)
		local pboard = part(
			folder,
			"PadSign" .. i,
			Vector3.new(8, 2.4, 0.6),
			CFrame.lookAt(
				origin + Vector3.new(pp.x, 2.6, pp.z - size / 2 + 0.6),
				origin + Vector3.new(pp.x, 2.6, pp.z + 10)
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
	local spawnPos = origin + Vector3.new(sp.x, 0.2, sp.z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(sp.size, 0.4, sp.size)
	spawn.CFrame = CFrame.lookAt(spawnPos, origin + Vector3.new(0, 0.5, 0))
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(28, 32, 46)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	folder.Parent = workspace
	outline("SpawnPadEdge", sp.size, sp.size, sp.x, sp.z, 0.5, CYAN, Enum.Material.Neon)
	return { spawn = spawn, pads = pads, folder = folder, claw = clawModel }
end

return Lobby
