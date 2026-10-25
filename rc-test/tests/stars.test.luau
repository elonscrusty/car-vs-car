--!strict
-- Carter's stars loop, phase 1: medals, the save, and the server's own run check.
local H = require("./harness")
local Medals = require("../src/shared/Medals")
local Profile = require("../src/shared/Profile")
local RunCheck = require("../src/shared/RunCheck")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Stars")

test("medals: times lower is better, drift points higher is better", function()
	eq(Medals.medal("race", 16), 3)
	eq(Medals.medal("race", 17), 3)
	eq(Medals.medal("race", 19), 2)
	eq(Medals.medal("race", 25), 1)
	eq(Medals.medal("race", 40), 0)
	eq(Medals.medal("drift", 4500), 3)
	eq(Medals.medal("drift", 600), 1)
	eq(Medals.medal("drift", 100), 0)
	eq(Medals.medal("rock", 100), 3)
	eq(Medals.medal("nope", 1), 0)
end)

test("medals: too good to be true never counts", function()
	eq(Medals.valid("race", 3), false)
	eq(Medals.medal("race", 3), 0)
	eq(Medals.valid("drift", 1e9), false)
	eq(Medals.valid("race", 0 / 0), false)
	eq(Medals.better("race", 3, 30), false)
end)

test("medals: every target is in order, gold hardest", function()
	for mode, t in Medals.TARGETS do
		if t.kind == "time" then
			truthy(t.limit < t.gold and t.gold < t.silver and t.silver < t.bronze, mode)
		else
			truthy(t.bronze < t.silver and t.silver < t.gold and t.gold < t.limit, mode)
		end
	end
end)

test("medals: better and format", function()
	truthy(Medals.better("race", 18, nil))
	truthy(Medals.better("race", 18, 19))
	eq(Medals.better("race", 19, 18), false)
	truthy(Medals.better("drift", 900, 800))
	eq(Medals.format("race", 41.25), "0:41.2")
	eq(Medals.format("rock", 125), "2:05.0")
	eq(Medals.format("drift", 1520.7), "1520")
end)

test("stars: only from other people's plots, once per medal per owner", function()
	local d = Profile.new()
	eq(Profile.award(d, 1, 1, "race", 3), 0) -- own plot
	eq(Profile.award(d, 1, 2, "race", 1), 1) -- bronze on Mia's race
	eq(Profile.award(d, 1, 2, "race", 1), 0) -- again: nothing
	eq(Profile.award(d, 1, 2, "race", 3), 2) -- gold later: the 2 more
	eq(Profile.award(d, 1, 2, "race", 2), 0) -- silver after gold: nothing
	eq(Profile.award(d, 1, 2, "drift", 2), 2) -- another kind of plot counts on its own
	eq(Profile.award(d, 1, 3, "race", 3), 3) -- another owner counts on its own
	eq(Profile.award(d, 1, 2, "race", 0), 0)
	eq(d.stars, 8)
end)

test("stars: the owner list has a cap", function()
	local d = Profile.new()
	for i = 1, Profile.MAX_OWNERS do
		Profile.award(d, 0, i, "race", 1)
	end
	eq(d.stars, Profile.MAX_OWNERS)
	eq(Profile.award(d, 0, Profile.MAX_OWNERS + 1, "race", 3), 0)
	eq(d.stars, Profile.MAX_OWNERS)
end)

test("save: missing or broken data becomes a clean save", function()
	for _, raw in { nil, 5, "x", {}, { stars = "lots", starsFrom = 7 } } :: { any } do
		local d = Profile.migrate(raw)
		eq(d.version, Profile.VERSION)
		eq(d.stars, 0)
		eq(d.coins, 0)
		eq(next(d.starsFrom), nil)
	end
end)

test("save: stars are counted again from starsFrom, junk is dropped", function()
	local d = Profile.migrate({
		stars = 999,
		starsFrom = {
			["2"] = { race = 3, drift = 9, rock = -1, moon = 2 },
			["3"] = { rock = 1.7 },
			["4"] = "bad",
		},
		plotRecords = {
			race = { value = 18.5, name = "Mia", userId = 2 },
			drift = { value = "fast", name = "x", userId = 1 },
			moon = { value = 1, name = "x", userId = 1 },
		},
		coins = 12.9,
	})
	eq(d.starsFrom["2"].race, 3)
	eq(d.starsFrom["2"].drift, 3) -- clamped
	eq(d.starsFrom["2"].rock, nil)
	eq(d.starsFrom["2"].moon, nil)
	eq(d.starsFrom["3"].rock, 1)
	eq(d.starsFrom["4"], nil)
	eq(d.stars, 7)
	eq(d.plotRecords.race.name, "Mia")
	eq(d.plotRecords.drift, nil)
	eq(d.plotRecords.moon, nil)
	eq(d.coins, 12)
end)

