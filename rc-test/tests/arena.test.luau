--!strict
-- The Smash arena's numbers (ArenaData.luau, arena-topdown-v2.png): 12 start spots, 22 boxes, and
-- the hard target "a box within 5 s drive from any spot", measured on a drive grid round the walls.
local H = require("./harness")
local A = require("../src/shared/ArenaData")
local Tuning = require("../src/shared/Tuning")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Smash arena")

local K = A.K
local LO, HI = A.WALL + 1.5, A.PIC - A.WALL - 1.5 -- a kart's middle stays this far in

local function segDist(px: number, py: number, a: { number }, b: { number }): number
	local ax, ay = b[1] - a[1], b[2] - a[2]
	local l2 = ax * ax + ay * ay
	local u = if l2 > 0 then math.clamp(((px - a[1]) * ax + (py - a[2]) * ay) / l2, 0, 1) else 0
	local x, y = a[1] + ax * u, a[2] + ay * u
	return math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
end

-- the bumper wall's solid pieces (edges of the sand, minus the gaps)
local function bumperPieces(): { { { number } } }
	local out = {}
	local n = #A.SAND
	for i = 1, n do
		local a, b = A.SAND[i], A.SAND[i % n + 1]
		local cuts = { 0 }
		for _, g in A.SAND_GAPS do
			if g[1] == i then
				table.insert(cuts, g[2])
				table.insert(cuts, g[3])
			end
		end
		table.insert(cuts, 1)
		for k = 1, #cuts - 1, 2 do
			local u0, u1 = cuts[k], cuts[k + 1]
			table.insert(out, {
				{ a[1] + (b[1] - a[1]) * u0, a[2] + (b[2] - a[2]) * u0 },
				{ a[1] + (b[1] - a[1]) * u1, a[2] + (b[2] - a[2]) * u1 },
			})
		end
	end
	return out
end

-- Can a kart's middle be at picture point (x, y)? (half a kart = 1.5 picture units of room)
local BUMPERS = bumperPieces()
local function open(x: number, y: number): boolean
	if x < LO or x > HI or y < LO or y > HI then
		return false
	end
	for _, t in A.TREES do
		if math.sqrt((x - t[1]) ^ 2 + (y - t[2]) ^ 2) < 1.2 + 1.5 then
			return false
		end
	end
	for _, seg in A.COVER do
		if segDist(x, y, seg[1], seg[2]) < A.COVER_W / 2 + 1.5 then
			return false
		end
	end
	for _, seg in BUMPERS do
		if segDist(x, y, seg[1], seg[2]) < A.BUMPER_W / 2 + 1.5 then
			return false
		end
	end
	return true
end

-- Drive-grid distance (picture units) from the nearest box to every open cell. A kart can drive
-- down any drop but climb only a ramp-sized step, so the search runs backwards from the boxes.
local STEP = 2
local CLIMB = 1.3 -- big units a kart climbs in one 2-unit step (ramps rise under 1 per step)
local function distances(): ({ [number]: number }, number, number)
	local n = math.floor(A.PIC / STEP)
	local function key(i: number, j: number): number
		return i * 1000 + j
	end
	local dist: { [number]: number } = {}
	local frontier: { { number } } = {}
	for _, b in A.BOXES do
		local i, j = math.floor(b[1] / STEP + 0.5), math.floor(b[2] / STEP + 0.5)
		dist[key(i, j)] = 0
		table.insert(frontier, { i, j, 0 })
	end
	-- simple Dijkstra (a few thousand cells: a sorted pop is fine)
	local done: { [number]: boolean } = {}
	while #frontier > 0 do
		local best = 1
		for k = 2, #frontier do
			if frontier[k][3] < frontier[best][3] then
				best = k
			end
		end
		local c = table.remove(frontier, best) :: { number }
		local ck = key(c[1], c[2])
		if not done[ck] then
			done[ck] = true
			local hc = A.groundAt({ c[1] * STEP, c[2] * STEP })
			for di = -1, 1 do
				for dj = -1, 1 do
					if di ~= 0 or dj ~= 0 then
						local i, j = c[1] + di, c[2] + dj
						local x, y = i * STEP, j * STEP
						if i >= 0 and j >= 0 and i <= n and j <= n and open(x, y) then
							-- backwards: a kart drives from (i, j) to c, so c may be at most CLIMB higher
							local h = A.groundAt({ x, y })
							if hc - h <= CLIMB then
								local d = c[3] + STEP * math.sqrt(di * di + dj * dj)
								local k2 = key(i, j)
								if d < (dist[k2] or math.huge) then
									dist[k2] = d
									table.insert(frontier, { i, j, d })
								end
							end
						end
					end
				end
			end
		end
	end
	local cells, worst = 0, 0
	for i = 0, n do
		for j = 0, n do
			if open(i * STEP, j * STEP) then
				cells += 1
				worst = math.max(worst, dist[key(i, j)] or math.huge)
			end
		end
	end
	return dist, cells, worst
