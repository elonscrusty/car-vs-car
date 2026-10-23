--!strict
-- Build your own track (carter 2026-10-23, /mnt/project-files/rc-game/build-track/PLAN.md).
-- A plot is a grid of square cells. Each cell holds one road piece, turned 0..3 quarter turns
-- clockwise (seen from above). trace() follows the road from the START tile and, when it comes
-- back round to it, gives the same things a plot gives the race: the loop samples, lap gates,
-- the start spot and where the line is. Pure maths (plain tables), so Lune tests all of it.
--
-- Plot-local big units like Plots/Race.luau (the plot is shrunk 0.25 later). +x = east, -z =
-- north = the back of the plot (away from the stand). Col 1 is the left, row 1 the front row.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
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

local Kit = sibling("Plots/Kit")

export type Tile = { c: number, r: number, piece: string, rot: number }
export type Grid = { cols: number, rows: number, tiles: { Tile } }
export type Ends = { N: boolean, E: boolean, S: boolean, W: boolean }
export type Piece = {
	id: string,
	name: string,
	ends: Ends, -- which edges the road touches at rot 0
	tier: string, -- "free" | "coins" | "legendary" (TileShop owns prices and odds)
	kind: string, -- "road" (a shape) | "hazard" (slows / blocks) | "power" (helps) - for the tray
	tip: string, -- tiny words for the tile card
}
export type Pad = { kind: string, x: number, z: number, dx: number, dz: number, len: number }
export type Result = {
	ok: boolean,
	why: string?, -- tiny words for the build screen when not ok
	loop: () -> { Kit.Sample },
	lineSample: () -> number,
	gates: { Kit.Gate },
	spawn: Kit.Spawn?,
	pads: { Pad }, -- boost / oil patches on the road
	order: { Tile }, -- tiles in driving order (a cross tile shows up twice)
}

local TrackTiles = {}

TrackTiles.CELL = 58 -- big studs (14.5 RC studs): 5 x 6 cells just fit the track area
TrackTiles.ROAD = 30 -- same road as the race plot
TrackTiles.CURB_WIDTH = 3
TrackTiles.SPACING = 8 -- distance between loop samples
-- grid size grows with stars (first guesses; the Stars thread hands out stars)
TrackTiles.SIZES = {
	{ stars = 0, cols = 5, rows = 5 }, -- fills the plot's width from the start (Studio 22:13, 22:25)
	{ stars = 10, cols = 5, rows = 6 },
}

-- edges: 0 = N, 1 = E, 2 = S, 3 = W
local EDGE_NAMES = { "N", "E", "S", "W" }
local STEP = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } } -- {dc, dr} per edge (N = one row back)

-- A road path inside a cell at rot 0: from edge `a` to edge `b`, t 0..1 -> (u, v) in cell
-- units, u = east, v = north, centre (0, 0), edges at +-0.5.
type Path = { a: number, b: number, at: (number) -> (number, number) }

local function line(a: number, b: number): Path
	local mid = { { 0, 0.5 }, { 0.5, 0 }, { 0, -0.5 }, { -0.5, 0 } }
	local p, q = mid[a + 1], mid[b + 1]
	return {
		a = a,
		b = b,
		at = function(t: number): (number, number)
			return p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t
		end,
	}
end

-- S to N with a sideways wiggle
local function wiggle(): Path
	return {
		a = 2,
		b = 0,
		at = function(t: number): (number, number)
			return 0.18 * math.sin(2 * math.pi * t), t - 0.5
		end,
	}
end

-- N to E round the north-east corner: straight in to `r` from the corner line, an arc of
-- radius r, then straight out. r = 0.5 is the plain turn, small r is the sharp one.
local function bend(r: number): Path
	local s = 0.5 - r -- straight bit on each side
	local arc = math.pi / 2 * r
	local total = 2 * s + arc
	return {
		a = 0,
		b = 1,
		at = function(t: number): (number, number)
			local d = t * total
			if d < s then
				return 0, 0.5 - d
			elseif d < s + arc then
				local ang = math.pi + (d - s) / r -- centre (r, r): from west of it to south of it
				return r + r * math.cos(ang), r + r * math.sin(ang)
			end
			return r + (d - s - arc), 0
		end,
	}
end

