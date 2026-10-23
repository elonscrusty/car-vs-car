--!strict
-- Tests for build-your-own-track tiles (shared/TrackTiles.luau).
local H = require("./harness")
local T = require("../src/shared/TrackTiles")
local Kit = require("../src/shared/Plots/Kit")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Track tiles")

-- smallest distance between two bits of road that are far apart along the loop
local function closestApproach(ring: { any }, step: number): number
	local best = math.huge
	local n = #ring
	for i = 1, n do
		for j = i + 1, n do
			local gap = math.min(j - i, n - (j - i))
			if gap > step then
				local dx, dz = ring[i].x - ring[j].x, ring[i].z - ring[j].z
				best = math.min(best, math.sqrt(dx * dx + dz * dz))
			end
		end
	end
	return best
end

local function roadInside(ring: { any }): boolean
	local edge = T.ROAD / 2 + T.CURB_WIDTH
	for _, s in ring do
		for _, side in { -1, 1 } do
			if not Kit.inArea(s.x - s.tz * edge * side, s.z + s.tx * edge * side) then
				return false
			end
		end
	end
	return true
end

test("every piece has a name, a tier and two or four ends", function()
	for _, p in T.PIECES do
		local n = 0
		for _, v in p.ends :: any do
			if v then
				n += 1
			end
		end
		truthy(n == 2 or n == 4, p.id)
		truthy(p.tier == "free" or p.tier == "coins" or p.tier == "legendary", p.id)
	end
	eq((T.piece("turn") :: any).ends.E, true)
	eq((T.piece("turn") :: any).ends.S, false)
end)

test("sizes grow with stars", function()
	local c, r = T.sizeFor(0)
	eq(c * 10 + r, 44)
	c, r = T.sizeFor(10)
	eq(c * 10 + r, 55)
	c, r = T.sizeFor(999)
	eq(c * 10 + r, 56)
end)