test("save: a saved profile loads back the same", function()
	local d = Profile.new()
	Profile.award(d, 1, 2, "rock", 2)
	d.plotRecords.race = { value = 20, name = "Carter", userId = 1 }
	local back = Profile.migrate(d)
	eq(back.stars, 2)
	eq(back.starsFrom["2"].rock, 2)
	eq(back.plotRecords.race.value, 20)
end)

test("save lock: free, ours, or stale can be taken; a live one can't", function()
	truthy(Profile.canTake(nil, "a", 100))
	truthy(Profile.canTake({ job = "a", at = 90 }, "a", 100))
	eq(Profile.canTake({ job = "b", at = 90 }, "a", 100), false)
	truthy(Profile.canTake({ job = "b", at = 0 }, "a", Profile.LOCK_TIMEOUT + 1))
	truthy(Profile.canTake({ job = "b" }, "a", 100))
	-- waited long enough: take it anyway
	truthy(Profile.canTake({ job = "b", at = 90 }, "a", 100, true))
	-- a Studio test takes the lock an older (stopped) Studio test left
	truthy(Profile.canTake({ job = "studio-old", at = 99 }, "studio-new", 100))
	eq(Profile.canTake({ job = "live-server", at = 99 }, "studio-new", 100), false)
end)

-- a straight test track along -z: start at z = 0, a gate at -100, finish / lap back at 0
local function gate(z: number): LapTimer.Gate
	return { x = 0, y = 0, z = z, dx = 0, dz = -1, halfWidth = 10, depth = 1 }
end
local START = { x = 0, z = 20 }

