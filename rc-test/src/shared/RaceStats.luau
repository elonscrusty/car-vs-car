--!strict
-- Car VS Car (carter 10-26, rc-game/cvc-plan.md): a car's trained bars in the big race. Race feel
-- stays LOCKED: the only change a car makes is these multipliers on today's numbers
-- (Tuning.setStats). A fresh starter car (Speed ~8) is a bit slower than today, a fully trained
-- starter (Speed 55) drives like today, and a full bar is faster, quicker off the line, tighter in
-- the turns, and its BOOST lasts longer (carter 10-28: starters start low, crate and trained cars
-- feel clearly stronger). Top speed never goes past +15% of today, so a weak car with a good
-- driver still wins sometimes. Pure, so Lune tests it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Training = sibling("Training")

-- (the shapes from Training.luau)
type Car = { uid: string, id: string, speed: number, turn: number, boost: number }
type Stats = { base: { speed: number, turn: number, boost: number }, cap: number, rate: number }

export type Drive = {
	top: number, -- top speed x (Speed bar)
	start: number, -- engine push x, so it gets away quicker (Speed bar)
	turn: number, -- wheel angle x (Turning bar)
	boostSecs: number, -- how long the BOOST button pushes (Boost bar)
}

local RaceStats = {}

-- a bar at 0 drives at the *_MIN part of today's numbers; a full bar (100) adds the rest on top
RaceStats.TOP_MIN = 0.82
RaceStats.TOP = 0.33 -- top speed 0.82 (Speed 0) .. 1.15 (Speed 100); Speed ~55 = today
RaceStats.START_MIN = 0.8
RaceStats.START = 0.45 -- engine push 0.8 .. 1.25
RaceStats.TURN = 0.15 -- wheel angle 1 .. 1.15 (never under today, so a slow car still makes the bends)
RaceStats.BOOST_MIN = 0.6 -- seconds of BOOST at Boost 0
RaceStats.BOOST_MAX = 1.8 -- at Boost 100

RaceStats.PLAIN = table.freeze({ top = 1, start = 1, turn = 1, boostSecs = RaceStats.BOOST_MIN })

local function part(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(v, 0, Training.MAX_BAR) / Training.MAX_BAR
end

-- Top speed (x today's) for a Speed bar of `v` (0..100).
function RaceStats.topAt(v: number): number
	return RaceStats.TOP_MIN + RaceStats.TOP * part(v)
end

-- The race numbers for a car (its bars = base + trained, from Training.bar; nil = plain car).
-- `cap` = the most strength (all 3 bars) it may race with: a stronger car racing a friend in a
-- lower league has all its bars scaled down to that (League.top).
function RaceStats.drive(car: Car?, stats: Stats?, cap: number?): Drive
	if not (car and stats) then
		return table.clone(RaceStats.PLAIN) :: Drive
	end
	local s, t, b =
		Training.bar(car, "speed", stats),
		Training.bar(car, "turn", stats),
		Training.bar(car, "boost", stats)
	local sum = s + t + b
	if cap and sum > cap and sum > 0 then
		local k = math.max(0, cap) / sum
		s, t, b = s * k, t * k, b * k
	end
	local speed = part(s)
	local turn = part(t)
	local boost = part(b)
	return {
		top = RaceStats.topAt(s),
		start = RaceStats.START_MIN + RaceStats.START * speed,
		turn = 1 + RaceStats.TURN * turn,
		boostSecs = RaceStats.BOOST_MIN + (RaceStats.BOOST_MAX - RaceStats.BOOST_MIN) * boost,
	}
end

-- Read back what the server put on the player (attributes RaceTop/RaceStart/RaceTurn/RaceBoost),
-- each kept inside what a full bar can give, so a bad value can't make a rocket.
function RaceStats.fromAttributes(get: (string) -> any): Drive
	local function within(v: any, lo: number, hi: number, plain: number): number
		if type(v) ~= "number" or v ~= v then
			return plain
		end
		return math.clamp(v, lo, hi)
	end
	return {
		top = within(get("RaceTop"), RaceStats.TOP_MIN, RaceStats.TOP_MIN + RaceStats.TOP, 1),
		start = within(
			get("RaceStart"),
			RaceStats.START_MIN,
			RaceStats.START_MIN + RaceStats.START,
			1
		),
		turn = within(get("RaceTurn"), 1, 1 + RaceStats.TURN, 1),
		boostSecs = within(
			get("RaceBoost"),
			RaceStats.BOOST_MIN,
			RaceStats.BOOST_MAX,
			RaceStats.BOOST_MIN
		),
	}
end

return RaceStats
