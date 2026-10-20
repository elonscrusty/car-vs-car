--!strict
-- "Wreck City": the chase map (docs/CHASE_MAP_SPEC.md). Pure data, no Roblox objects, so the tests
-- can check every number. The server builds it in ChaseMap.
--
-- Arena-local studs: the middle of the map is (0, 0), x runs east, z runs south, y up; the ground
-- top is y = 0. Walls close the map at +-halfX / +-halfZ. A 36-stud ring road runs round the
-- outside; a low barrier ring (at +-120) separates it from the plaza inside, with gaps where the
-- roads lead in. In the middle stands a raised deck (14 high) reached by four ramps and one hidden
-- ramp behind a breakable fence; a tunnel runs east-west right under it. A wrecking-ball crane
-- swings across the east road. Cars are about 16 studs long and 8 wide and cruise at ~45 studs/s.

local Layout = {}

Layout.halfX = 156 -- inner face of the walls
Layout.halfZ = 156
Layout.chamfer = 22 -- the four corners are cut at 45 degrees so a car never pins in a corner
Layout.wallHeight = 7 -- car height: a car bounces off it, nothing more
Layout.wallThickness = 4
Layout.wallBounce = 0.9
Layout.ringInner = 120 -- the ring road runs from here to the wall
Layout.groundSize = 516 -- slots are 520 apart, so neighbours never overlap -- the grass plate under and round everything

Layout.colors = {
	road = { 150, 160, 178 }, -- light blue-grey: dark cars do not melt into it
	roadEdgeA = { 245, 130, 32 }, -- orange lane edge
	roadEdgeB = { 37, 141, 221 }, -- blue lane edge
	line = { 244, 246, 240 },
	plaza = { 224, 200, 150 }, -- warm sand
	plazaDark = { 204, 178, 128 },
	deck = { 196, 204, 218 },
	deckStripe = { 245, 130, 32 },
	ramp = { 255, 200, 64 },
	tunnel = { 120, 128, 146 },
	wall = { 90, 100, 124 },
	orange = { 245, 130, 32 },
	blue = { 37, 141, 221 },
	red = { 214, 58, 52 },
	yellow = { 255, 214, 64 },
	grass = { 127, 186, 66 },
	hill = { 142, 200, 84 },
	dirt = { 168, 128, 86 },
	light = { 255, 168, 60 },
	skid = { 112, 120, 138 },
	building = {
		{ 255, 150, 120 },
		{ 255, 214, 100 },
		{ 120, 200, 235 },
		{ 160, 220, 140 },
		{ 214, 160, 235 },
		{ 255, 130, 160 },
	},
}

-- Raised deck: a solid block (tunnel carved through its feet) with a flat top.
Layout.deck = { half = 55, top = 14, thick = 3 }
Layout.tunnel = { halfWidth = 18, clear = 11 } -- under the deck, along x, clear height 11
Layout.ramp = { rise = 14, width = 40 }

Layout.spawnX = 90
Layout.spawnZ = 138 -- both starts on the south road, facing each other
Layout.spawnLane = 16 -- nothing but paint within this far of the line between the starts
Layout.pad = { sx = 26, sz = 18 }

Layout.hazard = {
	damageFrac = 0.10, -- of max HP per hit
	cooldown = 1.2, -- seconds before the same car can be hit again
	knockSpeed = 38,
	stagger = 0.6,
}

-- The wrecking-ball crane: mast at the east road edge, the arm swings over the road.
Layout.crane = {
	x = 151,
	z = -70,
	armLength = 24,
	ballRadius = 6,
	amp = 1.35, -- radians each side of straight across the road
	period = 4.6, -- seconds for one full swing there and back
	phase = 0,
}

export type Wall = {
	name: string,
	x: number,
	z: number,
	length: number,
	yawDeg: number, -- the long side runs along this heading (0 = along x)
	nx: number, -- unit vector pointing to the middle of the map (the inner face looks this way)
	nz: number,
}

