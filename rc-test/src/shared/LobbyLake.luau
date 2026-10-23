--!strict
-- Things to do at the lake (LobbyWater lays the water, beach and docks): fishing spots with stools
-- at the dock ends, a swim raft with a diving board, two sailboats, two little beaches (a campfire
-- and a bait shack on the left, umbrellas, towels and a canoe on the right), reeds, lily pads and
-- a family of ducks.
-- Looks only, plain numbers (Lune tests load this); LobbyWaterBuilder turns the pieces into Parts.
-- Pieces with a `group` are one of carter's Meshy props (LobbyLake.spots()): the builder skips them
-- when that mesh is imported.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local LobbyLayout = sibling("LobbyLayout")
local LobbyWater = sibling("LobbyWater")

export type Piece = {
	name: string,
	x: number, -- middle
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	ry: number, -- turn round the up axis (degrees), then...
	rz: number, -- ...tip the +x end up (degrees)
	color: { number },
	collide: boolean,
	hidden: boolean?,
	round: boolean?, -- a flat disc (Cylinder part standing up): sx = sz = width, sy = height
	wedge: boolean?, -- a ramp: tall at local +z, down to nothing at -z
	seat: boolean?, -- a Seat you can sit on, facing local -z
	neon: boolean?, -- glows (flames)
	light: boolean?, -- carries a warm light
	group: string?, -- the Meshy prop spot this block stands in for
}

-- Where one of carter's meshes goes: `mesh` is its name in ServerStorage.LobbyMeshes, standing on
-- (x, y, z), its front turned `ry` (0 = +z), `height` studs tall.
export type Spot = {
	id: string,
	mesh: string,
	x: number,
	y: number,
	z: number,
	ry: number,
	height: number,
}

local LobbyLake = {}

local WHITE = { 240, 240, 234 }
local RED = { 214, 64, 54 }
local BLUE = { 60, 130, 210 }
local ORANGE = { 240, 140, 40 }
local YELLOW = { 255, 214, 70 }
local PLANK_A = { 160, 110, 70 }
local PLANK_B = { 140, 95, 60 }
local POST = { 105, 72, 45 }
local BARK = { 120, 82, 52 }
local STONE = { 140, 140, 136 }
local SAND = { 226, 205, 150 }
local DARK = { 50, 50, 56 }
local REED = { 96, 150, 70 }
local CATTAIL = { 110, 70, 40 }
local LILY = { 70, 160, 80 }
local PINK = { 245, 150, 190 }
local TEAL = { 60, 180, 170 }

-- How far each beach reaches into the lake from the waterline. It stays inside the first
-- underwater step (LobbyWater.STEPS), so you walk up 0.5 studs onto it.
LobbyLake.BEACH_REACH = 10

local function side(): number
	return LobbyLayout.LAKE_SIDE or 1
end

-- Lake-local spots: `u` across (world x), `v` studs out from the near waterline.
local function at(u: number, v: number): (number, number)
	local l = LobbyWater.lakeBox()
	local s = side()
	return u, (if s > 0 then l.minZ else l.maxZ) + s * v
end

-- A front direction (0 = facing out over the lake) in world degrees.
local function face(a: number): number
	return if side() > 0 then a else 180 - a
end

