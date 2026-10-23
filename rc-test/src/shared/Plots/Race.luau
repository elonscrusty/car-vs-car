--!strict
-- RACE plot: a twisty lap from the plot picture (plot-race.png). Start / finish on the front
-- straight, a chicane on the right, a big right sweeper, a hairpin at the back, then the long
-- left straight home. Lap timer: gate 1 is the checkered line, then chicane, sweeper, hairpin,
-- left straight, and back over the line = one lap.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Kit = sibling("Kit")
local C = Kit.COLORS

local ROAD = 30 -- same road width as the race test carter liked
local CURB_WIDTH = 3
local CURB_HEIGHT = 0.4 -- low enough to drive over

-- Colours that tell road, edge and grass apart at a glance.
local function rgb(r: number, g: number, b: number): Color3
	local c: any = Color3
	return if c then c.fromRGB(r, g, b) else nil :: any
end
local ROAD_COLOR = rgb(52, 52, 58)
local GRASS_COLOR = rgb(86, 150, 70)

-- The picture is 120 wide, 160 deep, (0, 0) at the front left. Its numbers become plot spots:
-- picture x 60 is the plot middle, picture y 34 (the start straight) sits near the front.
local K = 2.6
local function spot(px: number, py: number): Kit.Pt
	return { x = (px - 60) * K, z = 115 - (py - 34) * K }
end

-- Driving order (the arrows in the picture).
local PICTURE = {
	{ 28, 34 }, -- front straight, the line is a bit further on
	{ 92, 34 },
	{ 108, 48 },
	{ 100, 64 },
	{ 78, 70 }, -- chicane: hard left
	{ 70, 82 },
	{ 92, 92 }, -- and back right
	{ 108, 108 },
	{ 106, 140 }, -- big right sweeper
	{ 88, 152 },
	{ 70, 140 },
	{ 56, 118 }, -- hairpin
	{ 42, 140 },
	{ 24, 152 },
	{ 12, 134 },
	{ 14, 90 }, -- long left straight home
	{ 20, 58 },
}
local POINTS: { Kit.Pt } = {}
for i, p in PICTURE do
	POINTS[i] = spot(p[1], p[2])
end

local Plot = {}
Plot.id = "race"
Plot.label = "RACE"
Plot.mode = "loop"
Plot.grip = 0.75 -- off the road is slower
Plot.ROAD = ROAD
Plot.CURB_WIDTH = CURB_WIDTH
Plot.GRASS_DRAG = 0.5 -- extra rolling drag on the grass (the car reads the "Drag" attribute)

function Plot.loop(): { Kit.Sample }
	return Kit.loop(POINTS, 8)
end

-- The sample closest to a picture spot.
local function nearest(ring: { Kit.Sample }, px: number, py: number): Kit.Sample
	local p = spot(px, py)
	local best, bestD = ring[1], math.huge
	for _, s in ring do
		local dx, dz = s.x - p.x, s.z - p.z
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = s, d
		end
	end
	return best
end

local ring = Plot.loop()
local line = nearest(ring, 47.5, 34) -- the checkered line
Plot.spawn = Kit.spawnAt(line, 14)
Plot.gates = {
	Kit.gateAt(line, 0, 22, 6),
	Kit.gateAt(nearest(ring, 72, 76), 0, 24, 12), -- chicane
	Kit.gateAt(nearest(ring, 108, 120), 0, 24, 12), -- sweeper
	Kit.gateAt(nearest(ring, 56, 118), 0, 24, 12), -- hairpin
	Kit.gateAt(nearest(ring, 14, 100), 0, 24, 12), -- left straight
}

-- ===== Looks (no effect on driving) =====
-- Everything below is scenery off the road. Things you can bump into stay at least
-- Plot.DECOR_CLEAR from the road centre line (runoff stays grass); the rest (flags, the start
-- light, paint) don't collide and the wheels don't see them. Meshy models from
-- ServerStorage.LobbyMeshes are used when imported, block stand-ins otherwise.

export type Decor = {
	kind: string, -- see the builders in buildDecor
	x: number,
	z: number,
	yaw: number, -- 0 = front looks to -Z (the back), math.pi = front looks at the stand
	h: number, -- height, big studs
	solid: boolean, -- can the car bump it?
	w: number?, -- footprint width (grandstand, tent)
	d: number?, -- footprint depth
	meshH: number?, -- tallest the Meshy model may be (it fills the footprint up to this)
}

Plot.DECOR_CLEAR = 30 -- solid scenery keeps this far from the road centre (curb edge is 18)
Plot.ARCH_WIDTH = 50
Plot.ARCH_HEIGHT = 24

