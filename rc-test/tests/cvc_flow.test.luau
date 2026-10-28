--!strict
-- Car VS Car, a new player's first minutes played through the real rules (CvcRules), the way
-- TrainingServer runs them: join, pick a starter, train with COACH, a race every 3 min (the
-- first one won against easy bots), coins, trophies, the first race's crate, a crate bought for
-- coins, and up a league. Then the save is stored and loaded back.
local H = require("./harness")
local CvcRules = require("../src/shared/CvcRules")
local CarStats = require("../src/shared/CarStats")
local Crates = require("../src/shared/Crates")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")
local Training = require("../src/shared/Training")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car: a new player's first minutes")

-- a fixed roll, so a crate always gives the same car
local function rng(n: number): Crates.Rng
	return {
		NextNumber = function(_: any): number
			return n
		end,
	} :: any
end

-- What a new player has after `mins` minutes: COACH tapped each time it's ready, a race every
-- 3 minutes with these places (first one = 1st against the easy bots), a free crate opened as
-- soon as it comes, and a crate bought once there are coins for it.
type Run = { data: Profile.Data, coachTaps: number, races: number, bought: number, log: { string } }
local function play(mins: number, places: { number }): Run
	local data = Profile.new()
	CvcRules.setUp(data)
	assert(CvcRules.pick(data, CarStats.STARTERS[1]), "pick")
	local run: Run = { data = data, coachTaps = 0, races = 0, bought = 0, log = {} }
	local now = 1_000_000
	local coachAt = 0
	local bits = 0
	for sec = 1, mins * 60 do
		now += 1
		if Training.coachReady(coachAt, now) then
			coachAt = now
			run.coachTaps += 1
		end
		bits = CvcRules.tick(data, 1, Training.coaching(coachAt, now), now, bits)
		if sec % 180 == 0 then
			run.races += 1
			local place = places[run.races] or 4
			local got = CvcRules.raceDone(data, place, now)
			if got.firstCrate then
				Profile.raiseStage(data, Profile.STAGE.RACED)
			end
			table.insert(
				run.log,
				`{sec // 60} min: race {run.races} place {place} +{got.coins} coins, {League.name(
					got.league
				)}`
			)
			while data.crates > 0 and CvcRules.open(data, rng(0.5)) do
			end
		end
		if CvcRules.buy(data, "basic", rng(0.5)) then
			run.bought += 1
			table.insert(run.log, `{sec // 60} min: bought a crate`)
		end
	end
	return run
end

