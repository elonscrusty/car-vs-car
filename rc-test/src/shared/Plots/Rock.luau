--!strict
-- ROCK plot: a hill that rises like stadium steps facing the driver stand, so the whole crawl can
-- be watched from the stand. The trail zigzags up it in five rows: grass and mounds with big
-- boulders at the front, a boulder field with a creek and a log bridge, a low shelf with rock
-- steps, a high shelf with big rock domes, then a steep rock face with a line painted up it to
-- the flag. Mountains rise behind the summit.
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
Plot.RIM = 10 -- the rock wall round the back and sides stands this high above the ground
Plot.FRONT_RIM = 3 -- and this high along the front, under the stand's view
Plot.SUMMIT_WALL = 5 -- the wall across the far end of the summit stands this high
Plot.GRASS_TOP = 14 -- ground below this height (off the trail) is grass, higher is rock
-- Highest bump the car can crawl over.
Plot.MAX_LIFT = 1.6
-- Highest sheer step a careful driver can get up (backing up and trying again); much over this
-- and nobody can (Studio: about 0.45 studs at RC size; carter found that too big, so 0.425).
Plot.SKILL_STEP = 1.7
-- The big wide boulders can stand taller: their sides are gentle enough to climb.
Plot.BIG_LIFT = 2.5
-- The person's eyes on the driver stand (see Main.client: stand top + 4.5 studs at RC size).
Plot.EYE = { x = Kit.STAND.x, y = Kit.STAND_H + 18, z = Kit.STAND.z }

-- The trail, front (start) to back (flag), from the approved picture plot-rock-v3.png. Picture
-- spots are studs at RC size from the front-left corner; the third number is the trail height.
local PICTURE = {
	{ 8, 25, 0.4 }, -- 1 start
	{ 24, 27, 0.9 },
	{ 40, 25, 0.6 }, -- 3 big boulders, right in front of the stand
	{ 56, 28, 1.1 },
	{ 68, 27, 1.2 },
	{ 72, 36, 2.0 }, -- 6 turn 1
	{ 66, 45, 2.8 }, -- boulder field, the creek and its log bridge
	{ 48, 44, 3.2 },
	{ 30, 45, 3.6 },
	{ 14, 44, 4.0 },
	{ 9, 54, 5.6 }, -- 11 turn 2
	{ 14, 63, 7.2 }, -- low shelf
	{ 32, 62, 8.0 }, -- 13 to 14: rock steps
	{ 50, 63, 10.0 },
	{ 66, 62, 10.8 },
	{ 72, 71, 12.4 }, -- 16 turn 3
	{ 66, 80, 14.0 }, -- high shelf: big rock domes
	{ 48, 79, 14.8 },
	{ 30, 80, 15.6 },
	{ 16, 79, 16.4 },
	{ 9.5, 88, 17.8 }, -- 21 turn 4
	{ 18, 96, 19.2 },
	{ 32, 97.5, 20.0 }, -- 23 to 24: the steep rock face, dead straight, a line painted up it
	{ 46, 99, 25.6 }, -- 24 top of the face: finish and flag
	{ 60, 100.5, 25.6 }, -- 25 flat summit (keeps the face evenly steep to the top)
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
			r = 14,
			h = (rand() * 1.0 + 0.5) * 4,
		}
	end
end

-- Big rock domes on the trail, part of the ground itself: taller than the car's wheels, but
-- gently rounded so it can crawl right over the top (or steer round them).
export type Dome = { u: number, side: number, r: number, h: number, x: number, z: number }
local function dome(u: number, side: number, r: number, h: number): Dome
	local x, z = Plot.spot(u, side)
	return { u = u, side = side, r = r, h = h, x = x, z = z }
end
Plot.domes = {
	-- all on the hill side of the trail (away from the front edge): rolling off one sends the
	-- car toward the hill, not over the edge. Rows 1 and 3 run left to right, so the hill side
	-- is the left (-); rows 2 and 4 run right to left, so it's the right (+).
	dome(3.7, -0.3, 12, 5), -- row 1, beside the big boulders
	dome(9.0, 0.3, 11, 4.5), -- row 2: the boulder field
	dome(9.75, 0.3, 10, 4.5),
	dome(14.9, -0.3, 12, 5), -- row 3, after the steps
	dome(17.9, 0.3, 12, 5.5), -- row 4: big domes
	dome(18.9, 0.35, 11, 5),
} :: { Dome }