local PI = math.pi
local function decor(
	kind: string,
	x: number,
	z: number,
	yaw: number,
	h: number,
	solid: boolean,
	w: number?,
	d: number?,
	meshH: number?
): Decor
	return {
		kind = kind,
		x = x,
		z = z,
		yaw = yaw,
		h = h,
		solid = solid,
		w = w,
		d = d,
		meshH = meshH,
	}
end

local DECOR: { Decor } = {
	-- grandstand in the infield, facing the main straight and the driver stand
	decor("grandstand", -20, 66, PI, 12, true, 70, 24, 22),
	decor("speaker", -60, 64, PI, 7, true),
	decor("speaker", 20, 64, PI, 7, true),
	decor("startLight", -70, 90, PI, 10, false),
	-- pit corner in the pocket right of the chicane
	decor("tent", 130, 0, -PI / 2, 12, true, 20, 20, 18),
	decor("wheelRack", 150, 12, -PI / 2, 6, true),
	decor("toolbox", 150, -8, -PI / 2, 3, true),
	decor("gasCan", 112, 2, 0.4, 2.5, true),
	-- race control tower in the V behind the hairpin, with a windsock
	decor("tower", -8, -196, PI, 30, true, 20, 20, 44),
	decor("windsock", 18, -210, PI, 16, false),
	-- trees: leafy ones in the infield, pines in the back corners
	decor("leafyTree", -78, -72, 0.3, 18, true),
	decor("leafyTree", -75, -40, 1.1, 16, true),
	decor("leafyTree", -50, -10, 2.0, 18, true),
	decor("leafyTree", -72, 8, 2.7, 15, true),
	decor("leafyTree", -20, -40, 0.8, 17, true),
	decor("leafyTree", -60, 40, 1.7, 15, true),
	decor("leafyTree", -30, 26, 0.5, 14, true),
	decor("pineTree", -144, -205, 0.2, 22, true),
	decor("pineTree", 142, -204, 1.4, 26, true),
	decor("pineTree", -34, -204, 2.4, 22, true),
	decor("bush", 144, 134, 0, 5, true),
	decor("bush", -144, 134, 1, 5, true),
	decor("bush", 0, 44, 2, 5, true),
}
-- tyre wall round the outside of the hairpin (out in the infield grass)
for i = 0, 6 do
	local a = -0.9 + 1.8 * i / 6
	table.insert(DECOR, decor("tires", -10 + 46 * math.sin(a), -108 + 46 * math.cos(a), a, 5, true))
end
-- flags on the outer walls: red on the left, blue on the right, yellow at the back
-- (each flag turned to face the middle of the plot, so its cloth reads from inside the track)
local function inward(x: number, z: number): number
	return math.atan2(x, z) -- yaw whose front looks from (x, z) towards (0, 0)
end
for z = -180, 120, 60 do
	table.insert(DECOR, decor("flag", -153, z, inward(-153, z), 14, false))
	table.insert(DECOR, decor("blueFlag", 153, z, inward(153, z), 14, false))
end
for x = -120, 120, 60 do
	table.insert(DECOR, decor("flag", x, -213, inward(x, -213), 14, false))
end
Plot.DECOR = DECOR

-- Meshy model for each kind (ServerStorage.LobbyMeshes). Grandstand, PitTent and MarshalTower
-- are on carter's list; until they exist the blocks below stand in.
local MESH: { [string]: string } = {
	grandstand = "Grandstand",
	tent = "PitTent",
	tower = "MarshalTower",
	speaker = "Speaker",
	startLight = "StartLight",
	wheelRack = "WheelRack",
	toolbox = "Toolbox",
	gasCan = "GasCan",
	windsock = "Windsock",
	leafyTree = "LeafyTree",
	pineTree = "PineTree",
	bush = "Bush",
	tires = "TireStack",
	flag = "Flag",
	blueFlag = "BlueFlag",
}
Plot.DECOR_MESH = MESH
-- Meshy models whose front is the other way round from the rest (carter saw them backwards).
local MESH_TURN: { [string]: number } = {
	grandstand = PI, -- seats face the main straight and the stand
}

local function setSolid(m: Instance, solid: boolean)
	local all = m:GetDescendants()
	table.insert(all, m)
	for _, p in all do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = solid
			p.CanQuery = solid -- the wheels and the camera ignore what you can't bump
			p.CanTouch = false
		end
	end
end

