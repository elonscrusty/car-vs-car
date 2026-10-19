--!strict
-- The Blender lobby shell (ServerStorage.Models.Shell): wall tiles, garage rooms and fronts, the
-- big door frame, roof trusses, join pads, truck stage, the big CAR VS CAR sign, spawn pad and
-- lane pieces. It dresses the plain lobby that Lobby.build made: the old look-only parts are
-- removed and the old solid parts stay as invisible collision. Models are pivoted at the bottom
-- centre and face -Z. Everything from the shell is look only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyShell = {}

-- Old parts (by name, trailing digits ignored) that the shell replaces.
local REMOVE: { [string]: boolean } = {}
for _, n in
	{
		"PadApron",
		"PadEdge",
		"SpawnApron",
		"SpawnEdge",
		"LaneLine",
		"PlazaFrame",
		"BayFloor",
		"BayEdge",
		"BayNumber",
		"BayDividerCap",
		"BayBand",
		"BayBackSeam",
		"BayPegboard",
		"BayTool",
		"BayPipe",
		"BayLight",
		"BayToolbox",
		"BayToolboxLid",
		"BayTire",
		"GaragesSign",
		"GaragesNeon",
		"GarageBand",
		"WindowGlass",
		"WindowBar",
		"WallPanel",
		"WallPipe",
		"PipeClamp",
		"WallHazard",
		"WallHazardStripe",
		"VentFrame",
		"VentSlat",
		"PosterFrame",
		"Poster",
		"ToolBoard",
		"BoardTool",
		"RoofBeam",
		"BeamNeon",
		"Skylight",
		"SignFrame",
		"SignBulb",
		"SignLetters",
		"SignUnderglow",
		"SignFlag",
		"ShowcaseRing",
		"ShowcaseTop",
		"FloorChevron",
		"StartLine",
		"SpawnTire",
		"SpawnBarrierRail",
	}
do
	REMOVE[n] = true
end
-- Old solid parts that stay as invisible collision (their looks and lights are removed).
local GHOST: { [string]: boolean } = {}
for _, n in
	{
		"BayDivider",
		"BayBack",
		"BayCeiling",
		"BayPortalPost",
		"BayPortalBeam",
		"BayHeader",
		"GarageWall",
		"GarageColumn",
		"Wall",
		"WallPost",
		"WallSign",
		"ShowcaseStage",
		"BayRing",
	}
do
	GHOST[n] = true
end

local LEFT, RIGHT, BACK, FRONT = -math.pi / 2, math.pi / 2, math.pi, 0

