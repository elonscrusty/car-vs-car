--!strict
-- Look-only dressing around the soccer / tag field and the race track (audit #30, #31, #95):
-- a grass island with light towers, trees, rocks, tire piles and flags around the field, a tag
-- floor that does not look like soccer, and curbs, tire piles, light towers, trees, an arch and
-- corner arrows on the race track. Models come from ServerStorage.Models.Bowl; a missing one is
-- skipped. Nothing here can be bumped into (no collision), so no match rule changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceTrack = require(ReplicatedStorage.Shared.RaceTrack)
local RaceTrackConfig = require(ReplicatedStorage.Shared.RaceTrackConfig)
local SoccerFieldConfig = require(ReplicatedStorage.Shared.SoccerFieldConfig)

local LobbyDecor = require(script.Parent.LobbyDecor)

local ModeDecor = {}

local RED = Color3.fromRGB(225, 60, 55)
local WHITE = Color3.fromRGB(245, 245, 245)
local YELLOW = Color3.fromRGB(255, 205, 40)
local BLACK = Color3.fromRGB(30, 30, 34)

-- Tag floor: light steel with orange hazard stripes (soccer keeps its green grass).
ModeDecor.TagFloor = Color3.fromRGB(112, 122, 142)
ModeDecor.TagFloorAlt = Color3.fromRGB(124, 134, 154)

local function look(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
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
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- A Bowl model at a spot (feet on `pos`), turned `yaw`, scaled. nil when the model is missing.
local function put(parent: Instance, name: string, pos: Vector3, yaw: number, scale: number): Model?
	local m = LobbyDecor.clone(name, parent, nil, "Bowl")
	if m == nil then
		return nil
	end
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0)) -- the pivot of a Bowl model is its bottom
	return m
end