-- A copy of a Meshy model standing at `at`, `h` tall, or with a footprint (w wide, d deep) as
-- big as fits in w x d and at most h tall. nil when it isn't imported. Import 3D brings models
-- in huge with the front at +Z.
local function meshProp(
	parent: Instance,
	name: string,
	at: CFrame,
	h: number,
	w: number?,
	d: number?
): Model?
	local folder = game:GetService("ServerStorage"):FindFirstChild("LobbyMeshes")
	local t = folder and folder:FindFirstChild(name)
	if not t or not (t:IsA("Model") or t:IsA("BasePart")) then
		return nil
	end
	local m: Model
	if t:IsA("Model") then
		m = t:Clone()
	else
		m = Instance.new("Model")
		m.Name = name
		local part = (t :: BasePart):Clone()
		part.Parent = m
		m.PrimaryPart = part
	end
	local _, size = m:GetBoundingBox()
	if size.Y > 0 then
		local k = h / size.Y
		if w and d and size.X > 0 and size.Z > 0 then
			k = math.min(k, w / size.X, d / size.Z)
		end
		m:ScaleTo(m:GetScale() * k)
	end
	local box, sized = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, sized.Y / 2, 0))
		* CFrame.Angles(0, PI, 0)
	m:PivotTo(at)
	m.Parent = parent
	return m
end

