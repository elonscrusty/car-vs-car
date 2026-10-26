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
	eq(ServerRace.signText(300, false, ""), "NEXT RACE\n5:00")
	eq(ServerRace.signText(8, false, "KITCHEN"), "RACE IN 0:08\nKITCHEN")
	eq(ServerRace.signText(0, true, "BACKYARD"), "RACING NOW!\nBACKYARD")
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

test("pay: every racer gets coins, the winner most", function()
	eq(ServerRace.payFor(1, true), ServerRace.PAY[1])
	truthy(ServerRace.payFor(1, true) > ServerRace.payFor(2, true), "1st beats 2nd")
	truthy(ServerRace.payFor(3, true) > ServerRace.payFor(4, true), "3rd beats 4th")
	eq(ServerRace.payFor(8, true), ServerRace.PAY_FINISH)
	truthy(ServerRace.payFor(1, false) > 0, "a try still pays")
	truthy(ServerRace.payFor(1, false) < ServerRace.PAY_FINISH, "finishing pays more")
end)

test("stars: finishers get stars by place, alone only the finish star", function()
	eq(ServerRace.starsFor(1, true, 4), 3)
	eq(ServerRace.starsFor(2, true, 4), 2)
	eq(ServerRace.starsFor(3, true, 4), 1)
	eq(ServerRace.starsFor(4, true, 4), 1)
	eq(ServerRace.starsFor(1, false, 4), 0)
	eq(ServerRace.starsFor(1, true, 1), 1)
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

test(
	"a built track (the starter circle) gives every grid spot on its road, behind its line",
	function()
		local TrackTiles = require("../src/shared/TrackTiles")
		local res = TrackTiles.trace(TrackTiles.circle(4, 4))
		truthy(res.ok, "circle not ready")
		local loop = res.loop()
		local line = res.gates[1]
		for k = 1, ServerRace.MAX do
			local g = ServerRace.gridOn(res, k, 2.5)
			local best = math.huge
			for i, a in loop do
				local b = loop[i % #loop + 1]
				local ex, ez = b.x - a.x, b.z - a.z
				local u =
					math.clamp(((g.x - a.x) * ex + (g.z - a.z) * ez) / (ex * ex + ez * ez), 0, 1)
				best =
					math.min(best, math.sqrt((g.x - a.x - ex * u) ^ 2 + (g.z - a.z - ez * u) ^ 2))
			end
			truthy(best <= TrackTiles.ROAD / 2 - 5, `grid {k} off the road ({best})`)
			local along = (g.x - line.x) * line.dx + (g.z - line.z) * line.dz
			truthy(along < -line.depth or along > 0, `grid {k} on the line ({along})`)
		end
	end
)

test("places, ordinals, medals and the wrong-way check", function()
	eq(ServerRace.ordinal(1), "1ST")
	eq(ServerRace.ordinal(2), "2ND")
	eq(ServerRace.ordinal(3), "3RD")
	eq(ServerRace.ordinal(4), "4TH")
	eq(ServerRace.ordinal(11), "11TH")
	eq(ServerRace.ordinal(22), "22ND")
	eq(ServerRace.medal(1), "🥇")
	eq(ServerRace.medal(4), "")
	-- a new lap beats every gate of the lap before
	truthy(ServerRace.progress(1, 1, 6, 50) > ServerRace.progress(0, 6, 6, 1), "lap order")
	-- same gate: closer to the next one is ahead
	truthy(ServerRace.progress(0, 3, 6, 10) > ServerRace.progress(0, 3, 6, 40), "dist order")
	local place = ServerRace.places({
		{ progress = ServerRace.progress(1, 2, 6, 20) },
		{ time = 70, progress = 0 },
		{ progress = ServerRace.progress(2, 0, 6, 5) },
		{ time = 65, progress = 0 },
	})
	eq(place[4], 1)
	eq(place[2], 2)
	eq(place[3], 3)
	eq(place[1], 4)
	eq(ServerRace.wrongWay(-30, 0, 1, 0, 10), true)
	eq(ServerRace.wrongWay(30, 0, 1, 0, 10), false)
	eq(ServerRace.wrongWay(0, 30, 1, 0, 10), false) -- side on (a bend) is fine
	eq(ServerRace.wrongWay(-5, 0, 1, 0, 10), false) -- too slow to count
end)

test("a drift round ranks by score and counts any points as a finish", function()
	local ranked = ServerRace.rankDrift({
		{ name = "a", laps = 0, score = 1200 },
		{ name = "b", laps = 0, score = 3400 },
		{ name = "c", laps = 0 },
	})
	eq(ranked[1].name, "b")
	eq(ranked[2].name, "a")
	eq(ranked[3].name, "c")
	eq(ServerRace.finished(ranked[1]), true)
	eq(ServerRace.finished(ranked[3]), false)
	eq(ServerRace.finished({ name = "d", laps = 3, time = 61 }), true)
	truthy(ServerRace.DRIFT_TIME > 30, "drift round too short")
end)

test("round clock: break, pick at the call, race at zero, or skip", function()
	local C = ServerRace.CALL
	eq(ServerRace.step("wait", C + 1, nil, 3), nil)
	eq(ServerRace.step("wait", C, nil, 3), "pick")
	eq(ServerRace.step("call", 1, 4, 3), nil)
	eq(ServerRace.step("call", 0, 4, 3), "race")
	eq(ServerRace.step("call", -2, 4, 3), "race") -- a late tick still starts it
	eq(ServerRace.step("call", 0, nil, 3), "skip") -- no plot was ready
	eq(ServerRace.step("call", 0, 4, 0), "skip") -- nobody here
	eq(ServerRace.step("racing", -50, 4, 3), nil) -- the race runs itself
end)

test("round clock: one whole round, ticking like the server", function()
	local phase, picked, t = "wait", nil :: number?, 0
	local startAt = ServerRace.BREAK
	local seen = {}
	while t < ServerRace.BREAK + 1 do
		local todo = ServerRace.step(phase, startAt - t, picked, 2)
		if todo == "pick" then
			phase, picked = "call", ServerRace.pick({ 5 }, { 1 }, 0.3)
			table.insert(seen, `pick {picked} at {startAt - t}`)
		elseif todo == "race" then
			table.insert(seen, `race {picked} at {startAt - t}`)
			phase, picked, startAt = "wait", nil, t + ServerRace.BREAK
		end
		t += 0.25
	end
	eq(#seen, 2)
	eq(seen[1], `pick 5 at {ServerRace.CALL}`)
	eq(seen[2], "race 5 at 0")
	eq(phase, "wait")
end)

test("pick: one ready plot is always it; the street's when no owner's is ready", function()
	for _, r in { 0, 0.5, 0.999 } do
		eq(ServerRace.pick({ 6 }, {}, r), 6)
		eq(ServerRace.pick({ 6 }, { 1, 2 }, r), 6) -- an owner's plot beats the street's
		eq(ServerRace.pick({}, { 2 }, r), 2)
	end
end)

test("build window: open all break, shut from the pick to the end of the race", function()
	local open, ends = ServerRace.build("wait", 1000.7)
	eq(open, true)
	eq(ends, math.floor(1000.7 - ServerRace.CALL))
	eq((ServerRace.build("call", 1000)), false)
	eq((ServerRace.build("racing", 1000)), false)
end)

test("a drift round gives stars like a race: 3, 2, 1 by score, none for no points", function()
	local ranked = ServerRace.rankDrift({
		{ name = "a", laps = 0, score = 1200 },
		{ name = "b", laps = 0, score = 3400 },
		{ name = "c", laps = 0, score = 600 },
		{ name = "d", laps = 0, score = 300 },
		{ name = "e", laps = 0 },
	})
	local stars = {}
	for place, e in ranked do
		stars[e.name] = ServerRace.starsFor(place, ServerRace.finished(e), #ranked)
	end
	eq(stars.b, 3)
	eq(stars.a, 2)
	eq(stars.c, 1)
	eq(stars.d, 1) -- any other finish
	eq(stars.e, 0) -- sat still all round
	-- the same places in a race give the same stars
	for place = 1, 4 do
		eq(ServerRace.starsFor(place, true, 5), ({ 3, 2, 1, 1 })[place])
	end
	-- alone: the finish star only, drift or race
	local alone = ServerRace.rankDrift({ { name = "a", laps = 0, score = 900 } })
	eq(ServerRace.starsFor(1, ServerRace.finished(alone[1]), 1), 1)
end)