type Def = Piece & { paths: { Path } }
local function def(
	id: string,
	name: string,
	tier: string,
	kind: string,
	tip: string,
	paths: { Path }
): any
	return { id = id, name = name, tier = tier, kind = kind, tip = tip, paths = paths }
end
-- carter 22:36: "way more tiles. jump and cones and variety". Every hazard and power hits every
-- racer the same (fair races). All are one square with road ends on N/E/S/W, so they swap in.
local DEFS: { Def } = {
	def("start", "START", "free", "road", "Start line", { line(2, 0) }),
	-- road shapes
	def("straight", "STRAIGHT", "free", "road", "Plain road", { line(2, 0) }),
	def("turn", "TURN", "free", "road", "Round corner", { bend(0.5) }),
	def("sharp", "SHARP TURN", "legendary", "road", "Tight corner", { bend(0.2) }),
	def("chicane", "WIGGLE", "coins", "road", "Left-right wiggle", { wiggle() }),
	def("cross", "CROSS", "coins", "road", "Roads cross (figure 8)", { line(2, 0), line(3, 1) }),
	def("split", "SPLIT", "coins", "road", "Pick a side of the island", { line(2, 0) }),
	def("narrow", "SQUEEZE", "coins", "road", "Road gets thin", { line(2, 0) }),
	-- hazards
	def("cones", "CONES", "coins", "hazard", "Weave the cones", { line(2, 0) }),
	def("barrels", "BARRELS", "coins", "hazard", "Dodge left, then right", { line(2, 0) }),
	def("bumps", "BUMPS", "coins", "hazard", "Bumpy ride", { line(2, 0) }),
	def("mud", "MUD", "coins", "hazard", "Slow and slippy", { line(2, 0) }),
	def("puddle", "PUDDLE", "coins", "hazard", "Splash, less grip", { line(2, 0) }),
	def("sand", "SAND", "coins", "hazard", "Heavy and slow", { line(2, 0) }),
	def("oil", "OIL SPILL", "legendary", "hazard", "Super slippy", { line(2, 0) }),
	-- powers
	def("boost", "BOOST", "legendary", "power", "Speed burst", { line(2, 0) }),
	def("jump", "JUMP", "legendary", "power", "Ramp: fly!", { line(2, 0) }),
} :: any
for _, d in DEFS do
	local e = { N = false, E = false, S = false, W = false }
	for _, p in d.paths do
		e[EDGE_NAMES[p.a + 1]] = true
		e[EDGE_NAMES[p.b + 1]] = true
	end
	d.ends = e :: Ends
end

TrackTiles.PIECES = DEFS :: { Piece } -- in shop / build-screen order
local BY_ID: { [string]: Def } = {}
for _, d in DEFS do
	BY_ID[d.id] = d
end
function TrackTiles.piece(id: string): Piece?
	return BY_ID[id]
end

-- ===== Grid =====

function TrackTiles.sizeFor(stars: number): (number, number)
	local cols, rows = TrackTiles.SIZES[1].cols, TrackTiles.SIZES[1].rows
	for _, s in TrackTiles.SIZES do
		if stars >= s.stars then
			cols, rows = s.cols, s.rows
		end
	end
	return cols, rows
end

-- Plot-local centre of a cell. The grid is centred in x and in depth on the track area (a
-- 5 x 5 grid leaves an even strip front and back; 5 x 6 fills it).
function TrackTiles.cellCenter(grid: Grid, c: number, r: number): (number, number)
	local cell = TrackTiles.CELL
	local midZ = (Kit.AREA.minZ + Kit.AREA.maxZ) / 2
	local x = (c - (grid.cols + 1) / 2) * cell
	local z = midZ + ((grid.rows + 1) / 2 - r) * cell
	return x, z
end

function TrackTiles.get(grid: Grid, c: number, r: number): Tile?
	for _, t in grid.tiles do
		if t.c == c and t.r == r then
			return t
		end
	end
	return nil
end

local function inside(grid: Grid, c: number, r: number): boolean
	return c >= 1 and c <= grid.cols and r >= 1 and r <= grid.rows
end

-- Which world edges a placed piece touches.
local function opens(def: Def, rot: number, edge: number): boolean
	local localEdge = (edge - rot) % 4
	return (def.ends :: any)[EDGE_NAMES[localEdge + 1]]
end

