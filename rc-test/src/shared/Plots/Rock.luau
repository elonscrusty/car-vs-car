--!strict
-- ROCK plot: a hill that rises like stadium steps facing the driver stand, so the whole crawl can
-- be watched from the stand. The trail zigzags up it in five rows: grass and bumpy mounds at the
-- front, a boulder creek, a low shelf, a high shelf, then a steep rock slab up to the flag.
--
-- The ground is one smooth sheet of triangles (two wedges each) that share edges exactly: no
-- gaps, no lips, and no two parts lie flat on top of each other, so nothing flickers. Each row
-- of the trail is a shelf; behind it the ground steps up to the next row, so every row sits
-- higher than the one in front and nothing hides the car. Grass slows the car down.

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

type Pt = { x: number, z: number }
type Sample = { x: number, z: number, tx: number, tz: number }
type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	halfWidth: number,
	depth: number,
}

-- Something on the trail. `u` is how far along (1 = start point, see PICTURE), `side` is across
-- the trail (-1 = left edge, 1 = right edge), `lift` is how high its top sits above the trail.
export type Feature = {
	kind: string, -- "rock", "ledge" or "log"
	u: number,
	side: number,
	r: number, -- rock radius, log radius, ledge length
	lift: number,
}

local ROAD = 34 -- trail width (8.5 studs at RC size)
local HALF = ROAD / 2
local PER = 10 -- samples between two points
local CELL = 10 -- ground triangle size (2.5 studs at RC size)

local Plot = {}
Plot.id = "rock"
Plot.label = "ROCKS"
Plot.mode = "oneway"
Plot.grip = 1
Plot.ROAD = ROAD
Plot.HALF_WIDTH = HALF
Plot.CELL = CELL
Plot.GRASS_DRAG = 4 -- extra rolling drag on the grass (the car reads the "Drag" attribute); high,
-- because drag grows with speed and the crawler is slow
Plot.RIM = 10 -- the rock wall round the back and sides stands this high above the ground
Plot.FRONT_RIM = 3 -- and this high along the front, under the stand's view
Plot.GRASS_TOP = 14 -- ground below this height (off the trail) is grass, higher is rock
-- Highest bump the car can crawl over.
Plot.MAX_LIFT = 1.6
-- The person's eyes on the driver stand (see Main.client: stand top + 4.5 studs at RC size).
Plot.EYE = { x = Kit.STAND.x, y = Kit.STAND_H + 18, z = Kit.STAND.z }

-- The trail, front (start) to back (flag), from the approved picture plot-rock-v3.png. Picture
-- spots are studs at RC size from the front-left corner; the third number is the trail height.
local PICTURE = {
	{ 8, 25, 0.4 }, -- 1 start
	{ 24, 27, 0.9 },
	{ 40, 25, 0.6 }, -- 3 big boulders, right in front of the stand
	{ 56, 28, 1.1 },
	{ 68, 27, 0.8 },
	{ 72, 36, 1.0 }, -- 6 turn 1
	{ 66, 45, 1.0 }, -- boulder creek
	{ 48, 44, 1.0 },
	{ 30, 45, 1.0 },
	{ 14, 44, 1.2 },
	{ 9, 54, 2.6 }, -- 11 turn 2
	{ 14, 63, 3.2 }, -- low shelf
	{ 32, 62, 4.0 },
	{ 50, 63, 4.8 },
	{ 66, 62, 5.6 },
	{ 72, 71, 6.6 }, -- 16 turn 3
	{ 66, 80, 7.4 }, -- high shelf
	{ 48, 79, 8.4 },
	{ 30, 80, 9.4 },
	{ 16, 79, 10.0 },
	{ 9.5, 88, 11.4 }, -- 21 turn 4
	{ 18, 96, 12.2 },
	{ 32, 97.5, 13.2 }, -- 23 to 24: the steep rock slab, dead straight
	{ 46, 99, 17.0 }, -- 24 top of the slab: finish and flag
	{ 60, 100.5, 17.0 }, -- 25 flat summit (keeps the slab evenly steep to the top)
}