-- Collects pieces and spots; everything added while `group` is set belongs to that mesh spot.
local function maker()
	local out: { Piece } = {}
	local spots: { Spot } = {}
	local group: string? = nil
	local count: { [string]: number } = {}

	local self = {}
	function self.piece(
		name: string,
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		color: { number },
		ry: number?,
		rz: number?
	): Piece
		local p: Piece = {
			name = name,
			x = x,
			y = y,
			z = z,
			sx = sx,
			sy = sy,
			sz = sz,
			ry = ry or 0,
			rz = rz or 0,
			color = color,
			collide = true,
			group = group,
		}
		table.insert(out, p)
		return p
	end
	-- local (lx, ly, lz) turned by `ry` and moved to (x, y, z); local +z is the front
	function self.frame(x: number, y: number, z: number, ry: number)
		local c, sn = math.cos(math.rad(ry)), math.sin(math.rad(ry))
		return function(
			name: string,
			lx: number,
			ly: number,
			lz: number,
			sx: number,
			sy: number,
			sz: number,
			color: { number },
			ryExtra: number?,
			rz: number?
		): Piece
			return self.piece(
				name,
				x + lx * c + lz * sn,
				y + ly,
				z - lx * sn + lz * c,
				sx,
				sy,
				sz,
				color,
				ry + (ryExtra or 0),
				rz
			)
		end
	end
	-- start a mesh spot; blocks added until the next call stand in for it
	function self.spot(mesh: string?, x: number, y: number, z: number, ry: number, height: number)
		if not mesh then
			group = nil
			return
		end
		count[mesh] = (count[mesh] or 0) + 1
		local id = mesh .. count[mesh]
		table.insert(spots, { id = id, mesh = mesh, x = x, y = y, z = z, ry = ry, height = height })
		group = id
	end
	self.out = out
	self.spots = spots
	return self
end

type Maker = typeof(maker())

-- Two fishing spots at a dock's far end: a stool each, a rod in a holder with its line and
-- float in the water, and a bucket between them.
local function fishing(m: Maker, e: { x: number, z: number, dz: number }, tackle: boolean)
	local put = m.frame(e.x, LobbyWater.DECK_TOP, e.z, if e.dz > 0 then 0 else 180)
	local tilt = 35
	local len = 7
	for _, sx in { -1, 1 } do
		put("StoolLeg", sx * 1.3, 0.5, -2.2, 0.4, 1, 0.4, POST)
		put("FishSeat", sx * 1.3, 1.15, -2.2, 1.6, 0.3, 1.6, RED, 180).seat = true
		-- the rod leans out over the water from a holder by the dock edge
		local bx, by, bz = sx * 2.1, 0.9, -1.6
		put("RodHolder", bx, 0.45, bz, 0.3, 0.9, 0.3, POST)
		local c, s = math.cos(math.rad(tilt)), math.sin(math.rad(tilt))
		put("FishRod", bx, by + s * len / 2, bz + c * len / 2, len, 0.18, 0.18, DARK, -90, tilt)
		put("RodReel", bx, by + s * 1.1 - 0.25, bz + c * 1.1, 0.35, 0.4, 0.4, STONE)
		local tipY, tipZ = by + s * len, bz + c * len
		local water = LobbyWater.WATER_TOP - LobbyWater.DECK_TOP
		local line = put("FishLine", bx, (tipY + water) / 2, tipZ, 0.06, tipY - water, 0.06, WHITE)
		line.collide = false
		local float = put("FishFloat", bx, water + 0.1, tipZ, 0.5, 0.5, 0.5, RED, 45)
		float.collide = false
	end
	put("Bucket", 0, 0.45, -3.4, 1.1, 0.9, 1.1, BLUE).round = true
	if tackle then
		put("TackleBox", 0, 0.3, -1.1, 1.2, 0.6, 0.7, { 70, 140, 80 })
		put("TackleLid", 0, 0.65, -1.1, 1.25, 0.1, 0.75, YELLOW)
	end
end

