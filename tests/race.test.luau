--!strict
local Harness = require("./harness")
local Race = require("../src/shared/Race")
local RaceTrack = require("../src/shared/RaceTrack")
local Config = require("../src/shared/RaceTrackConfig")
local ModesConfig = require("../src/shared/ModesConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("Race")

test("track is a sensible loop", function()
	local n = RaceTrack.count()
	truthy(n >= 6)
	local len = RaceTrack.lapLength()
	truthy(len > 800 and len < 1600, "lap length " .. len)
	for i = 1, n do
		truthy(
			RaceTrack.segmentLength(i) > Config.roadWidth,
			"stretch " .. i .. " is longer than the road is wide"
		)
		local dx, dz = RaceTrack.direction(i)
		near(dx * dx + dz * dz, 1, 1e-6)
	end
	eq(RaceTrack.point(0), RaceTrack.point(n))
	eq(RaceTrack.point(n + 1), RaceTrack.point(1))
end)

test("ramps sit on real stretches", function()
	for _, r in Config.ramps do
		truthy(r.seg >= 1 and r.seg <= RaceTrack.count())
		truthy(r.t > 0 and r.t < 1)
		truthy(r.width < Config.roadWidth)
	end
end)

test("grid: behind the line, facing the first stretch, nobody overlaps", function()
	local spots = RaceTrack.grid(ModesConfig.Race.cars)
	eq(#spots, ModesConfig.Race.cars)
	local start = RaceTrack.point(1)
	local dx, dz = RaceTrack.direction(1)
	for i, a in spots do
		local ahead = (a.x - start.x) * dx + (a.z - start.z) * dz
		truthy(ahead < 0, "car " .. i .. " starts behind the line")
		near(a.yaw, RaceTrack.yawFor(dx, dz), 1e-9)
		truthy(RaceTrack.onRoad(a.x, a.z), "car " .. i .. " starts on the road")
		for j = i + 1, #spots do
			local b = spots[j]
			truthy(
				math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 10,
				"cars " .. i .. "," .. j .. " apart"
			)
		end
	end
end)

test("respawn spot is on the road at the last passed waypoint", function()
	for i = 1, RaceTrack.count() do
		for slot = 1, 3 do
			local s = RaceTrack.respawn(i, slot)
			truthy(RaceTrack.onRoad(s.x, s.z))
		end
	end
end)

test("ground bounds cover every waypoint with a margin", function()
	local x0, x1, z0, z1 = RaceTrack.bounds()
	for _, p in Config.waypoints do
		truthy(p.x - x0 >= Config.groundMargin - 1e-6 and x1 - p.x >= Config.groundMargin - 1e-6)
		truthy(p.z - z0 >= Config.groundMargin - 1e-6 and z1 - p.z >= Config.groundMargin - 1e-6)
	end
	truthy(not RaceTrack.onRoad(x1, z1))
end)

local function drive(s: Race.State, i: number, laps: number, now: number)
	-- Pass every waypoint in order, `laps` times round (starting by aiming at waypoint 2).
	local n = RaceTrack.count()
	for _ = 1, laps * n do
		local p = RaceTrack.point(s.cars[i].next)
		Race.reach(s, i, p.x, p.z, p.x, p.z, 5, now)
	end
end

test("waypoints count only in order, and only when close", function()
	local s = Race.new(2, 3, 9)
	truthy(not Race.reach(s, 1, 100, 100, 0, 0, 30, 0), "too far")
	truthy(Race.reach(s, 1, 10, 0, 0, 0, 30, 0))
	eq(s.cars[1].next, 3)
	eq(s.cars[1].passed, 1)
	eq(s.cars[2].next, 2, "other car unchanged")
	truthy(not Race.reach(s, 99, 0, 0, 0, 0, 30, 0), "no such car")
end)

test("a full lap goes round to waypoint 1 and starts lap 2", function()
	local s = Race.new(1, 3, 9)
	for _ = 1, 8 do -- waypoints 2..9
		Race.reach(s, 1, 0, 0, 0, 0, 5, 1)
	end
	eq(s.cars[1].next, 1)
	eq(s.cars[1].lap, 1)
	Race.reach(s, 1, 0, 0, 0, 0, 5, 2) -- the line
	eq(s.cars[1].lap, 2)
	eq(s.cars[1].next, 2)
	truthy(s.cars[1].finishedAt == nil)
end)

test("finishing the last lap records the order", function()
	local s = Race.new(3, 2, 9)
	drive(s, 2, 2, 10)
	truthy(s.cars[2].finishedAt ~= nil)
	eq(s.order[1], 2)
	drive(s, 3, 2, 12)
	eq(s.order[2], 3)
	truthy(not Race.reach(s, 2, 0, 0, 0, 0, 5, 20), "a finished car does not move on")
	eq(#s.order, 2)
end)

test("positions: finished first, then progress, then distance to the next waypoint", function()
	local s = Race.new(4, 2, 9)
	drive(s, 4, 2, 5) -- car 4 finished
	s.cars[1].passed = 5
	s.cars[2].passed = 5
	s.cars[3].passed = 7
	local pos = Race.positions(s, { 50, 20, 99, 0 })
	eq(pos[4], 1)
	eq(pos[3], 2)
	eq(pos[2], 3, "same progress as car 1 but closer to its next waypoint")
	eq(pos[1], 4)
end)

test("leader at time up", function()
	local s = Race.new(2, 3, 9)
	eq(Race.leader(s, { 10, 20 }), 0, "nobody moved")
	s.cars[2].passed = 3
	eq(Race.leader(s, { 10, 20 }), 2)
end)

test("last passed waypoint, for respawns", function()
	local s = Race.new(1, 3, 9)
	eq(Race.lastPassed(s, 1), 1)
	Race.reach(s, 1, 0, 0, 0, 0, 5, 0)
	eq(Race.lastPassed(s, 1), 2)
	s.cars[1].next = 1
	eq(Race.lastPassed(s, 1), 9)
end)

test("ordinals", function()
	eq(Race.ordinal(1), "1st")
	eq(Race.ordinal(3), "3rd")
	eq(Race.ordinal(6), "6th")
end)
