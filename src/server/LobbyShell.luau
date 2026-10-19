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
		"PadOutline",
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
		"PadBase",
		"MatchPad",
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
	for _, sx in { -1, 1 } do
		local yaw = if sx < 0 then LEFT else RIGHT
		for k = 0, 13 do
			put("Wall_Upper", sx * (HW + WALL_MID), WH, -91 + 14 * k, yaw)
		end
		for _, z in { openEnd + 7, openEnd + 21 } do
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

	-- Roof trusses across the hall.
	for _, z in { -82, -50, -17, 16, 49, 82 } do
		put("RoofTruss", 0, WH + L.room.upper - 12.8, z, 0)
	end

	-- The big sign on the back wall, the stage, the pads and the way in.
	put("BigSign_CarVsCar", 0, 23, -HL + 3.2, BACK)
	put("TruckStage", L.showcase.x, 0, L.showcase.z, 0)
	for i, p in L.pads do
		put(string.format("JoinPad_%02d", i), p.x, 0, p.z, BACK)
	end
	put("SpawnPad", L.spawn.x, 0, L.spawn.z, 0)
	put("LaneChevrons", 0, 0.05, L.spawn.z - 14, 0)
	put("LaneChevrons", 0, 0.05, L.spawn.z - 30, 0)
	for _, sx in { -1, 1 } do
		for _, z in { 69, 53, 37, 21, 5, -11 } do
			put("LaneTrim", sx * (L.lane.halfWidth + 0.5), 0, z, math.pi / 2)
		end
	end
end

return LobbyShell
