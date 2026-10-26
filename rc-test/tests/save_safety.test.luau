--!strict
-- The save never gets worse: a broken or newer save is read but never written back, every old
-- version loads up to the current one, and what a kid earned comes back the same after a save.
local H = require("./harness")
local Profile = require("../src/shared/Profile")
local SaveRetry = require("../src/shared/SaveRetry")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Save safety")

test("load plan: empty starts fresh, a good save loads", function()
	eq(Profile.loadPlan(nil), "fresh")
	eq(Profile.loadPlan({ lock = { job = "a", at = 1 } }), "fresh") -- lock only, no data yet
	eq(Profile.loadPlan({ data = Profile.new() }), "load")
	eq(Profile.loadPlan({ data = { version = 1, coins = 5 } }), "load")
	eq(Profile.loadPlan({ data = { coins = 5 } }), "load") -- no version: oldest save
end)

test("load plan: junk or a newer version is never written over", function()
	eq(Profile.loadPlan("x"), "readOnly")
	eq(Profile.loadPlan(5), "readOnly")
	eq(Profile.loadPlan({ data = "broken" }), "readOnly")
	eq(Profile.loadPlan({ data = { version = Profile.VERSION + 1, coins = 9 } }), "readOnly")
end)

test("migrate: every old version comes up to the current one", function()
	for v = 1, Profile.VERSION do
		local d = Profile.migrate({ version = v, coins = 40, stars = 3 })
		eq(d.version, Profile.VERSION)
		eq(d.coins, 40)
		-- every field the current version has is there
		for k, want in Profile.new() :: any do
			eq(type((d :: any)[k]), type(want))
		end
	end
end)

