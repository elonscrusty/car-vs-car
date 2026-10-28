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
	-- Car VS Car map races: the wait after the winner is MAP_AFTER_WIN, not 30 s
	local two = { { name = "a", laps = 2, time = 60 }, { name = "b", laps = 1 } }
	local M = ServerRace.MAP_AFTER_WIN
	truthy(M < ServerRace.AFTER_WIN, "map races wait less after the winner")
	eq(ServerRace.over(two, 60 + M - 0.1, 60, ServerRace.MAP_TIME_LIMIT, M), false)
	eq(ServerRace.over(two, 60 + M, 60, ServerRace.MAP_TIME_LIMIT, M), true)
	near(ServerRace.GO_DELAY, 3.0, 1e-9)
end)

test("the street race plot gives every grid spot on its road, behind its line", function()
	local res = TrackData.plot("race")
	local loop = res.loop()
	local line = res.gates[1]
	for k = 1, ServerRace.MAX do
		local g = ServerRace.gridOn(res, k, 2.5)
		local best = math.huge
		for i, a in loop do
			local b = loop[i % #loop + 1]
			local ex, ez = b.x - a.x, b.z - a.z
			local u = math.clamp(((g.x - a.x) * ex + (g.z - a.z) * ez) / (ex * ex + ez * ez), 0, 1)
			best = math.min(best, math.sqrt((g.x - a.x - ex * u) ^ 2 + (g.z - a.z - ez * u) ^ 2))
		end
		truthy(best <= 30, `grid {k} off the road ({best})`)
		local along = (g.x - line.x) * line.dx + (g.z - line.z) * line.dz
		truthy(along < -line.depth or along > 0, `grid {k} on the line ({along})`)
	end
end)

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
	local G = ServerRace.JOIN_GRACE
	eq(ServerRace.step("call", 0, 4, 3), nil) -- 0:00 on the clock: a JOIN tap still gets in
	eq(ServerRace.step("call", -0.4, 4, 3), nil) -- (critic run 1: the tap landed 0.4 s late)
	eq(ServerRace.step("call", -G, 4, 3), "race")
	eq(ServerRace.step("call", -G - 2, 4, 3), "race") -- a late tick still starts it
	eq(ServerRace.step("call", -G, nil, 3), "skip") -- no plot was ready
	eq(ServerRace.step("call", -G, 4, 0), "skip") -- nobody here
	eq(ServerRace.step("racing", -50, 4, 3), nil) -- the race runs itself
end)