test("flow: a new player picks a starter, and it races and trains at once", function()
	local data = Profile.new()
	CvcRules.setUp(data)
	eq(#data.stations, 1, "one station at the start")
	eq(data.stations[1].kind, "treadmill")
	-- only the 3 starters, and only once
	truthy(not CvcRules.pick(data, "not_a_car"))
	truthy(CvcRules.pick(data, CarStats.STARTERS[2]))
	truthy(not CvcRules.pick(data, CarStats.STARTERS[1]), "a second pick")
	eq(#data.garage, 1)
	local car = data.garage[1]
	eq(car.id, CarStats.STARTERS[2])
	eq(data.racer, car.uid)
	eq(data.stations[1].uid, car.uid)
	truthy(data.picked)
	-- one minute later it has trained a bit and earned a few coins
	local bits = 0
	for t = 1, 60 do
		bits = CvcRules.tick(data, 1, false, t, bits)
	end
	H.near(car.speed, Training.MAIN_PER_MIN, 1e-6)
	eq(data.coins, CvcRules.COINS_PER_MIN)
end)

test("flow: 10 minutes of play: races pay, trophies, a crate car, and Silver league", function()
	local run = play(10, { 1, 1, 2 })
	local data = run.data
	eq(run.races, 3)
	eq(data.raceWins, 2)
	eq(data.trophies, 3)
	eq(data.stage, Profile.STAGE.RACED)
	-- the first race's crate was opened: a second car
	eq(data.crates, 0)
	truthy(#data.garage >= 2, "a crate car")
	-- strength from training + 2 wins = Silver
	truthy(CvcRules.best(data) >= League.NEED[2].strength, `strength {CvcRules.best(data)}`)
	eq(data.league, 2, "Silver")
	-- a win's boost is on for 10 minutes after the last win
	truthy(data.boostUntil > 0)
	truthy(data.coins > 0)
	print("       " .. table.concat(run.log, "\n       "))
	print(
		`       after 10 min: {data.coins} coins, {#data.garage} cars, strength {CvcRules.best(data)}`
	)
end)

test("flow: no wins means no league up, however strong the car", function()
	local run = play(30, { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 })
	eq(run.data.raceWins, 0)
	eq(run.data.league, 1)
	-- a finish still pays, and the first race still gives its crate
	truthy(run.data.coins > 0)
	truthy(#run.data.garage >= 2)
	eq(run.data.trophies, 0)
end)

test("flow: the save keeps everything after a play", function()
	local run = play(10, { 1, 1, 2 })
	local back = Profile.migrate(run.data)
	eq(#back.garage, #run.data.garage)
	eq(back.racer, run.data.racer)
	eq(back.league, run.data.league)
	eq(back.trophies, run.data.trophies)
	eq(back.raceWins, run.data.raceWins)
	eq(back.picked, true)
	eq(back.stations[1].uid, run.data.stations[1].uid)
	eq(back.garage[1].speed, run.data.garage[1].speed)
	-- and a load starts training again where it was
	CvcRules.setUp(back)
	eq(#back.stations, #run.data.stations)
end)

test("flow: the rules say no without changing anything", function()
	local data = Profile.new()
	CvcRules.setUp(data)
	CvcRules.pick(data, CarStats.STARTERS[1])
	local before = data.coins
	-- no coins: no crate, no upgrade, no plot level
	eq(CvcRules.buy(data, "basic", rng(0.5)), nil)
	truthy(not CvcRules.upgrade(data, 1))
	truthy(not CvcRules.levelUp(data))
	-- the free crate isn't for sale, and an unknown crate does nothing
	data.coins = 100000
	eq(CvcRules.buy(data, "free", rng(0.5)), nil)
	eq(CvcRules.buy(data, "gold", rng(0.5)), nil)
	eq(CvcRules.buy(data, 5, rng(0.5)), nil)
	-- no free crate to open
	eq(CvcRules.open(data, rng(0.5)), nil)
	eq(data.coins, 100000)
	data.coins = before
	-- someone else's car, a missing station, bad values
	truthy(not CvcRules.station(data, 1, "999"))
	truthy(not CvcRules.station(data, 2, data.garage[1].uid))
	truthy(not CvcRules.station(data, 0 / 0, ""))
	truthy(not CvcRules.station(data, "1", ""))
	truthy(not CvcRules.racer(data, "999"))
	eq(data.stations[1].uid, data.garage[1].uid)
	eq(#data.garage, 1)
end)

test("flow: coins buy a plot level, a station upgrade and a crate", function()
	local data = Profile.new()
	CvcRules.setUp(data)
	CvcRules.pick(data, CarStats.STARTERS[1])
	data.coins = (Training.plotCost(0) :: number) + (Training.upgradeCost(1) :: number) + 300
	truthy(CvcRules.levelUp(data))
	eq(#data.stations, 2)
	eq(data.stations[2].kind, "ramp")
	truthy(CvcRules.upgrade(data, 1))
	eq(data.stations[1].level, 2)
	local id = CvcRules.buy(data, "basic", rng(0.5))
	truthy(id ~= nil)
	eq(data.coins, 0)
	-- the new car goes on the new station, which takes nothing off the first one
	local new = data.garage[2]
	truthy(CvcRules.station(data, 2, new.uid))
	eq(data.stations[1].uid, data.garage[1].uid)
	-- moving a car takes it off its old station
	truthy(CvcRules.station(data, 1, new.uid))
	eq(data.stations[2].uid, "")
	eq(data.stations[1].uid, new.uid)
end)

test("flow: a broken or merged save is tidied on join", function()
	local data = Profile.new()
	CvcRules.pick(data, CarStats.STARTERS[1])
	local uid = data.garage[1].uid
	-- plot level 0 gives 1 station, but this save has 3, one car on two, a bad kind and level
	data.stations = {
		{ kind = "pool", level = 40, uid = uid },
		{ kind = "ramp", level = 1, uid = uid },
		{ kind = "track", level = 1, uid = "999" },
	}
	data.racer = "999"
	CvcRules.setUp(data)
	eq(#data.stations, 1)
	eq(data.stations[1].kind, "treadmill")
	eq(data.stations[1].level, Training.MAX_STATION_LEVEL)
	eq(data.stations[1].uid, uid)
	eq(data.racer, uid)
	-- one car on two stations trains once
	data.plotLevel = 1
	data.stations[2] = { kind = "ramp", level = 1, uid = uid }
	CvcRules.setUp(data)
	eq(data.stations[2].uid, "")
end)

test("flow: an old tycoon save gets the new-player steps once: pick, first race, crate", function()
	local old =
		Profile.migrate({ version = 15, coins = 500, stage = 3, cars = { race_bolt = true } })
	eq(old.stage, Profile.STAGE.SHOPPED)
	eq(#old.garage, 1, "the old car is kept")
	CvcRules.setUp(old)
	eq(old.stage, Profile.STAGE.NEW, "starts over")
	truthy(CvcRules.pick(old, CarStats.STARTERS[2]))
	eq(#old.garage, 2)
	local got = CvcRules.raceDone(old, 1, 100)
	truthy(got.firstCrate)
	Profile.raiseStage(old, Profile.STAGE.RACED)
	-- after that it's a normal save: joining again doesn't start over or give another crate
	CvcRules.setUp(old)
	eq(old.stage, Profile.STAGE.RACED)
	truthy(not CvcRules.raceDone(old, 1, 200).firstCrate)
	eq(old.crates, 1)
end)

test("flow: the daily gift gives the streak's coins and a free crate, once a day", function()
	local data = Profile.new()
	local coins, streak, crate = CvcRules.daily(data, 100)
	truthy(coins > 0)
	eq(streak, 1)
	truthy(crate)
	eq(data.crates, 1)
	-- the same day again: nothing
	coins, streak, crate = CvcRules.daily(data, 100)
	eq(coins, 0)
	truthy(not crate)
	eq(data.crates, 1)
	-- the next day: day 2 in a row, a bigger gift and another crate
	local c2, s2, crate2 = CvcRules.daily(data, 101)
	eq(s2, 2)
	truthy(c2 > 0 and crate2)
	eq(data.crates, 2)
	-- and the crates open
	truthy(CvcRules.open(data, rng(0.5)) ~= nil)
	eq(data.crates, 1)
end)

test("flow: the first new car brings the 2nd station free and starts training on it", function()
	local data = Profile.new()
	CvcRules.setUp(data)
	CvcRules.pick(data, CarStats.STARTERS[1])
	eq(data.plotLevel, 0)
	data.crates = 1
	local id = CvcRules.open(data, rng(0.5))
	truthy(id ~= nil)
	eq(data.plotLevel, 1)
	eq(#data.stations, 2)
	eq(data.stations[2].uid, data.garage[2].uid)
	eq(data.stations[1].uid, data.garage[1].uid) -- the first car keeps training
	-- a 3rd car with no empty station waits on a stand (and the plot doesn't grow again)
	data.crates = 1
	truthy(CvcRules.open(data, rng(0.5)) ~= nil)
	eq(data.plotLevel, 1)
	eq(#data.stations, 2)
end)