test("migrate: what a kid earned survives a save and load", function()
	local d = Profile.new()
	d.coins = 1234
	d.cars["buggy"] = true
	d.equipped.race = "buggy"
	d.tiles["jump"] = 2
	Profile.addRaceStars(d, 7)
	Profile.award(d, 1, 2, "race", 2)
	d.jobs = { day = 100, have = { 1, 2, 3 } }
	Profile.setTrackKind(d, "drift")
	Profile.setTrack(
		d,
		{ { c = 1, r = 1, piece = "straight", rot = 1 }, { c = 2, r = 1, piece = "jump", rot = 0 } }
	)
	local back = Profile.migrate(d)
	eq(back.coins, 1234)
	truthy(back.cars.buggy)
	eq(back.equipped.race, "buggy")
	eq(back.tiles.jump, 2)
	eq(back.raceStars, 7)
	eq(back.stars, 9)
	eq(back.jobs.day, 100)
	eq(back.jobs.have[3], 3)
	eq(back.trackKind, "drift")
	local t = back.track
	truthy(t)
	if t then
		eq(#t.tiles, 2)
		eq(t.tiles[1].rot, 1)
		eq(t.tiles[2].piece, "jump")
	end
	-- and again: loading twice changes nothing
	local twice = Profile.migrate(back)
	eq(twice.coins, back.coins)
	eq(twice.stars, back.stars)
end)

-- Saves from before the tycoon: coins and cars come through, the garage is empty and never seen,
-- so the server parks the free starter on the first join.
test(
	"old saves (v1..v14) keep coins, cars and old stars/tiles; tycoon fields start clean",
	function()
		for v = 1, 14 do
			local d = Profile.migrate({
				version = v,
				coins = 777,
				cars = { buggy = true },
				tiles = { jump = 3 },
				raceStars = 4,
				starsFrom = { ["55"] = { race = 3 } },
				track = { tiles = { { c = 1, r = 1, piece = "straight", rot = 0 } } },
			})
			eq(d.version, Profile.VERSION)
			eq(d.coins, 777)
			truthy(d.cars.buggy)
			eq(d.tiles.jump, 3)
			eq(d.raceStars, 4)
			eq(d.stars, 7)
			eq(#(d.track :: any).tiles, 1)
			eq(d.pile, 0)
			eq(d.lastSeen, 0)
			eq(d.plotLevel, 0)
			eq(#d.parked, 0)
		end
	end
)

test("tycoon fields survive a save and load", function()
	local d = Profile.new()
	d.pile = 91.5
	d.lastSeen = 1000
	d.boostUntil = 1600
	d.plotLevel = 2
	d.parked = { "a", "b", "c", "d" }
	local back = Profile.migrate(d)
	eq(back.pile, 91.5)
	eq(back.lastSeen, 1000)
	eq(back.boostUntil, 1600)
	eq(back.plotLevel, 2)
	eq(#back.parked, 4)
end)

test("broken numbers and lists are cleaned, never crash", function()
	local d = Profile.migrate({
		coins = 1e300,
		pile = 0 / 0,
		lastSeen = -5,
		plotLevel = 99,
		parked = { "a", "a", 5, "b" },
	})
	eq(d.coins, Profile.MAX_COINS)
	eq(d.pile, 0)
	eq(d.lastSeen, 0)
	eq(d.plotLevel, Profile.MAX_PLOT_LEVEL)
	eq(#d.parked, 2) -- the repeat and the number are gone
	-- more cars parked than the level has slots: the extras go
	local low = Profile.migrate({ plotLevel = 0, parked = { "a", "b", "c", "d", "e" } })
	eq(#low.parked, Profile.BASE_SLOTS)
	local junk = Profile.migrate({ pile = "x", parked = "y", boostUntil = {}, coins = -9 })
	eq(junk.coins, 0)
	eq(#junk.parked, 0)
end)

test("lock: a live server blocks, a stale or our own lock is taken, force always takes", function()
	local live = { data = Profile.new(), lock = { job = "other", at = 1000 } }
	eq(Profile.loadStep(live, "me", 1100, false).kind, "blocked")
	eq(Profile.loadStep(live, "me", 1000 + Profile.LOCK_TIMEOUT + 1, false).kind, "write")
	eq(Profile.loadStep(live, "me", 1100, true).kind, "write")
	live.lock.job = "me"
	eq(Profile.loadStep(live, "me", 1100, false).kind, "write")
end)

test("lock: the record written holds our lock and the data", function()
	local old = { data = { version = 3, coins = 50 }, lock = { job = "other", at = 1 } }
	local step = Profile.loadStep(old, "me", 99999, false)
	eq(step.kind, "write")
	local rec = step.record :: any
	eq(rec.lock.job, "me")
	eq(rec.lock.at, 99999)
	eq(rec.data.coins, 50)
	eq(rec.data.version, Profile.VERSION)
end)

test("load: a broken or newer save is played with but nothing is written", function()
	local newer = { data = { version = Profile.VERSION + 1, coins = 9 } }
	local step = Profile.loadStep(newer, "me", 1, false)
	eq(step.kind, "readOnly")
	eq(step.record, nil)
	eq((step.data :: any).coins, 9)
	eq(Profile.loadStep({ data = "broken" }, "me", 1, false).kind, "readOnly")
	eq(Profile.loadStep(nil, "me", 1, false).kind, "write") -- new player
end)

test("save: lost lock, late autosave and leave save", function()
	local d = Profile.new()
	local other = { data = d, lock = { job = "other", at = 5 } }
	eq(Profile.saveStep(other, "me", d, false, false, 10).kind, "lost")
	eq(Profile.saveStep(other, "me", d, true, true, 10).kind, "lost")
	local mine = { data = d, lock = { job = "me", at = 5 } }
	local auto = Profile.saveStep(mine, "me", d, false, false, 10)
	eq(auto.kind, "write")
	eq((auto.record :: any).lock.at, 10)
	-- the leave save lets go of the lock
	local leave = Profile.saveStep(mine, "me", d, true, true, 10)
	eq(leave.kind, "write")
	eq((leave.record :: any).lock, nil)
	-- ...and an autosave that was already waiting must not take it back
	eq(Profile.saveStep({ data = d }, "me", d, false, true, 11).kind, "skip")
	-- no lock at all (first save) is fine
	eq(Profile.saveStep(nil, "me", d, false, false, 10).kind, "write")
end)

-- A fake store: the first `fails` calls throw, then it works like UpdateAsync.
local function fakeStore(fails: number, err: string)
	local calls = 0
	local value: any = nil
	return {
		update = function(fn: (any) -> any)
			calls += 1
			if calls <= fails then
				error(err)
			end
			local new = fn(value)
			if new ~= nil then
				value = new
			end
			return new
		end,
		calls = function()
			return calls
		end,
		value = function()
			return value
		end,
	}
end

test("retry: a few failures then it works, waiting longer each time", function()
	local s = fakeStore(2, "503 throttled")
	local waits: { number } = {}
	local ok = SaveRetry.run(function()
		return s.update(function()
			return { data = Profile.new() }
		end)
	end, function(t)
		table.insert(waits, t)
	end)
	truthy(ok)
	eq(s.calls(), 3)
	eq(waits[1], 2)
	eq(waits[2], 4)
	truthy(s.value())
end)

test("retry: gives up after the tries, saves nothing, and says so", function()
	local s = fakeStore(99, "DataStore request was added to queue")
	local told = 0
	local ok = SaveRetry.run(function()
		return s.update(function()
			return { data = Profile.new() }
		end)
	end, function() end, function()
		told += 1
	end)
	eq(ok, false)
	eq(s.calls(), SaveRetry.TRIES)
	eq(told, SaveRetry.TRIES)
	eq(s.value(), nil)
end)

test("retry: a 403 (API access off) stops at once", function()
	local s = fakeStore(99, "403: Studio access to APIs is not allowed")
	local waited = false
	local ok = SaveRetry.run(function()
		return s.update(function()
			return nil
		end)
	end, function()
		waited = true
	end)
	eq(ok, false)
	eq(s.calls(), 1)
	eq(waited, false)
end)

test("two servers: the second waits for the first, the first stops when robbed", function()
	local d = Profile.new()
	d.coins = 40
	local stored: any = Profile.loadStep(nil, "A", 100, false).record
	-- B joins the same player while A is live: blocked
	eq(Profile.loadStep(stored, "B", 150, false).kind, "blocked")
	-- B waits, then forces: takes it with A's coins
	local b = Profile.loadStep(stored, "B", 160, true)
	eq(b.kind, "write")
	eq((b.data :: any).version, Profile.VERSION)
	stored = b.record
	-- A's next save finds B's lock and writes nothing
	eq(Profile.saveStep(stored, "A", d, false, false, 170).kind, "lost")
end)

-- A visit that played unsaved (DataStore down at join) reaches the real save later.
local function realSave(): Profile.Data
	local d = Profile.new()
	d.coins = 500
	d.cars["buggy"] = true
	d.parked = { "buggy", "starter" }
	d.plotLevel = 1
	d.lastSeen = 5000
	d.stage = 3
	d.dailyDay = 20
	d.dayStreak = 4
	d.raceStars = 5
	d.starsFrom["9"] = { race = 2 }
	d.jobs = { day = 20, have = { 1, 0, 0 } }
	d.stars = 7
	return d
end

test("merge: a blank visit changes nothing in the real save", function()
	local out = Profile.mergeVisit(realSave(), Profile.new(), Profile.new())
	local want = realSave()
	eq(out.coins, want.coins)
	eq(out.stars, want.stars)
	eq(#out.parked, 2)
	eq(out.plotLevel, 1)
	eq(out.stage, 3)
	truthy(out.cars.buggy)
end)

test("merge: coins and cars earned in the visit are added, never replacing the save", function()
	local session = Profile.new()
	session.coins = 120
	session.cars["rocket"] = true
	session.parked = { "starter", "rocket" }
	session.raceStars = 2
	session.likes = 1
	session.starsFrom["9"] = { race = 3, drift = 1 }
	session.bolts["2"] = true
	local out = Profile.mergeVisit(realSave(), session, Profile.new())
	eq(out.coins, 620)
	truthy(out.cars.rocket)
	truthy(out.cars.buggy)
	eq(out.parked[1], "buggy")
	eq(out.parked[3], "rocket") -- bought this visit, there is room (3 + level 1 = 4)
	eq(out.raceStars, 7)
	eq(out.likes, 1)
	eq(out.starsFrom["9"].race, 3)
	eq(out.starsFrom["9"].drift, 1)
	eq(out.stars, 4 + 7) -- 3 + 1 medals + 7 race stars
	truthy(out.bolts["2"])
end)

test("merge: the daily gift and jobs come from the later day, never lower", function()
	local session = Profile.new()
	session.dailyDay = 19
	session.dayStreak = 1
	session.jobs = { day = 20, have = { 0, 3, 0 } }
	local out = Profile.mergeVisit(realSave(), session, Profile.new())
	eq(out.dailyDay, 20)
	eq(out.dayStreak, 4)
	eq(out.jobs.have[1], 1)
	eq(out.jobs.have[2], 3)
	local later = Profile.new()
	later.dailyDay = 21
	later.dayStreak = 5
	later.jobs = { day = 21, have = { 2, 2, 2 } }
	local out2 = Profile.mergeVisit(realSave(), later, Profile.new())
	eq(out2.dailyDay, 21)
	eq(out2.jobs.day, 21)
end)

test("merge: running it again on a fresh copy of the save gives the same answer", function()
	local session = Profile.new()
	session.coins = 75
	session.cars["rocket"] = true
	local a = Profile.mergeVisit(Profile.migrate(realSave()), session, Profile.new())
	local b = Profile.mergeVisit(Profile.migrate(realSave()), session, Profile.new())
	eq(a.coins, b.coins)
	eq(a.coins, 575)
	-- and the visit itself was not changed by it
	eq(session.coins, 75)
end)

test("merge: a first-ever account takes the garage the visit set up", function()
	local session = Profile.new()
	session.parked = { "starter" }
	session.coins = 30
	local out = Profile.mergeVisit(Profile.new(), session, Profile.new())
	eq(out.parked[1], "starter")
	eq(out.coins, 30)
end)

test("retry: the last error comes back, so the server can tell a 403 from an outage", function()
	local _, _, err = SaveRetry.run(function()
		error("503 busy")
	end, function() end, nil, 2)
	truthy(string.find(err or "", "503", 1, true))
	local ok, _, none = SaveRetry.run(function()
		return 1
	end, function() end)
	truthy(ok)
	eq(none, nil)
end)