test("round clock: one whole round, ticking like the server", function()
	local phase, picked, t = "wait", nil :: number?, 0
	local startAt = ServerRace.BREAK
	local seen = {}
	while t < ServerRace.BREAK + ServerRace.JOIN_GRACE + 1 do
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
	eq(seen[2], `race 5 at {-ServerRace.JOIN_GRACE}`)
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

test("Car VS Car: a big race every 3 min, start to start, never squeezed", function()
	eq(ServerRace.nextStart(1000, 1100), 1000 + ServerRace.CVC_EVERY)
	-- a long race: the next one still waits a little after it ends
	eq(ServerRace.nextStart(1000, 1170), 1170 + ServerRace.CVC_GAP)
	-- a new server: soon
	eq(ServerRace.nextStart(-math.huge, 50), 50 + ServerRace.CVC_GAP)
end)

test("Car VS Car: the result card's NEXT RACE IN and the race call read the same start", function()
	-- the server fixes it when every race is over and sends it ("next"); the card counts down to it
	-- and the race call's startAt is set to it after the card (no ~15 s gap)
	local last, ended = 1000, 1100
	local nextAt = ServerRace.nextAfterRace(last, ended)
	eq(nextAt, 1000 + ServerRace.CVC_EVERY)
	-- a long race: still a full gap after the results go away
	local late = ServerRace.nextAfterRace(1000, 1160)
	eq(late, 1160 + ServerRace.SHOW + ServerRace.CVC_GAP)
	truthy(late - (1160 + ServerRace.SHOW) >= ServerRace.CVC_GAP, "a gap after the card")
end)

test("Car VS Car: the maps take turns", function()
	local ids = { "backyard", "kitchen" }
	eq(ServerRace.mapTurn(ids, 1), "backyard")
	eq(ServerRace.mapTurn(ids, 2), "kitchen")
	eq(ServerRace.mapTurn(ids, 3), "backyard")
	eq(ServerRace.mapTurn({}, 1), nil)
end)

test("Car VS Car: each league races on its own, friends in a league together", function()
	local g = ServerRace.groups({ 2, 1, 2, 1, 3 }, 8)
	eq(#g, 3)
	eq(table.concat(g[1], ","), "2,4") -- Bronze first
	eq(table.concat(g[2], ","), "1,3")
	eq(table.concat(g[3], ","), "5")
	-- a full league splits, in join order
	local big = ServerRace.groups({ 1, 1, 1 }, 2)
	eq(#big, 2)
	eq(table.concat(big[1], ","), "1,2")
	eq(table.concat(big[2], ","), "3")
	eq(#ServerRace.groups({}, 8), 0)
end)

test("Car VS Car (audit B1): a new kid's first race is them and bots only", function()
	-- racer 2 and 4 never raced: each gets a race alone, first; the rest race by league
	local g = ServerRace.groups({ 1, 1, 2, 1 }, 8, { false, true, false, true })
	eq(#g, 4)
	eq(table.concat(g[1], ","), "2")
	eq(table.concat(g[2], ","), "4")
	eq(table.concat(g[3], ","), "1")
	eq(table.concat(g[4], ","), "3")
	-- no new kids: the same as before
	eq(#ServerRace.groups({ 1, 1 }, 8, { false, false }), 1)
	-- more new kids than races left: they share, but only with other new kids
	local many = ServerRace.groups(
		{ 1, 1, 1, 1, 1, 2, 3 },
		8,
		{ true, true, true, true, true, false, false }
	)
	truthy(#many <= ServerRace.GROUPS, "never more races than GROUPS")
	local seen = 0
	for gi, idx in many do
		for _, i in idx do
			seen += 1
			if i <= 5 then
				for _, j in idx do
					truthy(j <= 5, `race {gi}: a new kid with an old racer`)
				end
			end
		end
	end
	eq(seen, 7)
end)

test("Car VS Car (audit B8): a first race starts 3 to 5 s after the JOIN tap", function()
	local wait = ServerRace.CVC_FIRST + ServerRace.JOIN_GRACE
	truthy(wait >= 3 and wait <= 5, `first race starts {wait} s after the tap`)
	-- the clock: picked straight away, racing once the grace is over
	eq(ServerRace.step("wait", ServerRace.CVC_FIRST, nil, 1), "pick")
	eq(ServerRace.step("call", 0, 1, 1), nil)
	eq(ServerRace.step("call", -ServerRace.JOIN_GRACE, 1, 1), "race")
	-- and the runner moves the start up in the last 10 s (call) too, not only in the break
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/ServerRaceRunner.luau")
	local a = string.find(src, "function ServerRaceRunner.join(", 1, true) :: number
	local join = string.sub(src, a, string.find(src, "\nend\n", a, true) :: number)
	truthy(
		string.find(join, '(phase == "wait" or phase == "call")', 1, true),
		"join: no call phase"
	)
	truthy(string.find(join, "now() + ServerRace.CVC_FIRST", 1, true), "join: start not moved up")
end)

test("Car VS Car (audit C2): friends always race together, in the lower league", function()
	-- racer 1 (Gold) and 3 (Bronze) are friends: both race in Bronze with 2; 4 races in Gold
	local g = ServerRace.groups({ 3, 1, 1, 3 }, 8, nil, { { 1, 3 } })
	eq(#g, 2)
	eq(table.concat(g[1], ","), "1,3,2")
	eq(table.concat(g[2], ","), "4")
	-- a friend of a friend too
	local chain = ServerRace.groups({ 4, 2, 1 }, 8, nil, { { 1, 2 }, { 2, 3 } })
	eq(#chain, 1)
	-- a new kid with a friend here races with them, not alone
	local kid = ServerRace.groups({ 2, 1, 1 }, 8, { false, true, true }, { { 1, 2 } })
	eq(#kid, 2)
	eq(table.concat(kid[1], ","), "3") -- the other new kid: alone with bots
	eq(table.concat(kid[2], ","), "1,2")
	-- a full league splits, but friends stay side by side
	local full = ServerRace.groups({ 1, 1, 1, 1 }, 2, nil, { { 1, 4 } })
	eq(table.concat(full[1], ","), "1,4")
	eq(table.concat(full[2], ","), "2,3")
	-- bad pairs are ignored
	eq(#ServerRace.groups({ 1, 2 }, 8, nil, { { 1, 9 }, { 2, 2 } }), 2)
end)

test(
	"Car VS Car (audit C2): the race asks who is friends, and prizes follow your own league",
	function()
		local fs = require("@lune/fs")
		local src = fs.readFile("src/server/ServerRaceRunner.luau")
		truthy(
			string.find(src, "FriendBonus.areFriends(list[i], list[j])", 1, true),
			"no friends check"
		)
		truthy(
			string.find(src, "ServerRace.groups(leagues, ServerRace.MAX, solo, friends)", 1, true)
		)
		truthy(string.find(src, "League.top(groupLeague[gi])", 1, true), "stronger cars not held")
		truthy(
			string.find(src, "League.prize(data.league, at)", 1, true),
			"prize not by own league"
		)
		local fb = fs.readFile("src/server/FriendBonus.luau")
		truthy(string.find(fb, "function FriendBonus.areFriends", 1, true))
	end
)

test("Car VS Car (audit C2): a new kid racing a friend still gets the easy first race", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/ServerRaceRunner.luau")
	-- a race is easy (easy bots, no catch-up, 1 lap) when ANY racer in it hasn't raced yet
	truthy(string.find(src, "easy = easy or solo[i]", 1, true), "easy needs every racer new")
	truthy(not string.find(src, "easy = easy and solo[i]", 1, true))
	truthy(
		string.find(src, "groupLaps[gi] = ServerRace.lapsFor(easy)", 1, true),
		"laps not from easy"
	)
	-- solo[i] is only ever true in a first-race map race
	truthy(
		string.find(
			src,
			'firstRace and not (type(stage) == "number" and stage >= Profile.STAGE.RACED)',
			1,
			true
		),
		"solo not limited to map races"
	)
	-- the kid and their friend share a race
	local g = ServerRace.groups({ 2, 1 }, 8, { false, true }, { { 1, 2 } })
	eq(#g, 1)
end)

test(
	"Car VS Car (Studio after-810): a first race on the time limit ranks the new kid first and pays them",
	function()
		local r = ServerRace.rank({
			{ name = "Aaron (bot)", laps = 0 },
			{ name = "kid", uid = 7, laps = 0, kid = true },
			{ name = "Abby (bot)", laps = 1 },
		})
		eq(r[1].uid, 7)
		-- a finisher is still ahead of anyone who didn't
		eq(
			ServerRace.rank({
				{ name = "kid", uid = 7, laps = 0, kid = true },
				{ name = "b", laps = 1, time = 50 },
			})[1].name,
			"b"
		)
		local fs = require("@lune/fs")
		local src = fs.readFile("src/server/ServerRaceRunner.luau")
		truthy(
			string.find(src, "(r.laps > 0 or r.timer.next >= 2)", 1, true),
			"try pay needs a gate past the line"
		)
		truthy(
			string.find(
				src,
				"ServerRace.finished(e) or (e.kid == true and tried[p.UserId] == true)",
				1,
				true
			)
		)
		truthy(
			string.find(
				src,
				"and (r.laps > 0 or r.timer.next >= 2)\n\t\t\t\t\t\t\tthen true",
				1,
				true
			),
			"an idle kid is still put first"
		)
		-- a kid who never moves doesn't hold the bots (or the race) for 3 min
		truthy(ServerRace.IDLE_KID <= 15)
		-- the podium and the card agree: the kid gets a finish time (the card's NICE TRY! is no time)
		truthy(
			string.find(src, "if e.kid and e.time == nil then\n\t\t\t\t\t\te.time = since", 1, true)
		)
		truthy(
			string.find(src, "local held = kidMoved or clock - goAt < ServerRace.IDLE_KID", 1, true)
		)
		truthy(string.find(src, "if held then kidLead else nil", 1, true))
		truthy(
			string.find(
				src,
				'p:SetAttribute("EasyRace", if groupEasy[gi] then true else nil)',
				1,
				true
			)
		)
		local bc = fs.readFile("src/server/RaceBotCars.luau")
		truthy(
			string.find(bc, "RaceBots.lineCap(fleet.route, bot, kid)", 1, true),
			"bots may finish first"
		)
	end
)
