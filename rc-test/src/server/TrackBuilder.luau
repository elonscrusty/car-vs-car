--!strict
-- Builds the three grey tracks out of plain parts, from the numbers in TrackData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackData = require(ReplicatedStorage.Shared.TrackData)

local ROAD_TOP = 0.1
local GROUND = Color3.fromRGB(88, 88, 92)
local ROAD = Color3.fromRGB(150, 150, 156)
local ROCK = Color3.fromRGB(118, 116, 114)
local WALL = Color3.fromRGB(190, 190, 195)

local TrackBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
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

-- A flat slab lying between two points on the ground plane (y = center height).
local function slab(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	extra: number,
	color: Color3
): Part
	local mid = (a + b) / 2
	local len = (b - a).Magnitude + extra
	return part(parent, name, Vector3.new(width, height, len), CFrame.lookAt(mid, b), color)
end

local function ground(folder: Folder, ox: number, cz: number, sx: number, sz: number, grip: number)
	local g = part(folder, "Ground", Vector3.new(sx, 4, sz), CFrame.new(ox, -2, cz), GROUND)
	g:SetAttribute("Grip", grip)
end

local function ribbon(
	folder: Folder,
	ox: number,
	ring: { TrackData.Sample },
	width: number,
	grip: number,
	walls: boolean
)
	local n = #ring
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		local road = slab(
			folder,
			"Road",
			Vector3.new(ox + a.x, ROAD_TOP / 2, a.z),
			Vector3.new(ox + b.x, ROAD_TOP / 2, b.z),
			width,
			ROAD_TOP,
			1.5,
			ROAD
		)
		road:SetAttribute("Grip", grip)
		if walls then
			for _, side in { -1, 1 } do
				local off = (width / 2 + 1) * side
				local pa = Vector3.new(ox + a.x - a.tz * off, 2, a.z + a.tx * off)
				local pb = Vector3.new(ox + b.x - b.tz * off, 2, b.z + b.tx * off)
				slab(folder, "Wall", pa, pb, 1.5, 4, 1.5, WALL)
			end
		end
	end
end