-- The turn (0..3) that makes `id` join world edges a and b, or nil.
function TrackTiles.fit(id: string, a: number, b: number): number?
	local def = BY_ID[id]
	if not def then
		return nil
	end
	for rot = 0, 3 do
		for _, p in def.paths do
			local pa, pb = (p.a + rot) % 4, (p.b + rot) % 4
			if (pa == a and pb == b) or (pa == b and pb == a) then
				return rot
			end
		end
	end
	return nil
end

-- Put a piece in a cell (replaces what was there). Only one START: placing it moves it.
-- Returns ok, why. The server checks the owner, the break and TileShop before calling this.
function TrackTiles.place(
	grid: Grid,
	c: number,
	r: number,
	id: string,
	rot: number
): (boolean, string?)
	if not inside(grid, c, r) then
		return false, "Off the plot"
	end
	if not BY_ID[id] then
		return false, "Unknown piece"
	end
	if rot ~= math.floor(rot) or rot < 0 or rot > 3 then
		return false, "Bad turn"
	end
	local old = TrackTiles.get(grid, c, r)
	if id ~= "start" and old and old.piece == "start" then
		return false, "Move the START first"
	end
	for i = #grid.tiles, 1, -1 do
		local t = grid.tiles[i]
		if (t.c == c and t.r == r) or (id == "start" and t.piece == "start") then
			table.remove(grid.tiles, i)
		end
	end
	table.insert(grid.tiles, { c = c, r = r, piece = id, rot = rot })
	return true, nil
end

function TrackTiles.remove(grid: Grid, c: number, r: number): (boolean, string?)
	for i, t in grid.tiles do
		if t.c == c and t.r == r then
			if t.piece == "start" then
				return false, "START can move, not go"
			end
			table.remove(grid.tiles, i)
			return true, nil
		end
	end
	return false, "Nothing there"
end

-- ===== Drag and drop (carter 22:03: "make it a drag and drop", "all tiles without paying") =====

