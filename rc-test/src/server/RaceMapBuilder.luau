--!strict
-- Builds the big race maps (Shared/Maps: Backyard, Kitchen) far from the lobby: tiny RC cars in a
-- giant world. Each map is built BIG (map-local, the numbers in its module), then shrunk to RC
-- size and put where its track says (rcX, rcZ, rcAngle), as workspace.RaceMaps.<id>. The race
-- runner (ServerRaceRunner) drives it; the start lamps on the arch are StartLamp1..3.
-- Driving stays the race plot's: same road, curbs and grass grip/drag, same JUMP tile ridge and
-- boost pads. carter's Meshy props (ServerStorage.LobbyMeshes) are used when imported, with an
-- invisible box to bump into; block stand-ins otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local Kit = require(ReplicatedStorage.Shared.Plots.Kit)
local MapKit = require(ReplicatedStorage.Shared.Maps.MapKit)
local Features = require(ReplicatedStorage.Shared.Features)
local MeshProps = require(script.Parent.MeshProps)

local RaceMapBuilder = {}

local PI = math.pi
local C = Kit.COLORS
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local ROAD_COLOR = rgb(52, 52, 58)
local GRASS = rgb(86, 150, 70)
local WOOD = rgb(150, 105, 65)
local LIGHT_WOOD = rgb(214, 172, 120)
local DARK = rgb(36, 36, 40)
local STEEL = rgb(190, 195, 202)
local BOOST_COLOR = rgb(255, 200, 40)
local ROAD_TOP = 0.1 -- the main road's top
local SIDE_TOP = 0.08 -- side roads sit a hair lower, so where they meet the main road it wins
local FLAT_TOP = 0.05 -- flat looks (patio, rug, mats) sit under both

local LOOKS = {
	dirt = { color = rgb(150, 105, 60), mat = Enum.Material.Ground },
	mown = { color = rgb(128, 196, 96), mat = Enum.Material.Grass },
	tunnel = { color = rgb(196, 160, 112), mat = Enum.Material.WoodPlanks },
	tiles = { color = rgb(118, 120, 128), mat = Enum.Material.SmoothPlastic },
}
local PAD_LOOK: { [string]: { color: Color3, mat: Enum.Material } } = {
	boost = { color = BOOST_COLOR, mat = Enum.Material.Neon },
	puddle = { color = rgb(70, 140, 210), mat = Enum.Material.Glass },
	milk = { color = rgb(248, 248, 244), mat = Enum.Material.Glass },
	mud = { color = rgb(120, 76, 36), mat = Enum.Material.Mud },
	sand = { color = rgb(222, 196, 130), mat = Enum.Material.Sand },
}
-- carter's Meshy model for a prop kind (ServerStorage.LobbyMeshes), when it has one
local MESH: { [string]: string } = {
	sneaker = "Sneaker",
	sodaCan = "SodaCan",
	gnome = "Gnome",
	pinecone = "Pinecone",
	bucket = "Bucket",
	flowerPot = "FlowerPot",
	birdBath = "BirdBath",
	sandCastle = "SandCastle",
	tree = "LeafyTree",
	bigBush = "Bush",
	trashCan = "TrashCan",
}
RaceMapBuilder.MESH = MESH

-- ===== small helpers =====

-- every part: anchored, no touch events; solid = can the car bump it (and the camera see it)
local function finish(p: BasePart, solid: boolean)
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = solid
	p.CanQuery = solid
	if not solid then
		p.CastShadow = p.Size.Magnitude > 20
	end
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Kit.part(parent, name, CFrame.identity, size, cf, color)
	if mat then
		p.Material = mat
	end
	if shape then
		p.Shape = shape
	end
	p.CanTouch = false
	return p
end