local function cloudsAround(group: Folder, center: Vector3, radius: number, count: number)
	local rng = Random.new(11)
	local names = { "Cloud_A", "Cloud_B", "Cloud_C" }
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = radius * rng:NextNumber(0.9, 1.5)
		local pos = center + Vector3.new(math.cos(a) * r, rng:NextNumber(40, 90), math.sin(a) * r)
		put(
			group,
			names[i % #names + 1],
			pos,
			rng:NextNumber(0, math.pi * 2),
			rng:NextNumber(1.5, 2.6)
		)
	end
end

-- Soccer and tag: `origin` is the field middle (floor top at origin.Y). `tag` = the tag floor.
function ModeDecor.field(model: Model, origin: Vector3, tag: boolean)
	local c = SoccerFieldConfig
	local group = Instance.new("Folder")
	group.Name = "FieldDecor"
	group.Parent = model
	local totalLen = c.length + 2 * c.goalDepth
	local halfX, halfZ = totalLen / 2 + c.wallThick, c.width / 2 + c.wallThick
	local ring = 38 -- width of the island around the walls

	-- The island: a slab a little below the field so it never fights the field floor, with a
	-- yellow edge stripe.
	local islandColor = if tag then Color3.fromRGB(104, 110, 126) else Color3.fromRGB(88, 160, 84)
	look(
		group,
		"Island",
		Vector3.new(2 * (halfX + ring), 2, 2 * (halfZ + ring)),
		CFrame.new(origin + Vector3.new(0, -1.15, 0)),
		islandColor,
		if tag then Enum.Material.Concrete else Enum.Material.Grass
	)
	look(
		group,
		"IslandEdge",
		Vector3.new(2 * (halfX + ring) + 2, 0.6, 2 * (halfZ + ring) + 2),
		CFrame.new(origin + Vector3.new(0, -1.9, 0)),
		YELLOW
	)

	-- Hazard stripes along the base of the walls (tag only): orange and dark, every few studs.
	if tag then
		local step = 8
		local nX = math.floor(totalLen / step)
		for i = 0, nX - 1 do
			local x = -totalLen / 2 + step * (i + 0.5)
			local col = if i % 2 == 0 then Color3.fromRGB(255, 150, 30) else BLACK
			for _, sz in { -1, 1 } do
				look(
					group,
					"Hazard",
					Vector3.new(step, 0.12, 2),
					CFrame.new(origin + Vector3.new(x, 0.14, sz * (c.width / 2 - 1.2))),
					col
				)
			end
		end
	end

	-- Four light towers at the corners, outside the walls.
	local ox, oz = halfX + 8, halfZ + 8
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			put(
				group,
				"LightTower",
				origin + Vector3.new(sx * ox, -1, sz * oz),
				if sz < 0 then 0 else math.pi,
				1.1
			)
		end
	end

	-- Trees, rocks, tire piles, cones and flags on the island (deterministic).
	local rng = Random.new(if tag then 3 else 5)
	local trees = { "Tree_Round", "Tree_Palm", "Tree_Pine" }
	for i = 1, 26 do
		local side = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-1, 1)
		local depth = rng:NextNumber(12, ring - 4)
		local x, z
		if side <= 2 then
			x = along * (halfX + ring - 6)
			z = (if side == 1 then -1 else 1) * (halfZ + depth)
		else
			x = (if side == 3 then -1 else 1) * (halfX + depth)
			z = along * (halfZ + ring - 6)
		end
		local pos = origin + Vector3.new(x, -1, z)
		local roll = rng:NextNumber(0, 1)
		if roll < 0.55 then
			put(
				group,
				trees[i % #trees + 1],
				pos,
				rng:NextNumber(0, math.pi * 2),
				rng:NextNumber(1.3, 2)
			)
		elseif roll < 0.75 then
			put(group, if i % 2 == 0 then "Rock_A" else "Rock_B", pos, rng:NextNumber(0, 6.28), 2)
		elseif roll < 0.9 then
			put(group, "TireStack", pos, rng:NextNumber(0, 6.28), 1.4)
		else
			put(group, "FeatherFlag", pos, rng:NextNumber(0, 6.28), 1.4)
		end
	end

	-- A row of tire walls in front of each long wall.
	for _, sz in { -1, 1 } do
		for k = -3, 3 do
			put(group, "TireWall", origin + Vector3.new(k * 22, -1, sz * (halfZ + 4)), 0, 1.2)
		end
	end

	cloudsAround(group, origin, halfX + ring, 10)
end

-- Race: `origin` is the track origin (road top at origin.Y).
function ModeDecor.race(model: Model, origin: Vector3)
	local c = RaceTrackConfig
	local group = Instance.new("Folder")
	group.Name = "RaceDecor"
	group.Parent = model
	local n = RaceTrack.count()
	local half = c.roadWidth / 2

	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	-- Red and white curbs along both edges of every stretch.
	for i = 1, n do
		local a = RaceTrack.point(i)
		local len = RaceTrack.segmentLength(i)
		local dx, dz = RaceTrack.direction(i)
		local sx, sz = -dz, dx
		local blocks = math.floor(len / 10)
		for k = 0, blocks - 1 do
			local t = (k + 0.5) * 10
			local col = if k % 2 == 0 then RED else WHITE
			for _, side in { -1, 1 } do
				local pos = at(
					a.x + dx * t + sx * side * (half + 1),
					0.18,
					a.z + dz * t + sz * side * (half + 1)
				)
				look(
					group,
					"Curb",
					Vector3.new(2, 0.36, 10),
					CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)),
					col
				)
			end
		end
	end

	-- Corners: a pile of tires and an arrow board on the outside, a light tower every other corner.
	for i = 1, n do
		local p = RaceTrack.point(i)
		local ax, az = RaceTrack.direction(i - 1)
		local bx, bz = RaceTrack.direction(i)
		local ox, oz = ax - bx, az - bz
		local len = math.sqrt(ox * ox + oz * oz)
		if len > 0.05 then
			ox, oz = ox / len, oz / len
			local out = half + 8
			local pos = at(p.x + ox * out, 0, p.z + oz * out)
			for k = -1, 1 do
				put(group, "TireStack", pos + Vector3.new(-oz * k * 6, 0, ox * k * 6), 0, 1.6)
			end
			-- Arrow board facing the cars coming in.
			local board = look(
				group,
				"CornerBoard",
				Vector3.new(14, 7, 1),
				CFrame.lookAt(
					at(p.x + ox * (half + 14), 6, p.z + oz * (half + 14)),
					at(p.x, 6, p.z)
				),
				YELLOW
			)
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.PixelsPerStud = 20
				gui.Parent = board
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = if bx * az - bz * ax > 0 then ">>>" else "<<<"
				label.TextScaled = true
				label.Font = Enum.Font.FredokaOne
				label.TextColor3 = BLACK
				label.Parent = gui
			end
			if i % 2 == 0 then
				put(
					group,
					"LightTower",
					at(p.x + ox * (half + 26), -1, p.z + oz * (half + 26)),
					0,
					1.2
				)
			end
		end
	end

	-- Cones in front of every jump.
	for _, r in c.ramps do
		local a, b = RaceTrack.point(r.seg), RaceTrack.point(r.seg + 1)
		local px, pz = a.x + (b.x - a.x) * r.t, a.z + (b.z - a.z) * r.t
		local dx, dz = RaceTrack.direction(r.seg)
		for _, side in { -1, 1 } do
			put(
				group,
				"Cone",
				at(
					px - dx * (r.length + 6) - dz * side * (r.width / 2 + 3),
					0,
					pz - dz * (r.length + 6) + dx * side * (r.width / 2 + 3)
				),
				0,
				1.5
			)
		end
	end

	-- Start / finish arch: two posts and a banner across the road at waypoint 1.
	local start = RaceTrack.point(1)
	local sdx, sdz = RaceTrack.direction(1)
	local across = CFrame.lookAt(at(start.x, 0, start.z), at(start.x + sdx, 0, start.z + sdz))
	for _, side in { -1, 1 } do
		look(
			group,
			"ArchPost",
			Vector3.new(3, 26, 3),
			across * CFrame.new(side * (half + 2), 13, 0),
			if side < 0 then RED else WHITE
		)
	end
	local banner = look(
		group,
		"ArchBanner",
		Vector3.new(c.roadWidth + 8, 7, 2),
		across * CFrame.new(0, 24, 0),
		BLACK
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 20
		gui.Parent = banner
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "START / FINISH"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = WHITE
		label.Parent = gui
	end

	-- Trees, rocks and flags scattered on the grass, away from the road.
	local rng = Random.new(21)
	local x0, x1, z0, z1 = RaceTrack.bounds()
	local trees = { "Tree_Round", "Tree_Palm", "Tree_Pine" }
	local placed, tries = 0, 0
	while placed < 70 and tries < 600 do
		tries += 1
		local x = rng:NextNumber(x0 + 12, x1 - 12)
		local z = rng:NextNumber(z0 + 12, z1 - 12)
		local near = false
		for dx = -1, 1 do
			for dz = -1, 1 do
				if RaceTrack.onRoad(x + dx * 24, z + dz * 24) then
					near = true
				end
			end
		end
		if not near then
			placed += 1
			local roll = rng:NextNumber(0, 1)
			local pos = at(x, 0, z)
			if roll < 0.6 then
				put(
					group,
					trees[placed % #trees + 1],
					pos,
					rng:NextNumber(0, 6.28),
					rng:NextNumber(1.4, 2.2)
				)
			elseif roll < 0.85 then
				put(
					group,
					if placed % 2 == 0 then "Rock_A" else "Rock_B",
					pos,
					rng:NextNumber(0, 6.28),
					2.4
				)
			else
				put(group, "FeatherFlag", pos, rng:NextNumber(0, 6.28), 1.6)
			end
		end
	end

	cloudsAround(group, at((x0 + x1) / 2, 0, (z0 + z1) / 2), (x1 - x0) / 2, 14)
end

return ModeDecor