function Layout.spawn(side: string): (number, number, number, number)
	if side == "a" then
		return -Layout.spawnX, Layout.spawnZ, 1, 0
	end
	return Layout.spawnX, Layout.spawnZ, -1, 0
end

-- The outer walls: four straights and four 45 degree corner cuts. Each piece is a box `length`
-- long; its INNER face passes through (x, z) and the box sits wallThickness / 2 behind it.
function Layout.walls(): { Wall }
	local list: { Wall } = {}
	local h, c = Layout.halfX, Layout.chamfer
	local run = (h - c) * 2
	-- straights
	table.insert(list, { name = "WallN", x = 0, z = -h, length = run, yawDeg = 0, nx = 0, nz = 1 })
	table.insert(list, { name = "WallS", x = 0, z = h, length = run, yawDeg = 0, nx = 0, nz = -1 })
	table.insert(
		list,
		{ name = "WallW", x = -h, z = 0, length = run, yawDeg = -90, nx = 1, nz = 0 }
	)
	table.insert(
		list,
		{ name = "WallE", x = h, z = 0, length = run, yawDeg = -90, nx = -1, nz = 0 }
	)
	-- corner cuts: from (h - c, -h) to (h, -h + c) and so on; each is 45 degrees
	local len = c * math.sqrt(2)
	local k = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k += 1
			local inv = 1 / math.sqrt(2)
			table.insert(list, {
				name = "Corner" .. k,
				x = sx * (h - c / 2),
				z = sz * (h - c / 2),
				length = len,
				yawDeg = if sx * sz > 0 then 45 else -45,
				nx = -sx * inv,
				nz = -sz * inv,
			})
		end
	end
	return list
end

export type Seg = { name: string, x: number, z: number, length: number, yawDeg: number }

-- Cuts the openings out of the interval [-half, half] and returns the pieces that remain.
local function pieces(half: number, openings: { { number } }): { { number } }
	local list: { { number } } = {}
	local cursor = -half
	local sorted = table.clone(openings)
	table.sort(sorted, function(a, b)
		return a[1] < b[1]
	end)
	for _, o in sorted do
		if o[1] > cursor then
			table.insert(list, { cursor, o[1] })
		end
		cursor = math.max(cursor, o[2])
	end
	if cursor < half then
		table.insert(list, { cursor, half })
	end
	return list
end

-- Gaps in the barrier ring and in the deck rails, one list per side ({from, to} along the side).
Layout.barrierGaps = {
	N = { { -24, 24 }, { 28, 48 } }, -- the second is the hidden one, shut by a breakable fence
	S = { { -24, 24 } },
	W = { { -56, 22 } },
	E = { { -22, 56 } },
}
Layout.railGaps = {
	N = { { -20, 20 }, { 26, 50 } },
	S = { { -20, 20 } },
	W = { { -54, -26 } },
	E = { { 26, 54 } },
}

