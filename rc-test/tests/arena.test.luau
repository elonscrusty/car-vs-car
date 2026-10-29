--!strict
-- The Smash arena's numbers (ArenaData.luau, arena-topdown-v2.png): 12 start spots, 22 boxes, and
-- the hard target "a box within 5 s drive from any spot", measured on a drive grid round the walls.
local H = require("./harness")
local A = require("../src/shared/ArenaData")
local Tuning = require("../src/shared/Tuning")
local TrackData = require("../src/shared/TrackData")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Smash arena")

local K = A.K

-- Can a kart's middle be at picture point (x, y)? (half a kart = 1.5 picture units of room)
local function open(x: number, y: number): boolean
	return A.clear(x, y, 1.5)
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

test(
	"start spots face the middle (or along a wall), the chase cam fits behind, well apart",
	function()
		for i, s in A.spawns do
			truthy(A.facing(A.START[i]) ~= nil, "spot " .. i .. " has a way to face")
			truthy(A.viewOpen(A.START[i], s.dx, s.dz), "spot " .. i .. " looks at open arena first")
			local p = A.START[i]
			for _, o in { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } } do
				eq(
					A.groundAt({ p[1] + o[1], p[2] + o[2] }),
					A.groundAt(p),
					"spot " .. i .. " on flat ground"
				)
			end
			truthy(math.abs(s.dx * s.dx + s.dz * s.dz - 1) < 1e-6, "unit direction " .. i)
			truthy(
				s.dx * s.x + s.dz * s.z <= 1e-6,
				"spot " .. i .. " doesn't face away from the middle"
			)
			local half = A.SIZE / 2 - A.WALL * K
			for _, q in
				{
					{ s.x - s.dx * A.CAM_BACK, s.z - s.dz * A.CAM_BACK },
					{ s.x + s.dx * A.NOSE_ROOM, s.z + s.dz * A.NOSE_ROOM },
				}
			do
				truthy(
					math.abs(q[1]) < half and math.abs(q[2]) < half,
					"spot " .. i .. ": cam and nose inside the walls"
				)
			end
			for j = i + 1, #A.spawns do
				local o = A.spawns[j]
				truthy(math.sqrt((s.x - o.x) ^ 2 + (s.z - o.z) ^ 2) > 30, `spots {i} and {j} apart`)
			end
		end
	end
)

test("from every spawn: nothing solid on the chase cam's line or 6 kart lengths ahead", function()
	for i, s in A.spawns do
		local p = A.START[i]
		local t = -A.CAM_BACK / K
		local ahead = 6 * 5.5 / K
		while t <= ahead do
			local q = { p[1] + s.dx * t, p[2] + s.dz * t }
			truthy(A.clear(q[1], q[2], 1.5), `spot {i}: clear at {math.floor(t * K)} big`)
			t += 0.5
		end
		-- and no tree stem standing in the view lane (a kart width either side of the line)
		local a = { p[1] - s.dx * A.CAM_BACK / K, p[2] - s.dz * A.CAM_BACK / K }
		local b = { p[1] + s.dx * ahead, p[2] + s.dz * ahead }
		for j, tr in A.TREES do
			local ax, ay = b[1] - a[1], b[2] - a[2]
			local u =
				math.clamp(((tr[1] - a[1]) * ax + (tr[2] - a[2]) * ay) / (ax * ax + ay * ay), 0, 1)
			local d = math.sqrt((tr[1] - a[1] - ax * u) ^ 2 + (tr[2] - a[2] - ay * u) ^ 2)
			truthy(d > 6, `spot {i}: tree {j} in the view lane ({math.floor(d * 10) / 10} off it)`)
		end
	end
end)

test(
	"placed the way the match places a kart (TrackData world spot and facing): open ahead and behind",
	function()
		-- MatchRunner.spawnWorld and the client's "drive" both turn ArenaData's spot into the world
		-- with TrackData.toWorld / dirToWorld on ArenaData.track(): walk that same world line back
		-- to the arena and check it
		local t = A.track()
		local S = TrackData.RC_SCALE
		for i, s in A.spawns do
			local wx, wy, wz = TrackData.toWorld(t, true, s.x, s.y, s.z)
			local dx, dz = TrackData.dirToWorld(t, true, s.dx, s.dz)
			truthy(math.abs(dx * dx + dz * dz - 1) < 1e-6, `spot {i}: a unit facing in the world`)
			local d = -A.CAM_BACK * S
			while d <= 3 * 5.5 * S do
				local lx, _, lz = TrackData.toLocal(t, true, wx + dx * d, wy, wz + dz * d)
				local px, py = lx / K + A.PIC / 2, lz / K + A.PIC / 2
				truthy(
					A.clear(px, py, 1.5),
					`spot {i}: clear {math.floor(d / S)} big along its world facing`
				)
				d += 0.5 * K * S
			end
			-- and the world facing points into the arena, not at the wall behind
			local lx, _, lz = TrackData.toLocal(t, true, wx + dx, wy, wz + dz)
			truthy(
				(lx - s.x) * -s.x + (lz - s.z) * -s.z >= -1e-6,
				`spot {i}: faces the middle side`
			)
		end
	end
)