local POINTS: { Pt } = {}
local HEIGHTS: { number } = {}
for i, p in PICTURE do
	-- picture studs -> big plot-local units (x across, z toward the front, 4x bigger)
	POINTS[i] = { x = (p[1] - 40) * 4, z = (55 - p[2]) * 4 }
	HEIGHTS[i] = p[3] * 4
end
Plot.POINTS = POINTS
Plot.LAST_U = #POINTS
Plot.TURNS = { 6, 11, 16, 21 }

-- Trail height at u (straight line between the points' heights).
function Plot.height(u: number): number
	local i = math.clamp(math.floor(u), 1, #HEIGHTS - 1)
	local t = math.clamp(u - i, 0, 1)
	return HEIGHTS[i] + (HEIGHTS[i + 1] - HEIGHTS[i]) * t
end

local cachedPath: { Sample }? = nil

-- The trail centre line, PER samples per point (sample i sits at u = 1 + (i - 1) / PER).
function Plot.path(): { Sample }
	local p = cachedPath
	if p == nil then
		p = Kit.path(POINTS, PER)
		cachedPath = p
	end
	return p :: { Sample }
end

function Plot.uOf(index: number): number
	return 1 + (index - 1) / PER
end

-- Trail spot at u: centre x, z, height, and the forward direction.
function Plot.at(u: number): (number, number, number, number, number)
	local path = Plot.path()
	local f = math.clamp((u - 1) * PER + 1, 1, #path)
	local i = math.min(math.floor(f), #path - 1)
	local t = f - i
	local a, b = path[i], path[i + 1]
	return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, Plot.height(u), a.tx, a.tz
end

-- Plot-local spot of something at u, `side` across the trail (-1 left .. 1 right).
function Plot.spot(u: number, side: number): (number, number, number)
	local x, z, h, tx, tz = Plot.at(u)
	local off = side * HALF
	-- right of forward (tx, tz) is (-tz, tx)
	return x - tz * off, z + tx * off, h
end

-- Low mounds in the grass at the front (same every time: tiny seeded random).
local MOUNDS: { { x: number, z: number, r: number, h: number } } = {}
do
	local seed = 4242
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, 30 do
		MOUNDS[#MOUNDS + 1] = {
			x = (rand() * 58 + 12 - 40) * 4,
			z = (55 - (rand() * 12 + 21)) * 4,
			r = 10.4,
			h = (rand() * 0.6 + 0.3) * 4,
		}
	end
end

-- Distance from (x, z) to the trail centre line, and the trail height at the closest sample.
-- Also: is the spot in front of (closer to the stand than) that sample, and the trail height
-- of the closest sample that is in front of the spot (the row below), or nil if none.
function Plot.nearest(x: number, z: number): (number, number, boolean, number?)
	local path = Plot.path()
	local best, bestI = math.huge, 1
	local front, frontI = math.huge, nil
	for i, s in path do
		local dx, dz = s.x - x, s.z - z
		local d = dx * dx + dz * dz
		if d < best then
			best, bestI = d, i
		end
		if s.z > z + HALF and d < front then
			front, frontI = d, i
		end
	end
	local below = if frontI then Plot.height(Plot.uOf(frontI)) else nil
	return math.sqrt(best), Plot.height(Plot.uOf(bestI)), z > path[bestI].z, below
end

Plot.SHOULDER = 6 -- flat ground beside the trail before the rock face drops away
Plot.FACE = 1.5 -- steepness of the rock faces down to the row below (too steep to drive up)
Plot.LOWEST = 1.6 -- the ground never goes lower than this (stays clear of the plot floor)

-- Ground height anywhere on the plot. Behind each row its shelf carries on flat up to the next
-- row's rock face. In front of a row the ground drops away down a steep rock face to the row
-- below, so the shelf never hides the car from the stand. Mounds bump up the low grass.
function Plot.groundAt(x: number, z: number): number
	local d, h, inFront, below = Plot.nearest(x, z)
	local edge = HALF + Plot.SHOULDER
	if inFront and d > edge then
		h = math.max(h - Plot.FACE * (d - edge), below or Plot.LOWEST)
	end
	if d > HALF then
		local away = math.clamp((d - HALF) / 32, 0, 1)
		for _, m in MOUNDS do
			local mx, mz = (x - m.x) / m.r, (z - m.z) / m.r
			h += m.h * away * math.exp(-(mx * mx + mz * mz))
		end
	end
	return math.max(h, Plot.LOWEST)
end

-- Corner heights of the ground grid. It covers the whole plot inside the outer walls (so there
-- is no gap at the walls to fall into), from the back wall up to the low wall in front of the
-- stand. grid[i][j] sits at x = x0 + (i - 1) * dx, z = z0 + (j - 1) * dz.
local cachedGrid: { { number } }? = nil
function Plot.grid(): ({ { number } }, number, number, number, number, number, number)
	local x0, x1 = -Kit.WIDTH / 2 + 1, Kit.WIDTH / 2 - 1
	local z0, z1 = -Kit.DEPTH / 2 + 1, Kit.FRONT_Z - 1
	local nx = math.ceil((x1 - x0) / CELL) + 1
	local nz = math.ceil((z1 - z0) / CELL) + 1
	local dx, dz = (x1 - x0) / (nx - 1), (z1 - z0) / (nz - 1)
	local g = cachedGrid
	if g == nil then
		g = {}
		for i = 1, nx do
			local col = {}
			for j = 1, nz do
				col[j] = Plot.groundAt(x0 + (i - 1) * dx, z0 + (j - 1) * dz)
			end
			g[i] = col
		end
		cachedGrid = g
	end
	return g :: { { number } }, x0, z0, nx, nz, dx, dz
end

-- Can the person on the stand see the top of the car at this trail spot? Walks the line of
-- sight over the ground.
function Plot.canSee(x: number, z: number, h: number): boolean
	local e = Plot.EYE
	local top = h + 2.8
	for k = 1, 60 do
		local f = 0.08 + 0.85 * k / 60
		local px, pz = e.x + (x - e.x) * f, e.z + (z - e.z) * f
		if pz < Kit.AREA.maxZ and Plot.groundAt(px, pz) > e.y + (top - e.y) * f + 0.2 then
			return false
		end
	end
	return true
end

local function rock(u: number, side: number, r: number, lift: number): Feature
	return { kind = "rock", u = u, side = side, r = r, lift = lift }
end
local function ledge(u: number, side: number, lift: number): Feature
	return { kind = "ledge", u = u, side = side, r = 8, lift = lift }
end
local function log(u: number, r: number): Feature
	return { kind = "log", u = u, side = 0, r = r, lift = r * 1.5 }
end

-- Everything on the trail, start to flag. Rocks come in left/right pairs a little apart, so one
-- side of the car climbs while the other drops. The steep slab is kept clear.
Plot.features = {
	-- row 1: grass and mounds, and two big boulders right in front of the stand
	rock(1.8, -0.35, 2.2, 1.0),
	rock(2.2, 0.3, 2.4, 1.1),
	rock(2.85, 0.3, 9, 1.6), -- big boulder: watch the springs up close
	rock(3.25, -0.35, 8, 1.5), -- big boulder, the other side
	rock(4.0, -0.4, 2.6, 1.3),
	rock(4.4, 0.4, 2.4, 1.2),
	ledge(4.75, 0.5, 0.9),
	-- turn 1
	rock(5.6, -0.5, 2.0, 0.9),
	rock(6.4, 0.5, 2.2, 1.0),
	-- row 2: the boulder creek
	rock(7.3, -0.4, 2.4, 1.2),
	rock(7.6, 0.35, 2.4, 1.3),
	log(8.1, 0.9),
	rock(8.6, 0.4, 2.8, 1.4),
	rock(8.9, -0.3, 2.6, 1.3),
	rock(9.3, 0.1, 2.2, 1.0),
	rock(9.7, -0.45, 2.4, 1.2),
	rock(10.1, 0.4, 2.4, 1.2),
	-- turn 2
	rock(10.8, 0.45, 1.8, 0.8),
	rock(11.3, -0.4, 1.8, 0.8),
	-- row 3: the low shelf
	rock(12.3, -0.4, 2.4, 1.2),
	rock(12.6, 0.4, 2.6, 1.4),
	ledge(13.1, -0.5, 1.0),
	rock(13.6, 0.45, 2.6, 1.5),
	rock(13.9, -0.45, 2.6, 1.5),
	log(14.5, 1.0),
	-- turn 3
	rock(15.7, 0.5, 2.0, 0.9),
	rock(16.4, -0.5, 2.0, 0.9),
	-- row 4: the high shelf
	ledge(17.3, 0.5, 1.2),
	rock(17.8, -0.35, 2.6, 1.4),
	rock(18.1, 0.4, 2.6, 1.5),
	rock(18.6, -0.4, 2.4, 1.3),
	rock(19.0, 0.4, 2.4, 1.3),
	log(19.5, 1.0),
	-- turn 4
	rock(20.6, -0.45, 1.8, 0.8),
	rock(21.3, 0.45, 1.8, 0.8),
} :: { Feature }

-- Start a little in front of the first point, facing along the trail, just above the ground.
local path = Plot.path()
Plot.spawn = Kit.spawnAt(path[1], -10)
Plot.spawn.y = Plot.height(1) + 2.5
Plot.START_U = 1.5
Plot.FINISH_U = 24.3
Plot.FLAG_U = 24.5

local function gate(u: number, depth: number): Gate
	local x, z, h, tx, tz = Plot.at(u)
	return { x = x, y = h, z = z, dx = tx, dz = tz, halfWidth = HALF + 6, depth = depth }
end

-- Start, a checkpoint in every turn (so cutting across the hill doesn't count), finish at the flag.
Plot.gates = { gate(Plot.START_U, 4) }
for _, u in Plot.TURNS do
	table.insert(Plot.gates, gate(u, 8))
end
table.insert(Plot.gates, gate(Plot.FINISH_U, 6))

-- ===== Building (Roblox only) =====

type Look = { name: string, color: Color3, material: Enum.Material, drag: number? }

local function yawCF(x: number, y: number, z: number, tx: number, tz: number): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(tx, 0, tz))
end

local function wedge(parent: Instance, origin: CFrame, size: Vector3, cf: CFrame, look: Look)
	local w = Instance.new("WedgePart")
	w.Name = look.name
	w.Anchored = true
	w.Size = size
	w.CFrame = origin * cf
	w.Color = look.color
	w.Material = look.material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w:SetAttribute("Grip", Plot.grip)
	if look.drag then
		w:SetAttribute("Drag", look.drag)
	end
	w.Parent = parent
end

-- A solid triangle a-b-c (plot-local points): two wedges, 1 thick, with the top face exactly on
-- the triangle, so neighbours meet edge to edge.
local function triangle(
	parent: Instance,
	origin: CFrame,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	look: Look
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local n = ac:Cross(ab)
	if n.Magnitude < 1e-6 then
		return
	end
	local right = n.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 1e-3 then
		return
	end
	-- push both halves down (away from the sky) by half their thickness
	local t = 1
	local down = if right.Y >= 0 then -right * (t / 2) else right * (t / 2)
	wedge(
		parent,
		origin,
		Vector3.new(t, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2 + down, right, up, back),
		look
	)
	wedge(
		parent,
		origin,
		Vector3.new(t, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2 + down, -right, up, -back),
		look
	)
end

local function looks(): { [string]: Look }
	return {
		trail = { name = "Road", color = C.dirt, material = Enum.Material.Ground },
		slab = { name = "Road", color = C.orange, material = Enum.Material.Slate },
		grass = {
			name = "Grass",
			color = Color3.fromRGB(86, 150, 70),
			material = Enum.Material.Grass,
			drag = Plot.GRASS_DRAG,
		},
		rock = { name = "Ground", color = C.rock, material = Enum.Material.Slate },
	}
end

local function buildGround(parent: Instance, origin: CFrame)
	local L = looks()
	local g, x0, z0, nx, nz, dx, dz = Plot.grid()
	local function corner(i: number, j: number): Vector3
		return Vector3.new(x0 + (i - 1) * dx, g[i][j], z0 + (j - 1) * dz)
	end
	local function lookFor(mid: Vector3, steep: number): Look
		local d = Plot.nearest(mid.X, mid.Z)
		if d < HALF then
			return if steep > 0.2 then L.slab else L.trail
		end
		if steep > 0.8 or mid.Y >= Plot.GRASS_TOP then
			return L.rock
		end
		return L.grass
	end
	for i = 1, nx - 1 do
		for j = 1, nz - 1 do
			local p00, p10 = corner(i, j), corner(i + 1, j)
			local p01, p11 = corner(i, j + 1), corner(i + 1, j + 1)
			for _, tri in { { p00, p10, p11 }, { p00, p11, p01 } } do
				local mid = (tri[1] + tri[2] + tri[3]) / 3
				local lo = math.min(tri[1].Y, tri[2].Y, tri[3].Y)
				local hi = math.max(tri[1].Y, tri[2].Y, tri[3].Y)
				triangle(
					parent,
					origin,
					tri[1],
					tri[2],
					tri[3],
					lookFor(mid, (hi - lo) / math.min(dx, dz))
				)
			end
		end
	end
	-- rim: a rock wall right round the edge of the ground, from inside the floor to well above
	-- the ground, so the car can't drop off the hill and out of the plot. Low at the front so it
	-- doesn't block the view from the stand.
	local function rim(a: Vector3, b: Vector3, above: number)
		local top = math.max(a.Y, b.Y) + above
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local p = Kit.part(
			parent,
			"Wall",
			origin,
			Vector3.new(2, top + 1, len),
			CFrame.lookAt(
				Vector3.new(mid.X, (top - 1) / 2, mid.Z),
				Vector3.new(b.X, (top - 1) / 2, b.Z)
			),
			C.rock
		)
		p.Material = Enum.Material.Slate
	end
	for i = 1, nx - 1 do
		rim(corner(i, 1), corner(i + 1, 1), Plot.RIM)
		rim(corner(i, nz), corner(i + 1, nz), Plot.FRONT_RIM)
	end
	for j = 1, nz - 1 do
		rim(corner(1, j), corner(1, j + 1), Plot.RIM)
		rim(corner(nx, j), corner(nx, j + 1), Plot.RIM)
	end
end

local function buildFeature(parent: Instance, origin: CFrame, f: Feature)
	local x, z, h = Plot.spot(f.u, f.side)
	local _, _, _, tx, tz = Plot.at(f.u)
	if f.kind == "rock" then
		Kit.rock(parent, origin, x, h + f.lift - f.r, z, f.r)
	elseif f.kind == "ledge" then
		-- a block over half the trail: one side of the car steps up
		local p = Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(HALF, f.lift + 2, f.r),
			yawCF(x, h + f.lift / 2 - 1, z, tx, tz),
			C.rock
		)
		p.Material = Enum.Material.Slate
	elseif f.kind == "log" then
		-- a round log across the whole trail (a cylinder lies along its X, which points across)
		local p = Kit.part(
			parent,
			"Log",
			origin,
			Vector3.new(ROAD, f.r * 2, f.r * 2),
			yawCF(x, h + f.lift - f.r, z, tx, tz),
			C.ground
		)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Wood
	end
end

function Plot.build(parent: Instance, origin: CFrame)
	buildGround(parent, origin)
	for _, f in Plot.features do
		buildFeature(parent, origin, f)
	end
	-- the flag at the summit, beside the trail
	local fx, fz, top, tx, tz = Plot.at(Plot.FLAG_U)
	local px, pz = fx - tz * (HALF - 3), fz + tx * (HALF - 3)
	local pole = Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(px, top + 7, pz),
		C.white
	)
	pole.CanCollide = false
	local cloth = Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(7, 4, 0.3),
		yawCF(px - 3.5 * tx, top + 12, pz - 3.5 * tz, -tz, tx),
		C.red
	)
	cloth.CanCollide = false
	-- start and finish lines, floating a hair above the ground
	for _, u in { Plot.START_U, Plot.FINISH_U } do
		local x, z, h, dx, dz = Plot.at(u)
		Kit.line(parent, origin, x, h + 0.1, z, dx, dz, ROAD, C.white)
	end
end

return Plot