-- A square ring of segments on the half-size line; `gaps` as above, `inset` shortens each end.
local function ring(half: number, gaps: { [string]: { { number } } }, tag: string): { Seg }
	local list: { Seg } = {}
	for side, yaw in { N = 0, S = 0, W = -90, E = -90 } do
		local n = 0
		for _, p in pieces(half, gaps[side] or {}) do
			n += 1
			local mid = (p[1] + p[2]) / 2
			local x, z
			if side == "N" then
				x, z = mid, -half
			elseif side == "S" then
				x, z = mid, half
			elseif side == "W" then
				x, z = -half, mid
			else
				x, z = half, mid
			end
			table.insert(list, {
				name = tag .. side .. n,
				x = x,
				z = z,
				length = p[2] - p[1],
				yawDeg = yaw,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- The low jersey barriers between the ring road and the plaza.
function Layout.barriers(): { Seg }
	return ring(Layout.ringInner, Layout.barrierGaps, "Barrier")
end

-- Guard rails round the top of the deck.
function Layout.rails(): { Seg }
	return ring(Layout.deck.half, Layout.railGaps, "Rail")
end

-- The breakable fence that hides the secret way in (fills the second north gap in the barrier).
function Layout.secretFence(): Seg
	local g = Layout.barrierGaps.N[2]
	return {
		name = "SecretFence",
		x = (g[1] + g[2]) / 2,
		z = -Layout.ringInner,
		length = g[2] - g[1],
		yawDeg = 0,
	}
end

export type Ramp = {
	name: string,
	x: number, -- centre of the footprint
	z: number,
	dx: number, -- unit direction the ramp RISES toward
	dz: number,
	length: number,
	width: number,
	height: number,
	secret: boolean,
}

function Layout.ramps(): { Ramp }
	local rise = Layout.ramp.rise
	local w = Layout.ramp.width
	return {
		{
			name = "RampN",
			x = 0,
			z = -85,
			dx = 0,
			dz = 1,
			length = 60,
			width = w,
			height = rise,
			secret = false,
		},
		{
			name = "RampS",
			x = 0,
			z = 85,
			dx = 0,
			dz = -1,
			length = 60,
			width = w,
			height = rise,
			secret = false,
		},
		{
			name = "RampW",
			x = -85,
			z = -36,
			dx = 1,
			dz = 0,
			length = 60,
			width = 32,
			height = rise,
			secret = false,
		},
		{
			name = "RampE",
			x = 85,
			z = 36,
			dx = -1,
			dz = 0,
			length = 60,
			width = 32,
			height = rise,
			secret = false,
		},
		{
			name = "RampSecret",
			x = 38,
			z = -76.5,
			dx = 0,
			dz = 1,
			length = 43,
			width = 24,
			height = rise,
			secret = true,
		},
	}
end

-- The dirt road behind the secret fence, from the barrier to the foot of the hidden ramp.
Layout.secretPath = { x = 38, z0 = -120, z1 = -98, width = 24 }

export type Block = {
	name: string,
	x: number,
	z: number,
	w: number,
	d: number,
	h: number,
	palette: number,
}

-- Buildings and blocks you can hide behind (solid, bouncy). Big ones at the corners, small ones
-- in the gaps.
function Layout.blockers(): { Block }
	return {
		{ name = "BuildingNW", x = -88, z = -88, w = 34, d = 34, h = 16, palette = 1 },
		{ name = "BuildingNE", x = 88, z = -88, w = 34, d = 34, h = 16, palette = 3 },
		{ name = "BuildingSW", x = -88, z = 88, w = 34, d = 34, h = 16, palette = 2 },
		{ name = "BuildingSE", x = 88, z = 88, w = 34, d = 34, h = 16, palette = 4 },
		{ name = "BlockW", x = -90, z = 40, w = 16, d = 16, h = 10, palette = 5 },
		{ name = "BlockE", x = 90, z = -40, w = 16, d = 16, h = 10, palette = 6 },
		{ name = "BlockNW2", x = -52, z = -96, w = 16, d = 16, h = 10, palette = 6 },
		{ name = "BlockSE2", x = 52, z = 96, w = 16, d = 16, h = 10, palette = 5 },
	}
end

-- Where a car can be put back when it is stuck or has fallen: on the road, facing along it.
function Layout.rescuePoints(): { { x: number, z: number, fx: number, fz: number } }
	local r = (Layout.ringInner + Layout.halfX) / 2
	return {
		{ x = -r, z = -r, fx = 1, fz = 0 },
		{ x = r, z = -r, fx = 0, fz = 1 },
		{ x = r, z = r, fx = -1, fz = 0 },
		{ x = -r, z = r, fx = 0, fz = -1 },
		{ x = 0, z = -r, fx = 1, fz = 0 },
		{ x = 0, z = r, fx = -1, fz = 0 },
		{ x = -r, z = 0, fx = 0, fz = -1 },
		{ x = r, z = 0, fx = 0, fz = 1 },
	}
end

-- Is the flat spot (x, z) clear of everything big, with `margin` studs to spare? Used to place
-- props (and checked by the tests).
function Layout.clear(x: number, z: number, margin: number): boolean
	local d = Layout.deck.half + 6 + margin
	if math.abs(x) < d and math.abs(z) < d then
		return false -- deck and tunnel
	end
	for _, r in Layout.ramps() do
		local halfAlong = r.length / 2 + margin
		local halfAcross = r.width / 2 + margin
		local along = (x - r.x) * r.dx + (z - r.z) * r.dz
		local across = (x - r.x) * -r.dz + (z - r.z) * r.dx
		if math.abs(along) < halfAlong and math.abs(across) < halfAcross then
			return false
		end
	end
	for _, b in Layout.blockers() do
		if math.abs(x - b.x) < b.w / 2 + margin and math.abs(z - b.z) < b.d / 2 + margin then
			return false
		end
	end
	local p = Layout.secretPath
	if math.abs(x - p.x) < p.width / 2 + margin and z > p.z0 - margin and z < p.z1 + margin then
		return false
	end
	-- the start lane on the south road
	if
		math.abs(z - Layout.spawnZ) < Layout.spawnLane + margin
		and math.abs(x) < Layout.spawnX + 20
	then
		return false
	end
	-- the crane's sweep
	local c = Layout.crane
	local dx, dz = x - c.x, z - c.z
	if math.sqrt(dx * dx + dz * dz) < c.armLength + c.ballRadius + margin then
		return false
	end
	-- the road gaps in the barrier ring (the throats of the roads)
	local rin = Layout.ringInner
	if math.abs(math.abs(x) - rin) < 8 + margin or math.abs(math.abs(z) - rin) < 8 + margin then
		return false
	end
	return true
end

export type Prop = { kind: string, x: number, z: number, yawDeg: number, variant: number }

-- Breakable props, laid out the same way every time. Deterministic scatter (a small LCG).
function Layout.breakables(): { Prop }
	local list: { Prop } = {}
	local seed = 20261020
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local function place(kind: string, count: number, minR: number, maxR: number)
		local made, tries = 0, 0
		while made < count and tries < count * 60 do
			tries += 1
			local x = (rnd() * 2 - 1) * (Layout.halfX - 10)
			local z = (rnd() * 2 - 1) * (Layout.halfZ - 10)
			local r = math.max(math.abs(x), math.abs(z))
			if r >= minR and r <= maxR and Layout.clear(x, z, 6) then
				made += 1
				table.insert(list, {
					kind = kind,
					x = x,
					z = z,
					yawDeg = rnd() * 360,
					variant = 1 + math.floor(rnd() * 4),
				})
			end
		end
	end
	-- road edges and the plaza; far from the walls so a car can drive round them
	place("barrel", 22, 126, 146)
	place("cone", 14, 126, 146)
	place("crate", 8, 126, 146)
	place("sign", 8, 126, 146)
	place("barrel", 6, 60, 112)
	place("crate", 4, 60, 112)
	return list
end

-- Breakable fence rows: along the inside of the barrier ring where it is solid, so they read as
-- yard fences, plus the secret one.
function Layout.fences(): { Seg }
	local list: { Seg } = {}
	local n = 0
	for _, s in Layout.barriers() do
		if s.length >= 30 then
			n += 1
			-- a fence a little inside the barrier, shorter than it
			local off = 8
			local nx, nz = 0, 0
			if s.name:find("N") == 8 then
				nz = 1
			elseif s.name:find("S") == 8 then
				nz = -1
			elseif s.name:find("W") == 8 then
				nx = 1
			else
				nx = -1
			end
			table.insert(list, {
				name = "Fence" .. n,
				x = s.x + nx * off,
				z = s.z + nz * off,
				length = math.min(s.length - 20, 36),
				yawDeg = s.yawDeg,
			})
		end
	end
	return list
end

-- Crane angle (radians from straight across the road) at server time t.
function Layout.craneAngle(t: number): number
	local c = Layout.crane
	return c.amp * math.sin(t / c.period * 2 * math.pi + c.phase)
end

-- Where the ball is, flat, when the arm is at `angle` (0 = straight across, toward -x).
function Layout.ballPosition(angle: number): (number, number)
	local c = Layout.crane
	return c.x - c.armLength * math.cos(angle), c.z + c.armLength * math.sin(angle)
end

return Layout
