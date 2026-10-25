--!strict
-- The save never gets worse: a broken or newer save is read but never written back, every old
-- version loads up to the current one, and what a kid earned comes back the same after a save.
local H = require("./harness")
local Profile = require("../src/shared/Profile")

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
