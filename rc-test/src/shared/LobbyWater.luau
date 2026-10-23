--!strict
-- The water round the walking lobby: a grass bank ring just outside LobbyLayout.ground(), a sand
-- shore, shallow and deep water, wooden docks, and a small island with an arched footbridge.
-- Looks only. Plain numbers (Lune tests load this); LobbyWaterBuilder turns the pieces into Parts.
-- Trees, bushes, rocks and fences belong to the landscaping file: it keeps off the outer
-- DOCK_FREE studs of the bank, where the docks start.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local LobbyLayout = sibling("LobbyLayout")

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
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
	color: { number }, -- r, g, b (0-255)
	collide: boolean,
	hidden: boolean?, -- invisible wall
	round: boolean?, -- a flat disc (Cylinder part standing up): sx = sz = width, sy = height
}

local LobbyWater = {}

LobbyWater.BANK = 24 -- grass bank ring past ground() on every side
LobbyWater.DOCK_FREE = 4 -- outer strip of the bank kept clear for docks
LobbyWater.SAND = 6 -- sand shore past the bank
LobbyWater.SHALLOW = 16 -- light water past the sand
LobbyWater.REACH = 600 -- deep water goes this far
LobbyWater.WALL = 70 -- invisible wall this far past the bank (people cannot wander off)

LobbyWater.GRASS_TOP = -0.15 -- a hair under the lobby grass (-0.05)
LobbyWater.SAND_TOP = -0.5
LobbyWater.SHALLOW_TOP = -0.75
LobbyWater.WATER_TOP = -0.8
LobbyWater.BED_TOP = -2.5 -- the lake floor: you wade in up to your waist
LobbyWater.DECK_TOP = 0.6 -- dock and bridge floors
-- Underwater steps from the sand down to the lake floor, so you can walk back out without
-- jumping: { top, how far past the bank it reaches }. The first one is wide enough to sit under
-- every shore bump.
LobbyWater.STEPS = { { -1.0, 22 }, { -1.5, 26 }, { -2.0, 30 } }

local GRASS = { 116, 186, 82 } -- same as the lobby grass
local SAND = { 226, 205, 150 }
local SHALLOW = { 110, 205, 235 }
local DEEP = { 55, 150, 225 }
local BED = { 70, 120, 140 }
local PLANK_A = { 160, 110, 70 }
local PLANK_B = { 140, 95, 60 }
local POST = { 105, 72, 45 }

local function grow(b: Box, d: number): Box
	return { minX = b.minX - d, maxX = b.maxX + d, minZ = b.minZ - d, maxZ = b.maxZ + d }
end

-- The bank box: ground() plus the grass bank. Landscaping props stay inside grow(bank, -DOCK_FREE).
function LobbyWater.bankBox(): Box
	return grow(LobbyLayout.ground(), LobbyWater.BANK)
end

local function piece(
	out: { Piece },
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: { number },
	collide: boolean,
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
		collide = collide,
	}
	table.insert(out, p)
	return p
end

-- a flat slab covering box b, top at `top`
local function slab(
	out: { Piece },
	name: string,
	b: Box,
	top: number,
	thick: number,
	color: { number },
	collide: boolean
)
	piece(
		out,
		name,
		(b.minX + b.maxX) / 2,
		top - thick / 2,
		(b.minZ + b.maxZ) / 2,
		b.maxX - b.minX,
		thick,
		b.maxZ - b.minZ,
		color,
		collide
	)
end

-- a square ring between box `inner` and box `outer`, as 4 slabs that never overlap
local function ring(
	out: { Piece },
	name: string,
	inner: Box,
	outer: Box,
	top: number,
	thick: number,
	color: { number },
	collide: boolean
)
	slab(
		out,
		name,
		{ minX = outer.minX, maxX = outer.maxX, minZ = outer.minZ, maxZ = inner.minZ },
		top,
		thick,
		color,
		collide
	)
	slab(
		out,
		name,
		{ minX = outer.minX, maxX = outer.maxX, minZ = inner.maxZ, maxZ = outer.maxZ },
		top,
		thick,
		color,
		collide
	)
	slab(
		out,
		name,
		{ minX = outer.minX, maxX = inner.minX, minZ = inner.minZ, maxZ = inner.maxZ },
		top,
		thick,
		color,
		collide
	)
	slab(
		out,
		name,
		{ minX = inner.maxX, maxX = outer.maxX, minZ = inner.minZ, maxZ = inner.maxZ },
		top,
		thick,
		color,
		collide
	)
