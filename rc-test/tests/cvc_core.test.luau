--!strict
-- Car VS Car core (carter 10-26, rc-game/cvc-plan.md): training, leagues, and the v16 save.
local H = require("./harness")
local Training = require("../src/shared/Training")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy
-- (Car VS Car SMASH drops the training-era fields on load) these tests round-trip them, so they
-- run with them kept
local function trainingEra(name: string, fn: () -> ())
	test(name, function()
		H.withTraining(Profile, fn)
	end)
end

print("Car VS Car core")

local STATS: Training.Stats = { base = { speed = 20, turn = 20, boost = 20 }, cap = 60, rate = 1 }

local function newCar(): Training.Car
	return { uid = "1", id = "bolt", speed = 0, turn = 0, boost = 0 }
end

test(
	"training: a minute on the treadmill fills a small bit of speed, a little of the rest",
	function()
		local c = Training.gain(newCar(), "treadmill", 1, 60, false, STATS)
		eq(c.speed, Training.MAIN_PER_MIN)
		eq(c.turn, Training.SIDE_PER_MIN)
		eq(c.boost, Training.SIDE_PER_MIN)
		-- each station trains its own bar most
		eq(Training.gain(newCar(), "ramp", 1, 60, false, STATS).boost, Training.MAIN_PER_MIN)
		eq(Training.gain(newCar(), "track", 1, 60, false, STATS).turn, Training.MAIN_PER_MIN)
		-- the old table is left alone
		local before = newCar()
		Training.gain(before, "treadmill", 1, 60, false, STATS)
		eq(before.speed, 0)
	end
)

test("training: coach doubles, upgrades and rarer cars train faster", function()
	local plain = Training.gain(newCar(), "treadmill", 1, 10, false, STATS).speed
	eq(Training.gain(newCar(), "treadmill", 1, 10, true, STATS).speed, plain * 2)
	truthy(Training.gain(newCar(), "treadmill", 3, 10, false, STATS).speed > plain)
	local rare = table.clone(STATS)
	rare.rate = 1.5
	truthy(Training.gain(newCar(), "treadmill", 1, 10, false, rare).speed > plain)
end)

test("training: stops at the car's top", function()
	local c = Training.gain(newCar(), "treadmill", 5, 3600 * 10, true, STATS)
	eq(Training.bar(c, "speed", STATS), STATS.cap)
	truthy(Training.full(c, STATS))
	eq(Training.strength(c, STATS), STATS.cap * 3)
	-- an unknown station does nothing
	eq(Training.gain(newCar(), "pool", 1, 60, false, STATS).speed, 0)
end)

test("training: coach once a minute, 2x for 10 s", function()
	truthy(Training.coachReady(0, 100))
	truthy(not Training.coachReady(100, 159))
	truthy(Training.coachReady(100, 160))
	truthy(Training.coaching(100, 109))
	truthy(not Training.coaching(100, 110))
	truthy(not Training.coaching(0, 5))
end)