-- A dry creek across the trail in row 2. A bridge of logs crosses it down the middle, on the
-- driving line; either side dips down through the creek bed.
Plot.CREEK = {
	u = 8.1,
	half = 16,
	depth = 5,
	reach = HALF + 14,
	logSide = 0,
	logR = 1.5,
	lift = 0.9, -- bridge deck top above the trail
	deckWidth = 10,
	rail = 0.8,
}
local creekX, creekZ, _, creekTX, creekTZ = Plot.at(Plot.CREEK.u)

-- How far the creek bed dips the ground at (x, z).
function Plot.creekDip(x: number, z: number): number
	local c = Plot.CREEK
	local s = (x - creekX) * creekTX + (z - creekZ) * creekTZ
	local l = math.abs((z - creekZ) * creekTX - (x - creekX) * creekTZ)
	if math.abs(s) >= c.half or l >= c.reach then
		return 0
	end
	local fade = math.clamp((c.reach - l) / 8, 0, 1)
	return c.depth * (1 + math.cos(math.pi * s / c.half)) / 2 * fade
end

-- Rock steps up the low shelf: flat blocks, each a small step up from the one before.
-- Four tall steps on the hill side of the trail: too tall to just hold the gas up, it takes
-- backing up and trying again. The front side of the trail is the easy way round.
-- `lead`: the trail still climbs right up to the first step, so its rise counts from the ground
-- this far before it (Studio measured the first rise 0.57 RC when it counted from `from`).
Plot.STEPS =
	{ from = 13.08, to = 13.84, lead = 0.08, n = 4, side = -0.45, width = 20, frontSide = 1 }
Plot.CURB = 1.2 -- the curb along the front edge beside the steps

-- The step blocks: from u0 to u1, top and bottom heights.
function Plot.stepBlocks(): { { u0: number, u1: number, top: number, bottom: number } }
	local st = Plot.STEPS
	local out = {}
	-- equal rises from the ground in front of the first step up to the trail after the last
	local base = Plot.height(st.from - st.lead)
	local rise = (Plot.height(st.to) - base) / st.n
	for k = 0, st.n - 1 do
		local u0 = st.from + (st.to - st.from) * k / st.n
		local u1 = st.from + (st.to - st.from) * (k + 1) / st.n
		table.insert(
			out,
			{ u0 = u0, u1 = u1, top = base + rise * (k + 1), bottom = base + rise * k - 3 }
		)
	end
	return out
end

-- Skill climbs: too tall to just hold the gas over. Each takes up part of the trail and leaves
-- an easy way round beside it.
-- * notch: two big boulders side by side with a V between them; straddle it with a wheel on each.
-- * stepUp: a tall rock block on the hill side; put one wheel on the small rock in front first.
-- * kicker: a steep ramp up to a lip, then a high block, on the front side.
Plot.SKILLS = {
	-- the boulders stand apart by less than the car's track, so the wheels ride up their sides
	notch = { u = 4.45, side = 0.2, gap = 0.395, r = 7, lift = 3.6 },
	stepUp = {
		u = 12.35,
		side = -0.55,
		width = 12,
		length = 10,
		lift = 3.3,
		-- a lower block right in front, on the line to the middle of the big one: half its
		-- height, so the car goes up in two skill steps
		helper = { width = 6, length = 5, lift = 1.6 },
	},
	-- a short steep ramp up to a lip below the block's top: holding the gas stalls on the lip
	kicker = {
		u = 18.4,
		side = -0.5,
		width = 14,
		length = 8,
		lift = 3.15,
		ramp = 2.6,
		rampLift = 1.45,
	},
}

-- The u this many studs back down the trail from u.
function Plot.uBefore(u: number, studs: number): number
	local ax, az = Plot.at(u - 0.01)
	local bx, bz = Plot.at(u + 0.01)
	return u - studs * 0.02 / math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