end

-- Turned squares every ~`step` studs round box b's edge, middles pushed `push` studs out, sizes
-- and turns picked by a fixed little number sequence (same shore every time).
local function wavy(
	out: { Piece },
	name: string,
	b: Box,
	push: number,
	step: number,
	top: number,
	thick: number,
	color: { number },
	collide: boolean,
	seed: number
)
	local n = seed
	local function nextSize(): number
		n = (n * 37 + 11) % 101
		return step * (0.6 + 0.9 * n / 100)
	end
	local sides = {
		{ b.minX, b.minZ, b.maxX, b.minZ, 0, -1 },
		{ b.maxX, b.minZ, b.maxX, b.maxZ, 1, 0 },
		{ b.maxX, b.maxZ, b.minX, b.maxZ, 0, 1 },
		{ b.minX, b.maxZ, b.minX, b.minZ, -1, 0 },
	}
	for _, sd in sides do
		local x0, z0, x1, z1, nx, nz = sd[1], sd[2], sd[3], sd[4], sd[5], sd[6]
		local len = math.abs(x1 - x0) + math.abs(z1 - z0)
		local count = math.max(1, math.floor(len / step))
		for i = 0, count - 1 do
			local t = (i + 0.5) / count
			local size = nextSize()
			local x = x0 + (x1 - x0) * t + nx * push
			local z = z0 + (z1 - z0) * t + nz * push
			piece(out, name, x, top - thick / 2, z, size, thick, size, color, collide, 20 + n % 50)
		end
	end
end

-- Something placed in its own little frame: local (lx, ly, lz) turned by `ry` round the up axis
-- and moved to (x, y, z). Local +z is the thing's front.
local function framed(out: { Piece }, x: number, y: number, z: number, ry: number)
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
		return piece(
			out,
			name,
			x + lx * c + lz * sn,
			y + ly,
			z - lx * sn + lz * c,
			sx,
			sy,
			sz,
			color,
			true,
			ry + (ryExtra or 0),
			rz
		)
	end
end

local BOAT_WHITE = { 236, 236, 230 }
local BOAT_RED = { 205, 60, 50 }

-- A little rowboat floating at (x, z), its bow pointing along `ry`: white hull, red sides, two
-- seats and a pair of oars. You can climb in.
local function boat(out: { Piece }, x: number, z: number, ry: number)
	local put = framed(out, x, LobbyWater.WATER_TOP - 0.2, z, ry)
	put("BoatHull", 0, 0, 0, 3.4, 0.6, 7, BOAT_WHITE)
	put("BoatFloor", 0, 0.35, 0, 3.3, 0.1, 6.9, PLANK_A)
	for _, side in { -1, 1 } do
		put("BoatSide", side * 1.85, 0.35, 0, 0.35, 1.3, 7, BOAT_RED)
		put("BoatTrim", side * 1.85, 1.1, 0, 0.45, 0.2, 7.05, BOAT_WHITE)
		put("BoatOar", side * 0.9, 0.95, 0.3, 0.25, 0.15, 5.5, PLANK_B, side * 8)
	end
	put("BoatStern", 0, 0.35, -3.6, 4.05, 1.3, 0.35, BOAT_RED)
	-- a stepped low-poly bow
	put("BoatBow", 0, 0.2, 4.1, 2.8, 1.6, 1.2, BOAT_RED)
	put("BoatBow", 0, 0.2, 5.1, 1.5, 1.6, 0.9, BOAT_RED)
	put("BoatBowTrim", 0, 1.1, 4.5, 2.9, 0.2, 2.2, BOAT_WHITE)
	put("BoatSeat", 0, 0.75, -1.6, 3.4, 0.25, 0.9, PLANK_B)
	put("BoatSeat", 0, 0.75, 1.8, 3.4, 0.25, 0.9, PLANK_B)
end

