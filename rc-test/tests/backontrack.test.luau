--!strict
-- Car VS Car big race: falling off or getting stuck puts the car back on the road at the last
-- gate, facing the way to go (a small loss, not the grid).
local H = require("./harness")
local BackOnTrack = require("../src/shared/BackOnTrack")
local LapTimer = require("../src/shared/LapTimer")
local RaceMaps = require("../src/shared/RaceMaps")
local LobbyLayout = require("../src/shared/LobbyLayout")
local Tuning = require("../src/shared/Tuning")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Back on track")

test("back on track: the gate just passed, round the lap", function()
	eq(BackOnTrack.lastGate(6, 2), 1) -- just over the line: the line
	eq(BackOnTrack.lastGate(6, 4), 3)
	eq(BackOnTrack.lastGate(6, 7), 6) -- after the last gate, before the line
	eq(BackOnTrack.lastGate(6, 8), 1) -- (LapTimer counts on: next 8 = gate 2 of the next lap)
end)

test("back on track: on every map, on the road and facing the next gate", function()
	for k, m in RaceMaps.list() do
		local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
		local timer = LapTimer.new(t.gates, t.mode)
		LapTimer.go(timer, 0)
		for next = 2, #t.gates + 1 do
			timer.next = next
			local sp = BackOnTrack.spot(t, timer.gates, timer.next) :: BackOnTrack.Spot
			local x, y, z, dx, dz = sp.x, sp.y, sp.z, sp.dx, sp.dz
			local g = t.gates[BackOnTrack.lastGate(#t.gates, next)]
			-- on the gate (the road), standing at least as high as the start
			truthy(LapTimer.inside(g, x, g.y, z), `{m.id} gate {next}: on the road`)
			truthy(y >= t.spawn.y)
			-- facing the next gate: it is ahead
			local n = t.gates[((next - 1) % #t.gates) + 1]
			truthy((n.x - x) * dx + (n.z - z) * dz > 0, `{m.id} gate {next}: faces the way to go`)
		end
		eq(BackOnTrack.spot(t, {}, 2), nil)
	end
end)

test("back on track: fell off the world, or stuck too long (not on the rocks)", function()
	local s = TrackData.RC_SCALE
	truthy(BackOnTrack.fell(-9, s)) -- (RC size: 8 studs under the floor)
	truthy(not BackOnTrack.fell(0, s))
	truthy(not BackOnTrack.fell(-1.5, s), "a dip in the road is not a fall")
	truthy(BackOnTrack.stuck(Tuning.stuckWait + 0.1, Tuning.stuckWait, "backyard"))
	truthy(not BackOnTrack.stuck(Tuning.stuckWait - 0.1, Tuning.stuckWait, "backyard"))
	truthy(not BackOnTrack.stuck(99, Tuning.stuckWait, "rock"))
end)

-- ===== lost in a big race: still, off the road, WRONG WAY (critic run 1) =====

local ServerRace = require("../src/shared/ServerRace")
local MapKit = require("../src/shared/Maps/MapKit")

test("lost: still 2.5 s after getting going puts it back, pedal or not", function()
	local l = BackOnTrack.newLost()
	local w = BackOnTrack.STILL_WAIT
	-- on the line after GO (HOLD GAS!) or in the first seconds: never
	eq(BackOnTrack.lost(l, 9, 5, false, true, true, false, true), nil)
	eq(BackOnTrack.lost(l, 9, nil, true, true, true, false, true), nil)
	eq(BackOnTrack.lost(l, 9, BackOnTrack.GO_CALM - 0.1, true, true, true, false, true), nil)
	eq(BackOnTrack.lost(l, w - 0.1, 10, true, true, false, false, false), nil)
	eq(BackOnTrack.lost(l, 0.2, 10, true, true, false, false, false), "still")
	-- the clocks start again after a put-back, and moving clears it
	eq(l.still, 0)
	eq(BackOnTrack.lost(l, w - 0.1, 20, true, true, false, false, false), nil)
	eq(BackOnTrack.lost(l, 0.1, 20, true, false, false, false, false), nil)
	eq(BackOnTrack.lost(l, 0.2, 20, true, true, false, false, false), nil)
end)

test("lost: 3 s off the road (in the air the clock waits), 3 s WRONG WAY", function()
	local l = BackOnTrack.newLost()
	local w = BackOnTrack.OFF_WAIT
	eq(BackOnTrack.lost(l, w - 0.5, 10, true, false, true, false, false), nil)
	eq(BackOnTrack.lost(l, 5, 10, true, false, true, true, false), nil) -- flying: waits
	eq(BackOnTrack.lost(l, 0.6, 10, true, false, true, false, false), "off")
	eq(BackOnTrack.lost(l, w - 0.1, 10, true, false, true, false, false), nil)
	eq(BackOnTrack.lost(l, 0.2, 10, true, false, false, false, false), nil) -- back on: clears
	eq(BackOnTrack.lost(l, BackOnTrack.WRONG_WAIT - 0.1, 10, true, false, false, false, true), nil)
	eq(BackOnTrack.lost(l, 0.2, 10, true, false, false, false, true), "wrong")
end)

for k, m in RaceMaps.list() do
	local roads = BackOnTrack.roads(m)
	local def = m.def

	test(`lost: {m.id} every road, its curbs and every jump are on the road`, function()
		eq(#roads, 1 + #def.paths)
		for r, ring in { m.loop(), m.path(1), m.path(2) } do
			local w = if r == 1 then def.road else def.paths[r - 1].width
			for i, s in ring do
				for _, o in { -1, -0.5, 0, 0.5, 1 } do
					local d = o * (w / 2 + MapKit.CURB_WIDTH)
					local x, z = s.x - s.tz * d, s.z + s.tx * d
					truthy(not BackOnTrack.offRoad(roads, x, z), `{m.id} road {r} sample {i} off`)
				end
			end
		end
		for _, j in def.jumps do
			truthy(not BackOnTrack.offRoad(roads, j.at.x, j.at.z), `{m.id} jump off the road`)
		end
		eq(BackOnTrack.CURB, MapKit.CURB_WIDTH)
	end)

	test(`lost: {m.id} out in the grass is off the road`, function()
		local loop = m.loop()
		local found = 0
		for i = 1, #loop, 8 do
			local s = loop[i]
			for _, side in { -1, 1 } do
				local d = side * (roads[1].reach + 30)
				local x, z = s.x - s.tz * d, s.z + s.tx * d
				local near = false
				for _, r in roads do
					near = near or MapKit.distTo(r.ring :: any, x, z) < r.reach + 15
				end
				if not near then
					found += 1
					truthy(BackOnTrack.offRoad(roads, x, z), `{m.id} {x}, {z} counts as on`)
				end
			end
		end
		truthy(found > 20, `only {found} grass spots tried`)
	end)

	-- a kid's slow pace round each real route (the main road, the shortcut, the secret): the lost
	-- clocks never put the car back
	local SPEED = 40 -- big units a second (the top bots go about 110)
	local DT = 1 / 30
	local function route(p: number): { MapKit.Sample }
		local loop = m.loop()
		local n = #loop
		local line = m.lineSample()
		local out = {}
		local function loopRun(from: number, to: number)
			local i = from
			while true do
				table.insert(out, loop[i])
				if i == to then
					break
				end
				i = (i % n) + 1
			end
		end
		if p == 0 then
			loopRun(line, (line - 2) % n + 1)
			loopRun(line, (line + 20 - 1) % n + 1)
			return out
		end
		local ring = m.path(p)
		local _, enter = MapKit.nearest(loop, ring[1])
		local _, leave = MapKit.nearest(loop, ring[#ring])
		loopRun(line, enter)
		for _, s in ring do
			table.insert(out, s)
		end
		loopRun(leave, (line + 20 - 1) % n + 1)
		return out
	end
	for p = 0, #def.paths do
		local name = if p > 0 then def.paths[p].kind else "main road"
		test(`lost: {m.id} driving the {name} never puts the car back`, function()
			local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
			local timer = LapTimer.new(t.gates, t.mode)
			LapTimer.go(timer, 0)
			local l = BackOnTrack.newLost()
			local pts = route(p)
			local now, laps, worstWrong, worstOff = 0, 0, 0, 0
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
				local steps = math.max(1, math.ceil(len / (SPEED * DT)))
				local vx, vz = (b.x - a.x) / len * SPEED, (b.z - a.z) / len * SPEED
				for st = 1, steps do
					local f = st / steps
					local x, z = a.x + (b.x - a.x) * f, a.z + (b.z - a.z) * f
					now += len / steps / SPEED
					if LapTimer.update(timer, now, x, 0, z) == "lap" then
						laps += 1
					end
					local g = t.gates[((timer.next - 1) % #t.gates) + 1]
					local wrong = ServerRace.wrongWay(vx, vz, g.x - x, g.z - z, 1)
					local off = BackOnTrack.offRoad(roads, x, z)
					local why = BackOnTrack.lost(
						l,
						len / steps / SPEED,
						now + 5,
						true,
						false,
						off,
						false,
						wrong
					)
					worstWrong = math.max(worstWrong, l.wrong)
					worstOff = math.max(worstOff, l.off)
					eq(why, nil, `{m.id} {name}: put back at {x}, {z}`)
				end
			end
			truthy(laps >= 1, `{m.id} {name}: no lap`)
			print(
				`    {m.id} {name}: longest WRONG WAY {math.floor(worstWrong * 10) / 10} s, off the road {worstOff} s`
			)
		end)
	end
end

test("back on track: driving off from every put-back spot is never WRONG WAY", function()
	for k, m in RaceMaps.list() do
		local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
		local count = #t.gates
		for next = 2, count + 1 do
			local sp = BackOnTrack.spot(t, t.gates, next) :: BackOnTrack.Spot
			local g = t.gates[((next - 1) % count) + 1] -- the gate the car heads for (Main)
			-- the first 40 units straight off the spot, at a kid's pace
			for d = 0, 40, 5 do
				local x, z = sp.x + sp.dx * d, sp.z + sp.dz * d
				truthy(
					not ServerRace.wrongWay(sp.dx * 40, sp.dz * 40, g.x - x, g.z - z, 1),
					`{m.id} next {next}: WRONG WAY {d} off the spot`
				)
			end
		end
	end
end)