end

-- Ground height the step-up's helper and block count from: just in front of the helper.
function Plot.stepUpBase(): number
	local st = Plot.SKILLS.stepUp
	local front = st.length / 2 + st.helper.length - 0.5
	return Plot.trailY(Plot.uBefore(st.u, front + 1.5), st.side)
end

-- Mountain peaks along the back wall, behind the summit, so the hill rises into real mountains.
Plot.PEAKS = {
	{ x = -165, z = -230, r = 45, h = 60 },
	{ x = -70, z = -232, r = 32, h = 50 },
	{ x = 20, z = -230, r = 30, h = 60 },
	{ x = 110, z = -232, r = 34, h = 55 },
	{ x = 168, z = -230, r = 45, h = 60 },
}

-- Distance from (x, z) to the trail centre line, and the trail height at the closest sample.
-- Also: is the spot in front of (closer to the stand than) that sample, the trail height of the
-- closest sample that is in front of the spot (the row below, or nil if none), and how far the
-- spot sits in front of that sample (z, scaled by how much the trail runs across the stand's
-- view there: full along a row, nothing in a turn).
function Plot.nearest(x: number, z: number): (number, number, boolean, number?, number)
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
	local s = path[bestI]
	return math.sqrt(best), Plot.height(Plot.uOf(bestI)), z > s.z, below, (z - s.z) * s.tx * s.tx
end

Plot.SHOULDER = 6 -- flat ground beside the trail before the rock face drops away
Plot.FACE = 1.5 -- steepness of the rock faces down to the row below (too steep to drive up)
Plot.LOWEST = 1.6 -- the ground never goes lower than this (stays clear of the plot floor)
-- Each row leans back into the hill by this much (rise over run), front edge highest, so a car
-- that wanders sideways rolls toward the hill and not off the front edge.
Plot.BANK = 0.08

-- How much the rock domes lift the ground at (x, z).
function Plot.domeLift(x: number, z: number): number
	local h = 0
	for _, m in Plot.domes do
		local mx, mz = (x - m.x) / m.r, (z - m.z) / m.r
		local q = mx * mx + mz * mz
		if q < 9 then
			h += m.h * math.exp(-q)
		end
	end
	return h
end

-- Ground height anywhere on the plot. Behind each row its shelf carries on up to the next
-- row's rock face. In front of a row the ground drops away down a steep rock face to the row
-- below, so the shelf never hides the car from the stand. Mounds bump up the low grass.
function Plot.groundAt(x: number, z: number): number
	local d, h, inFront, below, lean = Plot.nearest(x, z)
	local edge = HALF + Plot.SHOULDER
	h += Plot.BANK * math.clamp(lean, -edge, edge)
	if inFront and d > edge then
		h = math.max(h - Plot.FACE * (d - edge), below or Plot.LOWEST)
	end
	if d > HALF then
		local away = math.clamp((d - HALF) / 32, 0, 1)
		for _, m in MOUNDS do
			local mx, mz = (x - m.x) / m.r, (z - m.z) / m.r
			h += m.h * away * math.exp(-(mx * mx + mz * mz))
		end
		-- mountains only well away from the trail
		local far = math.clamp((d - edge - 4) / 24, 0, 1)
		if far > 0 then
			for _, p in Plot.PEAKS do
				local px, pz = (x - p.x) / p.r, (z - p.z) / p.r
				h += p.h * far * math.exp(-(px * px + pz * pz))
			end
		end
	end
	h += Plot.domeLift(x, z)
	h -= Plot.creekDip(x, z)
	return math.max(h, Plot.LOWEST)
end

-- The tilt of the trail at u: a frame at (x, y, z) facing along the trail, leaning back into the
-- hill like the ground does, for things laid on the trail.
function Plot.bankCF(u: number, x: number, y: number, z: number): CFrame
	local _, _, _, tx, tz = Plot.at(u)
	local fwd = Vector3.new(tx, 0, tz)
	-- across the trail, rising toward the front (+z) by BANK * tx^2 per stud of z
	local across = Vector3.new(-tz, Plot.BANK * tx * tx * tx, tx).Unit
	local up = across:Cross(fwd).Unit
	if up.Y < 0 then
		up = -up
	end
	return CFrame.fromMatrix(Vector3.new(x, y, z), across, up)