-- A red and white life ring hanging on a post. The post stands at (x, z) on a dock's edge; the
-- ring hangs on the post's deck side (local +z points at the deck).
local function lifebuoy(out: { Piece }, x: number, z: number, ry: number)
	local put = framed(out, x, LobbyWater.DECK_TOP, z, ry)
	put("BuoyPost", 0, 1.8, 0, 0.5, 3.6, 0.5, POST)
	local r, n = 1.0, 8
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		put(
			"Buoy",
			math.cos(a) * r,
			2.3 + math.sin(a) * r,
			0.5,
			2 * (r + 0.21) * math.tan(math.pi / n), -- outer edges meet: no gaps
			0.42,
			0.42,
			if i % 2 == 0 then BOAT_RED else BOAT_WHITE,
			0,
			math.deg(a) + 90
		)
	end
end

-- A dock from (x, z) on the bank edge out over the water in direction (dx, dz) (one of the 4
-- sides), `len` long, 6 wide: plank deck on posts, two short posts at the far end.
local function dock(out: { Piece }, x: number, z: number, dx: number, dz: number, len: number)
	local w = 6
	local ry = if dx ~= 0 then 90 else 0 -- planks run across the dock
	local start = -LobbyWater.DOCK_FREE + 0.5 -- starts on the grass so you step straight on
	local plank, gap = 1.1, 0.2
	local deckY = LobbyWater.DECK_TOP - 0.25
	local n = math.floor(len / (plank + gap))
	for i = 0, n - 1 do
		local d = start + (i + 0.5) * (plank + gap)
		piece(
			out,
			"DockPlank",
			x + dx * d,
			deckY,
			z + dz * d,
			w,
			0.5,
			plank,
			if i % 2 == 0 then PLANK_A else PLANK_B,
			true,
			ry
		)
	end
	-- a dark board under the planks so the gaps read as shadow, not water
	local mid = start + n * (plank + gap) / 2
	local full = n * (plank + gap)
	piece(
		out,
		"DockFrame",
		x + dx * mid,
		deckY - 0.35,
		z + dz * mid,
		w - 0.4,
		0.3,
		full,
		POST,
		true,
		ry
	)
	-- posts every 6 studs down both sides (only out in the water), into the lake floor
	local postH = LobbyWater.DECK_TOP - LobbyWater.BED_TOP
	local d = LobbyWater.DOCK_FREE + LobbyWater.SAND
	while d < start + full - 0.5 do
		for _, side in { -1, 1 } do
			local sx, sz = -dz * side * (w / 2), dx * side * (w / 2)
			piece(
				out,
				"DockPost",
				x + dx * d + sx,
				LobbyWater.BED_TOP + postH / 2 - 0.3,
				z + dz * d + sz,
				0.8,
				postH,
				0.8,
				POST,
				true
			)
		end
		d += 6
	end
	-- two bollards at the far end
	local endD = start + full - 0.6
	for _, side in { -1, 1 } do
		local sx, sz = -dz * side * (w / 2 - 0.6), dx * side * (w / 2 - 0.6)
		piece(
			out,
			"DockBollard",
			x + dx * endD + sx,
			LobbyWater.DECK_TOP + 0.6,
			z + dz * endD + sz,
			0.8,
			1.2,
			0.8,
			POST,
			true
		)
	end
end

-- A round island: a sand disc with a grass disc on top.
local function island(out: { Piece }, x: number, z: number, r: number)
	-- the same underwater steps round it as round the shore
	for i, st in LobbyWater.STEPS do
		local w = r * 2 + 5 + i * 6
		piece(out, "IslandStep", x, st[1] - 0.5, z, w, 1, w, SAND, true).round = true
	end
	piece(out, "IslandSand", x, LobbyWater.SAND_TOP - 2, z, r * 2 + 5, 4, r * 2 + 5, SAND, true).round =
		true
	piece(out, "IslandGrass", x, LobbyWater.GRASS_TOP - 1, z, r * 2, 2, r * 2, GRASS, true).round =
		true
end