function LobbyShell.build(folder: Folder, origin: Vector3)
	local L = LobbyLayout
	local HW, HL, WH = L.room.halfW, L.room.halfL, L.room.wallHeight

	-- Sweep the old look. Only the plain lobby parts (not the models inside Props/Decor/Shell).
	local shellGroup = Instance.new("Folder")
	shellGroup.Name = "Shell"
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			local base = string.gsub(d.Name, "%d+$", "")
			if REMOVE[base] then
				d:Destroy()
			elseif GHOST[base] then
				d.Transparency = 1
				for _, c in d:GetChildren() do
					if
						c:IsA("SurfaceGui")
						or c:IsA("Light")
						or c:IsA("Decal")
						or c:IsA("Texture")
					then
						c:Destroy()
					end
				end
			end
		end
	end
	shellGroup.Parent = folder

	local function put(
		name: string,
		x: number,
		y: number,
		z: number,
		yaw: number,
		glow: number?,
		source: string?
	)
		local m = LobbyDecor.clone(name, shellGroup, glow, source or "Shell")
		if m then
			m:PivotTo(CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0))
		end
	end

	-- Walls: panels (18 high) under tall upper walls (22 high).
	local WALL_MID = 1 -- the wall is 2 thick: its middle is 1 outside the inner face
	for k = 0, 9 do -- back wall
		local x = -59.4 + 13.2 * k
		put("Wall_Panel", x, 0, -HL - WALL_MID, BACK)
		put("Wall_Upper", x, WH, -HL - WALL_MID, BACK)
	end
	for _, sx in { -1, 1 } do -- front wall, either side of the door
		for _, ax in { 35, 47, 59 } do
			put("Wall_Panel", sx * ax, 0, HL + WALL_MID, FRONT)
			put("Wall_Upper", sx * ax, WH, HL + WALL_MID, FRONT)
		end
	end
	for k = -2, 2 do -- the front wall above the door
		put("Wall_Upper", k * 12, WH, HL + WALL_MID + 1, FRONT)
	end
	put("BayDoorFrame", 0, 0, HL + WALL_MID, FRONT)
	-- Side walls: upper tiles all along; low panels only by the store and the paint booth.
	local openEnd = L.bays[#L.bays].z + L.bay.d / 2
	local closeStart = L.bays[1].z - L.bay.d / 2 -- the back end of the garages: a low panel fills the corner behind it
	for _, sx in { -1, 1 } do
		local yaw = if sx < 0 then LEFT else RIGHT
		for k = 0, 13 do
			put("Wall_Upper", sx * (HW + WALL_MID), WH, -91 + 14 * k, yaw)
		end
		for _, z in { openEnd + 7, openEnd + 21, closeStart - 5.5 } do
			put("Wall_Panel", sx * (HW + WALL_MID), 0, z, yaw)
		end
	end

	-- Garages: a big room behind each open front, and the yellow outline for the parked cars. The
	-- code-built walls (Lobby.luau) stay as invisible collision. Models: ServerStorage.Models.Garage.
	for _, b in L.bays do
		local yaw = if b.face > 0 then LEFT else RIGHT
		put("GarageRoomBig", b.x, 0, b.z, yaw, nil, "Garage")
		put("GarageOpenFront", b.x + b.face * L.bay.w / 2, 0, b.z, yaw, nil, "Garage")
		put("ParkingMark", b.x - b.face * (L.bay.w / 2 - 5.5), 0.05, b.z, yaw, nil, "Garage")
	end

	-- The Blender garage rooms have bright white floors: tint any near-white flat part light steel.
	for _, m in shellGroup:GetChildren() do
		if m.Name == "GarageRoomBig" or m.Name == "GarageOpenFront" then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local c = d.Color
					local flat = d.Size.Y <= 2 and math.max(d.Size.X, d.Size.Z) >= 8
					if flat and math.min(c.R, c.G, c.B) > 0.75 then
						d.Color = Color3.fromRGB(150, 158, 172)
					end
				end
			end
		end
	end

	-- Roof trusses across the hall.
	for _, z in { -82, -50, -17, 16, 49, 82 } do
		put("RoofTruss", 0, WH + L.room.upper - 12.8, z, 0)
	end

	-- The big sign on the back wall, the stage, the pads and the way in.
	LobbyDecor.plate(
		shellGroup,
		"CAR VS CAR",
		Vector3.new(46, 10, 0.8),
		CFrame.lookAt(origin + Vector3.new(0, 24, -HL + 2.6), origin + Vector3.new(0, 24, 0))
	)
	put("TruckStage", L.showcase.x, 0, L.showcase.z, 0)
	-- (No JoinPad models: Lobby.luau draws plain steel pads with one yellow line.)
	put("SpawnPad", L.spawn.x, 0, L.spawn.z, 0)

	-- One dashed centre stripe from the spawn to the stage (no double lane lines).
	local function mark(
		name: string,
		size: Vector3,
		x: number,
		z: number,
		yaw: number,
		color: Color3,
		alpha: number
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(origin + Vector3.new(x, 0.05, z)) * CFrame.Angles(0, yaw, 0)
		p.Color = color
		p.Transparency = alpha
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = shellGroup
		return p
	end
	local white = Color3.fromRGB(240, 240, 245)
	for z = 64, -14, -9 do
		mark("CenterStripe", Vector3.new(0.7, 0.04, 5), 0, z, 0, white, 0)
	end

	-- A few faint oil spots and tire marks near the pads (10% opacity), so the floor is not blank.
	local dark = Color3.fromRGB(14, 14, 18)
	for _, d in
		{
			{ -16, 6, 5, 4, 0.4 },
			{ 18, 30, 4, 3, 1.1 },
			{ -14, 36, 6, 4, 2.0 },
			{ 15, -14, 5, 5, 0.2 },
			{ -8, 52, 4, 3, 0.9 },
		}
	do
		local spot = mark("OilSpot", Vector3.new(0.03, d[3], d[4]), d[1], d[2], d[5], dark, 0.9)
		spot.Shape = Enum.PartType.Cylinder
		spot.CFrame = spot.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
	for _, d in
		{
			{ -20, 14, 22, 0.3 },
			{ 21, 8, 26, -0.2 },
			{ -12, 44, 20, 0.15 },
		}
	do
		mark("TireMark", Vector3.new(0.9, 0.03, d[3]), d[1], d[2], d[4], dark, 0.9)
		mark("TireMark", Vector3.new(0.9, 0.03, d[3]), d[1] + 3.2, d[2], d[4], dark, 0.9)
	end
end

return LobbyShell