end

-- Ground height on the trail at u, `side` across it (-1 left .. 1 right), before domes and the
-- creek: the trail height plus the lean back into the hill.
function Plot.trailY(u: number, side: number): number
	local _, cz, h, tx = Plot.at(u)
	local _, z = Plot.spot(u, side)
	return h + Plot.BANK * (z - cz) * tx * tx
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
-- side of the car climbs while the other drops. Wide and flat, so they look big but stay
-- crawlable. The steep face at the top is kept clear.
Plot.features = {
	-- row 1: grass and mounds, and two big boulders right in front of the stand
	rock(1.8, -0.35, 3.4, 1.0),
	rock(2.2, 0.3, 3.6, 1.1),
	-- two big boulders, wide so they get climbed, not pushed past: watch the springs up close.
	-- The first sits right on the driving line, so going straight means going over the top.
	rock(2.7, 0.05, 12, 2.4),
	rock(3.3, -0.5, 11, 2.2),
	ledge(4.85, 0.5, 0.9),
	-- turn 1
	rock(5.6, -0.5, 3.0, 0.9),
	rock(6.4, 0.5, 3.2, 1.0),
	-- row 2: the boulder field, then the creek (8.1)
	rock(7.2, -0.4, 3.6, 1.2),
	rock(7.4, 0.35, 3.8, 1.3),
	rock(7.6, 0.6, 3.4, 1.4),
	rock(8.6, 0.4, 4.2, 1.4),
	rock(8.65, -0.5, 4.0, 1.3),
	rock(9.35, 0.3, 3.4, 1.2),
	rock(9.4, -0.6, 3.4, 1.0),
	rock(10.35, 0.45, 3.6, 1.2),
	rock(10.2, -0.4, 3.6, 1.3),
	-- turn 2
	rock(10.8, 0.45, 2.8, 0.8),
	rock(11.3, -0.4, 2.8, 0.8),
	-- row 3: the low shelf, the rock steps (13.05 to 13.95), a dome
	ledge(12.8, -0.5, 1.0),
	log(14.35, 1.0),
	rock(15.3, 0.45, 3.4, 1.2),
	-- turn 3
	rock(15.7, -0.5, 3.0, 0.9),
	rock(16.4, -0.5, 3.0, 0.9),
	-- row 4: the high shelf with the big domes
	ledge(17.3, 0.5, 1.2),
	rock(17.45, -0.45, 3.8, 1.4),
	rock(18.4, 0.5, 3.8, 1.5),
	rock(19.35, 0.4, 3.6, 1.3),
	rock(19.3, -0.45, 3.4, 1.2),
	log(19.7, 1.0),
	-- turn 4
	rock(20.6, -0.45, 2.8, 0.8),
	rock(21.3, 0.45, 2.8, 0.8),
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

-- Checkpoint flags, one near the end of each row, just before its turn (so one after every
-- row of climbs). Driving through a flag's gate saves it; a reset then puts the car back at the
-- last saved flag instead of the start, on the trail's middle, facing along the row.
Plot.CHECKPOINT_BACK = 0.3 -- this far before each turn, where the row is still straight
Plot.checkpoints = {} :: { { u: number, gate: Gate, spawn: Kit.Spawn } }
for _, turn in Plot.TURNS do
	local u = turn - Plot.CHECKPOINT_BACK
	local x, z, _, tx, tz = Plot.at(u)
	table.insert(Plot.checkpoints, {
		u = u,
		gate = gate(u, 8),
		spawn = { x = x, y = Plot.groundAt(x, z) + 2.5, z = z, dx = tx, dz = tz },
	})
end

-- ===== Building (Roblox only) =====

type Look = { name: string, color: Color3, material: Enum.Material }

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
		},
		rock = { name = "Ground", color = C.rock, material = Enum.Material.Slate },
		-- domes on the trail: drivable rock, a little lighter so they stand out
		dome = {
			name = "Road",
			color = Color3.fromRGB(140, 134, 126),
			material = Enum.Material.Slate,
		},
		creek = {
			name = "Road",
			color = Color3.fromRGB(96, 112, 122),
			material = Enum.Material.Pebble,
		},
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
		if Plot.creekDip(mid.X, mid.Z) > 0.3 then
			return L.creek
		end
		if Plot.domeLift(mid.X, mid.Z) > 0.6 then
			return L.dome
		end
		if d < HALF then
			-- orange only on the steep face at the top
			return if steep > 0.2 and mid.Y > Plot.height(23) - 2 then L.slab else L.trail
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
	-- doesn't block the view from the stand. Its top follows the ground smoothly (two triangles
	-- per piece), and it sits just outside the ground's edge so no faces line up.
	local wall: Look = { name = "Wall", color = C.rock, material = Enum.Material.Slate }
	local function rim(a: Vector3, b: Vector3, above: number, out: Vector3)
		local a0, b0 = Vector3.new(a.X, -1, a.Z) + out, Vector3.new(b.X, -1, b.Z) + out
		local a1, b1 = a + Vector3.new(0, above, 0) + out, b + Vector3.new(0, above, 0) + out
		triangle(parent, origin, a0, b0, b1, wall)
		triangle(parent, origin, a0, b1, a1, wall)
	end
	local back, front = Vector3.new(0, 0, -0.5), Vector3.new(0, 0, 0.5)
	local left, right = Vector3.new(-0.5, 0, 0), Vector3.new(0.5, 0, 0)
	for i = 1, nx - 1 do
		rim(corner(i, 1), corner(i + 1, 1), Plot.RIM, back)
		rim(corner(i, nz), corner(i + 1, nz), Plot.FRONT_RIM, front)
	end
	for j = 1, nz - 1 do
		rim(corner(1, j), corner(1, j + 1), Plot.RIM, left)
		rim(corner(nx, j), corner(nx, j + 1), Plot.RIM, right)
	end