local function box(folder: Folder, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return part(folder, name, size, cf, color)
end

local function outerWalls(folder: Folder, ox: number, cz: number, half: number)
	local h = 6
	box(folder, "Wall", Vector3.new(half * 2, h, 2), CFrame.new(ox, h / 2, cz - half), WALL)
	box(folder, "Wall", Vector3.new(half * 2, h, 2), CFrame.new(ox, h / 2, cz + half), WALL)
	box(folder, "Wall", Vector3.new(2, h, half * 2), CFrame.new(ox - half, h / 2, cz), WALL)
	box(folder, "Wall", Vector3.new(2, h, half * 2), CFrame.new(ox + half, h / 2, cz), WALL)
end

local function ramp(folder: Folder, ox: number, x: number, z: number, rise: number, len: number)
	-- low end at (x, z + len/2), high end at (x, z - len/2): drive toward -Z to jump
	local a = Vector3.new(ox + x, 0, z + len / 2)
	local b = Vector3.new(ox + x, rise, z - len / 2)
	local dir = (b - a).Unit
	local right = Vector3.xAxis
	local back = -dir
	local up = back:Cross(right)
	local mid = (a + b) / 2
	local p = part(
		folder,
		"Ramp",
		Vector3.new(16, 1, (b - a).Magnitude),
		CFrame.fromMatrix(mid - up * 0.5, right, up, back),
		ROAD
	)
	p.Material = Enum.Material.SmoothPlastic
end

local function buildDrift(folder: Folder, t: TrackData.Track)
	local ox = t.originX
	ground(folder, ox, 0, 560, 560, t.grip)
	ribbon(folder, ox, TrackData.driftLoop(), TrackData.ROAD_DRIFT, t.grip, false)
	outerWalls(folder, ox, 0, 280)
	-- practice donut in the middle of the track
	local ringPart = part(
		folder,
		"Donut",
		Vector3.new(0.2, 70, 70),
		CFrame.new(ox, 0.15, -50) * CFrame.Angles(0, 0, math.rad(90)),
		ROAD
	)
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart:SetAttribute("Grip", t.grip)
	-- a small jump to play with
	ramp(folder, ox, 0, 160, 3, 18)
end

local function buildRace(folder: Folder, t: TrackData.Track)
	local ox = t.originX
	ground(folder, ox, 20, 560, 600, t.grip)
	ribbon(folder, ox, TrackData.raceLoop(), TrackData.ROAD_RACE, 1, true)
	outerWalls(folder, ox, 20, 280)
	-- start line
	local g = t.gates[1]
	local line = part(
		folder,
		"StartLine",
		Vector3.new(TrackData.ROAD_RACE, 0.1, 3),
		CFrame.lookAt(
			Vector3.new(ox + g.x, ROAD_TOP + 0.06, g.z),
			Vector3.new(ox + g.x + g.dx, ROAD_TOP + 0.06, g.z + g.dz)
		),
		Color3.fromRGB(245, 245, 245)
	)
	line.CanCollide = false
end

local function buildRock(folder: Folder, t: TrackData.Track)
	local ox = t.originX
	local half = TrackData.ROCK_HALF_WIDTH
	ground(folder, ox, 0, 160, 360, 1)
	local prof = TrackData.rockProfile
	for i = 2, #prof do
		local a = Vector3.new(ox, prof[i - 1].y, prof[i - 1].z)
		local b = Vector3.new(ox, prof[i].y, prof[i].z)
		local dir = (b - a).Unit
		local right = Vector3.xAxis
		local back = -dir
		local up = back:Cross(right)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 2
		part(
			folder,
			"Hill",
			Vector3.new(half * 2, 2, len),
			CFrame.fromMatrix(mid - up, right, up, back),
			GROUND
		)
		for _, side in { -1, 1 } do
			part(
				folder,
				"Wall",
				Vector3.new(2, 16, len),
				CFrame.fromMatrix(mid + right * (half + 1) * side + up * 7, right, up, back),
				WALL
			)
		end
	end
	-- wall across the very back, behind the summit
	part(folder, "Wall", Vector3.new(half * 2 + 4, 20, 2), CFrame.new(ox, 76, -142), WALL)
	part(folder, "Wall", Vector3.new(half * 2 + 4, 14, 2), CFrame.new(ox, 6, 152), WALL)
	for _, r in TrackData.rocks() do
		local rock = part(
			folder,
			"Rock",
			Vector3.new(r.r * 2, r.r * 2, r.r * 2),
			CFrame.new(ox + r.x, r.y, r.z),
			ROCK
		)
		rock.Shape = Enum.PartType.Ball
		rock.Material = Enum.Material.Slate
	end
	-- summit flag
	local top = prof[#prof].y
	local pole = part(
		folder,
		"Flag",
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(ox, top + 7, -125),
		Color3.fromRGB(240, 240, 240)
	)
	pole.CanCollide = false
	local flag = part(
		folder,
		"Flag",
		Vector3.new(7, 4, 0.3),
		CFrame.new(ox + 3.8, top + 12, -125),
		Color3.fromRGB(235, 90, 40)
	)
	flag.CanCollide = false
	local pad = part(
		folder,
		"SummitPad",
		Vector3.new(half * 2, 0.1, 4),
		CFrame.new(ox, top + 0.06, -108),
		Color3.fromRGB(245, 245, 245)
	)
	pad.CanCollide = false
	-- start line
	local start = part(
		folder,
		"StartLine",
		Vector3.new(half * 2, 0.1, 3),
		CFrame.new(ox, 0.06, 128),
		Color3.fromRGB(245, 245, 245)
	)
	start.CanCollide = false
end

function TrackBuilder.build()
	local root = Instance.new("Folder")
	root.Name = "Tracks"
	root.Parent = workspace
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		local folder = Instance.new("Folder")
		folder.Name = id
		folder.Parent = root
		if id == "drift" then
			buildDrift(folder, t)
		elseif id == "race" then
			buildRace(folder, t)
		else
			buildRock(folder, t)
		end
	end
end

return TrackBuilder
