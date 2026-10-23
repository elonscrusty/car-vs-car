--!strict
-- Low-poly hills that close the lobby in on its three dry sides (left, right and the spawn end),
-- in three rising rows (near: low and bright, far: tall and hazy), with trees on the near two.
-- The lake is on the LobbyLayout.LAKE_SIDE end; hills wrap its two ends and far side, kept
-- KEEP_OFF studs off the sand, and the near bank (street to water) stays open so the docks show.
-- Nothing stands inside LobbyLayout.ground().
-- Pure placement (plain numbers, Lune tests load this); LobbyHillsBuilder turns it into parts.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local LobbyLayout = sibling("LobbyLayout")
local LobbyWater = sibling("LobbyWater")

export type Hill = {
	x: number, -- middle of its foot
	z: number,
	w: number, -- size: across (along its side), up, deep (away from the lobby)
	h: number,
	d: number,
	turn: number, -- degrees about y
	row: number, -- 1 near, 2 middle, 3 far
	kind: string, -- "meadow", "forest", "autumn", "rock" (near rows) or "peak" (far row)
	mesh: string, -- carter's model it is built from: DirtMound, or BigRock / FlatRock for cliffs
	snow: boolean, -- a white cap on top (tall far peaks)
	r: number, -- colour 0-255
	g: number,
	b: number,
}
export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
-- mesh "BlockTree" is a low-poly block tree in `color` (autumn and blossom trees); `color` is
-- also the stand-in colour for AutumnTree
export type Tree = {
	mesh: string,
	x: number,
	y: number,
	z: number,
	height: number,
	turn: number,
	color: { number }?,
}
-- small things at a near hill's foot: carter's Bush / Mushroom / TreeStump / Log / RockPile /
-- FlatRock, or "Flowers" (a little patch of coloured blocks); the builder drops them onto the hill
export type Prop = { mesh: string, x: number, z: number, height: number, turn: number }
-- a set piece on top of a middle-row hill, facing the lobby (turn), with a dirt path down the
-- lobby side (`path`: the points, top first) and a little fence round its yard; `extras` are
-- props beside it (a campfire and log seats by the cabin)
export type Landmark = {
	mesh: string,
	x: number,
	z: number,
	height: number,
	turn: number,
	path: { { number } },
	fence: boolean,
	extras: { Prop },
}

local LobbyHills = {}

-- per row: gap from the ground edge to the hill's foot middle, hill size ranges, colour,
-- and spacing (as a share of the average width: under 1 overlaps; the far row is hazy, so wider)
LobbyHills.ROWS = {
	{
		out = 14,
		w = { 34, 46 },
		h = { 12, 18 },
		d = { 26, 34 },
		color = { 112, 190, 86 },
		step = 0.62,
	},
	{
		out = 40,
		w = { 52, 70 },
		h = { 26, 38 },
		d = { 40, 52 },
		color = { 92, 166, 90 },
		step = 0.66,
	},
	{
		out = 76,
		w = { 80, 110 },
		h = { 46, 64 },
		d = { 60, 76 },
		color = { 116, 156, 130 },
		step = 0.72,
	},
}
LobbyHills.SAND = 8 -- sand rim round the lake water
LobbyHills.KEEP_OFF = 6 -- hills stay this far off the sand
LobbyHills.MAX_HILLS = 230
LobbyHills.MAX_TREES = 320
LobbyHills.MAX_PROPS = 200

-- The near rows come in stretches (ZONE studs long) of one kind, so the ring reads as meadows,
-- pine woods, autumn groves and rocky cliffs instead of one hill over and over.
LobbyHills.ZONE = 95
LobbyHills.KINDS = { "forest", "meadow", "forest", "autumn", "meadow", "rock", "forest", "autumn" }
-- per kind: size stretch (w, h, d), grass colour, row-2 shade
local LOOK = {
	meadow = { w = 1.15, h = 0.72, d = 1.1, color = { 136, 200, 88 } },
	forest = { w = 1, h = 1.05, d = 1, color = { 82, 152, 80 } },
	autumn = { w = 1, h = 0.9, d = 1, color = { 156, 182, 82 } },
	rock = { w = 0.62, h = 1.45, d = 0.7, color = { 146, 140, 132 } },
	peak = { w = 1.2, h = 0.8, d = 1.05, color = { 116, 152, 136 } }, -- soft and rolling
}
local AUTUMN = { { 236, 142, 52 }, { 242, 198, 66 }, { 206, 80, 58 }, { 244, 172, 204 } }