end

local function buildFeature(parent: Instance, origin: CFrame, f: Feature)
	local x, z = Plot.spot(f.u, f.side)
	local h = Plot.trailY(f.u, f.side)
	if f.kind == "rock" then
		Kit.rock(parent, origin, x, h + f.lift - f.r, z, f.r)
	elseif f.kind == "ledge" then
		-- a block over half the trail: one side of the car steps up
		local p = Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(HALF, f.lift + 2, f.r),
			Plot.bankCF(f.u, x, h + f.lift / 2 - 1, z),
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
			Plot.bankCF(f.u, x, h + f.lift - f.r, z),
			C.ground
		)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Wood
	end
end

-- Rock steps: each block's top sits at the trail height at its far end, so its near end is a
-- small step up from the ground and its far end meets the ground. Blocks overlap a little.
local function buildSteps(parent: Instance, origin: CFrame)
	-- a low curb along the front edge beside the steps, so a car on the easy side doesn't drive
	-- off the front of the row
	local st = Plot.STEPS
	local cu = (st.from + st.to) / 2
	local fx, fz = Plot.spot(cu, 0)
	local ax, az = Plot.at(st.from - 0.1)
	local bx, bz = Plot.at(st.to + 0.1)
	local edge = HALF + Plot.SHOULDER - 1
	local curb = Kit.part(
		parent,
		"Wall",
		origin,
		Vector3.new(1.5, Plot.CURB + 2, math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)),
		Plot.bankCF(cu, fx, Plot.height(cu), fz)
			* CFrame.new(st.frontSide * edge, Plot.CURB / 2 - 1, 0),
		C.rock
	)
	curb.Material = Enum.Material.Slate
	for _, st in Plot.stepBlocks() do
		local ax, az = Plot.at(st.u0)
		local bx, bz = Plot.at(st.u1)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) + 1
		local p = Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(Plot.STEPS.width, st.top - st.bottom, len),
			Plot.bankCF((st.u0 + st.u1) / 2, (ax + bx) / 2, (st.top + st.bottom) / 2, (az + bz) / 2)
				* CFrame.new(Plot.STEPS.side * HALF, 0, 0),
			C.rock
		)
		p.Material = Enum.Material.Slate
	end
