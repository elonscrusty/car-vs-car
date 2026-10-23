--!strict
local H = require("./harness")
local ServerRace = require("../src/shared/ServerRace")
local TrackData = require("../src/shared/TrackData")
local Race = require("../src/shared/Plots/Race")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("ServerRace")

test("sign: break countdown, then whose track, then racing", function()
	eq(ServerRace.BREAK, 300)
	eq(ServerRace.clock(754), "12:34")
	eq(ServerRace.clock(-3), "0:00")
	eq(ServerRace.trackName("Mia"), "MIA'S TRACK")
	eq(ServerRace.trackName(nil), "")
	eq(ServerRace.signText(300, false, ""), "NEXT RACE IN\n5:00")
	eq(ServerRace.signText(8, false, "MIA'S TRACK"), "RACE IN 0:08\nMIA'S TRACK")
	eq(ServerRace.signText(0, true, "MIA'S TRACK"), "RACING NOW!\nMIA'S TRACK")
end)

test("pick: a random player plot first, the street's plots when nobody has one ready", function()
	eq(ServerRace.pick({ 3, 7 }, { 1 }, 0), 3)
	eq(ServerRace.pick({ 3, 7 }, { 1 }, 0.99), 7)
	eq(ServerRace.pick({ 3, 7 }, { 1 }, 1), 7)
	eq(ServerRace.pick({}, { 1, 8 }, 0.6), 8)
	eq(ServerRace.pick({}, {}, 0.5), nil)
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