local function rng(seed: number): (number, number) -> number
	local state = seed
	return function(lo: number, hi: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * (state / 2147483648)
	end
end

-- Height of a hill's top surface at (x, z), or nil off it (a dome: high in the middle).
function LobbyHills.surface(hill: Hill, x: number, z: number): number?
	local a = math.rad(hill.turn)
	local c, s = math.cos(a), math.sin(a)
	local dx, dz = x - hill.x, z - hill.z
	-- into the hill's own axes (same turn as CFrame.Angles(0, turn, 0))
	local u = dx * c - dz * s
	local v = dx * s + dz * c
	local r2 = (u / (hill.w / 2)) ^ 2 + (v / (hill.d / 2)) ^ 2
	if r2 >= 1 then
		return nil
	end
	return hill.h * (1 - r2)
end

-- The lake water box: LobbyWater.lakeBox() when the water module has it, else the planned lake.
function LobbyHills.lakeBox(): Box
	if LobbyWater and type(LobbyWater.lakeBox) == "function" then
		return LobbyWater.lakeBox()
	end
	local g = LobbyLayout.ground()
	if (LobbyLayout.LAKE_SIDE or 1) > 0 then
		return { minX = g.minX - 30, maxX = g.maxX + 30, minZ = g.maxZ + 18, maxZ = g.maxZ + 148 }
	end
	return { minX = g.minX - 30, maxX = g.maxX + 30, minZ = g.minZ - 148, maxZ = g.minZ - 18 }
end

-- Where no hill may reach: the lake, its sand, KEEP_OFF more, and the open near bank to the street.
function LobbyHills.keepBox(): Box
	local g = LobbyLayout.ground()
	local lk = LobbyHills.lakeBox()
	local m = LobbyHills.SAND + LobbyHills.KEEP_OFF
	local b = { minX = lk.minX - m, maxX = lk.maxX + m, minZ = lk.minZ - m, maxZ = lk.maxZ + m }
	if (LobbyLayout.LAKE_SIDE or 1) > 0 then
		b.minZ = math.min(b.minZ, g.maxZ)
	else
		b.maxZ = math.max(b.maxZ, g.minZ)
	end
	return b
end

-- Does the hill's foot touch the box?
function LobbyHills.touches(hill: Hill, b: Box): boolean
	if hill.x > b.minX and hill.x < b.maxX and hill.z > b.minZ and hill.z < b.maxZ then
		return true
	end
	local a = math.rad(hill.turn)
	local c, s = math.cos(a), math.sin(a)
	for i = 0, 47 do
		local t = i / 48 * math.pi * 2
		local u, v = math.cos(t) * hill.w / 2, math.sin(t) * hill.d / 2
		-- back out of the hill's axes (inverse of surface())
		local x = hill.x + u * c + v * s
		local z = hill.z - u * s + v * c
		if x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ then
			return true
		end
	end
	for _, p in { { b.minX, b.minZ }, { b.minX, b.maxZ }, { b.maxX, b.minZ }, { b.maxX, b.maxZ } } do
		if LobbyHills.surface(hill, p[1], p[2]) then
			return true
		end
	end
	return false
end

-- the set pieces: what, roughly where (x, z), which kinds of hill suit it, how tall
LobbyHills.LANDMARKS = {
	{ mesh = "Cabin", x = -1, z = 0.45, kinds = { "forest", "autumn" }, height = 15, fence = true },
	{ mesh = "Windmill", x = 1, z = 0.3, kinds = { "meadow" }, height = 24, fence = false },
	{
		mesh = "WatchTower",
		x = 0.35,
		z = -1,
		kinds = { "forest", "rock", "meadow" },
		height = 20,
		fence = false,
	},
	{
		mesh = "Cabin",
		x = 1,
		z = 0.85,
		kinds = { "autumn", "forest", "meadow" },
		height = 14,
		fence = true,
	},
}
LobbyHills.LANDMARK_CLEAR = 13 -- no trees this close to a set piece

function LobbyHills.layout(): ({ Hill }, { Tree }, { Prop }, { Landmark })
	local hills: { Hill } = {}
	local trees: { Tree } = {}
	local props: { Prop } = {}
	local marks: { Landmark } = {}
	local rand = rng(20261023 + 17)
	local g = LobbyLayout.ground()
	local keep = LobbyHills.keepBox()
	local lake = LobbyLayout.LAKE_SIDE or 1
	local inward = if lake > 0 then 1 else -1 -- from the dry end toward the lake
	-- the dry end is the one away from the lake
	local endZ = if lake > 0 then g.minZ else g.maxZ
	-- the lake's far edge (past it the hills run across)
	local lakeFar = if lake > 0 then keep.maxZ else keep.minZ
	local lakeNear = if lake > 0 then keep.minZ else keep.maxZ

	for row, spec in LobbyHills.ROWS do
		-- push the hill out (dx, dz) until it is clear of the lake keep box
		-- `along` is where it is round the ring (picks its zone's kind); `side` -1 left, 1 right, 0 end
		local function hill(
			x: number,
			z: number,
			turn: number,
			dx: number,
			dz: number,
			along: number
		)
			local kind = "peak"
			if row < 3 then
				local zone = math.floor(along / LobbyHills.ZONE)
				kind = LobbyHills.KINDS[zone % #LobbyHills.KINDS + 1]
			end
			local look = LOOK[kind]
			local shade = if row == 2 then 0.88 else 1
			local tall = rand(spec.h[1], spec.h[2])
			local h: Hill = {
				x = x,
				z = z,
				w = rand(spec.w[1], spec.w[2]) * look.w,
				-- a few far peaks shoot up much higher
				h = math.min(tall * look.h, spec.h[2] * 1.45)
					* (if row == 3 and rand(0, 1) < 0.22 then 1.35 else 1),
				d = rand(spec.d[1], spec.d[2]) * look.d,
				turn = turn + rand(-12, 12),
				row = row,
				kind = kind,
				mesh = if kind == "rock"
					then (if rand(0, 1) < 0.6 then "BigRock" else "FlatRock")
					else "DirtMound",
				snow = false,
				r = look.color[1] * shade + rand(-9, 9),
				g = look.color[2] * shade + rand(-9, 9),
				b = look.color[3] * shade + rand(-7, 7),
			}
			h.snow = row == 3 and h.h > 60
			local tries = 0
			while LobbyHills.touches(h, keep) and tries < 60 do
				h.x += dx * 2
				h.z += dz * 2
				tries += 1
			end
			table.insert(hills, h)
		end
		local step = (spec.w[1] + spec.w[2]) / 2 * spec.step
		local wobble = step * 0.15
		local farOut = lakeFar + inward * (spec.out + LobbyHills.KEEP_OFF)
		-- round the ring: down the left side, across the dry end, up the right, across the far side
		local sideLen = math.abs(lakeFar - endZ)
		local width = g.maxX - g.minX
		-- left and right sides: from behind the dry end, along the street, round the lake's ends
		for _, side in { -1, 1 } do
			local streetX = if side < 0 then g.minX - spec.out else g.maxX + spec.out
			local lakeX = if side < 0
				then keep.minX - spec.out - LobbyHills.KEEP_OFF
				else keep.maxX + spec.out + LobbyHills.KEEP_OFF
			local z = endZ - inward * spec.out
			while (z - farOut) * inward < 0 do
				local x = if (z - lakeNear) * inward > -step / 2 then lakeX else streetX
				local along = if side < 0
					then (lakeFar - z) * inward
					else sideLen + width + (z - endZ) * inward
				hill(x + rand(-wobble, wobble), z + rand(-wobble, wobble), 90, side, 0, along)
				z += inward * step
			end
		end
		-- the dry end and the lake's far side: across, corner to corner
		local zEnd = endZ - inward * spec.out
		local x = g.minX - spec.out + step
		while x < g.maxX + spec.out - step / 2 do
			hill(
				x + rand(-wobble, wobble),
				zEnd + rand(-wobble, wobble),
				0,
				0,
				-inward,
				sideLen + x - g.minX
			)
			x += step
		end
		local farPad = spec.out + LobbyHills.KEEP_OFF
		x = keep.minX - farPad + step
		while x < keep.maxX + farPad - step / 2 do
			local along = 2 * sideLen + width + g.maxX - x
			hill(x + rand(-wobble, wobble), farOut + rand(-wobble, wobble), 0, 0, inward, along)
			x += step
		end
	end

	-- trees on the near two rows (only the near row past the lake), by the hill's kind:
	-- pine woods are thick with pines of mixed size, meadows have a lone tree or two, autumn
	-- groves have orange / yellow / red / blossom block trees, cliffs a stray pine
	local mid = { x = (g.minX + g.maxX) / 2, z = (g.minZ + g.maxZ) / 2 }
	local function clear(tx: number, tz: number): boolean
		local onGround = tx > g.minX and tx < g.maxX and tz > g.minZ and tz < g.maxZ
		local inKeep = tx > keep.minX and tx < keep.maxX and tz > keep.minZ and tz < keep.maxZ
		return not onGround and not inKeep
	end
	-- a spot on the hill at rr (0 middle, 1 foot), pulled `pull` toward the lobby
	local function spot(h: Hill, rr: number, pull: number): (number, number)
		local a = rand(0, math.pi * 2)
		local tx = h.x + math.cos(a) * h.w / 2 * rr
		local tz = h.z + math.sin(a) * h.d / 2 * rr
		local dx, dz = mid.x - h.x, mid.z - h.z
		local len = math.sqrt(dx * dx + dz * dz)
		return tx + dx / len * h.d * pull, tz + dz / len * h.d * pull
	end
	-- set pieces on middle-row hills: x/z in LANDMARKS are -1..1 across the lobby's width and
	-- along its length (from the dry end), and the nearest hill of a fitting kind gets it
	local function nearMark(x: number, z: number): boolean
		for _, m in marks do
			if (m.x - x) ^ 2 + (m.z - z) ^ 2 < LobbyHills.LANDMARK_CLEAR ^ 2 then
				return true
			end
		end
		return false
	end
	local taken: { [Hill]: boolean } = {}
	for _, spec in LobbyHills.LANDMARKS do
		local cx = mid.x + spec.x * (g.maxX - g.minX) / 2 * 1.6
		local along = (spec.z + 1) / 2
		local cz = endZ + inward * (along * (g.maxZ - g.minZ))
		if spec.z < -0.99 then
			cz = endZ - inward * 40
		end
		local best: Hill? = nil
		local bestD = math.huge
		for _, h in hills do
			local pastLake = (h.z - lakeNear) * inward > 0
			if h.row == 2 and not pastLake and not taken[h] and table.find(spec.kinds, h.kind) then
				local d = (h.x - cx) ^ 2 + (h.z - cz) ^ 2
				if d < bestD then
					best, bestD = h, d
				end
			end
		end
		if best then
			local h = best
			taken[h] = true
			local dx, dz = mid.x - h.x, mid.z - h.z
			local len = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / len, dz / len
			-- a path from the yard's edge down the lobby side to the hill's foot
			local path = {}
			local r = 7
			while r < math.max(h.w, h.d) do
				local px, pz = h.x + dx * r, h.z + dz * r
				if not LobbyHills.surface(h, px, pz) or not clear(px, pz) then
					break
				end
				table.insert(path, { px, pz })
				r += 4
			end
			local extras = {}
			if spec.mesh == "Cabin" then
				-- campfire and log seats off to one side of the door
				local sx, sz = -dz, dx
				local fx, fz = h.x + sx * 9 + dx * 3, h.z + sz * 9 + dz * 3
				table.insert(extras, { mesh = "Campfire", x = fx, z = fz, height = 2.2, turn = 0 })
				table.insert(
					extras,
					{ mesh = "Log", x = fx + dx * 3.5, z = fz + dz * 3.5, height = 1.4, turn = 90 }
				)
				table.insert(
					extras,
					{ mesh = "Log", x = fx + sx * 3.5, z = fz + sz * 3.5, height = 1.4, turn = 0 }
				)
			end
			table.insert(marks, {
				mesh = spec.mesh,
				x = h.x,
				z = h.z,
				height = spec.height,
				-- the model's front faces -z (MeshProps turns it half round), so face the lobby
				-- (the watch tower's ladder is on its -x side: turn that to the lobby instead)
				turn = math.deg(math.atan2(dx, dz)) - (if spec.mesh == "WatchTower" then 90 else 0),
				path = path,
				fence = spec.fence,
				extras = extras,
			})
		end
	end

	local function tree(h: Hill, mesh: string, size: number, color: { number }?)
		local tx, tz = spot(h, rand(0.05, 0.7), if h.kind == "forest" then 0.04 else 0.12)
		local y = LobbyHills.surface(h, tx, tz)
		if y and y > 1.5 and clear(tx, tz) and not nearMark(tx, tz) then
			local base = if mesh == "PineTree" then 13 elseif mesh == "LeafyTree" then 12 else 11
			table.insert(trees, {
				mesh = mesh,
				x = tx,
				y = y - 0.6,
				z = tz,
				height = base * size * (if h.row == 2 then 1.3 else 1),
				turn = rand(0, 360),
				color = color,
			})
		end
	end
	for _, h in hills do
		local pastLake = (h.z - lakeNear) * inward > 0
		if h.row == 1 or (h.row == 2 and not pastLake) then
			if h.kind == "forest" then
				for _ = 1, math.floor(rand(3, if h.row == 1 then 5.99 else 6.99)) do
					local pick = rand(0, 1)
					tree(
						h,
						if pick < 0.75
							then "PineTree"
							elseif pick < 0.87 then "BirchTree"
							else "LeafyTree",
						rand(0.7, 1.5)
					)
				end
			elseif h.kind == "meadow" then
				for _ = 1, math.floor(rand(0, 2.6)) do
					tree(h, if rand(0, 1) < 0.5 then "BirchTree" else "LeafyTree", rand(0.9, 1.3))
				end
			elseif h.kind == "autumn" then
				for _ = 1, math.floor(rand(2, 4.99)) do
					-- carter's autumn tree, with block trees for the yellow / red / blossom ones
					local c = AUTUMN[math.floor(rand(1, #AUTUMN + 0.99))]
					tree(
						h,
						if rand(0, 1) < 0.55 then "AutumnTree" else "BlockTree",
						rand(0.8, 1.3),
						c
					)
				end
				if rand(0, 1) < 0.5 then
					tree(h, "LeafyTree", rand(0.9, 1.2))
				end
			elseif rand(0, 1) < 0.5 then
				tree(h, "PineTree", rand(0.7, 1.1))
			end
		end
	end

	-- little things round the near row's foot, on the lobby side, by kind
	local FOOT = {
		meadow = { "Flowers", "Flowers", "Bush", "Flowers" },
		forest = { "Bush", "TreeStump", "Mushroom", "Log" },
		autumn = { "Bush", "Flowers", "Mushroom" },
		rock = { "RockPile", "FlatRock", "BigRock", "RockSpire" },
	}
	local SIZE = {
		Flowers = 1.2,
		Bush = 3.2,
		TreeStump = 2.2,
		Mushroom = 1.8,
		Log = 1.6,
		RockPile = 3,
		FlatRock = 2.4,
		BigRock = 4.5,
		RockSpire = 7,
	}
	for _, h in hills do
		local list = FOOT[h.kind]
		if h.row == 1 and list then
			for _ = 1, math.floor(rand(2, 3.99)) do
				local mesh = list[math.floor(rand(1, #list + 0.99))]
				local tx, tz = spot(h, rand(0.78, 0.98), 0.08)
				if clear(tx, tz) and not nearMark(tx, tz) then
					table.insert(props, {
						mesh = mesh,
						x = tx,
						z = tz,
						height = SIZE[mesh] * rand(0.8, 1.3),
						turn = rand(0, 360),
					})
				end
			end
		end
	end
	return hills, trees, props, marks
end

LobbyHills.BASE_TOP = -0.2 -- grass under the hills: a hair under the lobby grass

-- Grass slabs under the hills so nothing shows sky between their feet: the two sides and the
-- dry end, around ground() (the lake end has the water thread's own grass).
function LobbyHills.baseBoxes(hills: { Hill }): { Box }
	local g = LobbyLayout.ground()
	local lake = LobbyLayout.LAKE_SIDE or 1
	local minX, maxX, minZ, maxZ = g.minX, g.maxX, g.minZ, g.maxZ
	for _, h in hills do
		local reach = math.max(h.w, h.d) / 2 + 4
		minX = math.min(minX, h.x - reach)
		maxX = math.max(maxX, h.x + reach)
		minZ = math.min(minZ, h.z - reach)
		maxZ = math.max(maxZ, h.z + reach)
	end
	-- the sides stop where the lake end begins; the dry end spans corner to corner
	local sideMinZ = if lake > 0 then minZ else g.minZ
	local sideMaxZ = if lake > 0 then g.maxZ else maxZ
	local boxes = {
		{ minX = minX, maxX = g.minX, minZ = sideMinZ, maxZ = sideMaxZ },
		{ minX = g.maxX, maxX = maxX, minZ = sideMinZ, maxZ = sideMaxZ },
	}
	if lake > 0 then
		table.insert(boxes, { minX = g.minX, maxX = g.maxX, minZ = minZ, maxZ = g.minZ })
	else
		table.insert(boxes, { minX = g.minX, maxX = g.maxX, minZ = g.maxZ, maxZ = maxZ })
	end
	return boxes
end

return LobbyHills