end

-- A log bridge over the creek: three logs side by side along the trail, with a flat plank deck
-- on top (round logs alone twist the wheels off) and a low rail along each side of the deck.
local function buildLogBridge(parent: Instance, origin: CFrame)
	local c = Plot.CREEK
	local x, z, _, tx, tz = Plot.at(c.u)
	local cx, cz = x - tz * c.logSide * HALF, z + tx * c.logSide * HALF
	local h = Plot.trailY(c.u, c.logSide)
	local len = c.half * 2 + 20
	local deck = 0.6
	for _, off in { -3.2, 0, 3.2 } do
		local p = Kit.part(
			parent,
			"Log",
			origin,
			Vector3.new(len, c.logR * 2, c.logR * 2),
			-- a cylinder lies along its X: point X along the trail
			yawCF(cx - tz * off, h + c.lift - deck - c.logR, cz + tx * off, -tz, tx),
			C.ground
		)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Wood
	end
	local frame = Plot.bankCF(c.u, cx, h + c.lift - deck / 2, cz)
	local planks = Kit.part(
		parent,
		"Bridge",
		origin,
		Vector3.new(c.deckWidth, deck, len),
		frame,
		Color3.fromRGB(150, 110, 70)
	)
	planks.Material = Enum.Material.WoodPlanks
	for _, side in { -1, 1 } do
		local rail = Kit.part(
			parent,
			"Wall",
			origin,
			Vector3.new(0.6, c.rail, len),
			frame * CFrame.new(side * (c.deckWidth / 2 - 0.3), deck / 2 + c.rail / 2, 0),
			Color3.fromRGB(120, 85, 55)
		)
		rail.Material = Enum.Material.Wood
	end
end

