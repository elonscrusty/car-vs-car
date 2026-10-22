--!strict
local H = require("./harness")
local TrackData = require("../src/shared/TrackData")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy = H.test, H.eq, H.truthy

print("TrackData")

local function closestApproach(ring: { TrackData.Sample }, step: number): number
	-- smallest distance between two parts of the loop that are far apart along the loop
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

test("race loop does not touch itself (road width fits)", function()
	local ring = TrackData.raceLoop()
	truthy(closestApproach(ring, 10) > TrackData.ROAD_RACE + 6, "too close")
end)

test("drift loop does not touch itself", function()
	local ring = TrackData.driftLoop()
	truthy(closestApproach(ring, 10) > TrackData.ROAD_DRIFT + 6, "too close")
end)

test("directions are unit length", function()
	for _, s in TrackData.raceLoop() do
		truthy(math.abs(s.tx * s.tx + s.tz * s.tz - 1) < 1e-6)
	end
end)

test("race spawn is just behind the start gate and crossing it starts the clock", function()
	local t = TrackData.get("race")
	eq(#t.gates, 4)
	local timer = LapTimer.new(t.gates, t.mode)
	eq(LapTimer.update(timer, 0, t.spawn.x, 0, t.spawn.z), nil)
	local g = t.gates[1]
	eq(LapTimer.update(timer, 1, g.x, 0, g.z), "start")
end)

test("a full race lap through the gates in order completes", function()
	local t = TrackData.get("race")
	local timer = LapTimer.new(t.gates, t.mode)
	local now = 0
	for _, g in t.gates do
		now += 10
		LapTimer.update(timer, now, g.x, 0, g.z)
	end
	now += 10
	eq(LapTimer.update(timer, now, t.gates[1].x, 0, t.gates[1].z), "lap")
end)

test("rock course: heights climb, rocks stay on the course and apart", function()
	eq(TrackData.rockHeight(200), 0)
	eq(TrackData.rockHeight(-200), 60)
	truthy(TrackData.rockHeight(0) > TrackData.rockHeight(50))
	local rocks = TrackData.rocks()
	truthy(#rocks >= 40, "too few rocks")
	for _, r in rocks do
		truthy(math.abs(r.x) <= TrackData.ROCK_HALF_WIDTH - 2)
	end
	for i = 1, #rocks do
		for j = i + 1, #rocks do
			local a, b = rocks[i], rocks[j]
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			truthy(d > a.r + b.r + 4, "rocks too close")
		end
	end
end)

test("rock course: spawn is behind the start gate, summit gate sits on the top", function()
	local t = TrackData.get("rock")
	local timer = LapTimer.new(t.gates, t.mode)
	eq(LapTimer.update(timer, 0, t.spawn.x, 0, t.spawn.z), nil)
	eq(LapTimer.update(timer, 1, 0, 0, 128), "start")
	eq(LapTimer.update(timer, 90, 0, 60, -120), "finish")
end)

test("rocks are the same every time", function()
	local a, b = TrackData.rocks(), TrackData.rocks()
	eq(#a, #b)
	eq(a[5].x, b[5].x)
end)