test("run check: a thin gate between two looks still counts", function()
	local s = RunCheck.new({ gate(0), gate(-100) }, "oneway", "rock", START, {}, 0, 0, 0, 5)
	-- looks 10 studs apart jump right over the 2-stud gates
	local events = {}
	local t, z = 0, 5
	while z > -110 do
		t += 0.5
		z -= 10
		for _, e in RunCheck.step(s, t, 0, 0, z, 0, -1, true) do
			table.insert(events, e)
		end
	end
	eq(#events, 2)
	eq(events[1].kind, "start")
	eq(events[2].kind, "finish")
	-- 20 studs/s: the 100 studs from gate to gate take 5 s
	near(events[2].value, 5, 0.06)
end)

test("run check: a race lap is timed by the server", function()
	local s = RunCheck.new({ gate(0), gate(-50) }, "loop", "race", START, {}, 0, 0, 0, 5)
	local laps = {}
	local t = 0
	local path = { -10, -30, -55, -30, -10, 2, -10 } -- out past the gate and back over the line
	for _, z in path do
		t += 0.5
		for _, e in RunCheck.step(s, t, 0, 0, z, 0, -1, true) do
			if e.kind == "lap" then
				table.insert(laps, e.value)
			end
		end
	end
	eq(#laps, 1)
	truthy(laps[1] > 2 and laps[1] < 3, tostring(laps[1]))
end)

test("run check: a jump back to the start is a fresh run, anywhere else throws it out", function()
	local s = RunCheck.new({ gate(0), gate(-100) }, "oneway", "rock", START, {}, 0, 0, 0, 5)
	RunCheck.step(s, 0.5, 0, 0, -5, 0, -1, true)
	truthy(s.timer.running)
	-- back to the start spot (R): no void, timer waits for the start line again
	local e = RunCheck.step(s, 0.6, 0, 0, 19, 0, -1, true)
	eq(#e, 0)
	eq(s.timer.running, false)
	RunCheck.step(s, 1.0, 0, 0, 12, 0, -1, true)
	RunCheck.step(s, 1.5, 0, 0, -5, 0, -1, true)
	truthy(s.timer.running)
	-- teleport right next to the finish: thrown out
	local v = RunCheck.step(s, 1.6, 0, 0, -98, 0, -1, true)
	eq(#v, 1)
	eq(v[1].kind, "void")
	eq(s.timer.running, false)
end)

test("run check: a jump to a rock checkpoint flag keeps the climb going", function()
	local s = RunCheck.new(
		{ gate(0), gate(-100) },
		"oneway",
		"rock",
		START,
		{ { x = 0, z = -40 } },
		0,
		0,
		0,
		5
	)
	RunCheck.step(s, 0.5, 0, 0, -5, 0, -1, true)
	RunCheck.step(s, 1.5, 0, 0, -15, 0, -1, true)
	RunCheck.step(s, 1.6, 0, 0, -40, 0, -1, true) -- 25 studs in 0.1 s: too far for a crawler
	truthy(s.timer.running)
end)

test("run check: a long slide scores, driving straight does not", function()
	-- straight: nose along the way it moves
	local s = RunCheck.new({}, "loop", "drift", START, {}, 0, 0, 0, 0)
	local t, z = 0, 0
	for _ = 1, 40 do
		t += 0.1
		z -= 8
		for _, e in RunCheck.step(s, t, 0, 0, z, 0, -1, true) do
			error("straight driving scored " .. e.kind)
		end
	end
	-- sideways: moving along -z, nose turned 45 degrees, for 4 s, then stop
	local got: number? = nil
	for i = 1, 60 do
		t += 0.1
		if i <= 40 then
			z -= 8
		end
		for _, e in RunCheck.step(s, t, 0, 0, z, 0.7, -0.7, true) do
			if e.kind == "drift" then
				got = e.value
			end
		end
	end
	truthy(got ~= nil and got > 500, "slide scored " .. tostring(got))
end)

test("run check: a gap in the car's updates doesn't end a slide", function()
	local s = RunCheck.new({}, "loop", "drift", START, {}, 0, 0, 0, 0)
	local t, z = 0, 0
	local ended = false
	for i = 1, 30 do
		t += 0.1
		if i % 3 ~= 0 then -- every third look the car hasn't moved (no update came)
			z -= 8
		end
		for _, e in RunCheck.step(s, t, 0, 0, z, 0.7, -0.7, true) do
			if e.kind == "drift" then
				ended = true
			end
		end
	end
	eq(ended, false)
	truthy(s.chain > 0)
end)

-- ===== likes and the visit gift =====

test("likes: once per plot owner, never your own", function()
	local d = Profile.new()
	eq(Profile.like(d, 1, 1), false)
	eq(Profile.like(d, 1, 2), true)
	eq(Profile.like(d, 1, 2), false)
	eq(Profile.like(d, 1, 3), true)
end)

test("visit gift: once per owner per day, never your own plot", function()
	local d = Profile.new()
	eq(Profile.visit(d, 1, 1, 100), false)
	eq(Profile.visit(d, 1, 2, 100), true)
	eq(d.coins, Profile.VISIT_COINS)
	eq(Profile.visit(d, 1, 2, 100), false)
	eq(Profile.visit(d, 1, 3, 100), true)
	eq(Profile.visit(d, 1, 2, 101), true) -- next day
	eq(d.coins, 3 * Profile.VISIT_COINS)
	eq(Profile.day(86400 * 5 + 10), 5)
end)

test("save v2: likes, liked and visited load back, junk dropped", function()
	local d = Profile.new()
	d.likes = 4
	Profile.like(d, 1, 7)
	Profile.visit(d, 1, 7, 50)
	local back = Profile.migrate(d)
	eq(back.version, Profile.VERSION)
	eq(back.likes, 4)
	eq(back.liked["7"], true)
	eq(back.visited["7"], 50)
	local junk = Profile.migrate({ likes = -3, liked = { x = "yes" }, visited = { y = "z" } })
	eq(junk.likes, 0)
	eq(next(junk.liked), nil)
	eq(next(junk.visited), nil)
	-- a version 1 save (no new fields) still loads
	local v1 = Profile.migrate({ version = 1, coins = 5, starsFrom = { ["2"] = { race = 1 } } })
	eq(v1.coins, 5)
	eq(v1.stars, 1)
	eq(v1.likes, 0)
end)

-- ===== gold bolts =====

test("bolts: each of the 5 counts once, junk ids never", function()
	local d = Profile.new()
	eq(Profile.findBolt(d, 3), true)
	eq(Profile.findBolt(d, 3), false)
	eq(Profile.findBolt(d, 0), false)
	eq(Profile.findBolt(d, 6), false)
	eq(Profile.findBolt(d, 1.5), false)
	eq(Profile.findBolt(d, 1), true)
	eq(#Profile.boltList(d), 2)
	eq(Profile.boltList(d)[1], 1)
	local back = Profile.migrate(d)
	eq(back.version, Profile.VERSION)
	eq(#Profile.boltList(back), 2)
	local junk = Profile.migrate({ bolts = { ["9"] = true, ["2"] = "yes", ["4"] = true } })
	eq(#Profile.boltList(junk), 1)
	eq(Profile.boltList(junk)[1], 4)
end)

-- ===== beating friends: wins, streak, rivals =====

test("win: beating someone else's record pays and counts, your own doesn't", function()
	local d = Profile.new()
	eq(Profile.win(d, 1, 1, "Me", 10), false)
	eq(d.coins, 0)
	eq(Profile.win(d, 1, 2, "Mia", 10), true)
	eq(d.coins, Profile.WIN_COINS)
	eq(d.winPoints, 1)
	eq(d.streak, 1)
	Profile.win(d, 1, 3, "Sam", 11)
	Profile.win(d, 1, 2, "Mia", 12)
	eq(d.streak, 3)
	eq(d.rivals["2"].wins, 2)
end)

test("lose: only the streak ends and the rival score moves, nothing is taken", function()
	local d = Profile.new()
	Profile.win(d, 1, 2, "Mia", 10)
	Profile.win(d, 1, 2, "Mia", 11)
	local coins, points = d.coins, d.winPoints
	Profile.lose(d, 1, 2, "Mia", 12)
	eq(d.streak, 0)
	eq(d.bestStreak, 2)
	eq(d.coins, coins)
	eq(d.winPoints, points)
	eq(d.rivals["2"].losses, 1)
	eq(d.rivals["2"].wins, 2)
end)

test("rivals: newest first, capped, saved", function()
	local d = Profile.new()
	for i = 1, Profile.MAX_RIVALS + 5 do
		Profile.win(d, 0, i, "P" .. i, i)
	end
	local n = 0
	for _ in d.rivals do
		n += 1
	end
	eq(n, Profile.MAX_RIVALS)
	eq(d.rivals["1"], nil) -- the oldest went
	local list = Profile.rivalList(d, 3)
	eq(#list, 3)
	eq(list[1].name, "P" .. (Profile.MAX_RIVALS + 5))
	local back = Profile.migrate(d)
	eq(back.version, Profile.VERSION)
	eq(back.winPoints, Profile.MAX_RIVALS + 5)
	eq(back.rivals["2"], nil)
	eq(back.rivals[tostring(Profile.MAX_RIVALS + 5)].wins, 1)
	local junk = Profile.migrate({ streak = 4, bestStreak = 1, rivals = { x = { name = 5 } } })
	eq(junk.bestStreak, 4)
	eq(next(junk.rivals), nil)
end)

-- ===== daily gift and weekend coins =====

test("daily gift: once a day, grows each day in a row, back to day 1 after a missed day", function()
	local d = Profile.new()
	eq(select(1, Profile.daily(d, 100)), Profile.DAILY[1])
	eq(select(1, Profile.daily(d, 100)), 0) -- same day: nothing
	local coins, streak = Profile.daily(d, 101)
	eq(coins, Profile.DAILY[2])
	eq(streak, 2)
	for day = 102, 110 do
		Profile.daily(d, day)
	end
	eq(d.dayStreak, 11)
	eq(select(1, Profile.daily(d, 111)), Profile.DAILY[#Profile.DAILY]) -- stays at the top
	coins, streak = Profile.daily(d, 113) -- missed day 112
	eq(coins, Profile.DAILY[1])
	eq(streak, 1)
	eq(select(1, Profile.daily(d, 114, 2)), Profile.DAILY[2] * 2) -- weekend: doubled
end)

test("daily gift: coins add up and the streak saves", function()
	local d = Profile.new()
	d.coins = 5
	Profile.daily(d, 200)
	Profile.daily(d, 201)
	eq(d.coins, 5 + Profile.DAILY[1] + Profile.DAILY[2])
	local back = Profile.migrate(d)
	eq(back.dailyDay, 201)
	eq(back.dayStreak, 2)
	eq(back.coins, d.coins)
	local old = Profile.migrate({ version = 3, coins = 9 })
	eq(old.dailyDay, 0)
	eq(old.dayStreak, 0)
	local junk = Profile.migrate({ dailyDay = "x", dayStreak = 0 / 0 })
	eq(junk.dailyDay, 0)
end)

test("weekend: Saturday and Sunday (UTC) pay double", function()
	-- 2026-10-24 is a Saturday, 10-25 Sunday, 10-26 Monday, 10-23 Friday
	local sat = 1792800000 -- 2026-10-24 00:00 UTC
	eq(Profile.weekend(sat), true)
	eq(Profile.weekend(sat + 86400 + 3600 * 23), true)
	eq(Profile.weekend(sat + 2 * 86400), false)
	eq(Profile.weekend(sat - 1), false)
	eq(Profile.boost(sat), 2)
	eq(Profile.boost(sat - 3600), 1)
	local d = Profile.new()
	Profile.visit(d, 1, 2, 300, 2)
	eq(d.coins, Profile.VISIT_COINS * 2)
	Profile.win(d, 1, 3, "Mia", sat)
	eq(d.coins, Profile.VISIT_COINS * 2 + Profile.WIN_COINS * 2)
end)

test("track: saved tiles survive a save, junk tiles are dropped", function()
	local d = Profile.new()
	eq(Profile.getTrack(d), nil) -- the starter circle
	Profile.setTrack(d, {
		{ c = 1, r = 1, piece = "turn", rot = 1 },
		{ c = 2, r = 1, piece = "straight", rot = 5 }, -- rot wraps to 1
		{ c = 1, r = 1, piece = "straight", rot = 0 }, -- same cell: the last one wins
		{ c = 0, r = 1, piece = "straight", rot = 0 }, -- off the grid
		{ c = 3, r = 1, piece = "", rot = 0 },
		{ c = 3, r = 1, piece = "straight", rot = 0 / 0 },
		"junk" :: any,
	})
	local t = Profile.getTrack(d)
	truthy(t)
	local tiles = (t :: Profile.Track).tiles
	eq(#tiles, 2)
	eq(tiles[1].piece, "straight")
	eq(tiles[1].rot, 0)
	eq(tiles[2].rot, 1)
	local back = Profile.migrate(d)
	eq(#(back.track :: Profile.Track).tiles, 2)
	eq((back.track :: Profile.Track).tiles[2].piece, "straight")
	Profile.setTrack(d, nil)
	eq(Profile.getTrack(d), nil)
	eq(Profile.migrate({ version = 8, coins = 3 }).track, nil)
	eq(Profile.migrate({ track = { tiles = "x" } }).track, nil)
end)

test("race stars: add up, count in stars, survive a save, junk is cleaned", function()
	local d = Profile.new()
	d.starsFrom["2"] = { race = 2 }
	d.stars = 2
	eq(Profile.addRaceStars(d, 3), 3)
	eq(d.stars, 5)
	eq(Profile.addRaceStars(d, -4), 0)
	local back = Profile.migrate(d)
	eq(back.raceStars, 3)
	eq(back.stars, 5)
	eq(Profile.migrate({ version = 10, raceStars = "lots" }).raceStars, 0)
	eq(Profile.migrate({ version = 10, raceStars = -9 }).raceStars, 0)
end)

test("medals: a built track's race times stretch with its loop length", function()
	local square =
		{ { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }
	eq(Medals.loopLength(square), 400)
	local half = { { x = 0, z = 0 }, { x = 50, z = 0 }, { x = 50, z = 50 }, { x = 0, z = 50 } }
	near(Medals.loopScale(half, square), 0.5, 1e-9)
	eq(Medals.loopScale({}, square), 1)
	eq(Medals.loopScale(square, { { x = 0, z = 0 } }), 1)
	local tiny = { { x = 0, z = 0 }, { x = 1, z = 0 } }
	eq(Medals.loopScale(tiny, square), Medals.MIN_SCALE)
	local t = Medals.target("race", 0.5) :: any
	near(t.gold, Medals.TARGETS.race.gold * 0.5, 1e-9)
	-- the full track's silver time is too slow for any medal on a half-length one
	local v = Medals.TARGETS.race.silver
	eq(Medals.medal("race", v), 2)
	eq(Medals.medal("race", v, 0.5), 0)
	eq(Medals.medal("race", Medals.TARGETS.race.gold * 0.5, 0.5), 3)
	-- drift points never stretch
	eq(Medals.target("drift", 0.5), Medals.TARGETS.drift)
end)

test("track: a changed track clears my plot records, the same track keeps them", function()
	local d = Profile.new()
	d.plotRecords.race = { value = 20, name = "Mia", userId = 2 }
	local tiles =
		{ { c = 1, r = 1, piece = "turn", rot = 1 }, { c = 2, r = 1, piece = "straight", rot = 1 } }
	eq(Profile.setTrack(d, tiles), true)
	eq(d.plotRecords.race, nil)
	d.plotRecords.race = { value = 21, name = "Mia", userId = 2 }
	-- same tiles in another order: no change
	eq(Profile.setTrack(d, { tiles[2], tiles[1] }), false)
	truthy(d.plotRecords.race)
	eq(Profile.setTrack(d, nil), true)
	eq(d.plotRecords.race, nil)
	eq(Profile.setTrack(d, nil), false)
end)

test("next medal: bronze, then silver, then gold, then nothing", function()
	local m, v = Medals.nextGoal("race", 0)
	eq(m, 1)
	eq(v, Medals.TARGETS.race.bronze)
	m, v = Medals.nextGoal("race", 2)
	eq(m, 3)
	eq(v, Medals.TARGETS.race.gold)
	m, v = Medals.nextGoal("race", 3)
	eq(m, nil)
	eq(v, nil)
	m, v = Medals.nextGoal("drift", 1)
	eq(m, 2)
	eq(v, Medals.TARGETS.drift.silver)
	_, v = Medals.nextGoal("race", 0, 2) -- a built track twice as long
	eq(v, Medals.TARGETS.race.bronze * 2)
	eq((Medals.nextGoal("moon", 0)), nil)
end)

test("board: top 3, one row per player, best first", function()
	local list: { Medals.Run } = {}
	eq(Medals.addTop("race", list, { value = 22, name = "A", userId = 1 }), 1)
	eq(Medals.addTop("race", list, { value = 20, name = "B", userId = 2 }), 1)
	eq(Medals.addTop("race", list, { value = 25, name = "C", userId = 3 }), 3)
	eq(Medals.addTop("race", list, { value = 30, name = "D", userId = 4 }), nil) -- too slow
	eq(#list, 3)
	eq(Medals.addTop("race", list, { value = 23, name = "A", userId = 1 }), nil) -- slower than A's own
	eq(Medals.addTop("race", list, { value = 19, name = "A", userId = 1 }), 1) -- A moves up, once
	eq(#list, 3)
	eq(list[1].name, "A")
	eq(list[2].name, "B")
	eq(list[3].name, "C")
	eq(Medals.addTop("race", list, { value = 21, name = "D", userId = 4 }), 3)
	eq(list[3].name, "D")
	eq(#list, 3)
	eq(Medals.addTop("race", list, { value = 1, name = "X", userId = 9 }), nil) -- too fast to be real
	local drift: { Medals.Run } = {}
	Medals.addTop("drift", drift, { value = 900, name = "A", userId = 1 })
	eq(Medals.addTop("drift", drift, { value = 2000, name = "B", userId = 2 }), 1)
end)

test("board save: the top 3 load back clean, old saves start from the record", function()
	local d = Profile.new()
	d.plotTop.race = {
		{ value = 19, name = "A", userId = 1 },
		{ value = 20, name = "B", userId = 2 },
	}
	local back = Profile.migrate(d)
	eq(#back.plotTop.race, 2)
	eq(back.plotTop.race[2].name, "B")
	local junk = Profile.migrate({
		plotTop = {
			race = {
				{ value = 19, name = "A", userId = 1 },
				{ value = 18, name = "A", userId = 1 },
				"x",
				{ value = 0 / 0, name = "N", userId = 5 },
				{ value = 21, name = "C", userId = 3 },
				{ value = 22, name = "D", userId = 4 },
				{ value = 23, name = "E", userId = 5 },
			},
			moon = { { value = 1, name = "M", userId = 7 } },
		},
	})
	eq(#junk.plotTop.race, 3)
	eq(junk.plotTop.moon, nil)
	local old =
		Profile.migrate({ plotRecords = { race = { value = 20, name = "Mia", userId = 2 } } })
	eq(#old.plotTop.race, 1)
	eq(old.plotTop.race[1].name, "Mia")
	-- a rebuilt track or a new kind clears the board with the records
	old.plotTop.race = { { value = 20, name = "Mia", userId = 2 } }
	Profile.setTrack(old, { { c = 1, r = 1, piece = "start", rot = 0 } })
	eq(next(old.plotTop), nil)
	old.plotTop.race = { { value = 20, name = "Mia", userId = 2 } }
	Profile.setTrackKind(old, "drift")
	eq(next(old.plotTop), nil)
end)
