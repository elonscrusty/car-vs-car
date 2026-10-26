--!strict
-- Car VS Car race stats (carter 10-26): training makes a car a bit faster, quicker off the line
-- and tighter in turns, and its BOOST lasts longer. Nothing else about driving changes.
local H = require("./harness")
local RaceStats = require("../src/shared/RaceStats")
local Tuning = require("../src/shared/Tuning")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Race stats")

local function car(speed: number, turn: number, boost: number)
	return { uid = "1", id = "bolt", speed = speed, turn = turn, boost = boost }
end
local function stats(base: number, cap: number)
	return { base = { speed = base, turn = base, boost = base }, cap = cap, rate = 1 }
end

test("race stats: no car drives exactly like today", function()
	local d = RaceStats.drive(nil, nil)
	eq(d.top, 1)
	eq(d.start, 1)
	eq(d.turn, 1)
	eq(d.boostSecs, RaceStats.BOOST_MIN)
end)

test("race stats: more training = a little faster, never a rocket", function()
	local low = RaceStats.drive(car(0, 0, 0), stats(10, 100))
	local high = RaceStats.drive(car(50, 50, 50), stats(10, 100))
	truthy(high.top > low.top and high.start > low.start and high.turn > low.turn)
	truthy(high.boostSecs > low.boostSecs)
	-- a full car is at most a small step up
	local full = RaceStats.drive(car(999, 999, 999), stats(100, 100))
	eq(full.top, 1 + RaceStats.TOP)
	eq(full.start, 1 + RaceStats.START)
	eq(full.turn, 1 + RaceStats.TURN)
	truthy(math.abs(full.boostSecs - RaceStats.BOOST_MAX) < 1e-9)
	truthy(full.top <= 1.15)
end)

test("race stats: a car stops getting better at its top", function()
	local capped = RaceStats.drive(car(90, 0, 0), stats(10, 40))
	eq(capped.top, 1 + RaceStats.TOP * 0.4)
end)

test("race stats: bad numbers from the server can't break the car", function()
	local bad = RaceStats.fromAttributes(function(n: string): any
		return ({ RaceTop = 50, RaceStart = 0 / 0, RaceTurn = "x", RaceBoost = -5 })[n]
	end)
	eq(bad.top, 1 + RaceStats.TOP)
	eq(bad.start, 1)
	eq(bad.turn, 1)
	eq(bad.boostSecs, RaceStats.BOOST_MIN)
	local none = RaceStats.fromAttributes(function(_n: string): any
		return nil
	end)
	eq(none.top, 1)
end)

test("race stats: Tuning gets the trained numbers, and a plain car goes back to today", function()
	local setStats = (Tuning :: any).setStats
	local top, accel, steer = Tuning.topSpeed, Tuning.accel, Tuning.steerMax
	setStats({ top = 1.1, start = 1.2, turn = 1.1 })
	truthy(math.abs(Tuning.topSpeed - top * 1.1) < 1e-6)
	truthy(math.abs(Tuning.accel - accel * 1.2) < 1e-6)
	truthy(math.abs(Tuning.steerMax - steer * 1.1) < 1e-6)
	setStats(nil)
	eq(Tuning.topSpeed, top)
	eq(Tuning.accel, accel)
	eq(Tuning.steerMax, steer)
end)