-- A wooden swim raft on four barrels out in the lake, with a ladder on the shore side and a
-- diving board on the far side, and a ring of red and white floats round it.
local function raft(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local put = m.frame(x, 0, z, face(0))
	local deck = LobbyWater.DECK_TOP
	for i = 0, 4 do
		put(
			"RaftPlank",
			0,
			deck - 0.25,
			-4 + i * 2,
			10,
			0.5,
			1.8,
			if i % 2 == 0 then PLANK_A else PLANK_B
		)
	end
	put("RaftFrame", 0, deck - 0.65, 0, 9.4, 0.3, 9.4, POST)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			put("RaftBarrel", sx * 3.4, LobbyWater.WATER_TOP, sz * 3.4, 2.4, 1.6, 2.4, BLUE).round =
				true
		end
		put("RaftRail", sx * 1.6, deck + 0.6, -5.3, 0.25, 2.2, 0.25, WHITE)
	end
	-- two steps up from the lake floor (jump from one to the next)
	put("RaftStep", 0, -0.65, -5.9, 3, 0.3, 1.2, PLANK_B)
	put("RaftStep", 0, -1.65, -7.1, 3, 0.3, 1.2, PLANK_B)
	put("DiveStand", 0, deck + 0.3, 4.4, 1.8, 0.6, 1.2, BLUE)
	put("DiveBoard", 0, deck + 0.72, 6.6, 1.6, 0.25, 5.6, WHITE)
	-- floats in a square round the raft, 26 across
	local half, n = 13, 4
	local k = 0
	for i = 0, n * 4 - 1 do
		local t = (i % n) / n
		local edge = i // n
		local px, pz
		if edge == 0 then
			px, pz = -half + 2 * half * t, -half
		elseif edge == 1 then
			px, pz = half, -half + 2 * half * t
		elseif edge == 2 then
			px, pz = half - 2 * half * t, half
		else
			px, pz = -half, half - 2 * half * t
		end
		k += 1
		local f = put(
			"SwimFloat",
			px,
			LobbyWater.WATER_TOP,
			pz,
			1,
			0.6,
			1,
			if k % 2 == 0 then RED else WHITE
		)
		f.round = true
		f.collide = false
	end
	-- the rope between the floats
	for _, r in
		{
			{ 0, -half, 2 * half, 0.12 },
			{ 0, half, 2 * half, 0.12 },
			{ -half, 0, 0.12, 2 * half },
			{ half, 0, 0.12, 2 * half },
		}
	do
		put("SwimRope", r[1], LobbyWater.WATER_TOP + 0.05, r[2], r[3], 0.12, r[4], WHITE).collide =
			false
	end
end

-- A small sailboat at anchor out on the lake: white hull with a coloured stripe, a big white sail
-- and a coloured front sail.
local function sailboat(
	m: Maker,
	u: number,
	v: number,
	a: number,
	stripe: { number },
	jib: { number }
)
	local x, z = at(u, v)
	local ry = face(a)
	local y = LobbyWater.WATER_TOP - 0.3
	m.spot("Sailboat", x, y - 0.5, z, ry, 13)
	local put = m.frame(x, y, z, ry)
	put("SailHull", 0, 0, 0, 3.6, 1.0, 9, WHITE)
	put("SailBow", 0, 0, 5.0, 2.4, 1.0, 1.2, WHITE)
	put("SailBow", 0, 0, 5.9, 1.2, 1.0, 0.7, WHITE)
	put("SailStripe", 0, 0.42, 0, 3.7, 0.25, 9.1, stripe)
	put("SailDeck", 0, 0.55, -0.5, 3.2, 0.12, 7.5, PLANK_A)
	put("Mast", 0, 6.5, 1.0, 0.35, 12, 0.35, WHITE)
	put("MastFlag", 0.45, 12.2, 1.0, 0.7, 0.5, 0.08, jib, 90)
	put("Boom", 0, 2.3, -1.6, 0.25, 0.25, 5.4, POST)
	put("Sail", 0, 7.4, -1.6, 0.15, 9.8, 5.0, WHITE).wedge = true
	put("Jib", 0, 5.6, 2.9, 0.15, 7.6, 3.6, jib, 180).wedge = true
	m.spot(nil, 0, 0, 0, 0, 0)
end

-- A plain duck floating, `size` 1 for a grown-up.
local function duck(m: Maker, x: number, z: number, ry: number, size: number, body: { number })
	local y = LobbyWater.WATER_TOP
	m.spot("Duck", x, y - 0.2 * size, z, ry, 1.5 * size)
	local put = m.frame(x, y, z, ry)
	local function p(
		name: string,
		lx: number,
		ly: number,
		lz: number,
		sx: number,
		sy: number,
		sz: number,
		c
	)
		put(name, lx * size, ly * size, lz * size, sx * size, sy * size, sz * size, c).collide =
			false
	end
	p("DuckBody", 0, 0.25, 0, 1.4, 0.9, 2.0, body)
	p("DuckTail", 0, 0.6, -1.05, 0.7, 0.5, 0.5, body)
	p("DuckHead", 0, 1.05, 0.75, 0.8, 0.8, 0.8, body)
	p("DuckBeak", 0, 0.95, 1.3, 0.55, 0.2, 0.45, ORANGE)
	m.spot(nil, 0, 0, 0, 0, 0)
end

-- A little sandy beach in a near corner of the lake, from `u0` to `u1` across: a flat sand slab
-- with turned squares along its water edges.
local function beach(m: Maker, u0: number, u1: number)
	local reach = LobbyLake.BEACH_REACH
	local x0, z0 = at(u0, -0.5)
	local x1, z1 = at(u1, reach)
	local top, thick = LobbyWater.SAND_TOP, 4.5
	m.piece(
		"Beach",
		(x0 + x1) / 2,
		top - thick / 2,
		(z0 + z1) / 2,
		math.abs(x1 - x0),
		thick,
		math.abs(z1 - z0),
		SAND
	)
	-- bumps along the far edge and the inner end
	local inner = if math.abs(u0) < math.abs(u1) then u0 else u1
	local n = 3
	for u = math.min(u0, u1) + 4, math.max(u0, u1) - 4, 7 do
		n = (n * 37 + 11) % 101
		local bx, bz = at(u, reach)
		m.piece(
			"BeachBump",
			bx,
			top - thick / 2,
			bz,
			4 + n % 2,
			thick,
			4 + n % 2,
			SAND,
			20 + n % 50
		)
	end
	for v = 1.5, reach - 1, 4 do
		n = (n * 37 + 11) % 101
		local bx, bz = at(inner, v)
		m.piece("BeachBump", bx, top - thick / 2, bz, 4.5, thick, 4.5, SAND, 20 + n % 50)
	end
end

-- A campfire with stones round it.
local function campfire(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local y = LobbyWater.SAND_TOP
	m.spot("Campfire", x, y, z, face(0), 1.8)
	local put = m.frame(x, y, z, face(0))
	for i = 0, 6 do
		local a = i / 7 * 2 * math.pi
		put("FireStone", math.sin(a) * 1.7, 0.3, math.cos(a) * 1.7, 0.8, 0.6, 0.8, STONE, i * 25)
	end
	for i = 0, 2 do
		put("FireLog", 0, 0.3, 0, 2.6, 0.45, 0.45, BARK, i * 60)
	end
	put("Flame", 0, 0.95, 0, 1.0, 1.3, 1.0, ORANGE, 45).neon = true
	put("Flame", 0, 1.6, 0, 0.55, 0.9, 0.55, YELLOW, 20).neon = true
	m.spot(nil, 0, 0, 0, 0, 0)
	for _, p in m.out do
		if p.name == "Flame" then
			p.collide = false
		end
	end
	local glow = put("FireLight", 0, 2, 0, 0.5, 0.5, 0.5, ORANGE)
	glow.hidden, glow.collide, glow.light = true, false, true
end

-- A small bait shack facing the lake: back and side walls, a counter, a striped awning and a
-- fish-shaped sign on the roof (no words).
local function baitShack(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local y = LobbyWater.SAND_TOP
	local wood, light = { 150, 105, 70 }, { 196, 150, 100 }
	-- carter's BaitShack mesh has its door on its side (local +x), so turn it a quarter round to
	-- face the lake
	m.spot("BaitShack", x, y, z, face(-90), 5.4)
	local put = m.frame(x, y, z, face(0))
	put("ShackBack", 0, 2, -1.8, 5, 4, 0.4, wood)
	for _, sx in { -1, 1 } do
		put("ShackSide", sx * 2.3, 2, 0, 0.4, 4, 3.6, wood)
	end
	put("ShackCounter", 0, 1.1, 1.6, 5, 2.2, 0.6, light)
	put("ShackRoof", 0, 4.2, 0.2, 5.8, 0.4, 4.8, wood)
	for i = 0, 2 do
		put("Awning", -1.75 + i * 1.75, 3.6, 2.7, 1.75, 0.2, 1.4, if i % 2 == 0 then RED else WHITE)
	end
	put("SignFish", -0.3, 4.95, 0.2, 1.8, 0.9, 0.2, ORANGE)
	put("SignFish", 0.85, 4.95, 0.2, 0.6, 0.6, 0.2, ORANGE, 0, 45)
	m.spot(nil, 0, 0, 0, 0, 0)
	-- a rack of spare rods beside it
	local rack = m.frame(x, y, z, face(0))
	local rx = 3.8
	for _, sx in { -1, 1 } do
		rack("RackPost", rx + sx * 1.3, 1.1, -0.6, 0.3, 2.2, 0.3, POST)
	end
	rack("RackBar", rx, 2.1, -0.6, 2.9, 0.25, 0.25, POST)
	for i = -1, 1 do
		rack("RackRod", rx + i * 0.8, 2.0, -0.35, 0.15, 4.0, 0.15, DARK, 0, 6)
	end
end

-- A beach umbrella with a towel under it.
local function umbrella(m: Maker, u: number, v: number, a: { number }, b: { number })
	local x, z = at(u, v)
	local y = LobbyWater.SAND_TOP
	m.spot("BeachUmbrella", x, y, z, face(0), 5.2)
	local put = m.frame(x, y, z, face(0))
	put("UmbrellaPole", 0, 2.4, 0, 0.25, 4.8, 0.25, WHITE)
	put("Umbrella", 0, 4.6, 0, 5.4, 0.35, 5.4, a).round = true
	put("UmbrellaTop", 0, 4.9, 0, 3.4, 0.35, 3.4, b).round = true
	put("UmbrellaTip", 0, 5.2, 0, 1.0, 0.3, 1.0, a).round = true
	m.spot(nil, 0, 0, 0, 0, 0)
	put("Towel", -1.8, 0.05, 1.0, 2.0, 0.1, 3.6, b)
end

-- A canoe pulled up on the sand with its paddle beside it, lying across (along u).
local function canoe(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local y = LobbyWater.SAND_TOP
	local ry = face(90)
	m.spot("Canoe", x, y, z, ry, 1.0)
	local put = m.frame(x, y, z, ry)
	put("CanoeHull", 0, 0.35, 0, 1.8, 0.7, 7, ORANGE)
	put("CanoeEnd", 0, 0.5, 3.9, 1.1, 0.7, 0.9, ORANGE)
	put("CanoeEnd", 0, 0.5, -3.9, 1.1, 0.7, 0.9, ORANGE)
	put("CanoeInside", 0, 0.72, 0, 1.4, 0.06, 6.4, { 200, 110, 30 })
	put("CanoeSeat", 0, 0.6, 1.6, 1.5, 0.15, 0.6, PLANK_A)
	put("CanoeSeat", 0, 0.6, -1.6, 1.5, 0.15, 0.6, PLANK_A)
	m.spot(nil, 0, 0, 0, 0, 0)
	put("Paddle", 1.5, 0.08, 0.5, 0.5, 0.12, 4.2, PLANK_B)
end

-- A clump of reeds standing in the shallows, a few with cattail tops.
local REED_SPOTS = {
	{ 0, 0, 3.6 },
	{ 1.1, 0.4, 3.0 },
	{ -0.9, 0.7, 4.2 },
	{ 0.5, -1.0, 2.6 },
	{ -0.6, -0.8, 3.3 },
	{ 1.4, -0.5, 3.9 },
}
local function reeds(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local floor = -1.0
	for i, r in REED_SPOTS do
		local h = r[3]
		local p = m.piece("Reed", x + r[1], floor + h / 2, z + r[2], 0.25, h, 0.25, REED, i * 30)
		p.collide = false
		if i % 3 == 1 then
			local t =
				m.piece("Cattail", x + r[1], floor + h + 0.3, z + r[2], 0.45, 0.9, 0.45, CATTAIL)
			t.collide = false
		end
	end
end

-- A few lily pads floating together, one with a pink flower.
local function lilies(m: Maker, u: number, v: number)
	local x, z = at(u, v)
	local y = LobbyWater.WATER_TOP + 0.05
	for i, l in { { 0, 0, 2.6 }, { 2.4, 1.0, 1.8 }, { -1.6, 2.0, 2.0 }, { 1.0, -2.2, 1.5 } } do
		local p = m.piece("LilyPad", x + l[1], y, z + l[2], l[3], 0.1, l[3], LILY)
		p.round, p.collide = true, false
		if i == 1 then
			m.piece("LilyFlower", x + l[1] + 0.3, y + 0.3, z + l[2], 0.6, 0.5, 0.6, PINK, 45).collide =
				false
		end
	end
end

-- Every piece and Meshy spot at the lake.
function LobbyLake.build(): ({ Piece }, { Spot })
	local m = maker()
	local lake = LobbyWater.lakeBox()
	local w = lake.maxX - lake.minX
	local mid = (lake.minX + lake.maxX) / 2
	local ends = LobbyWater.dockEnds()
	for i, e in ends do
		fishing(m, e, i == 1)
	end
	raft(m, mid, 62)
	-- two sailboats side on to the street, so you see their sails as you walk up
	sailboat(m, mid + w * 0.2, 80, 75, BLUE, RED)
	sailboat(m, mid - w * 0.3, 104, -105, RED, BLUE)

	-- the two corner beaches, clear of the docks
	local edge = w / 2 - 2
	local inner = w / 2 - 55
	beach(m, mid - edge, mid - inner)
	campfire(m, mid - edge + 22, 3)
	baitShack(m, mid - inner - 6, -4.2)
	beach(m, mid + inner, mid + edge)
	umbrella(m, mid + inner + 12, 1.5, RED, WHITE)
	umbrella(m, mid + inner + 26, 1.5, TEAL, YELLOW)
	canoe(m, mid + edge - 10, 6)

	-- life: reeds in the far corners and along the far shore, lily pads, a mother duck and three
	-- ducklings swimming in a line
	local d = LobbyWater.LAKE_D
	for _, r in { { -0.45, d - 8 }, { -0.2, d - 5 }, { 0.3, d - 6 }, { 0.46, d - 14 } } do
		reeds(m, mid + w * r[1], r[2])
	end
	for _, l in { { -0.28, d - 22 }, { 0.12, d - 18 }, { -0.05, d - 32 } } do
		lilies(m, mid + w * l[1], l[2])
	end
	local dx, dz = at(mid - w * 0.18, 44)
	local dry = face(70)
	local fx, fz = math.sin(math.rad(dry)), math.cos(math.rad(dry))
	duck(m, dx, dz, dry, 1, WHITE)
	for i = 1, 3 do
		duck(m, dx - fx * (1.6 + 1.5 * i), dz - fz * (1.6 + 1.5 * i), dry, 0.55, YELLOW)
	end
	return m.out, m.spots
end

function LobbyLake.pieces(): { Piece }
	local p = LobbyLake.build()
	return p
end

function LobbyLake.spots(): { Spot }
	local _, s = LobbyLake.build()
	return s
end

return LobbyLake
