--!strict
-- The lobby's outside look: leafy trees, pines, bushes, hedges, boulders, corner cliffs, the wooden
-- fence round the lobby and low fences between the small plots. Low-poly flat colours, no text.
-- Pure placement (plain numbers, Lune tests load this); SceneryBuilder turns pieces into Parts.
--
-- Where it goes (agreed with the lobby, plaza and water threads):
--   * inside LobbyLayout.ground(): only the grass strips round the plots and plaza, and the gaps
--     between plots (never on the road, footpaths, plots or PLAZA; plot gaps stay walkable);
--   * outside ground(): the first BAND studs of the water thread's grass bank (its outer 4 studs
--     are where the docks start).
-- The fence has an opening in the middle of each side: the way out to a dock.

local function sibling(name: string): any
	if script then
		local node: any = (script :: any).Parent
		for _, part in string.split(name, "/") do
			node = node[part]
		end
		return require(node)
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local LobbyLayout = sibling("LobbyLayout")

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Piece = {
	kind: string, -- what it is part of: Tree, Pine, Bush, Hedge, Rock, Cliff, Fence
	shape: string, -- "Block" or "Wedge" (a wedge's tall side is its local +z)
	x: number, -- middle
	y: number,
	z: number,
	sx: number, -- size
	sy: number,
	sz: number,
	rx: number, -- turn, degrees (applied y, then x, then z: CFrame.fromEulerAnglesYXZ)
	ry: number,
	rz: number,
	r: number, -- colour 0-255
	g: number,
	b: number,
	solid: boolean, -- people and cars bump into it
}

local LobbyScenery = {}

LobbyScenery.BAND = 20 -- how far past ground() the scenery reaches (onto the water bank)
LobbyScenery.FENCE_IN = 1.5 -- the outer fence sits this far inside ground()
LobbyScenery.OPENING = 8 -- half width of each fence opening
LobbyScenery.FENCE_H = 2.4 -- outer fence height (a person is about 5)
LobbyScenery.LOW_FENCE_H = 1.4 -- the fences between plots, knee high
LobbyScenery.POST_STEP = 7
LobbyScenery.MAX_PIECES = 1800 -- phones: keep it light

-- colours
local LEAF = { { 96, 172, 72 }, { 120, 190, 84 }, { 76, 150, 62 } }
local PINE = { { 44, 122, 74 }, { 56, 140, 84 } }
local TRUNK = { 112, 78, 48 }
local ROCK = { { 122, 126, 134 }, { 142, 146, 154 }, { 104, 108, 116 } }
local BUSH = { { 92, 166, 70 }, { 108, 178, 76 } }
local HEDGE = { 64, 132, 58 }
local POST = { 122, 84, 50 }
local RAIL = { 152, 106, 62 }

-- The outer box of the scenery.
function LobbyScenery.outer(): Box
	local g = LobbyLayout.ground()
	local b = LobbyScenery.BAND
	return { minX = g.minX - b, maxX = g.maxX + b, minZ = g.minZ - b, maxZ = g.maxZ + b }
end

-- Middle of each fence opening, one per side (z for the left/right sides, x for back/front):
-- the water thread lines its docks up with these.
function LobbyScenery.openings(): { side: number, back: number, front: number }
	-- sides: the middle gap between plot rows
	local mid = LobbyLayout.FIRST_Z + (LobbyLayout.ROWS / 2 - 0.5) * LobbyLayout.STEP
	return { side = mid, back = 0, front = 0 }
end

-- Boxes nothing may stand in: plots, the road and footpaths, the plaza (all padded a little).
function LobbyScenery.keepOut(): { Box }
	local out: { Box } = {}
	local function pad(b: Box, p: number): Box
		return { minX = b.minX - p, maxX = b.maxX + p, minZ = b.minZ - p, maxZ = b.maxZ + p }
	end
	local hw, hd = LobbyLayout.PLOT_W / 2, LobbyLayout.PLOT_D / 2
	for _, s in LobbyLayout.slots() do
		table.insert(
			out,
			pad({
				minX = s.plotX - hd,
				maxX = s.plotX + hd,
				minZ = s.plotZ - hw,
				maxZ = s.plotZ + hw,
			}, 1)
		)
	end
	table.insert(out, pad(LobbyLayout.walks(), 2))
	table.insert(out, pad(LobbyLayout.PLAZA, 2))
	return out
end

-- Is a round thing of this radius clear of every keep-out box?
function LobbyScenery.clear(x: number, z: number, radius: number): boolean
	for _, b in LobbyScenery.keepOut() do
		if
			x + radius > b.minX
			and x - radius < b.maxX
			and z + radius > b.minZ
			and z - radius < b.maxZ
		then
			return false
		end
	end
	return true
end

-- Same numbers every run (no math.random: the picture and Studio must match).
local function rng(seed: number): (number, number) -> number
	local state = seed
	return function(lo: number, hi: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * (state / 2147483648)
	end
end

function LobbyScenery.pieces(): { Piece }
	local out: { Piece } = {}
	local rand = rng(20261023)

	local function add(
		kind: string,
		shape: string,
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		rx: number,
		ry: number,
		rz: number,
		c: { number },
		solid: boolean
	)
		table.insert(out, {
			kind = kind,
			shape = shape,
			x = x,
			y = y,
			z = z,
			sx = sx,
			sy = sy,
			sz = sz,
			rx = rx,
			ry = ry,
			rz = rz,
			r = c[1],
			g = c[2],
			b = c[3],
			solid = solid,
		})
	end

	local function pick(list: { { number } }): { number }
		return list[math.floor(rand(1, #list + 0.999))]
	end

	local free = LobbyScenery.clear

	-- leafy tree: trunk + three tilted blocks
	local function tree(x: number, z: number, s: number)
		local h = 5 * s
		add("Tree", "Block", x, h / 2, z, 1.2 * s, h, 1.2 * s, 0, rand(0, 90), 0, TRUNK, true)
		local c = pick(LEAF)
		for i, k in { { 0, 0, 6.4 }, { 1.6, 1.8, 4.8 }, { -1.4, 2.6, 4.2 } } do
			local a = rand(0, math.pi * 2)
			local dx, dz = math.cos(a) * k[1] * s, math.sin(a) * k[1] * s
			local sz = k[3] * s
			add(
				"Tree",
				"Block",
				x + dx,
				h + 1.5 * s + k[2] * s,
				z + dz,
				sz,
				sz * 0.85,
				sz,
				rand(-25, 25),
				rand(0, 90),
				rand(-25, 25),
				if i == 2 then pick(LEAF) else c,
				false
			)
		end
	end

	-- pine: trunk + two four-sided tiers (each tier = 4 wedges whose tall sides meet in the middle)
	local function pine(x: number, z: number, s: number)
		local h = 3 * s
		add("Pine", "Block", x, h / 2, z, 1 * s, h, 1 * s, 0, 0, 0, TRUNK, true)
		local c = pick(PINE)
		local base = h - 0.5 * s
		for _, tier in { { 7, 6 }, { 5, 5 } } do
			local w, th = tier[1] * s, tier[2] * s
			local y = base + th / 2
			-- ry 0: tall side at +z, so it sits on the -z half; ry 90: tall side at +x, -x half
			add("Pine", "Wedge", x, y, z - w / 4, w, th, w / 2, 0, 0, 0, c, false)
			add("Pine", "Wedge", x, y, z + w / 4, w, th, w / 2, 0, 180, 0, c, false)
			add("Pine", "Wedge", x - w / 4, y, z, w, th, w / 2, 0, 90, 0, c, false)
			add("Pine", "Wedge", x + w / 4, y, z, w, th, w / 2, 0, 270, 0, c, false)
			base += th * 0.55
		end
	end

	local function bush(x: number, z: number, s: number)
		local c = pick(BUSH)
		add(
			"Bush",
			"Block",
			x,
			0.9 * s,
			z,
			2.6 * s,
			1.8 * s,
			2.6 * s,
			rand(-15, 15),
			rand(0, 90),
			rand(-15, 15),
			c,
			false
		)
		add(
			"Bush",
			"Block",
			x + 1.1 * s,
			0.7 * s,
			z + rand(-1, 1) * s,
			1.8 * s,
			1.4 * s,
			1.8 * s,
			rand(-20, 20),
			rand(0, 90),
			rand(-20, 20),
			pick(BUSH),
			false
		)
	end

	-- boulder: a few tilted grey blocks; cliffs are big tall ones
	local function rock(x: number, z: number, s: number, kind: string)
		local n = if kind == "Cliff" then 4 else 2
		for i = 1, n do
			local w = rand(3, 5) * s
			local hh = if kind == "Cliff" then rand(4, 7) * s else rand(1.8, 3.2) * s
			local d = if i == 1 then 0 else rand(1, 2.2) * s
			local a = rand(0, math.pi * 2)
			add(
				kind,
				"Block",
				x + math.cos(a) * d,
				hh * 0.4,
				z + math.sin(a) * d,
				w,
				hh,
				w * rand(0.7, 1),
				rand(-18, 18),
				rand(0, 90),
				rand(-18, 18),
				pick(ROCK),
				true
			)
		end
	end

	local function treeAny(x: number, z: number, s: number)
		if rand(0, 1) < 0.5 then
			tree(x, z, s)
		else
			pine(x, z, s)
		end
	end

	-- fence along x (dir = "x") or z, from a to b at the other coordinate c
	local function fence(dir: string, a: number, b: number, c: number, height: number)
		local len = b - a
		if len < 1 then
			return
		end
		local mid = (a + b) / 2
		local function at(t: number): (number, number)
			if dir == "x" then
				return t, c
			end
			return c, t
		end
		local posts = math.max(1, math.ceil(len / LobbyScenery.POST_STEP))
		for i = 0, posts do
			local px, pz = at(a + len * i / posts)
			add("Fence", "Block", px, height / 2, pz, 0.45, height, 0.45, 0, 0, 0, POST, true)
		end
		for _, f in { 0.45, 0.8 } do
			local mx, mz = at(mid)
			local sx, sz = if dir == "x" then len else 0.2, if dir == "x" then 0.2 else len
			add("Fence", "Block", mx, height * f, mz, sx, 0.3, sz, 0, 0, 0, RAIL, true)
		end
	end

	local g = LobbyLayout.ground()
	local o = LobbyScenery.outer()
	local op = LobbyScenery.openings()
	local OPEN = LobbyScenery.OPENING
	local FI = LobbyScenery.FENCE_IN
	local FH = LobbyScenery.FENCE_H

	-- 1. outer fence, with an opening in the middle of each side
	for _, xEdge in { g.minX + FI, g.maxX - FI } do
		fence("z", g.minZ + FI, op.side - OPEN, xEdge, FH)
		fence("z", op.side + OPEN, g.maxZ - FI, xEdge, FH)
	end
	for _, zEdge in { g.minZ + FI, g.maxZ - FI } do
		fence("x", g.minX + FI, op.back - OPEN, zEdge, FH)
		fence("x", op.back + OPEN, g.maxX - FI, zEdge, FH)
	end

	-- 2. low fences down the middle of each gap between plot rows: from a little back from the
	--    footpath (so the gap's mouth stays open) to the back of the plots
	local front = LobbyLayout.EDGE + 8
	local back = LobbyLayout.EDGE + LobbyLayout.PLOT_D
	for row = 1, LobbyLayout.ROWS - 1 do
		local z = LobbyLayout.FIRST_Z + (row - 0.5) * LobbyLayout.STEP
		fence("x", -back, -front, z, LobbyScenery.LOW_FENCE_H)
		fence("x", front, back, z, LobbyScenery.LOW_FENCE_H)
		for _, side in { -1, 1 } do
			bush(side * (back + 2.5), z, 0.9) -- where the gap meets the side strip
		end
	end

	local function nearOpening(x: number, z: number, r: number): boolean
		local onSide = math.abs(z - op.side) < OPEN + r
		local onEnd = math.abs(x - op.back) < OPEN + r
		return (onSide and (x < g.minX + 30 or x > g.maxX - 30))
			or (onEnd and (z < g.minZ + 30 or z > g.maxZ - 30))
	end

	-- 3. inside ground(): side strips (between the plot backs / plaza and the fence)
	local stripX = (back + g.maxX - FI) / 2 + 1
	local zz = g.minZ + 7
	while zz < g.maxZ - 5 do
		for _, side in { -1, 1 } do
			local x = side * stripX + rand(-1.2, 1.2)
			local z = zz + rand(-1.5, 1.5)
			if free(x, z, 3) and not nearOpening(x, z, 3) then
				treeAny(x, z, rand(0.9, 1.15))
			end
		end
		zz += 12
	end
	-- hedges just inside the side fences, one run per stretch between the opening and the ends
	for _, side in { -1, 1 } do
		local hx = side * (g.maxX - FI - 1.6)
		for _, run in { { g.minZ + 6, op.side - OPEN - 2 }, { op.side + OPEN + 2, g.maxZ - 6 } } do
			local a, b = run[1], run[2]
			add("Hedge", "Block", hx, 0.9, (a + b) / 2, 1.8, 1.8, b - a, 0, 0, 0, HEDGE, true)
		end
	end
	-- back strip (behind the far end of the road): trees, bushes by the road end; front strip
	-- (past the plaza, only 14 deep): bushes
	for _, strip in { { g.minZ + 8, true }, { g.maxZ - 7, false } } do
		local zLine, trees = strip[1] :: number, strip[2] :: boolean
		local x = g.minX + 10
		while x < g.maxX - 9 do
			local px, pz = x + rand(-1, 1), zLine + rand(-1, 1)
			if free(px, pz, 3) and not nearOpening(px, pz, 3) then
				if trees and math.abs(px) > 18 then
					treeAny(px, pz, rand(0.85, 1.05))
				else
					bush(px, pz, rand(0.9, 1.2))
				end
			end
			x += 11
		end
	end

	-- 4. the bank outside ground(): a row of trees, then boulders, bushes between; cliffs at corners
	local function ring(
		offset: number,
		step: number,
		shift: number,
		fn: (x: number, z: number) -> ()
	)
		local minX, maxX = g.minX - offset, g.maxX + offset
		local minZ, maxZ = g.minZ - offset, g.maxZ + offset
		local x = minX + step * shift
		while x < maxX - step / 2 do
			fn(x + rand(-1.5, 1.5), minZ + rand(-1.5, 1.5))
			fn(x + rand(-1.5, 1.5), maxZ + rand(-1.5, 1.5))
			x += step
		end
		local z = minZ + step * shift
		while z < maxZ - step / 2 do
			fn(minX + rand(-1.5, 1.5), z + rand(-1.5, 1.5))
			fn(maxX + rand(-1.5, 1.5), z + rand(-1.5, 1.5))
			z += step
		end
	end
	ring(6, 10, 1, function(x, z)
		if not nearOpening(x, z, 3) then
			treeAny(x, z, rand(1, 1.3))
		end
	end)
	-- a second, gappy row of trees further out, between the first row's trees
	ring(12, 10, 0.5, function(x, z)
		if not nearOpening(x, z, 3) and rand(0, 1) < 0.55 then
			treeAny(x, z, rand(0.9, 1.2))
		end
	end)
	ring(14, 12, 1, function(x, z)
		if not nearOpening(x, z, 4) then
			rock(x, z, rand(1, 1.4), "Rock")
		end
	end)
	ring(2.5, 13, 1, function(x, z)
		if not nearOpening(x, z, 2) and rand(0, 1) < 0.6 then
			bush(x, z, rand(0.8, 1.1))
		end
	end)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local cx = if c[1] < 0 then o.minX + 9 else o.maxX - 9
		local cz = if c[2] < 0 then o.minZ + 9 else o.maxZ - 9
		rock(cx, cz, 1.6, "Cliff")
	end
	return out
end

return LobbyScenery