-- A painted line up the middle of the steep face: thin dashes just above the rock.
local function buildFaceLine(parent: Instance, origin: CFrame)
	local u = 23.1
	while u < 23.95 do
		local ax, az = Plot.at(u)
		local bx, bz = Plot.at(u + 0.05)
		local a = Vector3.new(ax, Plot.groundAt(ax, az) + 0.5, az)
		local b = Vector3.new(bx, Plot.groundAt(bx, bz) + 0.5, bz)
		local dash = Kit.part(
			parent,
			"Line",
			origin,
			Vector3.new(1.4, 0.2, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			Color3.fromRGB(240, 200, 40)
		)
		dash.CanCollide = false
		u += 0.1
	end
end

local function buildSkills(parent: Instance, origin: CFrame)
	local S = Plot.SKILLS
	local function slate(p: Part)
		p.Material = Enum.Material.Slate
	end
	-- the V-notch: two boulders either side of the driving line
	local n = S.notch
	for _, d in { -n.gap, n.gap } do
		local x, z = Plot.spot(n.u, n.side + d)
		Kit.rock(parent, origin, x, Plot.trailY(n.u, n.side + d) + n.lift - n.r, z, n.r)
	end
	-- the step-up block, and the small rock in front of it
	local st = S.stepUp
	local x, z = Plot.spot(st.u, st.side)
	-- heights count from the ground in front of the helper: the trail climbs on the way in, so
	-- it is lower there than at the block (Studio measured the helper 0.56 RC when it wasn't)
	local y = Plot.stepUpBase()
	slate(
		Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(st.width, st.lift + 2, st.length),
			Plot.bankCF(st.u, x, y + st.lift / 2 - 1, z),
			C.rock
		)
	)
	local hp = st.helper
	slate(Kit.part(
		parent,
		"Ledge",
		origin,
		Vector3.new(hp.width, hp.lift + 2, hp.length),
		-- in front of the big block (the bank frame's +Z points back down the trail)
		Plot.bankCF(st.u, x, y, z)
			* CFrame.new(0, hp.lift / 2 - 1, st.length / 2 + hp.length / 2 - 0.5),
		C.rock
	))
	-- the kicker: a block with a steep ramp up to it from behind (the bank frame's +Z points
	-- back down the trail)
	local k = S.kicker
	local kx, kz = Plot.spot(k.u, k.side)
	local frame = Plot.bankCF(k.u, kx, Plot.trailY(k.u, k.side), kz)
	slate(
		Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(k.width, k.lift + 2, k.length),
			frame * CFrame.new(0, k.lift / 2 - 1, 0),
			C.rock
		)
	)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ledge"
	ramp.Anchored = true
	-- a wedge's high end is at its +Z: turn it round so the high end meets the block
	ramp.Size = Vector3.new(k.width, k.rampLift + 0.3, k.ramp)
	ramp.CFrame = origin
		* frame
		* CFrame.new(0, (k.rampLift - 0.3) / 2, k.length / 2 + k.ramp / 2)
		* CFrame.Angles(0, math.pi, 0)
	ramp.Color = C.rock
	ramp.Material = Enum.Material.Slate
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp:SetAttribute("Grip", Plot.grip)
	ramp.Parent = parent
end

function Plot.build(parent: Instance, origin: CFrame)
	buildGround(parent, origin)
	for _, f in Plot.features do
		buildFeature(parent, origin, f)
	end
	buildSteps(parent, origin)
	buildLogBridge(parent, origin)
	buildFaceLine(parent, origin)
	buildSkills(parent, origin)
	-- a rock wall across the end of the summit, so holding the gas doesn't drive off the back
	local ex, ez, eh = Plot.at(Plot.LAST_U - 0.05)
	local endWall = Kit.part(
		parent,
		"Wall",
		origin,
		Vector3.new(ROAD + 2 * Plot.SHOULDER, Plot.SUMMIT_WALL + 3, 3),
		Plot.bankCF(Plot.LAST_U - 0.05, ex, eh + (Plot.SUMMIT_WALL - 3) / 2, ez),
		C.rock
	)
	endWall.Material = Enum.Material.Slate
	-- the flag at the summit, beside the trail
	local fx, fz, _, tx, tz = Plot.at(Plot.FLAG_U)
	local px, pz = fx - tz * (HALF - 3), fz + tx * (HALF - 3)
	local pole = Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(px, Plot.groundAt(px, pz) + 6.5, pz),
		C.white
	)
	pole.CanCollide = false
	local cloth = Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(7, 4, 0.3),
		yawCF(px - 3.5 * tx, Plot.groundAt(px, pz) + 11.5, pz - 3.5 * tz, -tz, tx),
		C.red
	)
	cloth.CanCollide = false
	-- a yellow flag beside the trail at each checkpoint, on the side away from the hill
	for k, cp in Plot.checkpoints do
		local cx, cz, _, ctx, ctz = Plot.at(cp.u)
		-- flag k is on row k: rows 1 and 3 have the hill on the - side, rows 2 and 4 on the +
		local front = if k % 2 == 1 then 1 else -1
		local off = front * (HALF + 2)
		local qx, qz = cx - ctz * off, cz + ctx * off
		local g = Plot.groundAt(qx, qz)
		local stick = Kit.part(
			parent,
			"Flag",
			origin,
			Vector3.new(0.5, 9, 0.5),
			CFrame.new(qx, g + 4, qz),
			C.white
		)
		stick.CanCollide = false
		local banner = Kit.part(
			parent,
			"Flag",
			origin,
			Vector3.new(4, 2.5, 0.3),
			yawCF(qx + 2 * ctx, g + 7.2, qz + 2 * ctz, -ctz, ctx),
			Color3.fromRGB(245, 205, 40)
		)
		banner.CanCollide = false
	end
	-- start and finish lines, floating just above the ground and leaning with it
	for _, u in { Plot.START_U, Plot.FINISH_U } do
		local x, z, h = Plot.at(u)
		local line = Kit.part(
			parent,
			"Line",
			origin,
			Vector3.new(ROAD, 0.2, 2),
			Plot.bankCF(u, x, h + 0.25, z),
			C.white
		)
		line.CanCollide = false
	end
end

return Plot