-- Block stand-ins, built in a model at the spot (local: front = -Z, floor at y = 0).
local function blocks(parent: Instance, e: Decor, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = e.kind
	m.Parent = parent
	local function box(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
		local p = Kit.part(m, e.kind, at, size, cf, color)
		if shape then
			p.Shape = shape
		end
		return p
	end
	local h = e.h
	local w, d = e.w or 4, e.d or 4
	local wood = rgb(140, 100, 64)
	local leaf = rgb(70, 140, 60)
	local dark = rgb(40, 40, 44)
	if e.kind == "grandstand" then
		-- four tiers of seats rising to the back, blue and white rows, a back wall
		local tiers = 4
		local rise, run = h / (tiers + 1), d / tiers
		for i = 1, tiers do
			local z = d / 2 - (i - 0.5) * run
			box(Vector3.new(w, rise * i, run), CFrame.new(0, rise * i / 2, -z), C.wall)
			box(
				Vector3.new(w - 2, 0.6, run * 0.5),
				CFrame.new(0, rise * i + 0.3, -z + run * 0.15),
				if i % 2 == 0 then C.white else C.blue
			)
		end
		box(Vector3.new(w, h, 1.5), CFrame.new(0, h / 2, d / 2 - 0.75), C.wall)
		for _, sx in { -1, 1 } do
			box(Vector3.new(1.5, h, d), CFrame.new(sx * (w / 2 - 0.75), h / 2, 0), C.wall)
		end
	elseif e.kind == "tent" then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(
					Vector3.new(0.8, h - 2, 0.8),
					CFrame.new(sx * (w / 2 - 1), (h - 2) / 2, sz * (d / 2 - 1)),
					C.white
				)
			end
		end
		box(Vector3.new(w, 1, d), CFrame.new(0, h - 1.5, 0), C.red)
		box(Vector3.new(w * 0.6, 1, d * 0.6), CFrame.new(0, h - 0.5, 0), C.white)
		box(Vector3.new(w - 4, 3, 3), CFrame.new(0, 1.5, d / 2 - 3), wood) -- bench
	elseif e.kind == "tower" then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(
					Vector3.new(1.2, h - 8, 1.2),
					CFrame.new(sx * (w / 2 - 1), (h - 8) / 2, sz * (d / 2 - 1)),
					C.wall
				)
			end
		end
		box(Vector3.new(w, 6, d), CFrame.new(0, h - 5, 0), C.white)
		box(Vector3.new(w - 1, 2, 0.4), CFrame.new(0, h - 4, -d / 2 - 0.1), C.blue) -- window
		box(Vector3.new(w + 2, 1, d + 2), CFrame.new(0, h - 1.5, 0), C.red)
		for i = 1, 6 do -- ladder
			box(Vector3.new(3, 0.4, 0.4), CFrame.new(0, i * (h - 8) / 7, d / 2 + 0.6), C.wall)
		end
	elseif e.kind == "leafyTree" then
		box(Vector3.new(h * 0.12, h * 0.5, h * 0.12), CFrame.new(0, h * 0.25, 0), wood)
		box(
			Vector3.new(h * 0.6, h * 0.6, h * 0.6),
			CFrame.new(0, h * 0.68, 0),
			leaf,
			Enum.PartType.Ball
		)
	elseif e.kind == "pineTree" then
		box(Vector3.new(h * 0.08, h * 0.3, h * 0.08), CFrame.new(0, h * 0.15, 0), wood)
		for i = 0, 2 do
			local s = h * (0.42 - i * 0.11)
			box(
				Vector3.new(s, h * 0.28, s),
				CFrame.new(0, h * (0.32 + i * 0.22), 0),
				rgb(40, 100, 55)
			)
		end
	elseif e.kind == "bush" then
		box(Vector3.new(h * 1.6, h, h * 1.6), CFrame.new(0, h / 2, 0), leaf, Enum.PartType.Ball)
	elseif e.kind == "tires" then
		for i = 0, 2 do
			box(
				Vector3.new(h / 3, 4, 4),
				CFrame.new(0, h / 6 + i * h / 3, 0) * CFrame.Angles(0, 0, PI / 2),
				dark,
				Enum.PartType.Cylinder
			)
		end
	elseif e.kind == "flag" or e.kind == "blueFlag" or e.kind == "windsock" then
		box(Vector3.new(0.5, h, 0.5), CFrame.new(0, h / 2, 0), C.wall)
		local color = if e.kind == "blueFlag"
			then C.blue
			elseif e.kind == "flag" then C.red
			else C.orange
		box(Vector3.new(0.2, h * 0.3, h * 0.4), CFrame.new(0, h * 0.82, h * 0.2), color)
	elseif e.kind == "startLight" then
		box(Vector3.new(0.6, h, 0.6), CFrame.new(0, h / 2, 0), dark)
		box(Vector3.new(5, 2, 1), CFrame.new(0, h - 1, 0), dark)
		for i = -1, 1 do
			local lamp = box(
				Vector3.new(1.2, 1.2, 0.4),
				CFrame.new(i * 1.6, h - 1, -0.6),
				if i < 0 then C.red elseif i == 0 then C.orange else rgb(60, 200, 80)
			)
			lamp.Material = Enum.Material.Neon
		end
	else -- speaker, wheel rack, toolbox, gas can: a plain crate of the right size
		box(Vector3.new(h * 0.7, h, h * 0.7), CFrame.new(0, h / 2, 0), dark)
	end
	return m
end

-- The start / finish arch over the line: blue posts out on the grass past the curbs, a
-- checker beam high over the road. Always blocks: the FinishArch model's wide feet land on
-- the curbs at this size.
function Plot.archPostInner(): number
	return Plot.ARCH_WIDTH / 2 - 3 -- inner face of a post, from the road centre
end

local function buildArch(parent: Instance, origin: CFrame)
	local g = Plot.gates[1]
	local yaw = math.atan2(-g.dx, -g.dz) -- front looks along the road
	local at = origin * CFrame.new(g.x, 0, g.z) * CFrame.Angles(0, yaw, 0)
	local arch = Instance.new("Model")
	arch.Name = "FinishArch"
	arch.Parent = parent
	local w, h = Plot.ARCH_WIDTH, Plot.ARCH_HEIGHT
	local inner = Plot.archPostInner()
	for _, s in { -1, 1 } do
		-- post (3 thick) and a wider foot, both starting at `inner` and going outwards
		Kit.part(
			arch,
			"ArchPost",
			at,
			Vector3.new(3, h, 3),
			CFrame.new(s * (inner + 1.5), h / 2, 0),
			C.blue
		)
		-- the foot wraps the post's bottom (bigger on every side, so no faces share a plane)
		Kit.part(
			arch,
			"ArchFoot",
			at,
			Vector3.new(4.6, 3, 6),
			CFrame.new(s * (inner + 1.5), 1.5, 0),
			C.blue
		)
	end
	-- the beam runs between the posts' inner faces (it used to run into them and flicker)
	local span = 2 * inner
	local cells = 10
	for row = 0, 1 do
		for i = 0, cells - 1 do
			Kit.part(
				arch,
				"ArchBeam",
				at,
				Vector3.new(span / cells, 2, 1.5),
				CFrame.new((i + 0.5) * span / cells - span / 2, h - 1 - row * 2, 0),
				if (i + row) % 2 == 0 then C.white else rgb(30, 30, 34)
			)
		end
	end
	setSolid(arch, true)
end

-- Paint on the road: a dashed white centre line and two grid boxes behind the start line.
local function buildPaint(parent: Instance, origin: CFrame, loop: { Kit.Sample })
	local paint: { Part } = {}
	for i = 1, #loop, 2 do
		local s = loop[i]
		local g = Plot.gates[1]
		local dx, dz = s.x - g.x, s.z - g.z
		if dx * dx + dz * dz > 20 * 20 then -- not over the checkers
			local p = Kit.line(parent, origin, s.x, 0, s.z, -s.tz, s.tx, 5, C.white)
			p.Size = Vector3.new(5, 0.1, 0.8) -- along the road: 5 long, thin
			table.insert(paint, p)
		end
	end
	local g = Plot.gates[1]
	local rx, rz = -g.dz, g.dx
	for slot = 1, 2 do
		local back = 12 + (slot - 1) * 14
		local side = if slot == 1 then -7 else 7
		local cx, cz = g.x - g.dx * back + rx * side, g.z - g.dz * back + rz * side
		-- a "[" shape: front bar across, two short side bars
		table.insert(
			paint,
			Kit.line(parent, origin, cx + g.dx * 4, 0, cz + g.dz * 4, g.dx, g.dz, 8, C.white)
		)
		for _, sd in { -1, 1 } do
			local p = Kit.line(
				parent,
				origin,
				cx + rx * sd * 4,
				0,
				cz + rz * sd * 4,
				-g.dz,
				g.dx,
				8,
				C.white
			)
			p.Size = Vector3.new(8, 0.1, 0.8)
			table.insert(paint, p)
		end
	end
	for _, p in paint do
		p.CanQuery = false
		p.CanTouch = false
	end
end

local function buildDecor(parent: Instance, origin: CFrame, loop: { Kit.Sample })
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent
	for _, e in Plot.DECOR do
		local at = origin * CFrame.new(e.x, 0, e.z) * CFrame.Angles(0, e.yaw, 0)
		local name = MESH[e.kind]
		local m: Instance? = nil
		if name then
			local turn = MESH_TURN[e.kind] or 0
			m = meshProp(folder, name, at * CFrame.Angles(0, turn, 0), e.meshH or e.h, e.w, e.d)
		end
		if not m then
			m = blocks(folder, e, at)
		end
		setSolid(m :: Instance, e.solid)
	end
	buildArch(folder, origin)
	buildPaint(folder, origin, loop)
end

function Plot.build(parent: Instance, origin: CFrame)
	-- Grass over the whole track area (drivable, just slower), under the road.
	local a = Kit.AREA
	local grass = Kit.part(
		parent,
		"Grass",
		origin,
		Vector3.new(a.maxX - a.minX, 0.04, a.maxZ - a.minZ),
		CFrame.new((a.minX + a.maxX) / 2, 0.02, (a.minZ + a.maxZ) / 2),
		GRASS_COLOR
	)
	grass:SetAttribute("Grip", Plot.grip)
	grass:SetAttribute("Drag", Plot.GRASS_DRAG) -- the car slows down on it
	grass.Material = Enum.Material.Grass

	local loop = Plot.loop()
	Kit.ribbon(parent, origin, loop, ROAD, { grip = 1, color = ROAD_COLOR })
	-- A flat round patch of road at every joint fills the little wedges the straight road pieces
	-- leave on the outside of bends (the grass showed through there). Same height and grip.
	for _, s in loop do
		local patch = Kit.disc(parent, "Road", origin, s.x, 0.05, s.z, ROAD / 2, 0.1, ROAD_COLOR)
		patch:SetAttribute("Grip", 1)
	end

	-- Low red and white curbs on both edges instead of walls.
	local n = #loop
	local off = ROAD / 2 + CURB_WIDTH / 2
	for i = 1, n do
		local p, q = loop[i], loop[(i % n) + 1]
		local color = if i % 2 == 0 then C.white else C.red
		for _, side in { -1, 1 } do
			local o = off * side
			local pa = Vector3.new(p.x - p.tz * o, CURB_HEIGHT / 2, p.z + p.tx * o)
			local pb = Vector3.new(q.x - q.tz * o, CURB_HEIGHT / 2, q.z + q.tx * o)
			local curb =
				Kit.slab(parent, "Curb", origin, pa, pb, CURB_WIDTH, CURB_HEIGHT, 0.5, color)
			curb:SetAttribute("Grip", 1)
		end
	end

	-- Checkered start / finish: two rows of squares across the road.
	local g = Plot.gates[1]
	local rx, rz = -g.dz, g.dx -- across the road
	local cells = 6
	local size = ROAD / cells
	for row = 0, 1 do
		for i = 0, cells - 1 do
			local across = (i + 0.5) * size - ROAD / 2
			local along = (row - 0.5) * 3
			local color = if (i + row) % 2 == 0 then C.white else ROAD_COLOR
			Kit.line(
				parent,
				origin,
				g.x + rx * across + g.dx * along,
				0,
				g.z + rz * across + g.dz * along,
				g.dx,
				g.dz,
				size,
				color
			)
		end
	end

	buildDecor(parent, origin, loop)
end

return Plot