test("training: one station at the start, plot levels add more", function()
	eq(#Training.stationsFor(0), 1)
	eq(Training.stationsFor(0)[1], "treadmill")
	eq(#Training.stationsFor(2), 3)
	eq(#Training.stationsFor(99), #Training.STATIONS)
	eq(Training.MAX_PLOT_LEVEL, #Training.STATIONS - 1)
	eq(Profile.MAX_STATIONS, #Training.STATIONS)
	eq(Profile.BAR_MAX, Training.MAX_BAR)
end)

test("league: up by strength AND top-3 finishes, never down", function()
	eq(League.next(0, 0, 1), 1)
	eq(League.next(500, 0, 1), 1) -- strong car, no top-3 finishes yet
	eq(League.next(0, 500, 1), 1) -- many top-3 finishes, weak car
	eq(League.next(League.NEED[2].strength, League.NEED[2].top3, 1), 2)
	eq(League.next(League.NEED[2].strength, League.NEED[2].top3 - 1, 1), 1)
	eq(League.next(300, 999, 1), #League.NAMES)
	eq(League.next(0, 0, 3), 3) -- never down
	eq(League.clamp(9), #League.NAMES)
	eq(League.clamp(nil), 1)
	eq(#League.NAMES, Profile.LEAGUES)
end)

test("league: top 3 get a trophy, higher leagues pay more", function()
	truthy(League.trophy(1) and League.trophy(3))
	truthy(not League.trophy(4) and not League.trophy(0))
	eq(League.prize(1, 0), League.TRY_PAY) -- didn't finish: still a little
	truthy(League.prize(1, 0) > 0)
	truthy(League.prize(1, 0) < League.prize(1, 4), "finishing pays more")
	truthy(League.prize(1, 1) > League.prize(1, 2))
	truthy(League.prize(1, 4) > 0)
	for i = 2, #League.NAMES do
		truthy(League.prize(i, 1) > League.prize(i - 1, 1))
	end
end)

test("save v16: a new save has an empty garage, Bronze, no starter yet", function()
	local d = Profile.new()
	eq(#d.garage, 0)
	eq(d.league, 1)
	eq(d.picked, false)
	local car = Profile.addCar(d, "bolt") :: Profile.GarageCar
	local twin = Profile.addCar(d, "bolt") :: Profile.GarageCar
	truthy(car.uid ~= twin.uid) -- duplicates kept, each its own
	eq(#d.garage, 2)
	eq(Profile.findCar(d, twin.uid), twin)
end)

test("save v16: an old save gets one untrained car per car it owned", function()
	local old: any = { version = 15, coins = 50, cars = { bolt = true, dart = true } }
	local d = Profile.migrate(old)
	eq(#d.garage, 2)
	eq(d.garage[1].id, "bolt")
	eq(d.garage[1].speed, 0)
	eq(d.coins, 50)
	-- and it round-trips without making more cars
	local again = Profile.migrate(d)
	eq(#again.garage, 2)
	eq(again.nextUid, d.nextUid)
end)

trainingEra("save v16: bad garage data is cleaned, uids never repeat", function()
	local raw: any = {
		garage = {
			{ uid = "7", id = "bolt", speed = 999, turn = -5, boost = 0 / 0 },
			{ uid = "7", id = "dart" }, -- a repeat uid is dropped
			{ uid = 3, id = "x" }, -- not a string
			"junk",
		},
		racer = "7",
		stations = {
			{ kind = "treadmill", level = 99, uid = "7" },
			{ kind = "ramp", uid = "nope" },
		},
		league = 12,
		trophies = -4,
		picked = true,
	}
	local d = Profile.migrate(raw)
	eq(#d.garage, 1)
	eq(d.garage[1].speed, Profile.BAR_MAX)
	eq(d.garage[1].turn, 0)
	eq(d.garage[1].boost, 0)
	eq(d.racer, "7")
	eq(d.stations[1].level, Profile.MAX_LEVEL)
	eq(d.stations[2].uid, "")
	eq(d.league, Profile.LEAGUES)
	eq(d.trophies, 0)
	eq(d.picked, true)
	local car = Profile.addCar(d, "dart") :: Profile.GarageCar
	truthy(car.uid ~= "7")
end)

test("save v16: an unsaved visit's cars and training reach the real save", function()
	local stored = Profile.new()
	local mine = Profile.addCar(stored, "bolt") :: Profile.GarageCar
	mine.speed = 10
	local base = Profile.new()
	local session = Profile.new()
	local same = Profile.addCar(session, "bolt") :: Profile.GarageCar -- uid "1", same car
	same.speed = 4
	same.turn = 6
	local clash = Profile.addCar(session, "dart") :: Profile.GarageCar
	clash.uid = mine.uid -- impossible normally, but must not eat a car
	session.trophies = 2
	session.league = 2
	local out = Profile.mergeVisit(stored, session, base)
	eq(Profile.findCar(out, mine.uid).speed, 10)
	eq(Profile.findCar(out, mine.uid).turn, 6)
	local ids = {}
	for _, c in out.garage do
		ids[c.id] = true
	end
	truthy(ids.dart, "the dart was lost")
	eq(out.trophies, 2)
	eq(out.league, 2)
end)

test("training: every station level and plot level past the first has a cost", function()
	eq(#Training.UPGRADE_COST, Training.MAX_STATION_LEVEL - 1)
	eq(#Training.PLOT_COST, Training.MAX_PLOT_LEVEL)
	eq(Training.upgradeCost(Training.MAX_STATION_LEVEL), nil)
	eq(Training.plotCost(Training.MAX_PLOT_LEVEL), nil)
	truthy((Training.plotCost(0) :: number) > 0)
end)
