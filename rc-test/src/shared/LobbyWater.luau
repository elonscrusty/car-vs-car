--!strict
-- The lake at the end of the lobby street (past LobbyLayout.ground() on the LAKE_SIDE edge): a
-- grass bank, a wavy sand beach, shallow then deep water, two plank docks with a rowboat each and
-- life rings. A real lake, not the sea: grass and sand all round it, with the landscaping's hills on the
-- far side and the ends (LobbyWater.landBox()).
-- Looks only. Plain numbers (Lune tests load this); LobbyWaterBuilder turns the pieces into Parts.

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

LobbyWater.BANK = 10 -- grass between the lobby's end edge and the beach
LobbyWater.DOCK_FREE = 4 -- outer strip of the bank kept clear for docks
LobbyWater.SAND = 8 -- sand beach past the bank
LobbyWater.SHALLOW = 16 -- light water past the sand
LobbyWater.LAKE_D = 130 -- water from the beach to the far shore
LobbyWater.LAKE_OVER = 30 -- the water runs this far past the lobby's sides
LobbyWater.SHORE = 160 -- grass round the lake's ends and far side, wide enough for the hills

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

-- Which edge of ground() the lake is past: +1 = maxZ (the street end), -1 = minZ.
local function side(): number
	return LobbyLayout.LAKE_SIDE or 1
end

-- The z of a line `d` studs out from the lobby's lake edge.
local function out(d: number): number
	local g = LobbyLayout.ground()
	local s = side()
	return (if s > 0 then g.maxZ else g.minZ) + s * d
end

local function grow(b: Box, d: number): Box
	return { minX = b.minX - d, maxX = b.maxX + d, minZ = b.minZ - d, maxZ = b.maxZ + d }
end

-- The waterline: where the sand meets the water, all round the lake.
function LobbyWater.lakeBox(): Box
	local g = LobbyLayout.ground()
	local a, b =
		out(LobbyWater.BANK + LobbyWater.SAND),
		out(LobbyWater.BANK + LobbyWater.SAND + LobbyWater.LAKE_D)
	return {
		minX = g.minX - LobbyWater.LAKE_OVER,
		maxX = g.maxX + LobbyWater.LAKE_OVER,
		minZ = math.min(a, b),
		maxZ = math.max(a, b),
	}
end

-- All the ground this file lays: the lake, its sand and the grass round it, from the lobby's edge.
function LobbyWater.landBox(): Box
	local l = grow(LobbyWater.lakeBox(), LobbyWater.SAND + LobbyWater.SHORE)
	local edge = out(-2)
	if side() > 0 then
		l.minZ = edge
	else
		l.maxZ = edge
	end
	return l
end

-- The grass bank between the lobby and the beach. Landscaping props stay off its outer
-- DOCK_FREE studs, where the docks start.
function LobbyWater.bankBox(): Box
	local l = LobbyWater.landBox()
	local a, b = out(0), out(LobbyWater.BANK)
	return { minX = l.minX, maxX = l.maxX, minZ = math.min(a, b), maxZ = math.max(a, b) }
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

-- Turned squares every ~`step` studs round box b's edge, middles pushed `push` studs out, sizes
-- and turns from a fixed little number sequence (same shore every time).
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
	for _, sd in
		{
			{ b.minX, b.minZ, b.maxX, b.minZ, 0, -1 },
			{ b.maxX, b.minZ, b.maxX, b.maxZ, 1, 0 },
			{ b.maxX, b.maxZ, b.minX, b.maxZ, 0, 1 },
			{ b.minX, b.maxZ, b.minX, b.minZ, -1, 0 },
		}
	do
		local x0, z0, x1, z1, nx, nz = sd[1], sd[2], sd[3], sd[4], sd[5], sd[6]
		local count = math.max(1, math.floor((math.abs(x1 - x0) + math.abs(z1 - z0)) / step))
		for i = 0, count - 1 do
			n = (n * 37 + 11) % 101
			local size = step * (0.6 + 0.9 * n / 100)
			local t = (i + 0.5) / count
			local x = x0 + (x1 - x0) * t + nx * push
			local z = z0 + (z1 - z0) * t + nz * push
			piece(out, name, x, top - thick / 2, z, size, thick, size, color, collide, 20 + n % 50)
		end
	end
end

-- A square ring between box `inner` and box `outer`, as 4 slabs that never overlap.
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
	for _, b in
		{
			{ minX = outer.minX, maxX = outer.maxX, minZ = outer.minZ, maxZ = inner.minZ },
			{ minX = outer.minX, maxX = outer.maxX, minZ = inner.maxZ, maxZ = outer.maxZ },
			{ minX = outer.minX, maxX = inner.minX, minZ = inner.minZ, maxZ = inner.maxZ },
			{ minX = inner.maxX, maxX = outer.maxX, minZ = inner.minZ, maxZ = inner.maxZ },
		}
	do
		if b.maxX - b.minX > 0.01 and b.maxZ - b.minZ > 0.01 then
			slab(out, name, b, top, thick, color, collide)
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
			LobbyWater.RING_UP + math.sin(a) * r,
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

export type Landing = { x: number, z: number, dx: number, dz: number }

