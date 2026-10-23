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

-- ===== phase 2: plot looks by stars =====
local PlotLooks = require("../src/shared/PlotLooks")

test("looks: tier edges at 10 / 25 / 50 stars", function()
	eq(PlotLooks.tier(0), 0)
	eq(PlotLooks.tier(9), 0)
	eq(PlotLooks.tier(10), 1)
	eq(PlotLooks.tier(24), 1)
	eq(PlotLooks.tier(25), 2)
	eq(PlotLooks.tier(49), 2)
	eq(PlotLooks.tier(50), 3)
	eq(PlotLooks.tier(999), 3)
end)

test("looks: each tier keeps the ones below and adds more", function()
	eq(#PlotLooks.pieces(0), 0)
	local last = 0
	for tier = 1, 3 do
		local n = #PlotLooks.pieces(tier)
		truthy(n > last, "tier " .. tier)
		last = n
	end
	local groups = {}
	for _, p in PlotLooks.pieces(3) do
		groups[p.group] = true
	end
	truthy(groups.Night and groups.Snow and groups.Party)
end)

test("looks: nothing is solid, all inside the plot, lights within the phone budget", function()
	for tier = 1, 3 do
		for _, p in PlotLooks.pieces(tier) do
			eq(p.collide, false, p.name)
			truthy(math.abs(p.pos.x) <= 41 and math.abs(p.pos.z) <= 56, p.name)
		end
		truthy(PlotLooks.lightCount(tier) <= PlotLooks.MAX_LIGHTS, "lights tier " .. tier)
	end
end)

test("looks: night colours go darker and bluer", function()
	local c = PlotLooks.nightColor({ 120, 180, 90 })
	truthy(c[1] < 120 and c[2] < 180)
	truthy(c[3] - c[1] > 90 - 120, "bluer")
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
	eq(back.version, 2)
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