test("the starter circle is race ready at every size", function()
	for _, s in T.SIZES do
		local g = T.circle(s.cols, s.rows)
		local res = T.trace(g)
		truthy(res.ok, res.why)
		eq(#res.order, 2 * s.cols + 2 * s.rows - 4)
		eq(#res.gates, 5)
		truthy(roadInside(res.loop()), "road off the plot")
		truthy(T.track(res) ~= nil)
	end
end)

test("the start line sits on the START tile and gates go round in order", function()
	local res = T.trace(T.circle(4, 4))
	local line = res.loop()[res.lineSample()]
	local g = T.copy(T.circle(4, 4))
	local st
	for _, t in g.tiles do
		if t.piece == "start" then
			st = t
		end
	end
	local cx, cz = T.cellCenter(g, st.c, st.r)
	truthy(math.abs(line.x - cx) < T.CELL / 2 and math.abs(line.z - cz) < T.CELL / 2)
	eq(res.gates[1].x, line.x)
	-- spawn is behind the line, facing along the road
	local sp = res.spawn :: any
	truthy((line.x - sp.x) * sp.dx + (line.z - sp.z) * sp.dz > 0)
end)

test("a gap is not ready", function()
	local g = T.circle(4, 4)
	T.remove(g, 4, 2)
	local ok, why = T.ready(g)
	eq(ok, false)
	eq(why, "Road has a gap")
end)

test("a piece turned wrong is a gap", function()
	local g = T.circle(4, 4)
	local t = T.get(g, 1, 1) :: any -- front-left corner turn
	t.rot = (t.rot + 1) % 4
	eq(T.ready(g), false)
end)

test("no START = not ready, START can move but not go", function()
	local g = T.circle(4, 4)
	local ok = T.remove(g, 2, 1)
	eq(ok, false)
	ok = T.place(g, 2, 1, "straight", 1)
	eq(ok, false)
	-- moving the START onto another straight keeps one START and stays ready
	ok = T.place(g, 3, 1, "start", 1)
	eq(ok, true)
	local starts = 0
	for _, t in g.tiles do
		if t.piece == "start" then
			starts += 1
		end
	end
	eq(starts, 1)
	eq(T.ready(g), false) -- old START spot is empty now
	T.place(g, 2, 1, "straight", 1)
	eq(T.ready(g), true)
end)

test("place checks the cell, the piece and the turn", function()
	local g = T.circle(4, 4)
	eq((T.place(g, 0, 1, "straight", 0)), false)
	eq((T.place(g, 5, 1, "straight", 0)), false)
	eq((T.place(g, 2, 2, "rocket", 0)), false)
	eq((T.place(g, 2, 2, "straight", 4)), false)
	eq((T.place(g, 2, 2, "straight", 1.5)), false)
	eq((T.place(g, 2, 2, "straight", 3)), true)
end)

test("swapping straights for legendary and coin pieces stays ready", function()
	local g = T.circle(5, 5)
	-- front row: START at col 2, straights at 3 and 4 going east (rot 1)
	T.place(g, 3, 1, "boost", 1)
	T.place(g, 4, 1, "oil", 3) -- a straight works either way round
	T.place(g, 5, 3, "chicane", 0)
	T.place(g, 1, 1, "sharp", T.fit("sharp", 0, 1) :: number)
	local res = T.trace(g)
	truthy(res.ok, res.why)
	eq(#res.pads, 2)
	truthy(roadInside(res.loop()))
end)

test("a figure 8 through a CROSS tile works", function()
	-- 3x3 with a cross in the middle:
	--  turn  str  turn        row 3
	--  str   X    str ...
	local g: T.Grid = { cols = 3, rows = 3, tiles = {} }
	local function put(c: number, r: number, id: string, a: number, b: number)
		table.insert(g.tiles, { c = c, r = r, piece = id, rot = T.fit(id, a, b) :: number })
	end
	-- loop A: (2,1) start going N, cross (2,2), (2,3) turn N->... use a shape:
	-- start (2,1) N -> cross (2,2) -> (2,3) turn S->E -> (3,3) turn W->S -> (3,2) turn N->W
	-- -> cross (2,2) E->W -> (1,2) turn E->S -> (1,1) turn N->E -> back into start from W? no:
	-- start enters from S, so finish (1,1) N->E into (2,1)? that enters from W. Use a bigger shape.
	g = { cols = 4, rows = 4, tiles = {} }
	table.insert(g.tiles, { c = 2, r = 1, piece = "start", rot = 0 }) -- S -> N
	put(2, 2, "cross", 2, 0)
	put(2, 3, "turn", 2, 1) -- in from S, out E
	put(3, 3, "turn", 3, 2) -- in from W, out S
	put(3, 2, "turn", 0, 3) -- in from N, out W
	-- cross E -> W
	put(1, 2, "turn", 1, 2) -- in from E, out S
	put(1, 1, "straight", 0, 2) -- dead end? needs to come round under the start
	-- (1,1) cannot reach the START's south side inside the grid, so this one is not ready
	eq(T.ready(g), false)
	-- shift everything up one row so there is room to come round below
	g = { cols = 4, rows = 4, tiles = {} }
	table.insert(g.tiles, { c = 2, r = 2, piece = "start", rot = 0 })
	put(2, 3, "cross", 2, 0)
	put(2, 4, "turn", 2, 1)
	put(3, 4, "turn", 3, 2)
	put(3, 3, "turn", 0, 3)
	put(1, 3, "turn", 1, 2)
	put(1, 2, "straight", 0, 2)
	put(1, 1, "turn", 0, 1)
	put(2, 1, "turn", 3, 0)
	local res = T.trace(g)
	truthy(res.ok, res.why)
	eq(#res.order, 10) -- the cross is driven twice
end)

test("plain tracks never touch themselves", function()
	local res = T.trace(T.circle(5, 6))
	truthy(closestApproach(res.loop(), 6) > T.ROAD + 6)
end)

test("road off the edge is caught", function()
	local g = T.circle(4, 4)
	T.place(g, 4, 1, "straight", 1) -- points east, off the right side
	local ok, why = T.ready(g)
	eq(ok, false)
	eq(why, "Road runs off the plot")
end)

-- ===== drag and drop =====

local function emptyWithStart(): T.Grid
	local g: T.Grid = { cols = 4, rows = 4, tiles = {} }
	table.insert(g.tiles, { c = 2, r = 1, piece = "start", rot = 1 }) -- going east
	return g
end

test("dragging a ring of squares from the START makes a ready track", function()
	local g = emptyWithStart()
	local ok = T.drawPath(
		g,
		{ { 2, 1 }, { 3, 1 }, { 3, 2 }, { 3, 3 }, { 2, 3 }, { 1, 3 }, { 1, 2 }, { 1, 1 }, { 2, 1 } }
	)
	eq(ok, true)
	local res = T.trace(g)
	truthy(res.ok, res.why)
	eq((T.get(g, 2, 1) :: any).piece, "start")
end)

test("drag must go square by square and stay on the plot", function()
	local g = emptyWithStart()
	eq((T.drawPath(g, { { 1, 1 }, { 3, 1 } })), false)
	eq((T.drawPath(g, { { 4, 1 }, { 5, 1 } })), false)
	eq((T.drawPath(g, { { 1, 1 } })), false)
end)

test("dragging across a straight road makes a crossing", function()
	local g = T.circle(4, 4)
	T.drawPath(g, { { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 } })
	-- (1,2) and (4,2) were straights on the sides: the ends join the old road (turns / tees)
	eq((T.get(g, 2, 2) :: any).piece, "straight")
	local g2 = T.circle(5, 5)
	-- an end of the drag joins the old road instead of making a crossing
	T.drawPath(g2, { { 3, 3 }, { 3, 2 }, { 3, 1 } })
	truthy((T.get(g2, 3, 1) :: any).piece ~= "cross")
	-- a north-south straight, then a drag straight across it
	T.place(g2, 3, 2, "straight", 0)
	T.drawPath(g2, { { 2, 2 }, { 3, 2 }, { 4, 2 } })
	eq((T.get(g2, 3, 2) :: any).piece, "cross")
end)

test("dropping special tiles turns them to fit the road", function()
	local g = T.circle(4, 4)
	eq((T.drop(g, 3, 1, "boost")), true) -- front straight
	eq((T.get(g, 3, 1) :: any).piece, "boost")
	eq((T.drop(g, 1, 1, "sharp")), true) -- corner turn
	eq((T.drop(g, 1, 2, "sharp")), false) -- a straight
	eq((T.drop(g, 4, 4, "oil")), false) -- a corner
	eq((T.drop(g, 2, 2, "boost")), false) -- grass
	eq((T.drop(g, 2, 1, "oil")), false) -- the START
	eq((T.drop(g, 4, 2, "cross")), true)
	truthy(T.trace(g).ok)
	truthy(T.ALL_FREE)
end)