-- testing switch: true = every tile unlocked for everyone. false (carter 22:51 "plenty of tiles to
-- unlock") = TileShop decides; workspace attribute AllTilesFree = true still frees them in Studio.
TrackTiles.ALL_FREE = false

local STRAIGHTS: { [string]: boolean } = {}
local BENDS: { [string]: boolean } = { turn = true, sharp = true }
for _, d in DEFS do
	if #d.paths == 1 and (d.paths[1].a + 2) % 4 == d.paths[1].b then
		STRAIGHTS[d.id] = true
	end
end

-- The world edges a placed tile's road touches.
local function edgesOf(t: Tile): { number }
	local def = BY_ID[t.piece]
	local out = {}
	if def then
		for e = 0, 3 do
			if opens(def, t.rot, e) then
				table.insert(out, e)
			end
		end
	end
	return out
end

-- Edge of cell a that faces cell b (nil if not side by side).
local function edgeTo(ac: number, ar: number, bc: number, br: number): number?
	for e = 0, 3 do
		if ac + STEP[e + 1][1] == bc and ar + STEP[e + 1][2] == br then
			return e
		end
	end
	return nil
end

local function connected(grid: Grid, c: number, r: number, e: number): boolean
	local n = TrackTiles.get(grid, c + STEP[e + 1][1], r + STEP[e + 1][2])
	return n ~= nil and table.find(edgesOf(n), (e + 2) % 4) ~= nil
end

-- Make the cell's road join edges a and b, keeping its special piece when it still fits.
local function setLink(grid: Grid, c: number, r: number, a: number, b: number)
	local old = TrackTiles.get(grid, c, r)
	local straight = (a + 2) % 4 == b
	local id = if straight then "straight" else "turn"
	if old then
		if straight and STRAIGHTS[old.piece] then
			id = old.piece
		elseif not straight and BENDS[old.piece] then
			id = old.piece
		elseif old.piece == "start" then
			return -- the START stays a straight
		end
	end
	local rot = TrackTiles.fit(id, a, b) :: number
	if old and (old.piece == "start") and (old.rot - rot) % 2 == 0 then
		rot = old.rot -- keep which way the START points
	end
	TrackTiles.place(grid, c, r, id, rot)
end

-- Finger dragged across these cells (each next to the last): lay road along them. Straights
-- and turns are picked and turned automatically. Crossing a straight road at right angles
-- makes a CROSS. Returns ok, why.
function TrackTiles.drawPath(grid: Grid, cells: { { number } }): (boolean, string?)
	local n = #cells
	if n < 2 then
		return false, "Drag across squares"
	end
	for i, cell in cells do
		if type(cell) ~= "table" or not inside(grid, cell[1], cell[2]) then
			return false, "Off the plot"
		end
		if i > 1 and not edgeTo(cells[i - 1][1], cells[i - 1][2], cell[1], cell[2]) then
			return false, "Drag square by square"
		end
	end
	for i, cell in cells do
		local c, r = cell[1], cell[2]
		local inE = if i > 1 then edgeTo(c, r, cells[i - 1][1], cells[i - 1][2]) else nil
		local outE = if i < n then edgeTo(c, r, cells[i + 1][1], cells[i + 1][2]) else nil
		local old = TrackTiles.get(grid, c, r)
		local a, b = inE, outE
		if not a or not b then
			-- an end of the drag: join the road that is already here, or carry straight on
			local new = (a or b) :: number
			local keep: number? = nil
			if old then
				for _, e in edgesOf(old) do
					if
						e ~= new
						and connected(grid, c, r, e)
						and (keep == nil or e == (new + 2) % 4)
					then
						keep = e
					end
				end
			end
			a, b = new, keep or (new + 2) % 4
		end
		local ea, eb = a :: number, b :: number
		if old and (ea + 2) % 4 == eb and #edgesOf(old) == 2 then
			local oe = edgesOf(old)
			local crossing = (oe[1] + 2) % 4 == oe[2] and oe[1] % 2 ~= ea % 2
			if crossing and old.piece == "straight" and inE and outE then
				TrackTiles.place(grid, c, r, "cross", 0)
				continue
			end
		end
		if old and old.piece == "cross" and (ea + 2) % 4 == eb and inE and outE then
			continue -- driving straight through a crossing keeps it
		end
		setLink(grid, c, r, ea, eb)
	end
	return true, nil
end

-- Drop a special tile on a road square: it turns itself to fit the road there.
function TrackTiles.drop(grid: Grid, c: number, r: number, id: string): (boolean, string?)
	if not inside(grid, c, r) then
		return false, "Off the plot"
	end
	local d = BY_ID[id]
	if not d or id == "start" then
		return false, "Unknown piece"
	end
	local old = TrackTiles.get(grid, c, r)
	if old and old.piece == "start" then
		return false, "Not on the START"
	end
	-- pick the turn that joins the most road around it (ties: keep the old tile's ends)
	local oldEnds = if old then edgesOf(old) else {}
	local bestRot, bestScore = 0, -1
	for rot = 0, 3 do
		local score = 0
		for e = 0, 3 do
			if opens(d, rot, e) then
				if connected(grid, c, r, e) then
					score += 10
				end
				if table.find(oldEnds, e) then
					score += 1
				end
			end
		end
		if score > bestScore then
			bestRot, bestScore = rot, score
		end
	end
	return TrackTiles.place(grid, c, r, id, bestRot)
end

-- Turn the tile in a square a quarter turn clockwise (tap / ROTATE button). A straight shows
-- the other way; the START flips which way the race goes only on its own square.
function TrackTiles.rotate(grid: Grid, c: number, r: number): (boolean, string?)
	local t = TrackTiles.get(grid, c, r)
	if not t then
		return false, "Nothing there"
	end
	t.rot = (t.rot + 1) % 4
	return true, nil
end

-- The starter track: a ring round the edge of the grid, START in the front row going east.
function TrackTiles.circle(cols: number, rows: number): Grid
	local grid: Grid = { cols = cols, rows = rows, tiles = {} }
	-- ring cells in driving order: front row left->right, right side up, back row right->left,
	-- left side down
	local ring: { { number } } = {}
	for c = 1, cols do
		table.insert(ring, { c, 1 })
	end
	for r = 2, rows do
		table.insert(ring, { cols, r })
	end
	for c = cols - 1, 1, -1 do
		table.insert(ring, { c, rows })
	end
	for r = rows - 1, 2, -1 do
		table.insert(ring, { 1, r })
	end
	local n = #ring
	local function edgeTo(a: { number }, b: { number }): number
		for e = 0, 3 do
			if a[1] + STEP[e + 1][1] == b[1] and a[2] + STEP[e + 1][2] == b[2] then
				return e
			end
		end
		error("ring cells not next to each other")
	end
	local startAt = math.max(2, math.floor(cols / 2))
	for i, cell in ring do
		local prev, nxt = ring[((i - 2) % n) + 1], ring[(i % n) + 1]
		local inE, outE = edgeTo(cell, prev), edgeTo(cell, nxt)
		local id = if (inE + 2) % 4 == outE then "straight" else "turn"
		if i == startAt then
			id = "start"
		end
		local rot: number
		if id == "start" then
			rot = (outE - 0) % 4 -- START drives S -> N at rot 0
		else
			rot = TrackTiles.fit(id, inE, outE) :: number
		end
		table.insert(grid.tiles, { c = cell[1], r = cell[2], piece = id, rot = rot })
	end
	return grid
end

function TrackTiles.copy(grid: Grid): Grid
	local tiles = {}
	for i, t in grid.tiles do
		tiles[i] = { c = t.c, r = t.r, piece = t.piece, rot = t.rot }
	end
	return { cols = grid.cols, rows = grid.rows, tiles = tiles }
end

-- ===== Following the road =====

local function fail(why: string): Result
	return {
		ok = false,
		why = why,
		loop = function()
			return {}
		end,
		lineSample = function()
			return 1
		end,
		gates = {},
		spawn = nil,
		pads = {},
		order = {},
	}
end

function TrackTiles.trace(grid: Grid): Result
	local start: Tile? = nil
	for _, t in grid.tiles do
		if t.piece == "start" then
			if start then
				return fail("Only one START")
			end
			start = t
		end
	end
	if not start then
		return fail("Put down the START")
	end
	local st = start :: Tile
	local cell = TrackTiles.CELL
	local ring: { Kit.Pt } = {}
	local order: { Tile } = {}
	local pads: { Pad } = {}
	local used: { [string]: boolean } = {}
	local lineIdx = 1

	local cur = st
	local entry = (2 + st.rot) % 4 -- START is driven S -> N at rot 0
	for _ = 1, grid.cols * grid.rows * 2 + 1 do
		local def = BY_ID[cur.piece]
		if not def then
			return fail("Unknown piece")
		end
		-- the path inside this cell that starts (or ends) at the edge we came in through
		local localIn = (entry - cur.rot) % 4
		local path: Path? = nil
		local forward = true
		for _, p in def.paths do
			if p.a == localIn then
				path, forward = p, true
			elseif p.b == localIn then
				path, forward = p, false
			end
		end
		if not path then
			return fail("Road has a gap")
		end
		local pth = path :: Path
		local key = cur.c .. "," .. cur.r .. "," .. math.min(pth.a, pth.b)
		if used[key] then
			return fail("Road loops wrong")
		end
		used[key] = true
		table.insert(order, cur)

		-- samples along this piece (rotated into the world)
		local cx, cz = TrackTiles.cellCenter(grid, cur.c, cur.r)
		local function world(t: number): (number, number)
			local u, v = pth.at(if forward then t else 1 - t)
			for _ = 1, cur.rot do
				u, v = v, -u -- a quarter turn clockwise
			end
			return cx + u * cell, cz - v * cell
		end
		local len = 0
		local px, pz = world(0)
		for i = 1, 20 do
			local x, z = world(i / 20)
			len += math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
			px, pz = x, z
		end
		local count = math.max(3, math.floor(len / TrackTiles.SPACING + 0.5))
		local first = #ring + 1
		for i = 0, count - 1 do
			local x, z = world(i / count)
			table.insert(ring, { x = x, z = z })
		end
		if cur == st then
			lineIdx = first + math.floor(count / 2)
		end
		if cur.piece == "boost" or cur.piece == "oil" then
			local ax, az = world(0)
			local bx, bz = world(1)
			local d = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			table.insert(pads, {
				kind = cur.piece,
				x = (ax + bx) / 2,
				z = (az + bz) / 2,
				dx = (bx - ax) / d,
				dz = (bz - az) / d,
				len = d * 0.6,
			})
		end

		-- out through the other end, into the next cell
		local exitLocal = if forward then pth.b else pth.a
		local exit = (exitLocal + cur.rot) % 4
		local nc, nr = cur.c + STEP[exit + 1][1], cur.r + STEP[exit + 1][2]
		if not inside(grid, nc, nr) then
			return fail("Road runs off the plot")
		end
		local nxt = TrackTiles.get(grid, nc, nr)
		local back = (exit + 2) % 4
		if not nxt or not BY_ID[nxt.piece] or not opens(BY_ID[nxt.piece], nxt.rot, back) then
			return fail("Road has a gap")
		end
		if nxt == st then
			if back ~= (2 + st.rot) % 4 then
				return fail("Road meets START from the wrong side")
			end
			-- round we go: tangents from the neighbours
			local n = #ring
			if n < 24 then
				return fail("Track too short")
			end
			local samples: { Kit.Sample } = {}
			for i, p in ring do
				local a, b = ring[((i - 2) % n) + 1], ring[(i % n) + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				local d = math.sqrt(dx * dx + dz * dz)
				samples[i] = { x = p.x, z = p.z, tx = dx / d, tz = dz / d }
			end
			local lineS = samples[lineIdx]
			local gates = { Kit.gateAt(lineS, 0, 22, 6) }
			for k = 1, 4 do
				local idx = ((lineIdx - 1 + math.floor(n * k / 5)) % n) + 1
				table.insert(gates, Kit.gateAt(samples[idx], 0, 24, 12))
			end
			return {
				ok = true,
				why = nil,
				loop = function()
					return samples
				end,
				lineSample = function()
					return lineIdx
				end,
				gates = gates,
				spawn = Kit.spawnAt(lineS, 14),
				pads = pads,
				order = order,
			}
		end
		cur, entry = nxt, back
	end
	return fail("Road loops wrong")
end

-- ===== Building (Roblox only) =====

TrackTiles.GRASS_GRIP = 0.75 -- same grass as the race plot
TrackTiles.GRASS_DRAG = 0.5
TrackTiles.OIL_GRIP = 0.35 -- the car reads Grip off whatever is under each wheel
TrackTiles.CURB_HEIGHT = 0.4

local function rgb(r: number, g: number, b: number): Color3
	local c: any = Color3
	return if c then c.fromRGB(r, g, b) else nil :: any
end
local ROAD_COLOR = rgb(52, 52, 58)
local GRASS_COLOR = rgb(86, 150, 70)
local BOOST_COLOR = rgb(255, 200, 40)
local OIL_COLOR = rgb(20, 20, 26)

-- Points along one path of a placed tile (world = plot-local), every SPACING or so, both ends.
local function pathPoints(grid: Grid, t: Tile, pth: Path): { Kit.Pt }
	local cx, cz = TrackTiles.cellCenter(grid, t.c, t.r)
	local cell = TrackTiles.CELL
	local n = 12
	local out = {}
	for i = 0, n do
		local u, v = pth.at(i / n)
		for _ = 1, t.rot do
			u, v = v, -u
		end
		table.insert(out, { x = cx + u * cell, z = cz - v * cell })
	end
	return out
end

local SURFACES: { [string]: { name: string, color: Color3, grip: number, drag: number?, mat: string } } =
	{
		boost = { name = "BoostPad", color = BOOST_COLOR, grip = 1, mat = "Neon" },
		oil = { name = "OilPatch", color = OIL_COLOR, grip = 0.35, mat = "Glass" },
		mud = { name = "MudPatch", color = rgb(110, 78, 46), grip = 0.6, drag = 0.8, mat = "Mud" },
		puddle = { name = "Puddle", color = rgb(70, 140, 210), grip = 0.5, mat = "Glass" },
		sand = {
			name = "SandPatch",
			color = rgb(222, 196, 130),
			grip = 0.8,
			drag = 1.2,
			mat = "Sand",
		},
	}

-- Hazards and powers sitting on a tile: plot-local CFrame from tile spots (u across, v along the
-- rot-0 road, in cells), so everything turns with the tile. With TileLooks around, the solid
-- blocks go see-through (same collide and grip) and TileLooks draws the real shapes on the spots.
local function buildExtras(parent: Instance, origin: CFrame, grid: Grid, t: Tile, hide: boolean)
	local cell = TrackTiles.CELL
	local ROAD = TrackTiles.ROAD
	local cx, cz = TrackTiles.cellCenter(grid, t.c, t.r)
	local yaw = CFrame.Angles(0, -t.rot * math.pi / 2, 0)
	local function at(u: number, y: number, v: number): CFrame
		return CFrame.new(cx, 0, cz) * yaw * CFrame.new(u * cell, y, -v * cell)
	end
	local function box(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Kit.part(parent, name, origin, size, cf, color)
		p:SetAttribute("Grip", 1)
		return p
	end
	local function solid(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = box(name, size, cf, color)
		if hide then
			p.Transparency = 1
		end
		return p
	end
	local id = t.piece
	local surf = SURFACES[id]
	if surf then
		-- a patch just on top of the road along the middle of the tile
		local pad =
			box(surf.name, Vector3.new(ROAD - 6, 0.04, cell * 0.6), at(0, 0.12, 0), surf.color)
		pad.Material = (Enum.Material :: any)[surf.mat]
		pad:SetAttribute("Grip", surf.grip)
		if surf.drag then
			pad:SetAttribute("Drag", surf.drag)
		end
		if id == "boost" then
			pad:SetAttribute("Boost", true) -- the car pushes forward while on it
		elseif id == "oil" then
			pad:SetAttribute("Oil", true)
		end
	elseif id == "jump" then
		-- a hump: up, flat top, down (works whichever way the loop runs)
		local h, w = 4, ROAD - 4
		local a, b2 = at(0, 0, -0.42).Position, at(0, h, -0.12).Position
		local c2, d2 = at(0, h, 0.12).Position, at(0, 0, 0.42).Position
		Kit.ramp(parent, "JumpRamp", origin, a, b2, w, BOOST_COLOR):SetAttribute("Grip", 1)
		Kit.ramp(parent, "JumpRamp", origin, d2, c2, w, BOOST_COLOR):SetAttribute("Grip", 1)
		box("JumpTop", Vector3.new(w, 1, cell * 0.24), at(0, h - 0.5, 0), ROAD_COLOR)
	elseif id == "cones" then
		for i, sp in { { -0.13, -0.3 }, { 0.13, -0.1 }, { -0.13, 0.1 }, { 0.13, 0.3 } } do
			solid("Cone", Vector3.new(3, 4, 3), at(sp[1], 2, sp[2]), Kit.COLORS.orange).Name = "Cone"
				.. i
		end
	elseif id == "barrels" then
		solid("Barrel", Vector3.new(12, 5, 6), at(-0.15, 2.5, -0.2), Kit.COLORS.red)
		solid("Barrel", Vector3.new(12, 5, 6), at(0.15, 2.5, 0.2), Kit.COLORS.red)
	elseif id == "bumps" then
		for _, v in { -0.25, 0, 0.25 } do
			solid("Bump", Vector3.new(ROAD - 2, 0.8, 3), at(0, 0.4, v), Kit.COLORS.white)
		end
	elseif id == "narrow" then
		for _, side in { -1, 1 } do
			solid(
				"Squeeze",
				Vector3.new(7, 3, cell * 0.4),
				at(side * (ROAD / 2 - 3.5) / cell, 1.5, 0),
				Kit.COLORS.red
			)
		end
	elseif id == "split" then
		solid("Island", Vector3.new(8, 2, cell * 0.55), at(0, 1, 0), rgb(86, 150, 70))
	end
end

-- Road, curbs, grass, the start line and boost / oil pads for every tile (loose ones too, so
-- the owner sees what they put down). Big studs, plot-local around origin, like Race.build.
function TrackTiles.build(parent: Instance, origin: CFrame, grid: Grid)
	local looksMod = if script then (script :: any).Parent:FindFirstChild("TileLooks") else nil
	local hide = looksMod ~= nil
	local C = Kit.COLORS
	local ROAD, CW, CH = TrackTiles.ROAD, TrackTiles.CURB_WIDTH, TrackTiles.CURB_HEIGHT
	local a = Kit.AREA
	local grass = Kit.part(
		parent,
		"Grass",
		origin,
		Vector3.new(a.maxX - a.minX, 0.04, a.maxZ - a.minZ),
		CFrame.new((a.minX + a.maxX) / 2, 0.02, (a.minZ + a.maxZ) / 2),
		GRASS_COLOR
	)
	grass:SetAttribute("Grip", TrackTiles.GRASS_GRIP)
	grass:SetAttribute("Drag", TrackTiles.GRASS_DRAG)
	grass.Material = Enum.Material.Grass

	-- every road point on the plot, so curbs never land on another bit of road
	local all: { { Kit.Pt } } = {}
	local owners: { Tile } = {}
	for _, t in grid.tiles do
		local def = BY_ID[t.piece]
		if def then
			for _, pth in def.paths do
				table.insert(all, pathPoints(grid, t, pth))
				table.insert(owners, t)
			end
		end
	end
	local function onRoad(x: number, z: number): boolean
		for _, pts in all do
			for _, p in pts do
				if (p.x - x) ^ 2 + (p.z - z) ^ 2 < (ROAD / 2 - 0.5) ^ 2 then
					return true
				end
			end
		end
		return false
	end

	for k, pts in all do
		local t = owners[k]
		for i = 1, #pts - 1 do
			local p, q = pts[i], pts[i + 1]
			local road = Kit.slab(
				parent,
				"Road",
				origin,
				Vector3.new(p.x, 0.05, p.z),
				Vector3.new(q.x, 0.05, q.z),
				ROAD,
				0.1,
				1.5,
				ROAD_COLOR
			)
			road:SetAttribute("Grip", 1)
			local patch =
				Kit.disc(parent, "Road", origin, p.x, 0.05, p.z, ROAD / 2, 0.1, ROAD_COLOR)
			patch:SetAttribute("Grip", 1)
			-- low red / white curbs on both edges
			local dx, dz = q.x - p.x, q.z - p.z
			local d = math.sqrt(dx * dx + dz * dz)
			local tx, tz = dx / d, dz / d
			local off = ROAD / 2 + CW / 2
			for _, side in { -1, 1 } do
				local o = off * side
				local ax, az = p.x - tz * o, p.z + tx * o
				local bx, bz = q.x - tz * o, q.z + tx * o
				if not onRoad(ax, az) and not onRoad(bx, bz) then
					local curb = Kit.slab(
						parent,
						"Curb",
						origin,
						Vector3.new(ax, CH / 2, az),
						Vector3.new(bx, CH / 2, bz),
						CW,
						CH,
						0.5,
						if i % 2 == 0 then C.white else C.red
					)
					curb:SetAttribute("Grip", 1)
				end
			end
		end
		if k == 1 or owners[k - 1] ~= t then
			buildExtras(parent, origin, grid, t, hide)
		end
	end

	-- extra looks per tile (Prettier plots thread's TileLooks: never collide, never change grip)
	if looksMod then
		local TileLooks: any = require(looksMod)
		for _, t in grid.tiles do
			local cx, cz = TrackTiles.cellCenter(grid, t.c, t.r)
			local at = origin * CFrame.new(cx, 0, cz) * CFrame.Angles(0, -t.rot * math.pi / 2, 0)
			pcall(TileLooks.make, t.piece, parent, at, TrackTiles.CELL)
		end
	end

	-- checkered start line across the START tile
	local res = TrackTiles.trace(grid)
	local st: Tile? = nil
	for _, t in grid.tiles do
		if t.piece == "start" then
			st = t
		end
	end
	if st then
		local pts = pathPoints(grid, st, BY_ID.start.paths[1])
		local mid = pts[7]
		local fx, fz = pts[8].x - mid.x, pts[8].z - mid.z
		local fd = math.sqrt(fx * fx + fz * fz)
		fx, fz = fx / fd, fz / fd
		local rx, rz = -fz, fx
		local cells = 6
		local size = ROAD / cells
		for row = 0, 1 do
			for i = 0, cells - 1 do
				local across = (i + 0.5) * size - ROAD / 2
				local along = (row - 0.5) * 3
				Kit.line(
					parent,
					origin,
					mid.x + rx * across + fx * along,
					0,
					mid.z + rz * across + fz * along,
					fx,
					fz,
					size,
					if (i + row) % 2 == 0 then C.white else ROAD_COLOR
				)
			end
		end
	end
	parent:SetAttribute("TrackReady", res.ok)
end

-- The driving data for a traced track, in TrackData.Track's shape (the Lobby thread stores
-- it as JSON in the plot's TrackJson attribute). Same feel as the race plot.
function TrackTiles.track(res: Result): { [string]: any }?
	if not res.ok then
		return nil
	end
	return { mode = "loop", grip = 0.75, spawn = res.spawn, gates = res.gates }
end

-- For the build screen: is it race ready, and if not, why (tiny words).
function TrackTiles.ready(grid: Grid): (boolean, string?)
	local res = TrackTiles.trace(grid)
	return res.ok, res.why
end

return TrackTiles