-- a part that is only for looks: no collisions, no shadow
local function looks(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = part(parent, name, size, cf, color, mat, shape)
	finish(p, false)
	p.CastShadow = false
	return p
end

-- a flat strip from a to b (map-local), top at `top`
local function strip(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	top: number,
	color: Color3,
	mat: Enum.Material?
): Part
	local h = 0.2
	local p = Kit.slab(
		parent,
		name,
		CFrame.identity,
		Vector3.new(a.X, top - h / 2, a.Z),
		Vector3.new(b.X, top - h / 2, b.Z),
		width,
		h,
		1.5,
		color
	)
	if mat then
		p.Material = mat
	end
	p.CanTouch = false
	return p
end

local function disc(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	r: number,
	top: number,
	color: Color3
): Part
	local p = Kit.disc(parent, name, CFrame.identity, x, top - 0.1, z, r, 0.2, color)
	p.CanTouch = false
	return p
end

local function surface(p: BasePart, grip: number, drag: number?)
	p:SetAttribute("Grip", grip)
	if drag then
		p:SetAttribute("Drag", drag)
	end
end

-- a closed road ring or an open path: flat strips every `step` samples, a round patch at the
-- joints (fills the wedges on bends), all at `top`
local function road(
	parent: Instance,
	ring: { MapKit.Sample },
	closed: boolean,
	width: number,
	top: number,
	color: Color3,
	mat: Enum.Material?,
	name: string
): { BasePart }
	local out = {}
	local n = #ring
	local step = 2
	local idx = {}
	for i = 1, n, step do
		table.insert(idx, i)
	end
	if not closed and idx[#idx] ~= n then
		table.insert(idx, n)
	end
	local last = if closed then #idx else #idx - 1
	for k = 1, last do
		local a, b = ring[idx[k]], ring[idx[(k % #idx) + 1]]
		table.insert(
			out,
			strip(
				parent,
				name,
				Vector3.new(a.x, 0, a.z),
				Vector3.new(b.x, 0, b.z),
				width,
				top,
				color,
				mat
			)
		)
	end
	for _, i in idx do
		local s = ring[i]
		local d = disc(parent, name, s.x, s.z, width / 2, top, color)
		if mat then
			d.Material = mat
		end
		table.insert(out, d)
	end
	return out
end

-- the frame at a road sample: x across (right), z back (CFrame look = along the road)
local function frameAt(s: MapKit.Sample, y: number): CFrame
	local pos = Vector3.new(s.x, y, s.z)
	return CFrame.lookAt(pos, pos + Vector3.new(s.tx, 0, s.tz))
end

-- ===== the road (looks and grip like the race plot) =====

local function buildRoad(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local loop: { MapKit.Sample } = map.loop()
	local w = def.road
	for _, p in road(folder, loop, true, w, ROAD_TOP, ROAD_COLOR, nil, "Road") do
		surface(p, 1)
	end
	-- low red and white curbs on both edges
	local n = #loop
	local off = w / 2 + MapKit.CURB_WIDTH / 2
	local h = MapKit.CURB_HEIGHT
	-- the curb opens where the shortcut turns off and comes back, so it reads as a way in
	local gaps: { { ring: { MapKit.Sample }, r: number } } = {}
	for i, sp in def.paths do
		if sp.kind == "shortcut" then
			table.insert(gaps, { ring = map.path(i), r = sp.width / 2 + MapKit.CURB_WIDTH })
		end
	end
	local k = 0
	for i = 1, n, 2 do
		local p, q = loop[i], loop[((i + 1) % n) + 1]
		k += 1
		-- the white pieces a hair taller, so where two pieces overlap at a joint the tops don't
		-- flicker
		local ch = if k % 2 == 0 then h + 0.02 else h
		for _, side in { -1, 1 } do
			local o = off * side
			local pa = Vector3.new(p.x - p.tz * o, ch / 2, p.z + p.tx * o)
			local pb = Vector3.new(q.x - q.tz * o, ch / 2, q.z + q.tx * o)
			local open = false
			for _, gap in gaps do
				if MapKit.distTo(gap.ring, (pa.X + pb.X) / 2, (pa.Z + pb.Z) / 2) < gap.r then
					open = true
				end
			end
			if open then
				continue
			end
			local curb = Kit.slab(
				folder,
				"Curb",
				CFrame.identity,
				pa,
				pb,
				MapKit.CURB_WIDTH,
				ch,
				0.5,
				if k % 2 == 0 then C.white else C.red
			)
			curb.CanTouch = false
			surface(curb, 1)
		end
	end
	-- checkered start / finish line
	local g = map.gates[1]
	local rx, rz = -g.dz, g.dx
	local cells = 6
	local size = w / cells
	for row = 0, 1 do
		for i = 0, cells - 1 do
			local across = (i + 0.5) * size - w / 2
			local along = (row - 0.5) * 3
			local l = Kit.line(
				folder,
				CFrame.identity,
				g.x + rx * across + g.dx * along,
				0,
				g.z + rz * across + g.dz * along,
				g.dx,
				g.dz,
				size,
				if (i + row) % 2 == 0 then C.white else ROAD_COLOR
			)
			l.CanQuery = false
			l.CanCollide = false
			l.CanTouch = false
		end
	end
end

-- side roads: the shortcut you can see and the hidden secret
local function buildPaths(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for i, p in def.paths do
		local look = LOOKS[p.look] or LOOKS.dirt
		for _, s in
			road(folder, map.path(i), false, p.width, SIDE_TOP, look.color, look.mat, "SideRoad")
		do
			surface(s, 1) -- no drag: that's what makes it quick
		end
		if p.look == "mown" then
			-- mower stripes, so it reads as lawn
			local ring = map.path(i)
			for k = 1, #ring - 1, 4 do
				local a, b = ring[k], ring[math.min(k + 2, #ring)]
				local st = strip(
					folder,
					"Stripe",
					Vector3.new(a.x, 0, a.z),
					Vector3.new(b.x, 0, b.z),
					p.width * 0.4,
					SIDE_TOP + 0.03,
					rgb(150, 214, 116),
					Enum.Material.Grass
				)
				finish(st, false)
			end
		end
	end
end

-- boost / slippy / slow patches on top of a road
local function buildPads(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for _, pad in def.pads do
		local ring = map.ring(pad.path)
		local s = MapKit.nearest(ring, pad.at)
		local w = (if pad.path == 0 then def.road else def.paths[pad.path].width) - 6
		local look = PAD_LOOK[pad.kind]
		local rule = MapKit.PADS[pad.kind]
		local p = part(
			folder,
			if pad.kind == "boost" then "BoostPad" else "Patch",
			Vector3.new(w, 0.04, pad.len),
			frameAt(s, ROAD_TOP + 0.04),
			look.color,
			look.mat
		)
		surface(p, rule.grip, rule.drag)
		if rule.boost then
			p:SetAttribute("Boost", true) -- the car pushes forward while on it
			-- two orange arrows pointing the way to go
			for k = 0, 1 do
				for _, side in { -1, 1 } do
					local arm = part(
						folder,
						"BoostArrow",
						Vector3.new(w * 0.36, 0.05, 2),
						frameAt(s, ROAD_TOP + 0.08)
							* CFrame.new(side * w * 0.15, 0, -pad.len * 0.25 + k * pad.len * 0.4)
							* CFrame.Angles(0, side * 0.6, 0),
						rgb(240, 110, 20),
						Enum.Material.Neon
					)
					finish(arm, false)
				end
			end
		end
	end
end

-- jump ridges across the road, same shape as the JUMP tile (Studio-tested air time)
local function buildJumps(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local color = if def.theme == "kitchen" then LIGHT_WOOD else WOOD
	for _, j in def.jumps do
		local ring = map.ring(j.path)
		local s = MapKit.nearest(ring, j.at)
		local w = (if j.path == 0 then def.road else def.paths[j.path].width) - 4
		local half = (j.len or MapKit.JUMP_LEN) / 2
		local t = Vector3.new(s.tx, 0, s.tz)
		local mid = Vector3.new(s.x, 0, s.z)
		local peak = mid + Vector3.new(0, j.h or MapKit.JUMP_H, 0)
		for _, dir in { -1, 1 } do
			local run = if dir < 0 then half else MapKit.JUMP_DOWN -- a long landing slope
			local r =
				Kit.ramp(folder, "JumpRamp", CFrame.identity, mid + t * dir * run, peak, w, color)
			r.Material = Enum.Material.WoodPlanks
			r.CanTouch = false
			surface(r, 1)
			if dir < 0 then
				-- yellow bands up the run-up, so it reads as a jump from far off
				local len = r.Size.Z
				for b = 0, 3 do
					looks(
						folder,
						"JumpStripe",
						Vector3.new(w - 2, 0.06, 3),
						r.CFrame * CFrame.new(0, 0.53, len / 2 - 4 - b * (len - 8) / 3),
						rgb(255, 205, 40),
						Enum.Material.SmoothPlastic
					)
				end
			end
		end
	end
end

-- the start / finish arch: posts out past the curbs, a checker beam, three start lamps facing
-- the grid (client/StartLights turns them red, red, red, green)
local function buildArch(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local g = map.gates[1]
	local yaw = math.atan2(-g.dx, -g.dz)
	local at = CFrame.new(g.x, 0, g.z) * CFrame.Angles(0, yaw, 0)
	local arch = Instance.new("Model")
	arch.Name = "FinishArch"
	arch.Parent = folder
	local h = 30
	local inner = def.road / 2 + MapKit.CURB_WIDTH + 4
	for _, s in { -1, 1 } do
		part(
			arch,
			"ArchPost",
			Vector3.new(4, h, 4),
			at * CFrame.new(s * (inner + 2), h / 2, 0),
			C.blue
		)
		part(
			arch,
			"ArchFoot",
			Vector3.new(6, 3, 7),
			at * CFrame.new(s * (inner + 2), 1.5, 0),
			C.blue
		)
	end
	local span = 2 * inner
	local cells = 12
	for row = 0, 1 do
		for i = 0, cells - 1 do
			part(
				arch,
				"ArchBeam",
				Vector3.new(span / cells, 2.4, 2),
				at * CFrame.new((i + 0.5) * span / cells - span / 2, h - 1.2 - row * 2.4, 0),
				if (i + row) % 2 == 0 then C.white else rgb(30, 30, 34)
			)
		end
	end
	local lightY = h - 7
	part(
		arch,
		"StartLights",
		Vector3.new(14, 4.6, 1.4),
		at * CFrame.new(0, lightY, 0),
		rgb(24, 24, 28)
	)
	for i = 1, 3 do
		part(
			arch,
			"StartLamp" .. i,
			Vector3.new(3, 3, 3),
			at * CFrame.new((i - 2) * 4.2, lightY, 0.8),
			rgb(40, 40, 44),
			nil,
			Enum.PartType.Ball
		)
	end
	for _, d in arch:GetDescendants() do
		if d:IsA("BasePart") then
			finish(d, true)
		end
	end
end

-- ===== the floor and the edge of the map =====

local function buildFloor(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local w, d = def.maxX - def.minX, def.maxZ - def.minZ
	local cx, cz = (def.minX + def.maxX) / 2, (def.minZ + def.maxZ) / 2
	local kitchen = def.theme == "kitchen"
	local floor = part(
		folder,
		"Ground",
		Vector3.new(w, 4, d),
		CFrame.new(cx, -2, cz),
		if kitchen then rgb(244, 236, 218) else GRASS,
		if kitchen then Enum.Material.SmoothPlastic else Enum.Material.Grass
	)
	-- off the road: the race plot's grass (slower, a bit slidier)
	surface(floor, MapKit.GRASS_GRIP, MapKit.GRASS_DRAG)
	if kitchen then
		-- checker floor tiles: paint only (the wheels read the floor under them)
		local t = 66 -- a 12 inch tile: a giant square next to the car
		for i = 0, math.ceil(w / t) - 1 do
			for j = 0, math.ceil(d / t) - 1 do
				if (i + j) % 2 == 0 then
					local x0, z0 = def.minX + i * t, def.minZ + j * t
					local x1, z1 = math.min(x0 + t, def.maxX), math.min(z0 + t, def.maxZ)
					local tile = part(
						folder,
						"FloorTile",
						Vector3.new(x1 - x0, 0.04, z1 - z0),
						CFrame.new((x0 + x1) / 2, 0.02, (z0 + z1) / 2),
						rgb(110, 140, 182)
					)
					finish(tile, false)
				end
			end
		end
	else
		-- lawn past the fence, under the giant trees
		local m = 700
		local out = part(
			folder,
			"Lawn",
			Vector3.new(w + m * 2, 4, d + m * 2),
			CFrame.new(cx, -2.2, cz),
			rgb(76, 138, 62),
			Enum.Material.Grass
		)
		finish(out, true)
	end
end

local function buildEdge(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local kitchen = def.theme == "kitchen"
	local w, d = def.maxX - def.minX, def.maxZ - def.minZ
	local cx, cz = (def.minX + def.maxX) / 2, (def.minZ + def.maxZ) / 2
	local h = if kitchen then 620 else 264 -- a kitchen wall; a 4 ft fence
	local t = 12
	local sides: { { size: Vector3, cf: CFrame } } = {
		{ size = Vector3.new(w + t * 2, h, t), cf = CFrame.new(cx, h / 2, def.minZ - t / 2) },
		{ size = Vector3.new(w + t * 2, h, t), cf = CFrame.new(cx, h / 2, def.maxZ + t / 2) },
		{ size = Vector3.new(t, h, d), cf = CFrame.new(def.minX - t / 2, h / 2, cz) },
		{ size = Vector3.new(t, h, d), cf = CFrame.new(def.maxX + t / 2, h / 2, cz) },
	}
	for _, sd in sides do
		local wall = part(
			folder,
			"Wall",
			sd.size,
			sd.cf,
			if kitchen then rgb(250, 232, 176) else C.white,
			Enum.Material.SmoothPlastic
		)
		-- slippery and a bit bouncy, like the plots' walls: the car pushes off instead of grinding
		wall.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.45, 100, 100)
		finish(wall, true)
		if not kitchen then
			wall.Transparency = 1 -- the pickets below are the looks
		end
	end
	if kitchen then
		-- baseboard all round, a window over the sink, and a door in the front wall
		for _, sd in sides do
			local bb = part(
				folder,
				"Baseboard",
				Vector3.new(sd.size.X + 2, 24, sd.size.Z + 2),
				sd.cf - Vector3.new(0, h / 2 - 12, 0),
				rgb(250, 250, 246)
			)
			finish(bb, false)
		end
		local win = part(
			folder,
			"Window",
			Vector3.new(320, 200, 2),
			CFrame.new(296, 400, def.minZ + 1),
			rgb(170, 214, 240),
			Enum.Material.Glass
		)
		finish(win, false)
		local frame = part(
			folder,
			"WindowFrame",
			Vector3.new(340, 220, 1),
			CFrame.new(296, 400, def.minZ + 0.4),
			C.white
		)
		finish(frame, false)
		local door = part(
			folder,
			"Door",
			Vector3.new(200, 440, 2),
			CFrame.new(-330, 220, def.maxZ - 1),
			rgb(176, 128, 86),
			Enum.Material.Wood
		)
		finish(door, false)
		local knob = part(
			folder,
			"DoorKnob",
			Vector3.new(16, 16, 16),
			CFrame.new(-410, 200, def.maxZ - 8),
			rgb(220, 190, 90),
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		finish(knob, false)
		return
	end
	-- white picket fence: two rails and a picket every 40 (looks only; the clear wall stops you)
	local function run(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		for _, y in { 70, 190 } do
			local rail = part(
				folder,
				"FenceRail",
				Vector3.new(8, 14, len),
				CFrame.lookAt((a + b) / 2 + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
				rgb(238, 238, 232),
				Enum.Material.Wood
			)
			finish(rail, false)
		end
		local count = math.floor(len / 40)
		for i = 0, count do
			local p = a + dir * (i * len / count)
			local picket = part(
				folder,
				"Picket",
				Vector3.new(24, h, 6),
				CFrame.lookAt(p + Vector3.new(0, h / 2, 0), p + Vector3.new(0, h / 2, 0) + dir)
					* CFrame.Angles(0, PI / 2, 0),
				C.white,
				Enum.Material.Wood
			)
			finish(picket, false)
			local tip = part(
				folder,
				"PicketTip",
				Vector3.new(17, 17, 6),
				CFrame.new(p + Vector3.new(0, h, 0))
					* CFrame.lookAt(Vector3.zero, dir)
					* CFrame.Angles(0, PI / 2, PI / 4),
				C.white,
				Enum.Material.Wood
			)
			finish(tip, false)
		end
	end
	local x0, x1, z0, z1 = def.minX - 6, def.maxX + 6, def.minZ - 6, def.maxZ + 6
	run(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	run(Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1))
	run(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))
	run(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1))
end

-- ===== props =====

-- lines lying on the floor: the garden hose (solid, a giant bump), the dropped spoon (looks)
local function buildLines(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for _, l in def.lines do
		local pts = Kit.path(l.points, 6)
		local r = l.width / 2
		local hose = l.kind == "hose"
		local color = if hose then rgb(46, 150, 64) else STEEL
		for i = 1, #pts - 1 do
			local a = Vector3.new(pts[i].x, r, pts[i].z)
			local b = Vector3.new(pts[i + 1].x, r, pts[i + 1].z)
			local len = (b - a).Magnitude
			local seg = part(
				folder,
				if hose then "Hose" else "Spoon",
				Vector3.new(len + r, l.width, l.width),
				CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, PI / 2, 0),
				color,
				if hose then Enum.Material.Plastic else Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
			-- under a jump the ridge covers it; only out on the grass is it something to hit
			local onRoad = MapKit.distTo(map.loop(), (a.X + b.X) / 2, (a.Z + b.Z) / 2)
				< def.road / 2 + 6
			finish(seg, hose and not onRoad)
		end
		if not hose then
			local tip = pts[#pts]
			local bowl = part(
				folder,
				"SpoonBowl",
				Vector3.new(l.width * 3, l.width, l.width * 4),
				CFrame.new(tip.x, l.width / 2, tip.z),
				STEEL,
				Enum.Material.Metal,
				Enum.PartType.Ball
			)
			finish(bowl, false)
		end
	end
end

type Box = (
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	shape: Enum.PartType?
) -> Part

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, PI / 2) -- a cylinder standing up

-- Block looks for each kind, in the prop's own space (floor at y = 0, front = -Z). Return true
-- when the kind is hollow / drive-through (its own parts are its collision, no footprint box).
local BUILD: { [string]: (box: Box, e: MapKit.Prop) -> boolean? } = {}

function BUILD.patio(box, e)
	local w, d = e.w or 100, e.d or 100
	local s = 64
	for i = 0, math.floor(w / s) - 1 do
		for j = 0, math.floor(d / s) - 1 do
			local shade = if (i + j) % 2 == 0 then rgb(200, 190, 174) else rgb(184, 174, 160)
			box(
				Vector3.new(s - 4, 0.04, s - 4),
				CFrame.new(-w / 2 + (i + 0.5) * s, FLAT_TOP, -d / 2 + (j + 0.5) * s),
				shade,
				Enum.Material.Slate
			)
		end
	end
	return nil
end

function BUILD.steps(box, e)
	local w, d = e.w or 100, e.d or 30
	for i = 0, 2 do
		box(
			Vector3.new(w, e.h / 3 * (i + 1), d / 3),
			CFrame.new(0, e.h / 6 * (i + 1), d / 2 - (i + 0.5) * d / 3),
			rgb(176, 166, 154),
			Enum.Material.Concrete
		)
	end
	box(
		Vector3.new(w + 400, 400, 20),
		CFrame.new(0, 200, d / 2 + 10),
		rgb(214, 196, 168),
		Enum.Material.Brick
	) -- the house
	return nil
end

function BUILD.sandbox(box, e)
	local w, d = e.w or 100, e.d or 100
	local t = 10
	box(
		Vector3.new(w - t * 2, e.h - 6, d - t * 2),
		CFrame.new(0, (e.h - 6) / 2, 0),
		rgb(232, 210, 150),
		Enum.Material.Sand
	)
	for _, s in { -1, 1 } do
		box(
			Vector3.new(w, e.h, t),
			CFrame.new(0, e.h / 2, s * (d / 2 - t / 2)),
			WOOD,
			Enum.Material.Wood
		)
		box(
			Vector3.new(t, e.h, d),
			CFrame.new(s * (w / 2 - t / 2), e.h / 2, 0),
			WOOD,
			Enum.Material.Wood
		)
	end
	box(
		Vector3.new(24, 16, 12),
		CFrame.new(-50, e.h + 2, 30) * CFrame.Angles(0.3, 0.4, 0),
		rgb(230, 60, 60)
	) -- toy spade
	return nil
end

function BUILD.sandCastle(box, e)
	local sand = rgb(214, 182, 112)
	box(
		Vector3.new(e.w or 60, e.h * 0.45, e.d or 60),
		CFrame.new(0, 22 + e.h * 0.225, 0),
		sand,
		Enum.Material.Sand
	)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = c[1] * (e.w or 60) * 0.42, c[2] * (e.d or 60) * 0.42
		box(
			Vector3.new(e.h * 0.6, 18, 18),
			CFrame.new(x, 22 + e.h * 0.3, z) * UP,
			sand,
			Enum.Material.Sand,
			CYL
		)
	end
	box(
		Vector3.new(e.h * 0.3, 26, 26),
		CFrame.new(0, 22 + e.h * 0.6, 0) * UP,
		sand,
		Enum.Material.Sand,
		CYL
	)
	return nil
end

function BUILD.sneaker(box, e)
	local l, w, h = e.d or 68, e.w or 30, e.h
	local upper = rgb(230, 64, 64)
	box(Vector3.new(w, h * 0.2, l), CFrame.new(0, h * 0.1, 0), C.white) -- sole
	box(Vector3.new(w * 0.92, h * 0.5, l * 0.62), CFrame.new(0, h * 0.45, l * 0.16), upper) -- heel half
	box(Vector3.new(w * 0.9, h * 0.34, l * 0.4), CFrame.new(0, h * 0.36, -l * 0.28), upper) -- toe
	box(Vector3.new(w * 0.88, h * 0.3, l * 0.2), CFrame.new(0, h * 0.3, -l * 0.42), C.white) -- toe cap
	box(Vector3.new(w * 0.7, h * 0.3, l * 0.3), CFrame.new(0, h * 0.75, l * 0.3), upper) -- ankle
	for i = 0, 3 do -- laces
		box(
			Vector3.new(w * 0.7, 1.2, 2),
			CFrame.new(0, h * 0.54 + i * 0.02 * h, -l * 0.12 + i * l * 0.07),
			C.white
		)
	end
	return nil
end

function BUILD.tap(box, e)
	box(
		Vector3.new(12, e.h, 12),
		CFrame.new(0, e.h / 2, 0),
		rgb(150, 150, 160),
		Enum.Material.Metal
	)
	box(Vector3.new(30, 8, 8), CFrame.new(0, e.h - 6, -10), rgb(200, 60, 50), Enum.Material.Metal)
	return nil
end

function BUILD.hoseReel(box, e)
	box(
		Vector3.new(e.w or 60, e.h * 0.8, e.h * 0.8),
		CFrame.new(0, e.h * 0.5, 0),
		rgb(46, 150, 64),
		Enum.Material.Plastic,
		CYL
	)
	for _, s in { -1, 1 } do
		box(
			Vector3.new(4, e.h, e.h * 0.6),
			CFrame.new(s * ((e.w or 60) / 2 + 2), e.h / 2, 0),
			rgb(60, 60, 66)
		)
	end
	return nil
end

function BUILD.flowerBed(box, e)
	box(
		Vector3.new(e.w or 100, 0.04, e.d or 80),
		CFrame.new(0, FLAT_TOP, 0),
		rgb(110, 76, 46),
		Enum.Material.Ground
	)
	return nil
end

function BUILD.flowerPot(box, e)
	local w = e.w or 50
	box(
		Vector3.new(e.h * 0.7, w * 0.8, w * 0.8),
		CFrame.new(0, e.h * 0.35, 0) * UP,
		rgb(196, 106, 66),
		Enum.Material.Slate,
		CYL
	)
	box(
		Vector3.new(e.h * 0.1, w, w),
		CFrame.new(0, e.h * 0.72, 0) * UP,
		rgb(206, 116, 74),
		Enum.Material.Slate,
		CYL
	)
	box(Vector3.new(4, e.h * 1.6, 4), CFrame.new(0, e.h * 1.4, 0), rgb(60, 140, 50))
	box(
		Vector3.new(w * 0.9, w * 0.5, w * 0.9),
		CFrame.new(0, e.h * 2.2, 0),
		rgb(240, 90, 150),
		nil,
		BALL
	)
	box(
		Vector3.new(w * 0.35, w * 0.35, w * 0.35),
		CFrame.new(0, e.h * 2.25, 0),
		rgb(255, 214, 60),
		nil,
		BALL
	)
	return nil
end

function BUILD.gnome(box, e)
	local h = e.h
	box(Vector3.new(h * 0.32, h * 0.18, h * 0.32), CFrame.new(0, h * 0.09, 0), rgb(70, 70, 76)) -- boots
	box(
		Vector3.new(h * 0.4, h * 0.36, h * 0.4),
		CFrame.new(0, h * 0.36, 0),
		rgb(60, 100, 200),
		nil,
		BALL
	)
	box(
		Vector3.new(h * 0.26, h * 0.26, h * 0.26),
		CFrame.new(0, h * 0.6, 0),
		rgb(250, 210, 180),
		nil,
		BALL
	)
	box(Vector3.new(h * 0.24, h * 0.2, h * 0.1), CFrame.new(0, h * 0.5, -h * 0.12), C.white) -- beard
	box(Vector3.new(h * 0.3, h * 0.34, h * 0.3), CFrame.new(0, h * 0.84, 0), rgb(220, 50, 50))
	return nil
end

-- the dog house sits ON the secret strip: no footprint box, walls on both sides of the way through
function BUILD.dogHouse(box, e)
	local w, d, h = e.w or 200, e.d or 170, e.h
	local red, roof = rgb(170, 60, 50), rgb(70, 60, 60)
	local wallH = h * 0.6
	local gap = 84 -- the way through (local z, front to back, turned to the road)
	for _, s in { -1, 1 } do
		box(
			Vector3.new((w - gap) / 2, wallH, d),
			CFrame.new(s * (gap / 2 + (w - gap) / 4), wallH / 2, 0),
			red,
			Enum.Material.WoodPlanks
		)
		box(
			Vector3.new(w * 0.62, 8, d + 16),
			CFrame.new(s * w * 0.24, wallH + h * 0.18, 0) * CFrame.Angles(0, 0, s * -0.55),
			roof,
			Enum.Material.Slate
		)
	end
	-- front and back walls above the door
	for _, s in { -1, 1 } do
		box(
			Vector3.new(gap, wallH - 60, 6),
			CFrame.new(0, 60 + (wallH - 60) / 2, s * (d / 2 - 3)),
			red,
			Enum.Material.WoodPlanks
		)
	end
	box(Vector3.new(gap, 6, d), CFrame.new(0, wallH, 0), red, Enum.Material.WoodPlanks)
	box(Vector3.new(60, 12, 2), CFrame.new(0, wallH - 8, -d / 2 - 1), rgb(250, 230, 120)) -- name board (no words)
	box(Vector3.new(30, 8, 8), CFrame.new(w / 2 + 30, 4, 20) * CFrame.Angles(0, 0.5, 0), C.white) -- a bone
	return true
end

-- leaves you can drive through (they hide the secret's start)
function BUILD.bigBush(box, e)
	local w, d = e.w or 100, e.d or 80
	for i, c in { { 0, 0, 1 }, { -0.3, 0.2, 0.8 }, { 0.32, -0.15, 0.75 }, { 0.1, 0.3, 0.7 } } do
		box(
			Vector3.new(w * c[3], e.h * c[3], d * c[3]),
			CFrame.new(w * c[1], e.h * 0.45 * c[3], d * c[2]),
			if i % 2 == 0 then rgb(48, 120, 52) else rgb(40, 104, 46),
			Enum.Material.Grass,
			BALL
		)
	end
	return nil
end

function BUILD.dogBowl(box, e)
	box(
		Vector3.new(e.h, e.w or 44, e.w or 44),
		CFrame.new(0, e.h / 2, 0) * UP,
		rgb(70, 110, 200),
		Enum.Material.Plastic,
		CYL
	)
	box(
		Vector3.new(1, (e.w or 44) * 0.8, (e.w or 44) * 0.8),
		CFrame.new(0, e.h, 0) * UP,
		rgb(130, 90, 50),
		Enum.Material.Pebble,
		CYL
	)
	return nil
end

function BUILD.birdBath(box, e)
	local w = e.w or 90
	box(
		Vector3.new(14, w * 0.5, w * 0.5),
		CFrame.new(0, 7, 0) * UP,
		rgb(186, 186, 190),
		Enum.Material.Concrete,
		CYL
	)
	box(
		Vector3.new(e.h * 0.8, w * 0.22, w * 0.22),
		CFrame.new(0, e.h * 0.4, 0) * UP,
		rgb(190, 190, 195),
		Enum.Material.Concrete,
		CYL
	)
	box(
		Vector3.new(e.h * 0.14, w, w),
		CFrame.new(0, e.h * 0.9, 0) * UP,
		rgb(196, 196, 200),
		Enum.Material.Concrete,
		CYL
	)
	box(
		Vector3.new(1, w * 0.84, w * 0.84),
		CFrame.new(0, e.h * 0.97, 0) * UP,
		rgb(110, 170, 220),
		Enum.Material.Glass,
		CYL
	)
	return nil
end

function BUILD.bucket(box, e)
	local w = e.w or 60
	box(
		Vector3.new(e.h, w, w),
		CFrame.new(0, e.h / 2, 0) * UP,
		rgb(240, 190, 40),
		Enum.Material.Plastic,
		CYL
	)
	box(
		Vector3.new(4, e.h * 0.7, 4),
		CFrame.new(0, e.h + 2, 0) * CFrame.Angles(0, 0, PI / 2),
		rgb(60, 60, 60)
	) -- handle, resting on the rim
	return nil
end

function BUILD.sodaCan(box, e)
	box(
		Vector3.new(e.w or 26, e.h, e.h),
		CFrame.new(0, e.h / 2, 0),
		rgb(220, 40, 40),
		Enum.Material.Metal,
		CYL
	)
	return nil
end

function BUILD.ball(box, e)
	box(Vector3.new(e.h, e.h, e.h), CFrame.new(0, e.h / 2, 0), C.white, nil, BALL)
	for _, c in { { 0.42, 0.6, 0 }, { -0.3, 0.75, 0.3 }, { 0, 0.55, -0.45 } } do
		box(
			Vector3.new(e.h * 0.25, e.h * 0.25, e.h * 0.25),
			CFrame.new(e.h * c[1], e.h * c[2], e.h * c[3]),
			DARK,
			nil,
			BALL
		)
	end
	return nil
end

function BUILD.picnicTable(box, e)
	local w, d, h = e.w or 400, e.d or 200, e.h
	box(Vector3.new(w, 10, d * 0.45), CFrame.new(0, h - 5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		box(
			Vector3.new(w, 8, d * 0.18),
			CFrame.new(0, h * 0.55, s * d * 0.4),
			WOOD,
			Enum.Material.WoodPlanks
		) -- benches
		for _, sx in { -1, 1 } do
			box(
				Vector3.new(10, h, 10),
				-- (2.5 lower: the lean lifts a box's bottom corner off the grass)
				CFrame.new(sx * w * 0.4, h / 2 - 2.5, s * d * 0.15)
					* CFrame.Angles(s * 0.3, 0, 0),
				WOOD,
				Enum.Material.Wood
			)
		end
	end
	return true -- drive under it, between the legs
end

function BUILD.leaf(box, e)
	box(
		Vector3.new(e.w or 50, 0.06, e.d or 34),
		CFrame.new(0, FLAT_TOP + 0.02, 0) * CFrame.Angles(0, 0.3, 0),
		rgb(206, 140, 44)
	)
	box(
		Vector3.new((e.w or 50) * 0.9, 0.08, 1.5),
		CFrame.new(0, FLAT_TOP + 0.03, 0) * CFrame.Angles(0, 0.3, 0),
		rgb(150, 92, 30)
	)
	return nil
end

function BUILD.pinecone(box, e)
	for i = 0, 3 do
		local s = (e.w or 20) * (1 - i * 0.18)
		box(
			Vector3.new(s, e.h * 0.3, s),
			CFrame.new(0, e.h * (0.15 + i * 0.22), 0),
			rgb(120, 80, 48),
			Enum.Material.Wood,
			BALL
		)
	end
	return nil
end

function BUILD.tree(box, e)
	local w = e.w or 100
	box(
		Vector3.new(e.h * 0.6, w, w),
		CFrame.new(0, e.h * 0.3, 0) * UP,
		rgb(100, 74, 52),
		Enum.Material.Wood,
		CYL
	)
	for _, c in
		{ { 0, 0.75, 0, 5 }, { -1.5, 0.68, 1, 4 }, { 1.6, 0.7, -0.8, 4 }, { 0.4, 0.88, 1.2, 3.6 } }
	do
		box(
			Vector3.new(w * c[4], w * c[4] * 0.8, w * c[4]),
			CFrame.new(w * c[1], e.h * c[2], w * c[3]),
			rgb(66, 130, 58),
			Enum.Material.Grass,
			BALL
		)
	end
	return nil
end

function BUILD.tuft(box, e)
	for i = 0, 4 do
		local a = i * 1.26
		local lean = 0.25 + (i % 2) * 0.15
		box(
			Vector3.new(3, e.h * (0.7 + (i % 3) * 0.15), 1),
			CFrame.new(math.cos(a) * 6, e.h * 0.35, math.sin(a) * 6)
				* CFrame.Angles(math.sin(a) * lean, a, math.cos(a) * lean),
			rgb(70, 150, 56),
			Enum.Material.Grass
		)
	end
	return nil
end

-- kitchen

function BUILD.fridge(box, e)
	local w, d, h = e.w or 190, e.d or 170, e.h
	box(
		Vector3.new(w, h, d),
		CFrame.new(0, h / 2, 0),
		rgb(236, 238, 242),
		Enum.Material.SmoothPlastic
	)
	box(Vector3.new(w - 4, 3, 2), CFrame.new(0, h * 0.68, -d / 2 - 1), rgb(196, 198, 204)) -- freezer line
	for _, y in { h * 0.45, h * 0.84 } do
		box(
			Vector3.new(6, h * 0.18, 6),
			CFrame.new(w / 2 - 20, y, -d / 2 - 5),
			STEEL,
			Enum.Material.Metal
		)
	end
	-- magnets and a kid's drawing (shapes only)
	box(Vector3.new(40, 50, 1), CFrame.new(-30, h * 0.52, -d / 2 - 1), rgb(255, 250, 230))
	box(Vector3.new(14, 14, 3), CFrame.new(-50, h * 0.58, -d / 2 - 2), rgb(230, 60, 60), nil, BALL)
	box(Vector3.new(12, 12, 3), CFrame.new(30, h * 0.75, -d / 2 - 2), rgb(60, 140, 230), nil, BALL)
	return nil
end

-- stove and sink: the counter run builds the box, these add the top and the front
function BUILD.stove(box, e)
	local w, d, h = e.w or 170, e.d or 140, e.h
	box(Vector3.new(w, 4, d), CFrame.new(0, h + 2, 0), DARK, Enum.Material.Glass)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		box(
			Vector3.new(1, 36, 36),
			CFrame.new(c[1] * w * 0.24, h + 4.5, c[2] * d * 0.22) * UP,
			rgb(60, 60, 64),
			Enum.Material.Metal,
			CYL
		)
	end
	box(
		Vector3.new(w - 20, h * 0.5, 2),
		CFrame.new(0, h * 0.42, d / 2 + 1),
		rgb(50, 50, 56),
		Enum.Material.Glass
	) -- oven door
	box(Vector3.new(w - 40, 5, 5), CFrame.new(0, h * 0.72, d / 2 + 5), STEEL, Enum.Material.Metal)
	return true
end

function BUILD.sink(box, e)
	local w, d, h = e.w or 180, e.d or 140, e.h
	box(Vector3.new(w * 0.8, 2, d * 0.6), CFrame.new(0, h + 1.2, 0), STEEL, Enum.Material.Metal)
	box(Vector3.new(10, 50, 10), CFrame.new(0, h + 25, -d * 0.4), STEEL, Enum.Material.Metal)
	box(Vector3.new(10, 10, 40), CFrame.new(0, h + 48, -d * 0.25), STEEL, Enum.Material.Metal)
	return true
end

-- an open cabinet door, swung all the way round flat against the cupboard next to its hole
-- (it never sticks out into the road)
function BUILD.cabinetDoor(box, e)
	local w, h = e.w or 66, e.h
	box(
		Vector3.new(w, h * 0.6, 3),
		CFrame.new(-w * 1.05, 6 + h * 0.3, 2),
		rgb(196, 156, 112),
		Enum.Material.Wood
	)
	box(Vector3.new(4, 16, 4), CFrame.new(-w * 1.4, 6 + h * 0.4, 5), STEEL, Enum.Material.Metal)
	return true
end

function BUILD.table(box, e)
	local w, d, h = e.w or 280, e.d or 380, e.h
	box(Vector3.new(w, 10, d), CFrame.new(0, h - 5, 0), rgb(160, 110, 70), Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				Vector3.new(14, h - 10, 14),
				CFrame.new(sx * (w / 2 - 12), (h - 10) / 2, sz * (d / 2 - 12)),
				rgb(120, 80, 50),
				Enum.Material.Wood
			)
		end
	end
	return true -- drive under it
end

function BUILD.chair(box, e)
	local w, h = e.w or 96, e.h
	box(Vector3.new(w, 8, w), CFrame.new(0, h - 4, 0), rgb(190, 140, 90), Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				Vector3.new(8, h - 8, 8),
				CFrame.new(sx * (w / 2 - 4), (h - 8) / 2, sz * (w / 2 - 4)),
				rgb(120, 80, 50),
				Enum.Material.Wood
			)
		end
	end
	box(
		Vector3.new(w, h * 0.9, 6),
		CFrame.new(0, h + h * 0.45, w / 2 - 3),
		rgb(190, 140, 90),
		Enum.Material.Wood
	)
	return true -- drive between the legs
end

function BUILD.mopBucket(box, e)
	local w = e.w or 80
	box(
		Vector3.new(e.h, w, w),
		CFrame.new(0, e.h / 2, 0) * UP,
		rgb(240, 200, 40),
		Enum.Material.Plastic,
		CYL
	)
	box(
		Vector3.new(1, w * 0.86, w * 0.86),
		CFrame.new(0, e.h, 0) * UP,
		rgb(150, 190, 210),
		Enum.Material.Glass,
		CYL
	)
	box(
		Vector3.new(6, e.h * 4, 6),
		CFrame.new(10, e.h * 2, 10) * CFrame.Angles(0.2, 0, 0.2),
		rgb(140, 100, 70),
		Enum.Material.Wood
	) -- mop
	return nil
end

function BUILD.wetSign(box, e)
	local w, h = e.w or 50, e.h
	for _, s in { -1, 1 } do
		box(
			Vector3.new(w, h, 2),
			CFrame.new(0, h / 2, s * 8) * CFrame.Angles(s * 0.2, 0, 0),
			rgb(250, 210, 40)
		)
	end
	return nil
end

function BUILD.doorMat(box, e)
	box(
		Vector3.new(e.w or 200, 0.04, e.d or 110),
		CFrame.new(0, FLAT_TOP, 0),
		rgb(150, 70, 50),
		Enum.Material.Fabric
	)
	return nil
end

function BUILD.rug(box, e)
	local w, d = e.w or 500, e.d or 300
	box(
		Vector3.new(w, 0.04, d),
		CFrame.new(0, FLAT_TOP, 0),
		rgb(96, 128, 186),
		Enum.Material.Fabric
	)
	box(
		Vector3.new(w - 40, 0.05, d - 40),
		CFrame.new(0, FLAT_TOP + 0.01, 0),
		rgb(120, 150, 200),
		Enum.Material.Fabric
	)
	return nil
end

function BUILD.trashCan(box, e)
	local w = e.w or 84
	box(
		Vector3.new(e.h, w, w),
		CFrame.new(0, e.h / 2, 0) * UP,
		rgb(130, 135, 140),
		Enum.Material.Metal,
		CYL
	)
	box(
		Vector3.new(6, w + 4, w + 4),
		CFrame.new(0, e.h + 3, 0) * UP,
		rgb(150, 155, 160),
		Enum.Material.Metal,
		CYL
	)
	return nil
end

function BUILD.cerealBox(box, e)
	box(Vector3.new(e.w or 66, e.h, e.d or 44), CFrame.new(0, e.h / 2, 0), rgb(240, 170, 40))
	box(
		Vector3.new((e.w or 66) * 0.5, e.h + 0.2, (e.d or 44) * 0.6),
		CFrame.new(0, e.h / 2, 0),
		rgb(230, 60, 60)
	)
	return nil
end

function BUILD.cereal(box, e)
	box(
		Vector3.new(e.w or 10, e.h, e.w or 10),
		CFrame.new(0, e.h / 2, 0),
		rgb(214, 164, 70),
		nil,
		BALL
	)
	return nil
end

function BUILD.apple(box, e)
	box(Vector3.new(e.h, e.h, e.h), CFrame.new(0, e.h / 2, 0), rgb(214, 40, 40), nil, BALL)
	box(Vector3.new(1.5, 5, 1.5), CFrame.new(0, e.h + 1.5, 0), rgb(100, 70, 40))
	return nil
end

function BUILD.banana(box, e)
	for i = -1, 1 do
		box(
			Vector3.new((e.w or 40) / 3 + 2, e.h, e.h),
			CFrame.new(i * (e.w or 40) / 3, e.h / 2, math.abs(i) * 3)
				* CFrame.Angles(0, i * 0.35, 0),
			rgb(250, 220, 60)
		)
	end
	return nil
end

function BUILD.mug(box, e)
	local w = e.w or 20
	box(
		Vector3.new(e.h, w, w),
		CFrame.new(0, e.h / 2, 0) * UP,
		rgb(70, 130, 210),
		Enum.Material.SmoothPlastic,
		CYL
	)
	box(Vector3.new(3, e.h * 0.6, w * 0.5), CFrame.new(w / 2 + 2, e.h / 2, 0), rgb(70, 130, 210))
	return nil
end

function BUILD.toyBlock(box, e)
	box(
		Vector3.new(e.h, e.h, e.h),
		CFrame.new(0, e.h / 2, 0),
		if e.yaw > 1 then rgb(80, 160, 220) else rgb(240, 90, 80)
	)
	return nil
end

function BUILD.cuttingBoard(box, e)
	box(
		Vector3.new(e.w or 20, e.h, e.d or 110),
		CFrame.new(0, e.h / 2, 0) * CFrame.Angles(0, 0, 0.2),
		LIGHT_WOOD,
		Enum.Material.Wood
	)
	return nil
end

-- the counter run along the back wall (fridge on the left): cabinets, a top, and the secret
-- tunnel left hollow inside them along its side road
local function buildCounters(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local h, front = map.COUNTER_H, map.COUNTER_FRONT
	local back = def.minZ
	local d = front - back
	local x0 = def.minX + 190 -- right of the fridge
	local x1 = def.maxX
	local cab = rgb(176, 132, 92)
	local tunnel: { MapKit.Sample } = map.path(2)
	-- the hollow: from the first door to the last, low enough to feel like inside a cupboard
	local tx0, tx1 = math.huge, -math.huge
	for _, s in tunnel do
		if s.z < front then
			tx0, tx1 = math.min(tx0, s.x), math.max(tx1, s.x)
		end
	end
	tx0 -= 60
	tx1 += 60
	local hollowH = 80
	local function slab(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
		local p = part(folder, name, size, cf, color, mat)
		finish(p, true)
		return p
	end
	-- solid runs either side of the tunnel
	for _, r in { { x0, tx0 }, { tx1, x1 } } do
		local w = r[2] - r[1]
		if w > 1 then
			slab(
				"Counter",
				Vector3.new(w, h, d),
				CFrame.new((r[1] + r[2]) / 2, h / 2, back + d / 2),
				cab,
				Enum.Material.Wood
			)
		end
	end
	-- over the tunnel: solid above, hollow below with a back, a front (door holes) and a glow
	local tw = tx1 - tx0
	local tcx = (tx0 + tx1) / 2
	slab(
		"Counter",
		Vector3.new(tw, h - hollowH, d),
		CFrame.new(tcx, hollowH + (h - hollowH) / 2, back + d / 2),
		cab,
		Enum.Material.Wood
	)
	slab(
		"CabinetBack",
		Vector3.new(tw, hollowH, 10),
		CFrame.new(tcx, hollowH / 2, back + 5),
		rgb(120, 90, 64),
		Enum.Material.Wood
	)
	-- door holes where the tunnel crosses the front
	local holes = {}
	for i = 1, #tunnel - 1 do
		local a, b = tunnel[i], tunnel[i + 1]
		if (a.z - front) * (b.z - front) <= 0 then
			table.insert(holes, (a.x + b.x) / 2)
		end
	end
	table.sort(holes)
	local holeW = 74
	local edges = { tx0 }
	for _, hx in holes do
		table.insert(edges, hx - holeW / 2)
		table.insert(edges, hx + holeW / 2)
	end
	table.insert(edges, tx1)
	for k = 1, #edges - 1, 2 do
		local a, b = edges[k], edges[k + 1]
		if b - a > 1 then
			slab(
				"CabinetFront",
				Vector3.new(b - a, hollowH, 8),
				CFrame.new((a + b) / 2, hollowH / 2, front - 4),
				cab,
				Enum.Material.Wood
			)
		end
	end
	for _, s in { tx0, tx1 } do
		slab(
			"CabinetEnd",
			Vector3.new(8, hollowH, d),
			CFrame.new(s, hollowH / 2, back + d / 2),
			cab,
			Enum.Material.Wood
		)
	end
	-- a soft glow strip on the cupboard roof, so the inside isn't pitch dark
	local glow = part(
		folder,
		"CabinetGlow",
		Vector3.new(tw - 40, 1, 6),
		CFrame.new(tcx, hollowH - 2, back + d / 2),
		rgb(255, 230, 160),
		Enum.Material.Neon
	)
	finish(glow, false)
	-- cupboard things inside (looks), spray bottles by the back
	for i, x in { tcx - tw * 0.3, tcx - tw * 0.1, tcx + tw * 0.25 } do
		local b = part(
			folder,
			"Bottle",
			Vector3.new(14, 40, 14),
			CFrame.new(x, 20, back + 18),
			if i == 2 then rgb(60, 160, 230) else rgb(240, 120, 40),
			Enum.Material.Plastic
		)
		finish(b, false)
	end
	-- the countertop over everything, a strip of doors and handles on the front
	local top = part(
		folder,
		"CounterTop",
		Vector3.new(x1 - x0, 8, d + 12),
		CFrame.new((x0 + x1) / 2, h + 4, back + (d + 12) / 2),
		rgb(236, 232, 224),
		Enum.Material.Marble
	)
	finish(top, true)
	local n = math.floor((x1 - x0) / 132)
	for i = 0, n - 1 do
		local cx = x0 + (i + 0.5) * (x1 - x0) / n
		local hp = part(
			folder,
			"Handle",
			Vector3.new(30, 4, 4),
			CFrame.new(cx, h - 30, front + 2),
			STEEL,
			Enum.Material.Metal
		)
		finish(hp, false)
		local seam = part(
			folder,
			"DoorSeam",
			Vector3.new(2, h - 50, 1),
			CFrame.new(x0 + i * (x1 - x0) / n, (h - 50) / 2 + 40, front + 0.6),
			rgb(140, 100, 66)
		)
		finish(seam, false)
	end
	-- a toaster and a fruit bowl up on the counter (looks)
	local toaster = part(
		folder,
		"Toaster",
		Vector3.new(60, 50, 34),
		CFrame.new(-200, h + 33, back + 50),
		STEEL,
		Enum.Material.Metal
	)
	finish(toaster, false)
	local bowl = part(
		folder,
		"FruitBowl",
		Vector3.new(24, 70, 70),
		CFrame.new(500, h + 20, back + 60) * UP,
		rgb(240, 240, 240),
		nil,
		CYL
	)
	finish(bowl, false)
end

-- One prop: the Meshy model (looks) + a clear box to bump into, or its block looks.
local function buildProp(folder: Instance, e: MapKit.Prop, map: any)
	local yaw = if e.kind == "dogHouse" then MapKit.pathYaw(map, e.x, e.z) else e.yaw
	local at = CFrame.new(e.x, 0, e.z) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = e.kind
	m.Parent = folder
	local flat = e.h <= 2
	local meshName = MESH[e.kind]
	local mesh = if meshName then MeshProps.place(m, meshName, at, e.h) else nil
	local hollow: boolean? = nil
	if mesh then
		for _, d in mesh:GetDescendants() do
			if d:IsA("BasePart") then
				finish(d, false)
			end
		end
	else
		local fn = BUILD[e.kind]
		local function box(
			size: Vector3,
			cf: CFrame,
			color: Color3,
			mat: Enum.Material?,
			shape: Enum.PartType?
		): Part
			return part(m, e.kind, size, at * cf, color, mat, shape)
		end
		if fn then
			hollow = fn(box, e)
		else
			box(
				Vector3.new(e.w or e.h * 0.6, e.h, e.d or e.h * 0.6),
				CFrame.new(0, e.h / 2, 0),
				C.wall
			)
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				-- a drive-through thing's own parts are what you bump; flat looks never are
				finish(d, e.solid and hollow == true and not flat)
			end
		end
	end
	if e.solid and not hollow and not flat then
		local w, d = e.w or e.h * 0.6, e.d or e.h * 0.6
		local hit = part(m, "Hit", Vector3.new(w, e.h, d), at * CFrame.new(0, e.h / 2, 0), C.wall)
		hit.Transparency = 1
		finish(hit, true)
	end
end

-- ===== what makes it read as a giant world from the chase cam =====

-- a part nobody bumps and the wheels and camera never see

-- a blade of grass: a thin tall slab leaning out from the road, many times taller than the car
local function blade(
	parent: Instance,
	x: number,
	z: number,
	yaw: number,
	h: number,
	lean: number,
	color: Color3
)
	looks(
		parent,
		"Grass",
		Vector3.new(4, h, 1.2),
		CFrame.new(x, 0, z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(0, 0, lean)
			* CFrame.new(0, h / 2, 0),
		color,
		Enum.Material.Grass
	)
end

local BLADES = { rgb(70, 150, 56), rgb(86, 168, 62), rgb(60, 132, 50) }

local function yardEdges(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local near = MapKit.edgeSpots(map, 34, def.road / 2 + MapKit.CURB_WIDTH + 10, 5)
	for n, e in near do
		local r = Random.new(n)
		local count = if n % 3 == 0 then 3 else 2
		for b = 1, count do
			local h = r:NextNumber(26, 52)
			local dx, dz = r:NextNumber(-8, 8), r:NextNumber(-8, 8)
			-- lean away from the road (side -1 = left of the driver)
			blade(
				folder,
				e.x + dx,
				e.z + dz,
				e.yaw + r:NextNumber(-0.4, 0.4),
				h,
				-e.side * r:NextNumber(0.15, 0.45),
				BLADES[(b + n) % 3 + 1]
			)
		end
		if n % 7 == 0 then
			-- a dandelion towering over the road
			local h = r:NextNumber(80, 110)
			looks(
				folder,
				"Dandelion",
				Vector3.new(3, h, 3),
				CFrame.new(e.x, h / 2, e.z),
				rgb(96, 160, 64)
			)
			looks(
				folder,
				"Dandelion",
				Vector3.new(24, 16, 24),
				CFrame.new(e.x, h + 4, e.z),
				rgb(255, 214, 40),
				Enum.Material.Grass,
				BALL
			)
		elseif n % 11 == 5 then
			-- a clover: three round leaves on a stalk
			looks(
				folder,
				"Clover",
				Vector3.new(2, 20, 2),
				CFrame.new(e.x, 10, e.z),
				rgb(70, 140, 56)
			)
			for k = 0, 2 do
				local a = k * 2.1
				looks(
					folder,
					"Clover",
					Vector3.new(1, 16, 16),
					CFrame.new(e.x + math.cos(a) * 8, 20, e.z + math.sin(a) * 8) * UP,
					rgb(80, 160, 64),
					Enum.Material.Grass,
					CYL
				)
			end
		end
	end
	-- a taller row further out, so the far side of every bend is a wall of grass
	for n, e in MapKit.edgeSpots(map, 60, def.road / 2 + MapKit.CURB_WIDTH + 40, 8) do
		local r = Random.new(1000 + n)
		for b = 1, 2 do
			blade(
				folder,
				e.x + r:NextNumber(-12, 12),
				e.z + r:NextNumber(-12, 12),
				e.yaw + r:NextNumber(-0.6, 0.6),
				r:NextNumber(60, 95),
				-e.side * r:NextNumber(0.1, 0.3),
				BLADES[(b + n) % 3 + 1]
			)
		end
	end
end

-- giant toys and crumbs by the kitchen road (solid: they are big things on the floor)
local TOYS = { "brick", "crayon", "coin", "pea", "brick", "button", "crayon", "cereal" }
local TOY_COLORS =
	{ rgb(230, 50, 50), rgb(40, 120, 230), rgb(250, 200, 30), rgb(60, 180, 80), rgb(240, 120, 30) }

local function kitchenEdges(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for n, e in MapKit.toySpots(map) do
		local kind = TOYS[(n - 1) % #TOYS + 1]
		local color = TOY_COLORS[(n - 1) % #TOY_COLORS + 1]
		local spin = if kind == "crayon" then PI / 2 else n * 0.7 -- crayons lie along the road
		local at = CFrame.new(e.x, 0, e.z) * CFrame.Angles(0, e.yaw + spin, 0)
		local m = Instance.new("Model")
		m.Name = "Toy"
		m.Parent = folder
		local function box(
			size: Vector3,
			cf: CFrame,
			c: Color3,
			mat: Enum.Material?,
			shape: Enum.PartType?
		)
			local p = part(m, kind, size, at * cf, c, mat, shape)
			finish(p, false)
		end
		local hit: Vector3? = nil
		if kind == "brick" then
			-- a toy building brick, 4 studs on top
			box(Vector3.new(44, 26, 22), CFrame.new(0, 13, 0), color)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					box(
						Vector3.new(5, 12, 12),
						CFrame.new(sx * 11, 28, sz * 5.5) * UP,
						color,
						nil,
						CYL
					)
				end
			end
			hit = Vector3.new(44, 30, 22)
		elseif kind == "crayon" then
			box(Vector3.new(70, 10, 10), CFrame.new(0, 5, 0), color, nil, CYL)
			box(Vector3.new(12, 6, 6), CFrame.new(40, 5, 0), color, nil, CYL)
			box(Vector3.new(30, 10.4, 10.4), CFrame.new(-5, 5, 0), rgb(30, 30, 30), nil, CYL)
			hit = Vector3.new(80, 10, 10)
		elseif kind == "coin" then
			-- a real-size coin: about as big as the car
			box(
				Vector3.new(1.2, 6, 6),
				CFrame.new(0, 0.7, 0) * UP,
				rgb(200, 200, 205),
				Enum.Material.Metal,
				CYL
			)
		elseif kind == "pea" then
			box(Vector3.new(9, 9, 9), CFrame.new(0, 4.5, 0), rgb(90, 180, 60), nil, BALL)
			box(Vector3.new(8, 8, 8), CFrame.new(12, 4, 6), rgb(90, 180, 60), nil, BALL)
		elseif kind == "button" then
			box(Vector3.new(3, 22, 22), CFrame.new(0, 1.5, 0) * UP, color, nil, CYL)
			for k = 0, 3 do
				local a = k * PI / 2 + 0.78
				box(
					Vector3.new(3.4, 3, 3),
					CFrame.new(math.cos(a) * 4, 1.6, math.sin(a) * 4) * UP,
					rgb(40, 40, 40),
					nil,
					CYL
				)
			end
		else -- a cereal ring
			box(Vector3.new(6, 16, 16), CFrame.new(0, 3, 0) * UP, rgb(214, 164, 70), nil, CYL)
			box(Vector3.new(6.2, 6, 6), CFrame.new(0, 3, 0) * UP, rgb(160, 110, 40), nil, CYL)
		end
		if hit then
			local p = part(m, "Hit", hit, at * CFrame.new(0, hit.Y / 2, 0), C.wall)
			p.Transparency = 1
			finish(p, true)
		end
	end
end

-- the kitchen's walls: a tiled splash band and upper cupboards over the counters, a clock, and
-- framed drawings (shapes only, no words)
local function kitchenWalls(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local h = map.COUNTER_H
	local x0, x1 = def.minX + 190, def.maxX
	local back = def.minZ
	looks(
		folder,
		"Splash",
		Vector3.new(x1 - x0, 110, 2),
		CFrame.new((x0 + x1) / 2, h + 63, back + 1.5),
		rgb(250, 250, 248),
		Enum.Material.Marble
	)
	for x = x0 + 22, x1, 44 do
		looks(
			folder,
			"SplashLine",
			Vector3.new(1, 110, 2.4),
			CFrame.new(x, h + 63, back + 1.5),
			rgb(210, 214, 222)
		)
	end
	-- upper cupboards (not over the window or the stove's hood)
	local function cupboard(a: number, b: number)
		looks(
			folder,
			"Cupboard",
			Vector3.new(b - a, 200, 80),
			CFrame.new((a + b) / 2, 460, back + 40),
			rgb(176, 132, 92),
			Enum.Material.Wood
		)
		local n = math.max(1, math.floor((b - a) / 110))
		for i = 0, n - 1 do
			local cx = a + (i + 0.5) * (b - a) / n
			looks(
				folder,
				"CupboardHandle",
				Vector3.new(4, 30, 4),
				CFrame.new(cx + (b - a) / n * 0.35, 390, back + 82),
				STEEL,
				Enum.Material.Metal
			)
		end
	end
	cupboard(x0, -110)
	cupboard(470, x1)
	looks(
		folder,
		"Hood",
		Vector3.new(200, 60, 100),
		CFrame.new(0, 420, back + 50),
		STEEL,
		Enum.Material.Metal
	)
	-- a big round clock on the left wall, frames on the right and front walls
	local lx = def.minX + 1
	looks(
		folder,
		"Clock",
		Vector3.new(4, 110, 110),
		CFrame.new(lx + 2, 420, -80),
		C.white,
		nil,
		CYL
	)
	looks(
		folder,
		"ClockRim",
		Vector3.new(3, 120, 120),
		CFrame.new(lx + 1, 420, -80),
		rgb(200, 60, 50),
		nil,
		CYL
	)
	looks(folder, "ClockHand", Vector3.new(5, 44, 5), CFrame.new(lx + 5, 438, -80), DARK)
	looks(folder, "ClockHand", Vector3.new(5, 4, 34), CFrame.new(lx + 5, 420, -64), DARK)
	local rx = def.maxX - 1
	for i, f in { { -150, rgb(255, 200, 60) }, { 120, rgb(80, 170, 230) } } do
		looks(
			folder,
			"Frame",
			Vector3.new(3, 150, 120),
			CFrame.new(rx - 1, 380, f[1]),
			rgb(120, 80, 50),
			Enum.Material.Wood
		)
		looks(
			folder,
			"Drawing",
			Vector3.new(3.4, 130, 100),
			CFrame.new(rx - 1.2, 380, f[1]),
			rgb(252, 250, 244)
		)
		looks(
			folder,
			"Sun",
			Vector3.new(3.8, 40, 40),
			CFrame.new(rx - 1.4, 410, f[1] + 20 * i - 30),
			f[2],
			nil,
			CYL
		)
		looks(
			folder,
			"Hill",
			Vector3.new(3.8, 30, 90),
			CFrame.new(rx - 1.4, 340, f[1]),
			rgb(90, 170, 80)
		)
	end
end

-- white arrows painted on the main road, pointing the way to go: big, and closer together into
-- and round every bend, where each one points at the road a little way ahead
local ARROW_GAP, ARROW_GAP_BEND, ARROW_AIM = 150, 45, 60
local function roadArrows(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local loop: { MapKit.Sample } = map.loop()
	local n = #loop
	local bend: { [number]: boolean } = {}
	for _, t in MapKit.turns(map) do
		for i = t.from - 10, t.to do
			bend[(i - 1) % n + 1] = true
		end
	end
	local run = ARROW_GAP
	for i, a in loop do
		local b = loop[(i % n) + 1]
		if run > (if bend[i] then ARROW_GAP_BEND else ARROW_GAP) then
			local clearOf = true
			for _, g in map.gates do
				if (g.x - a.x) ^ 2 + (g.z - a.z) ^ 2 < 40 * 40 then
					clearOf = false
				end
			end
			for _, j in def.jumps do
				if (j.at.x - a.x) ^ 2 + (j.at.z - a.z) ^ 2 < 60 * 60 then
					clearOf = false
				end
			end
			for _, p in def.pads do
				if (p.at.x - a.x) ^ 2 + (p.at.z - a.z) ^ 2 < 50 * 50 then
					clearOf = false
				end
			end
			if clearOf then
				run = 0
				-- aim at the road ARROW_AIM ahead (on a straight that's straight on)
				local k, ahead = i, 0
				while ahead < ARROW_AIM and k < i + n do
					local p, q = loop[(k - 1) % n + 1], loop[k % n + 1]
					ahead += math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
					k += 1
				end
				local aim = loop[(k - 1) % n + 1]
				local pos = Vector3.new(a.x, ROAD_TOP + 0.03, a.z)
				local at = CFrame.lookAt(pos, Vector3.new(aim.x, pos.Y, aim.z))
				for _, side in { -1, 1 } do
					looks(
						folder,
						"Arrow",
						Vector3.new(20, 0.05, 4),
						at * CFrame.new(side * 7.5, 0, 0) * CFrame.Angles(0, side * 0.7, 0),
						C.white
					)
				end
			end
		end
		run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
end

-- yellow chevron boards round the outside of each bend (MapKit.turnSigns): a board on a post, two
-- black arrows on its face pointing the way the road turns
local SIGN_YELLOW = rgb(255, 205, 40)
local function turnSigns(folder: Instance, map: any)
	local w, h, low = MapKit.SIGN_W, 16, 4
	for _, sg in MapKit.turnSigns(map) do
		-- local +Z faces the oncoming car, +X is that driver's right
		local at = CFrame.new(sg.x, 0, sg.z) * CFrame.Angles(0, sg.yaw, 0)
		looks(
			folder,
			"SignPost",
			Vector3.new(2, low + h / 2, 2),
			at * CFrame.new(0, (low + h / 2) / 2, -1.5),
			DARK
		)
		looks(folder, "Sign", Vector3.new(w, h, 1), at * CFrame.new(0, low + h / 2, 0), SIGN_YELLOW)
		for _, cx in { -5, 5 } do
			for _, up in { 1, -1 } do
				-- ">" (or "<" on a left-hand bend): two bars meeting at the tip
				looks(
					folder,
					"SignArrow",
					Vector3.new(8, 2.6, 0.3),
					at
						* CFrame.new(sg.dir * cx, low + h / 2 + up * 2.6, 0.6)
						* CFrame.Angles(0, 0, -up * sg.dir * 0.65),
					DARK
				)
			end
		end
	end
end

-- white arrows on the start of the shortcut, so it's clear you can go that way
local function shortcutArrows(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for i, p in def.paths do
		if p.kind == "shortcut" then
			local ring: { MapKit.Sample } = map.path(i)
			local run, made = 0, 0
			for k = 2, #ring do
				local a, b = ring[k - 1], ring[k]
				run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
				local off = MapKit.distTo(map.loop(), b.x, b.z) > def.road / 2 + MapKit.CURB_WIDTH
				if off and run > 36 and made < 3 then
					run, made = 0, made + 1
					for _, side in { -1, 1 } do
						looks(
							folder,
							"Arrow",
							Vector3.new(10, 0.05, 2.4),
							frameAt(b, SIDE_TOP + 0.05)
								* CFrame.new(side * 3.6, 0, 0)
								* CFrame.Angles(0, side * 0.7, 0),
							C.white
						)
					end
				end
			end
		end
	end
end

-- a trail of gold coins into the secret (a hint, not a prize): the first stretch of the secret
-- road, floating where the car drives through them
local function secretHint(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	for i, p in def.paths do
		if p.kind == "secret" then
			local ring: { MapKit.Sample } = map.path(i)
			local run = 0
			for k = 2, math.floor(#ring * 0.3) do
				local a, b = ring[k - 1], ring[k]
				run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
				-- only once it has left the main road (not in the face of cars that stay on it)
				local off = MapKit.distTo(map.loop(), b.x, b.z)
					> def.road / 2 + MapKit.CURB_WIDTH + 4
				if run > 30 and off then
					run = 0
					local coin = looks(
						folder,
						"SecretCoin",
						Vector3.new(1.2, 6, 6),
						frameAt(b, 3.5) * CFrame.Angles(0, PI / 2, 0),
						rgb(255, 200, 40),
						Enum.Material.Metal,
						CYL
					)
					coin.CastShadow = false
				end
			end
			local start = ring[3]
			local spark = looks(
				folder,
				"SecretSparkle",
				Vector3.new(1, 1, 1),
				CFrame.new(start.x, 10, start.z),
				rgb(255, 230, 120)
			)
			spark.Transparency = 1
			local fx = Instance.new("Sparkles")
			fx.SparkleColor = rgb(255, 220, 90)
			fx.Parent = spark
		end
	end
end

-- ===== the driver stand (Car VS Car) =====

-- A raised wooden deck by the start: racers stand on it side by side with their remotes and
-- watch their cars. Yard: a patio deck on posts. Kitchen: a big step stool. Stairs go down off
-- its left end; a rail runs round the other three sides (low at the front, so it never hides a
-- car). Picture: rc-game/cvc/pics/*-stand.png (carter said yes 10-26).
local function buildStand(folder: Instance, map: any)
	local def: MapKit.Def = map.def
	local st = def.stand
	if not st then
		return
	end
	local kitchen = def.theme == "kitchen"
	local wood = if kitchen then LIGHT_WOOD else WOOD
	local dark = if kitchen then rgb(176, 136, 92) else rgb(110, 76, 46)
	local stand = Instance.new("Model")
	stand.Name = "DriverStand"
	stand.Parent = folder
	local x0, x1 = st.x - st.w / 2, st.x + st.w / 2
	local z0, z1 = st.z - st.d / 2, st.z + st.d / 2
	local function solid(name: string, size: Vector3, cf: CFrame, color: Color3)
		local p = part(stand, name, size, cf, color, Enum.Material.WoodPlanks)
		finish(p, true)
		return p
	end
	-- the deck
	solid("Deck", Vector3.new(st.w, 4, st.d), CFrame.new(st.x, st.h - 2, st.z), wood)
	-- legs: four posts, the stool's splay out a little
	for _, cx in { x0 + 5, x1 - 5 } do
		for _, cz in { z0 + 5, z1 - 5 } do
			local leg =
				solid("Leg", Vector3.new(8, st.h - 4, 8), CFrame.new(cx, (st.h - 4) / 2, cz), dark)
			if kitchen then
				leg.CFrame = leg.CFrame * CFrame.Angles(if cz < st.z then 0.06 else -0.06, 0, 0)
			end
		end
	end
	-- a cross bar half way up (a stool's step, a deck's brace)
	solid("Bar", Vector3.new(st.w - 10, 5, 5), CFrame.new(st.x, st.h * 0.45, z0 + 5), dark)
	solid("Bar", Vector3.new(st.w - 10, 5, 5), CFrame.new(st.x, st.h * 0.45, z1 - 5), dark)
	-- rails: front (low), back, right end; the left end is open to the stairs
	local railH = 14
	local function rail(a: Vector3, b: Vector3, h: number)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		solid(
			"Rail",
			Vector3.new(2, 2, len),
			CFrame.lookAt(mid + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0)),
			dark
		)
		for k = 0, math.floor(len / 20) do
			local q = a:Lerp(b, k / math.max(math.floor(len / 20), 1))
			solid("Post", Vector3.new(2, h, 2), CFrame.new(q.X, st.h + h / 2, q.Z), dark)
		end
	end
	local top = st.h
	rail(Vector3.new(x0 + 1, top, z0 + 1), Vector3.new(x1 - 1, top, z0 + 1), 8)
	rail(Vector3.new(x0 + 1, top, z1 - 1), Vector3.new(x1 - 1, top, z1 - 1), railH)
	rail(Vector3.new(x1 - 1, top, z0 + 1), Vector3.new(x1 - 1, top, z1 - 1), railH)
	-- stairs down off the left end: solid blocks, each a step lower
	local n = math.ceil(st.h / MapKit.STAND_STEP)
	local rise, run = st.h / n, MapKit.STAND_STAIRS / n
	for i = 1, n - 1 do
		local y = st.h - i * rise
		solid(
			"Step",
			Vector3.new(run, y, st.d * 0.6),
			CFrame.new(x0 - (i - 0.5) * run, y / 2, st.z),
			if i % 2 == 0 then wood else dark
		)
	end
	-- a yellow spot for each racer
	for _, sp in map.standSpots() do
		looks(
			stand,
			"Spot",
			Vector3.new(0.3, 12, 12),
			CFrame.new(sp.x, sp.y + 0.15, sp.z) * CFrame.Angles(0, 0, PI / 2),
			BOOST_COLOR,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
end

-- ===== one map =====

function RaceMapBuilder.buildMap(map: any): Model
	local model = Instance.new("Model")
	model.Name = map.id
	local def: MapKit.Def = map.def
	buildFloor(model, map)
	buildEdge(model, map)
	local track = Instance.new("Folder")
	track.Name = "Track"
	track.Parent = model
	buildRoad(track, map)
	buildPaths(track, map)
	buildPads(track, map)
	buildJumps(track, map)
	buildArch(model, map)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = model
	buildLines(scenery, map)
	if def.theme == "kitchen" then
		buildCounters(scenery, map)
		kitchenWalls(scenery, map)
		kitchenEdges(scenery, map)
	else
		yardEdges(scenery, map)
	end
	roadArrows(track, map)
	turnSigns(track, map)
	shortcutArrows(track, map)
	secretHint(scenery, map)
	for _, e in def.props do
		buildProp(scenery, e, map)
	end
	if Features.CVC then
		buildStand(model, map)
	end
	-- shrink to RC size and put it where the track says
	model.WorldPivot = CFrame.identity
	model:ScaleTo(TrackData.RC_SCALE)
	local t = map.track()
	model:PivotTo(CFrame.new(t.rcX, 0, t.rcZ) * CFrame.Angles(0, t.rcAngle, 0))
	return model
end

-- Every map in RaceMaps, under workspace.RaceMaps. Safe to call once at start-up.
function RaceMapBuilder.build(): Folder
	local folder = workspace:FindFirstChild("RaceMaps") :: Folder?
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "RaceMaps"
		f.Parent = workspace
		folder = f
	end
	local root = folder :: Folder
	for _, map in RaceMaps.list() do
		local old = root:FindFirstChild(map.id)
		if old then
			old:Destroy()
		end
		local ok, res = pcall(RaceMapBuilder.buildMap, map)
		if ok then
			(res :: Model).Parent = root
		else
			warn("race map " .. tostring(map.id) .. " failed to build: " .. tostring(res))
		end
	end
	return root
end

return RaceMapBuilder
