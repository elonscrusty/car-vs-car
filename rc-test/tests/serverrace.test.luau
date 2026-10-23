--!strict
local H = require("./harness")
local ServerRace = require("../src/shared/ServerRace")
local TrackData = require("../src/shared/TrackData")
local Race = require("../src/shared/Plots/Race")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("ServerRace")

test("next start is on the 15 minute mark, always ahead", function()
	eq(ServerRace.nextStart(0), 900)
	eq(ServerRace.nextStart(899.5), 900)
	eq(ServerRace.nextStart(900), 1800)
	eq(ServerRace.clock(754), "12:34")
	eq(ServerRace.clock(-3), "0:00")
	truthy(string.find(ServerRace.signText(45, false), "JOIN NOW") ~= nil)
	truthy(string.find(ServerRace.signText(300, false), "5:00") ~= nil)
	truthy(string.find(ServerRace.signText(0, true), "RACING") ~= nil)
end)

test("every grid spot is on the race road, apart, behind the line", function()
	local t = TrackData.get("race")
	local loop = Race.loop()
	local line = Race.gates[1]
	local at = Race.lineSample()
	for k = 1, ServerRace.MAX do
		local g = ServerRace.grid(loop, at, 14, k, t.spawn.y)
		-- distance to the road's centre line
		local best = math.huge
		for i, a in loop do
			local b = loop[i % #loop + 1]
			local ex, ez = b.x - a.x, b.z - a.z
			local u = math.clamp(((g.x - a.x) * ex + (g.z - a.z) * ez) / (ex * ex + ez * ez), 0, 1)
			best = math.min(best, math.sqrt((g.x - a.x - ex * u) ^ 2 + (g.z - a.z - ez * u) ^ 2))
		end
		truthy(best <= Race.ROAD / 2 - 5, `grid {k} off the road ({best})`)
		-- behind the start line (before it along the travel direction)
		local along = (g.x - line.x) * line.dx + (g.z - line.z) * line.dz
		truthy(along < -line.depth, `grid {k} not behind the line ({along})`)
		for j = 1, k - 1 do
			local o = ServerRace.grid(loop, at, 14, j, t.spawn.y)
			truthy(math.sqrt((g.x - o.x) ^ 2 + (g.z - o.z) ^ 2) >= 10, `grid {j} and {k} too close`)
		end
	end
end)

test("rank: finishers by time, then by laps; race ends when all are in", function()
	local r = ServerRace.rank({
		{ name = "c", laps = 1 },
		{ name = "a", laps = 3, time = 70.2 },
		{ name = "b", laps = 3, time = 65.1 },
		{ name = "d", laps = 2 },
	})
	eq(r[1].name, "b")
	eq(r[2].name, "a")
	eq(r[3].name, "d")
	eq(r[4].name, "c")
	eq(ServerRace.over({ { name = "a", laps = 3, time = 60 } }, 61, 60), true)
	eq(
		ServerRace.over({ { name = "a", laps = 3, time = 60 }, { name = "b", laps = 1 } }, 70, 60),
		false
	)
	eq(
		ServerRace.over({ { name = "a", laps = 3, time = 60 }, { name = "b", laps = 1 } }, 91, 60),
		true
	)
	eq(ServerRace.over({ { name = "b", laps = 1 } }, ServerRace.TIME_LIMIT, nil), true)
	near(ServerRace.GO_DELAY, 3.0, 1e-9)
end)