test(
	"no wedge spots: rocks and crates gone, round-off corners, a bumper round each hill but its ramp",
	function()
		eq(#A.ROCKS, 0, "no rocks")
		eq(#A.CRATES, 0, "no crates")
		eq(#A.rampFillets, 2 * #A.RAMPS, "a fillet each side of each ramp")
		-- a kart can't get its nose into a wall corner: a curve fills each one, the big ones (all
		-- but the north-west) well out
		for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			local reach = if c[1] < 0 and c[2] < 0 then 1.5 else 4.5
			local x = A.PIC / 2 + c[1] * (A.PIC / 2 - A.WALL - reach)
			local y = A.PIC / 2 + c[2] * (A.PIC / 2 - A.WALL - reach)
			truthy(not A.clear(x, y, 0), `corner {c[1]},{c[2]} filled`)
		end
		-- the way up each ramp is open; every hill edge's middle (away from a ramp) is bumpered
		for i, r in A.RAMPS do
			for k = 0, 10 do
				local u = k / 10
				local q =
					{ r.from[1] + (r.to[1] - r.from[1]) * u, r.from[2] + (r.to[2] - r.from[2]) * u }
				truthy(A.clear(q[1], q[2], 1), `ramp {i} open at {u}`)
			end
		end
		for _, h in A.HILLS do
			for j = 1, #h.poly do
				local a, b = h.poly[j], h.poly[j % #h.poly + 1]
				local m = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }
				local nearRamp = false
				for _, r in A.RAMPS do
					if math.sqrt((m[1] - r.to[1]) ^ 2 + (m[2] - r.to[2]) ^ 2) < r.width then
						nearRamp = true
					end
				end
				if not nearRamp then
					truthy(not A.clear(m[1], m[2], 0), `{h.name} edge {j} has its bumper`)
				end
			end
		end
	end
)

test("hills: boxes on them sit on top, ramps are gentle", function()
	eq(A.boxSpots[6].y, A.HILLS[1].h, "HIGH PINK box on top")
	eq(A.boxSpots[15].y, A.HILLS[2].h, "LOW PINK box on top")
	for i, r in A.RAMPS do
		local len = math.sqrt((r.to[1] - r.from[1]) ^ 2 + (r.to[2] - r.from[2]) ^ 2) * K
		truthy(math.deg(math.atan(r.h / len)) < 18, "ramp " .. i .. " under 18 degrees")
	end
	eq(A.groundAt({ 120, 120 }), 0, "plain floor")
	eq(A.groundAt({ 30, 20 }), A.STEP_H, "the purple platform")
	eq(A.spawns[1].y, A.STEP_H + 2.5, "start spot 1 on top of the platform")
	-- the hill sides are too steep to drive up, the platform's are gentle
	for _, h in A.HILLS do
		truthy(h.h / (h.slope * K) > 1.5, h.name .. " sides steep")
	end
	truthy(A.STEP_H / (A.STEP_SLOPE * K) < 0.3, "platform sides gentle")
	-- each ramp's deck reaches the full-height top
	for i, r in A.RAMPS do
		local ax, ay = r.to[1] - r.from[1], r.to[2] - r.from[2]
		local len = math.sqrt(ax * ax + ay * ay)
		local p =
			{ r.to[1] + ax / len * (A.RAMP_DECK - 0.5), r.to[2] + ay / len * (A.RAMP_DECK - 0.5) }
		eq(A.groundAt(p), r.h, "ramp " .. i .. " deck at the top")
		local hill = A.HILLS[i]
		local inner = A.insetPoly(hill.poly, hill.slope)
		truthy(A.inside(inner, p), "ramp " .. i .. " deck ends on the flat top")
	end
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