-- An arched footbridge along x from x0 to x1 at depth z: ramp up, flat top, ramp down, rails.
local function footbridge(out: { Piece }, x0: number, x1: number, z: number)
	local w = 5
	local len = x1 - x0
	local rise = 2.4
	local rampLen = len * 0.3
	local flatLen = len - rampLen * 2
	local tilt = math.deg(math.atan2(rise, rampLen))
	local slope = math.sqrt(rampLen * rampLen + rise * rise)
	local base = LobbyWater.DECK_TOP - 0.25
	-- up ramp (west half rises toward +x), flat, down ramp
	piece(
		out,
		"BridgeDeck",
		x0 + rampLen / 2,
		base + rise / 2,
		z,
		slope,
		0.5,
		w,
		PLANK_A,
		true,
		0,
		tilt
	)
	piece(
		out,
		"BridgeDeck",
		x0 + rampLen + flatLen / 2,
		base + rise,
		z,
		flatLen,
		0.5,
		w,
		PLANK_B,
		true
	)
	piece(
		out,
		"BridgeDeck",
		x1 - rampLen / 2,
		base + rise / 2,
		z,
		slope,
		0.5,
		w,
		PLANK_A,
		true,
		0,
		-tilt
	)
	-- a rail each side: posts plus a top bar over the flat part and down the ramps
	for _, side in { -1, 1 } do
		local rz = z + side * (w / 2 - 0.2)
		piece(
			out,
			"BridgeRail",
			x0 + rampLen / 2,
			base + rise / 2 + 2.2,
			rz,
			slope,
			0.3,
			0.3,
			POST,
			true,
			0,
			tilt
		)
		piece(
			out,
			"BridgeRail",
			x0 + rampLen + flatLen / 2,
			base + rise + 2.2,
			rz,
			flatLen,
			0.3,
			0.3,
			POST,
			true
		)
		piece(
			out,
			"BridgeRail",
			x1 - rampLen / 2,
			base + rise / 2 + 2.2,
			rz,
			slope,
			0.3,
			0.3,
			POST,
			true,
			0,
			-tilt
		)
		for i = 0, 4 do
			local px = x0 + len * i / 4
			local h = if i == 0 or i == 4 then 0 elseif i == 2 then rise else rise * 0.75
			piece(out, "BridgePost", px, base + h + 1.1, rz, 0.4, 2.4, 0.4, POST, true)
		end
	end
	-- posts down into the water under the middle
	for _, px in { x0 + rampLen, x1 - rampLen } do
		for _, side in { -1, 1 } do
			local hTop = base + rise
			local h = hTop - LobbyWater.BED_TOP
			piece(
				out,
				"BridgePier",
				px,
				LobbyWater.BED_TOP + h / 2,
				z + side * (w / 2 - 0.4),
				0.8,
				h,
				0.8,
				POST,
				true
			)
		end
	end
end

export type Landing = { x: number, z: number, dx: number, dz: number }

-- Where each dock meets the bank edge (x, z), which way it points out (dx, dz) and how long it is.
local function docks(): { Landing & { len: number } }
	local g = LobbyLayout.ground()
	local bank = LobbyWater.bankBox()
	local midZ = (g.minZ + g.maxZ) / 2
	return {
		{ x = bank.minX, z = midZ - 20, dx = -1, dz = 0, len = 32 },
		{ x = bank.minX, z = g.maxZ - 40, dx = -1, dz = 0, len = 26 },
		{ x = bank.maxX, z = midZ + 60, dx = 1, dz = 0, len = 32 },
		{ x = (g.minX + g.maxX) / 2 + 30, z = bank.minZ, dx = 0, dz = -1, len = 28 },
	}
end

-- The island's middle (x, z) and radius; the footbridge leaves the right bank in line with it.
local function islandSpot(): (number, number, number)
	local g = LobbyLayout.ground()
	return LobbyWater.bankBox().maxX + 38, g.minZ + 40, 14
end

-- The island footbridge: from x0 (on the bank) to x1 (on the island) along depth z.
function LobbyWater.bridgeSpan(): (number, number, number)
	local isX, isZ, isR = islandSpot()
	return LobbyWater.bankBox().maxX - LobbyWater.DOCK_FREE + 0.5, isX - isR + 2, isZ
end

-- Every dock and the footbridge, where it meets the bank edge and which way it points out
-- (landscaping opens its fence and keeps a walking lane clear in line with each one).
function LobbyWater.landings(): { Landing }
	local out: { Landing } = {}
	for _, d in docks() do
		table.insert(out, { x = d.x, z = d.z, dx = d.dx, dz = d.dz })
	end
	local _, isZ = islandSpot()
	table.insert(out, { x = LobbyWater.bankBox().maxX, z = isZ, dx = 1, dz = 0 })
	return out