-- Where each dock meets the bank edge (x, z), which way it points out (dx, dz) and how long it is:
-- two, a quarter of the lobby's width either side of the road.
local function docks(): { Landing & { len: number } }
	local g = LobbyLayout.ground()
	local mid = (g.minX + g.maxX) / 2
	local off = (g.maxX - g.minX) / 4
	local z = out(LobbyWater.BANK)
	return {
		{ x = mid - off, z = z, dx = 0, dz = side(), len = 30 },
		{ x = mid + off, z = z, dx = 0, dz = side(), len = 34 },
	}
end

-- The rowboats: middle (x, z) and which way each bow points (degrees round the up axis; 0 = +z).
-- One is tied up on the outer side of each dock.
function LobbyWater.boatSpots(): { { x: number, z: number, ry: number } }
	local out = {}
	for i, d in docks() do
		local along = LobbyWater.SAND + 14
		local beside = 3 + 0.4 + 2 -- half the dock, a gap, half the boat
		local sx = if i == 2 then 1 else -1 -- the outer side
		table.insert(out, {
			x = d.x + sx * beside,
			z = d.z + d.dz * along,
			ry = if d.dz > 0 then 0 else 180,
		})
	end
	return out
end

-- The far end of each dock: middle of its last plank's outer edge (x, z) and which way it points
-- out (dz), for the fishing spots.
function LobbyWater.dockEnds(): { { x: number, z: number, dz: number } }
	local out = {}
	local plank, gap = 1.1, 0.2
	for _, d in docks() do
		local n = math.floor(d.len / (plank + gap))
		local e = -LobbyWater.DOCK_FREE + 0.5 + n * (plank + gap) - gap
		table.insert(out, { x = d.x, z = d.z + d.dz * e, dz = d.dz })
	end
	return out
end

-- The life ring posts: where each stands on a dock edge, and `ry` turning local +z from the post
-- toward the deck middle (the ring hangs on that side, LobbyWater.RING_UP above the deck).
LobbyWater.RING_UP = 2.3
function LobbyWater.ringSpots(): { { x: number, z: number, ry: number } }
	local out = {}
	for i, d in docks() do
		local at = LobbyWater.SAND + 2
		local sx = if i == 2 then -1 else 1 -- the side away from the boat
		table.insert(out, {
			x = d.x + sx * 3.3,
			z = d.z + d.dz * at,
			ry = if sx > 0 then -90 else 90,
		})
	end
	return out
end

-- Every dock, where it meets the bank edge and which way it points out (landscaping keeps a
-- walking lane clear in line with each one).
function LobbyWater.landings(): { Landing }
	local out: { Landing } = {}
	for _, d in docks() do
		table.insert(out, { x = d.x, z = d.z, dx = d.dx, dz = d.dz })
	end
	return out
end

-- Every piece of the lake.
function LobbyWater.pieces(): { Piece }
	local out: { Piece } = {}
	local W = LobbyWater
	local lake = W.lakeBox()
	local sand = grow(lake, W.SAND)
	local shallow = grow(lake, -W.SHALLOW)

	-- grass from the lobby's edge round the lake, a sand rim with a wavy edge into the water
	ring(out, "Bank", sand, W.landBox(), W.GRASS_TOP, 2, GRASS, true)
	ring(out, "Shore", lake, sand, W.SAND_TOP, 4.5, SAND, true)
	wavy(out, "ShoreBump", lake, 0, 18, W.SAND_TOP, 4.5, SAND, true, 1)
	wavy(out, "ShallowBump", shallow, 4, 28, W.SHALLOW_TOP - 0.02, 0.3, SHALLOW, false, 7)
	-- water: light near the shore, deep in the middle; you can walk in (no collide)
	ring(out, "Shallow", shallow, lake, W.SHALLOW_TOP, 0.3, SHALLOW, false)
	slab(out, "Water", shallow, W.WATER_TOP, 0.3, DEEP, false)
	-- small underwater steps from the lake floor up to the sand, so you can walk back out
	-- (STEPS distances count from the outer edge of the sand)
	local last = lake
	for _, st in W.STEPS do
		local inner = grow(sand, -st[2])
		ring(out, "ShoreStep", inner, last, st[1], 1, SAND, true)
		last = inner
	end
	slab(out, "LakeBed", last, W.BED_TOP, 1, BED, true)

	for _, d in docks() do
		dock(out, d.x, d.z, d.dx, d.dz, d.len)
	end
	for _, b in W.boatSpots() do
		boat(out, b.x, b.z, b.ry)
	end
	for _, r in W.ringSpots() do
		lifebuoy(out, r.x, r.z, r.ry)
	end

	-- invisible walls round the land's three outer sides, so people cannot wander off
	local l = W.landBox()
	local h = 30
	local farZ = if side() > 0 then l.maxZ else l.minZ
	for _, w in
		{
			{ (l.minX + l.maxX) / 2, farZ, l.maxX - l.minX, 1 },
			{ l.minX, (l.minZ + l.maxZ) / 2, 1, l.maxZ - l.minZ },
			{ l.maxX, (l.minZ + l.maxZ) / 2, 1, l.maxZ - l.minZ },
		}
	do
		local p = piece(out, "EdgeWall", w[1], W.BED_TOP + h / 2, w[2], w[3], h, w[4], BED, true)
		p.hidden = true
	end
	return out
end

return LobbyWater