end

-- seconds to drive d big units from a stop: full gas up to a cautious cruise speed (turns, bumps
-- and other karts keep a kart under its top speed most of the time)
local CRUISE = 0.6
local function driveTime(d: number): number
	(Tuning :: any).setMode("race");
	(Tuning :: any).setScale(1) -- big units, whatever an earlier test left
	local v, a = Tuning.topSpeed * CRUISE, Tuning.accel
	local ramp = v * v / (2 * a)
	if d <= ramp then
		return math.sqrt(2 * d / a)
	end
	return v / a + (d - ramp) / v
end

test("12 start spots and 22 box spots, all inside the walls and on open floor", function()
	eq(#A.spawns, 12, "start spots")
	eq(#A.boxSpots, 22, "box spots")
	for i, p in A.START do
		truthy(open(p[1], p[2]), "start spot " .. i .. " is clear of walls and trees")
	end
	for i, p in A.BOXES do
		truthy(open(p[1], p[2]), "box " .. i .. " is clear of walls and trees")
	end
end)

test("start spots face the middle and are well apart", function()
	for i, s in A.spawns do
		truthy(math.abs(s.dx * s.dx + s.dz * s.dz - 1) < 1e-6, "unit direction " .. i)
		truthy(s.dx * s.x + s.dz * s.z < 0, "spot " .. i .. " faces the middle")
		for j = i + 1, #A.spawns do
			local o = A.spawns[j]
			truthy(math.sqrt((s.x - o.x) ^ 2 + (s.z - o.z) ^ 2) > 30, `spots {i} and {j} apart`)
		end
	end
end)

test("hills: boxes on them sit on top, ramps are gentle", function()
	eq(A.boxSpots[6].y, A.HILLS[1].h, "HIGH PINK box on top")
	eq(A.boxSpots[15].y, A.HILLS[2].h, "LOW PINK box on top")
	for i, r in A.RAMPS do
		local len = math.sqrt((r.to[1] - r.from[1]) ^ 2 + (r.to[2] - r.from[2]) ^ 2) * K
		truthy(math.deg(math.atan(r.h / len)) < 18, "ramp " .. i .. " under 18 degrees")
	end
	eq(A.groundAt({ 1, 1 }), 0, "plain floor")
	eq(A.groundAt({ 30, 20 }), A.STEP_H, "the purple step")
end)

test("hard target: every open spot is within 5 s drive of a box (and none is cut off)", function()
	local _, cells, worst = distances()
	truthy(cells > 10000, "the grid covers the arena")
	truthy(worst < math.huge, "every open spot can drive to a box")
	local seconds = driveTime(worst * K)
	print(
		`    farthest open spot: {math.floor(worst * K)} big units of driving, {math.floor(
			seconds * 10
		) / 10} s`
	)
	truthy(seconds <= 5, "farthest open spot reaches a box in 5 s")
end)

test("the arena is a track the driving code can place karts in", function()
	local t = A.track()
	eq(t.id, "arena", "id")
	eq(t.mode, "arena", "mode")
	eq(#t.gates, 0, "no gates")
	eq(t.rcZ, A.RC_Z, "placed")
	eq(t.spawn.x, A.spawns[1].x, "spawn = start spot 1")
end)
