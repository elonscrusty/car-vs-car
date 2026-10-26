--!strict
-- Car VS Car (carter 10-26, rc-game/cvc-plan.md): a car's trained bars in the big race. Race feel
-- stays LOCKED: the only change a car makes is these small multipliers on today's numbers
-- (Tuning.setStats). A bar at 0 drives exactly like today; a full bar is a bit faster, quicker off
-- the line, tighter in the turns, and its BOOST lasts longer. Kept small so skill and car count
-- the same (a weak car with a good driver still wins sometimes). Pure, so Lune tests it.

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

-- what a full bar (100) adds on top of today's numbers
RaceStats.TOP = 0.12
RaceStats.START = 0.25
RaceStats.TURN = 0.15
RaceStats.BOOST_MIN = 0.6 -- seconds of BOOST at Boost 0
RaceStats.BOOST_MAX = 1.8 -- at Boost 100

RaceStats.PLAIN = table.freeze({ top = 1, start = 1, turn = 1, boostSecs = RaceStats.BOOST_MIN })

local function part(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(v, 0, Training.MAX_BAR) / Training.MAX_BAR
end

-- The race numbers for a car (its bars = base + trained, from Training.bar; nil = plain car).
function RaceStats.drive(car: Car?, stats: Stats?): Drive
	if not (car and stats) then
		return table.clone(RaceStats.PLAIN) :: Drive
	end
	local speed = part(Training.bar(car, "speed", stats))
	local turn = part(Training.bar(car, "turn", stats))
	local boost = part(Training.bar(car, "boost", stats))
	return {
		top = 1 + RaceStats.TOP * speed,
		start = 1 + RaceStats.START * speed,
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
		top = within(get("RaceTop"), 1, 1 + RaceStats.TOP, 1),
		start = within(get("RaceStart"), 1, 1 + RaceStats.START, 1),
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
