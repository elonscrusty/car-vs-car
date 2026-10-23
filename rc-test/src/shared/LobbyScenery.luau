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
local LobbyWater = sibling("LobbyWater")

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
	prop: number, -- which Prop it is the block stand-in for (0 = none: fences, hedges)
}
-- One thing that carter's Meshy model can stand in for (MeshProps, ServerStorage.LobbyMeshes).
export type Prop = {
	id: number,
	mesh: string, -- LeafyTree, PineTree, Bush, BigRock, FlatRock, Cactus
	x: number, -- middle of its foot
	z: number,
	height: number, -- studs tall
	turn: number, -- degrees about y
	trunk: number, -- width of the solid trunk under a tree or cactus (0 = whole mesh is solid / not solid)
	solid: boolean,
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

export type Opening = { side: string, at: number } -- side "left"/"right" (at = z), "back"/"front" (at = x)

-- One fence opening per dock and footbridge (LobbyWater.landings), in line with it, with a clear
-- lane from the fence out to it.
function LobbyScenery.openings(): { Opening }
	local out: { Opening } = {}
	for _, l in LobbyWater.landings() do
		if l.dx < 0 then
			table.insert(out, { side = "left", at = l.z })
		elseif l.dx > 0 then
			table.insert(out, { side = "right", at = l.z })
		elseif l.dz < 0 then
			table.insert(out, { side = "back", at = l.x })
		else
			table.insert(out, { side = "front", at = l.x })
		end
	end
	return out
end

-- Is a round thing of this radius in a lane out to a dock (from inside the fence to the bank edge)?
-- Lanes end at outer(): the island and the water are not lanes.
function LobbyScenery.inLane(x: number, z: number, r: number): boolean
	local g = LobbyLayout.ground()
	local ob = LobbyScenery.outer()
	if x < ob.minX or x > ob.maxX or z < ob.minZ or z > ob.maxZ then
		return false -- out on the water (the island, the far end of a bridge)
	end
	local w = LobbyScenery.OPENING + r
	local reach = 14 -- how far inside the fence the lane starts
	for _, o in LobbyScenery.openings() do
		if o.side == "left" and x < g.minX + reach + r and math.abs(z - o.at) < w then
			return true
		elseif o.side == "right" and x > g.maxX - reach - r and math.abs(z - o.at) < w then
			return true
		elseif o.side == "back" and z < g.minZ + reach + r and math.abs(x - o.at) < w then
			return true
		elseif o.side == "front" and z > g.maxZ - reach - r and math.abs(x - o.at) < w then
			return true
		end
	end
	return false
end

-- The island (LobbyWater's IslandGrass disc): middle and radius, or nil.
function LobbyScenery.island(): (number?, number, number)
	for _, pc in LobbyWater.pieces() do
		if pc.name == "IslandGrass" then
			return pc.x, pc.z, pc.sx / 2
		end
	end
	return nil, 0, 0
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

-- Every block piece, and the props they make up (a Meshy model replaces a prop's pieces).
function LobbyScenery.layout(): ({ Piece }, { Prop })
	local out: { Piece } = {}
	local props: { Prop } = {}
	local current = 0
	local rand = rng(20261023)

	-- start a new prop: the pieces added until done() are its block stand-in
	local function begin(
		mesh: string,
		x: number,
		z: number,
		height: number,
		trunk: number,
		solid: boolean
	)
		current = #props + 1
		table.insert(props, {
			id = current,
			mesh = mesh,
			x = x,
			z = z,
			height = height,
			turn = rand(0, 360),
			trunk = trunk,
			solid = solid,
		})
	end
	local function done()
		current = 0
	end

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
			prop = current,
		})
	end

	local function pick(list: { { number } }): { number }
		return list[math.floor(rand(1, #list + 0.999))]
	end

	local free = LobbyScenery.clear

	-- leafy tree: trunk + three tilted blocks
	local function tree(x: number, z: number, s: number)
		begin("LeafyTree", x, z, 12 * s, 1.2 * s, false)
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
		begin("PineTree", x, z, 13 * s, 1 * s, false)
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
		begin("Bush", x, z, 2.2 * s, 0, false)
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
		if kind == "Cliff" then
			begin("BigRock", x, z, 6 * s, 0, true)
		elseif rand(0, 1) < 0.5 then
			begin("BigRock", x, z, 3.5 * s, 0, true)
		else
			begin("FlatRock", x, z, 2.2 * s, 0, true)
		end
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

	local WOOD = { 128, 88, 54 }
	-- tree stump or a fallen log, beside a tree
	local function stumpOrLog(x: number, z: number)
		if rand(0, 1) < 0.5 then
			begin("TreeStump", x, z, 1.4, 1.4, true)
			add("Stump", "Block", x, 0.6, z, 1.6, 1.2, 1.6, 0, rand(0, 90), 0, WOOD, true)
		else
			begin("Log", x, z, 1.3, 0, true)
			add("Log", "Block", x, 0.6, z, 3.6, 1.2, 1.2, 0, rand(0, 180), 0, WOOD, true)
		end
	end

	-- a small heap of grey stones
	local function rockPile(x: number, z: number, s: number)
		begin("RockPile", x, z, 2.2 * s, 0, true)
		for i = 1, 3 do
			local a = i * 2.1
			add(
				"RockPile",
				"Block",
				x + math.cos(a) * 0.9 * s,
				0.6 * s,
				z + math.sin(a) * 0.9 * s,
				1.6 * s,
				1.3 * s,
				1.5 * s,
				rand(-20, 20),
				rand(0, 90),
				rand(-20, 20),
				pick(ROCK),
				true
			)
		end
	end

	local function hayBale(x: number, z: number)
		begin("HayBale", x, z, 1.8, 0, true)
		add(
			"HayBale",
			"Block",
			x,
			0.9,
			z,
			3.4,
			1.8,
			1.8,
			0,
			rand(0, 180),
			0,
			{ 222, 190, 100 },
			true
		)
	end

	-- cactus: a green column with two arms
	local function cactus(x: number, z: number, s: number)
		begin("Cactus", x, z, 4.5 * s, 0.9 * s, false)
		local c = { 86, 150, 78 }
		add("Cactus", "Block", x, 2.2 * s, z, 1.1 * s, 4.4 * s, 1.1 * s, 0, 0, 0, c, true)
		add("Cactus", "Block", x - 0.9 * s, 2 * s, z, 0.8 * s, 0.6 * s, 0.7 * s, 0, 0, 0, c, false)
		add(
			"Cactus",
			"Block",
			x - 1.2 * s,
			2.7 * s,
			z,
			0.7 * s,
			1.6 * s,
			0.7 * s,
			0,
			0,
			0,
			c,
			false
		)
		add(
			"Cactus",
			"Block",
			x + 0.9 * s,
			2.8 * s,
			z,
			0.8 * s,
			0.6 * s,
			0.7 * s,
			0,
			0,
			0,
			c,
			false
		)
		add(
			"Cactus",
			"Block",
			x + 1.2 * s,
			3.4 * s,
			z,
			0.7 * s,
			1.3 * s,
			0.7 * s,
			0,
			0,
			0,
			c,
			false
		)
	end

	local function treeAny(x: number, z: number, s: number)
		if rand(0, 1) < 0.5 then
			tree(x, z, s)
		else
			pine(x, z, s)
		end
		-- now and then a stump or a fallen log at its foot (toward the lobby, kept off the paths)
		if rand(0, 1) < 0.14 then
			local g = LobbyLayout.ground()
			local dx, dz = (g.minX + g.maxX) / 2 - x, (g.minZ + g.maxZ) / 2 - z
			local len = math.sqrt(dx * dx + dz * dz)
			local sx, sz =
				x + dx / len * 3.5 + rand(-1.5, 1.5), z + dz / len * 3.5 + rand(-1.5, 1.5)
			if LobbyScenery.clear(sx, sz, 2) and not LobbyScenery.inLane(sx, sz, 2) then
				stumpOrLog(sx, sz)
			end
		end
	end

	-- fence along x (dir = "x") or z, from a to b at the other coordinate c
	local function fence(dir: string, a: number, b: number, c: number, height: number)
		done()
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

	-- 1. outer fence, open in line with each dock
	-- runs from a to b with the cuts (opening middles) taken out
	local function runs(a: number, b: number, cuts: { number }, gap: number): { { number } }
		table.sort(cuts)
		local out: { { number } } = {}
		local from = a
		for _, c in cuts do
			if c - gap > from then
				table.insert(out, { from, c - gap })
			end
			from = math.max(from, c + gap)
		end
		if b > from then
			table.insert(out, { from, b })
		end
		return out
	end
	local cuts: { [string]: { number } } = { left = {}, right = {}, back = {}, front = {} }
	for _, o in op do
		table.insert(cuts[o.side], o.at)
	end
	for _, e in { { "left", g.minX + FI }, { "right", g.maxX - FI } } do
		for _, r in runs(g.minZ + FI, g.maxZ - FI, cuts[e[1]], OPEN) do
			fence("z", r[1], r[2], e[2] :: number, FH)
		end
	end
	for _, e in { { "back", g.minZ + FI }, { "front", g.maxZ - FI } } do
		for _, r in runs(g.minX + FI, g.maxX - FI, cuts[e[1]], OPEN) do
			fence("x", r[1], r[2], e[2] :: number, FH)
		end
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

	local nearOpening = LobbyScenery.inLane

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
		for _, run in
			runs(g.minZ + 6, g.maxZ - 6, cuts[if side < 0 then "left" else "right"], OPEN + 2)
		do
			local a, b = run[1], run[2]
			done()
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
			if rand(0, 1) < 0.3 then
				rockPile(x, z, rand(1, 1.3))
			else
				rock(x, z, rand(1, 1.4), "Rock")
			end
			-- now and then a cactus beside the rock, on its lobby side
			if rand(0, 1) < 0.22 then
				local mx, mz = (g.minX + g.maxX) / 2, (g.minZ + g.maxZ) / 2
				local dx, dz = mx - x, mz - z
				local len = math.sqrt(dx * dx + dz * dz)
				local cx, cz =
					x + dx / len * 4.5 + rand(-1.5, 1.5), z + dz / len * 4.5 + rand(-1.5, 1.5)
				if not nearOpening(cx, cz, 2) then
					cactus(cx, cz, rand(0.9, 1.2))
				end
			end
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

	-- hay bales: a pair at each far corner past the plaza
	for _, side in { -1, 1 } do
		local hx, hz = side * (g.maxX - 9), g.maxZ - 6
		if free(hx, hz, 2) and not nearOpening(hx, hz, 2) then
			hayBale(hx, hz)
			hayBale(hx - side * 0.5, hz - 2.2)
		end
	end

	-- 5. the island: a pine, a leafy tree and a rock
	local ix, iz, ir = LobbyScenery.island()
	if ix then
		pine(ix - ir * 0.3, iz - ir * 0.2, 1.2)
		tree(ix + ir * 0.35, iz + ir * 0.3, 1)
		rock(ix + ir * 0.2, iz - ir * 0.5, 0.9, "Rock")
	end
	done()
	return out, props
end

-- Just the block pieces (everything, as if no Meshy model is imported).
function LobbyScenery.pieces(): { Piece }
	local out = LobbyScenery.layout()
	return out
end

return LobbyScenery