end

-- Every piece of the water scenery.
function LobbyWater.pieces(): { Piece }
	local out: { Piece } = {}
	local g = LobbyLayout.ground()
	local bank = LobbyWater.bankBox()
	local sand = grow(bank, LobbyWater.SAND)
	local shallow = grow(sand, LobbyWater.SHALLOW)
	local far = grow(bank, LobbyWater.REACH)

	-- grass under everything (the lobby's own grass sits on top inside ground())
	slab(out, "Bank", bank, LobbyWater.GRASS_TOP, 2, GRASS, true)
	ring(out, "Shore", bank, sand, LobbyWater.SAND_TOP, 4.5, SAND, true)
	-- a wavy shore: turned sand squares along the bank edge poke out into the water, and turned
	-- light-water squares along the sand edge poke into the deep water
	wavy(out, "ShoreBump", bank, 0, 18, LobbyWater.SAND_TOP, 4.5, SAND, true, 1)
	wavy(out, "ShallowBump", shallow, -6, 28, LobbyWater.SHALLOW_TOP - 0.02, 0.3, SHALLOW, false, 7)
	-- water: light near the shore, deep further out; you can walk in (no collide)
	ring(out, "Shallow", sand, shallow, LobbyWater.SHALLOW_TOP, 0.3, SHALLOW, false)
	ring(out, "Water", shallow, far, LobbyWater.WATER_TOP, 0.3, DEEP, false)
	local inner = bank
	for _, st in LobbyWater.STEPS do
		local outer = grow(bank, st[2])
		ring(out, "ShoreStep", inner, outer, st[1], 1, SAND, true)
		inner = outer
	end
	ring(out, "LakeBed", inner, far, LobbyWater.BED_TOP, 1, BED, true)

	-- docks: two on the left, one on the right, one off the back
	for _, d in docks() do
		dock(out, d.x, d.z, d.dx, d.dz, d.len)
	end

	-- a small island off the back-right, reached by an arched footbridge from the right bank
	local isX, isZ, isR = islandSpot()
	island(out, isX, isZ, isR)
	local b0, b1, bz = LobbyWater.bridgeSpan()
	footbridge(out, b0, b1, bz)

	-- a rowboat tied up beside the right dock, and life rings by two docks
	local ds = docks()
	local bd = ds[3]
	local along = LobbyWater.DOCK_FREE + LobbyWater.SAND + 9
	local beside = 3 + 0.4 + 2 -- half the dock, a gap, half the boat
	boat(
		out,
		bd.x + bd.dx * along - bd.dz * beside,
		bd.z + bd.dz * along + bd.dx * beside,
		if bd.dx ~= 0 then 90 * bd.dx else 0
	)
	for _, i in { 1, 3 } do
		local d = ds[i]
		local at = LobbyWater.DOCK_FREE + LobbyWater.SAND + 1
		-- on the side away from the boat, ring facing across the deck
		local side = -1
		local px = d.x + d.dx * at - d.dz * side * 3.3
		local pz = d.z + d.dz * at + d.dx * side * 3.3
		-- local +z must point from the post back toward the deck middle
		local tx, tz = d.dz * side, -d.dx * side
		lifebuoy(out, px, pz, math.deg(math.atan2(tx, tz)))
	end

	-- invisible walls so people cannot wander off across the lake floor
	local wall = grow(bank, LobbyWater.WALL)
	local h = 30
	for _, w in
		{
			{ (wall.minX + wall.maxX) / 2, wall.minZ, wall.maxX - wall.minX, 1 },
			{ (wall.minX + wall.maxX) / 2, wall.maxZ, wall.maxX - wall.minX, 1 },
			{ wall.minX, (wall.minZ + wall.maxZ) / 2, 1, wall.maxZ - wall.minZ },
			{ wall.maxX, (wall.minZ + wall.maxZ) / 2, 1, wall.maxZ - wall.minZ },
		}
	do
		local p =
			piece(out, "EdgeWall", w[1], LobbyWater.BED_TOP + h / 2, w[2], w[3], h, w[4], BED, true)
		p.hidden = true
	end
	return out
end

return LobbyWater
