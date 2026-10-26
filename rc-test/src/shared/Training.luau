--!strict
-- Car VS Car (carter 10-26, rc-game/cvc-plan.md): cars train on stations in your plot. Each
-- station trains all 3 bars a bit and its own bar most (treadmill = speed, ramp = boost, speed
-- track = turning). A small bit of a bar takes about a minute; COACH doubles it for 10 s, once a
-- minute. Training stops at the car's top, and only runs while you're in the game. Pure, so Lune
-- tests it; TrainingServer runs it every second. (Numbers are first guesses; Economy tunes them.)

export type Car = { uid: string, id: string, speed: number, turn: number, boost: number }
-- what CarStats says about one car id: its starting bars, its top (per bar) and how fast it trains
export type Stats = {
	base: { speed: number, turn: number, boost: number },
	cap: number,
	rate: number,
}

local Training = {}

Training.BARS = { "speed", "turn", "boost" }
Training.KINDS = { "treadmill", "ramp", "track" }
Training.MAIN = { treadmill = "speed", ramp = "boost", track = "turn" }
Training.NAMES = { treadmill = "TREADMILL", ramp = "RAMP", track = "SPEED TRACK" }
Training.MAIN_PER_MIN = 5 -- its own bar, a level 1 station, a rate 1 car
Training.SIDE_PER_MIN = 2 -- the other two bars
Training.LEVEL_STEP = 0.5 -- each station level past 1 adds this much (level 3 = 2x)
Training.MAX_STATION_LEVEL = 5
Training.COACH_MULT = 2
Training.COACH_SECS = 10
Training.COACH_EVERY = 60
Training.MAX_BAR = 100
-- plot level -> the stations it has (level 0 = 1 station: one car trains at the start)
Training.STATIONS = {
	"treadmill",
	"ramp",
	"track",
	"treadmill",
	"ramp",
	"track",
	"treadmill",
	"ramp",
	"track",
}
Training.MAX_PLOT_LEVEL = #Training.STATIONS - 1

function Training.isKind(kind: any): boolean
	return type(kind) == "string" and Training.MAIN[kind] ~= nil
end

-- The stations a plot at this level has, in order.
function Training.stationsFor(plotLevel: number): { string }
	local n = math.clamp(math.floor(plotLevel) + 1, 1, #Training.STATIONS)
	return table.move(Training.STATIONS, 1, n, 1, {})
end

-- Points a minute on one bar.
function Training.perMin(kind: string, bar: string, level: number, rate: number): number
	local base = if Training.MAIN[kind] == bar then Training.MAIN_PER_MIN else Training.SIDE_PER_MIN
	local lv = math.clamp(math.floor(level), 1, Training.MAX_STATION_LEVEL)
	return base * (1 + Training.LEVEL_STEP * (lv - 1)) * math.max(rate, 0)
end

-- A car's bar now (base + trained, up to its top).
function Training.bar(car: Car, bar: string, stats: Stats): number
	local top = math.min(stats.cap, Training.MAX_BAR)
	return math.min((stats.base :: any)[bar] + (car :: any)[bar], top)
end

-- Speed + turning + boost (0..300): what the league looks at.
function Training.strength(car: Car, stats: Stats): number
	local n = 0
	for _, b in Training.BARS do
		n += Training.bar(car, b, stats)
	end
	return n
end

-- Is every bar at the top?
function Training.full(car: Car, stats: Stats): boolean
	for _, b in Training.BARS do
		if Training.bar(car, b, stats) < math.min(stats.cap, Training.MAX_BAR) then
			return false
		end
	end
	return true
end

-- The car after `seconds` on a station of this kind and level (a new table; trained points are
-- kept on top of the base, so a car's base can be retuned without losing training).
function Training.gain(
	car: Car,
	kind: string,
	level: number,
	seconds: number,
	coach: boolean,
	stats: Stats
): Car
	local out = table.clone(car)
	if not Training.isKind(kind) or seconds <= 0 then
		return out
	end
	local mult = if coach then Training.COACH_MULT else 1
	local top = math.min(stats.cap, Training.MAX_BAR)
	for _, b in Training.BARS do
		local room = math.max(top - (stats.base :: any)[b], 0)
		local add = Training.perMin(kind, b, level, stats.rate) * mult * seconds / 60;
		(out :: any)[b] = math.min((out :: any)[b] + add, room)
	end
	return out
end

-- May COACH be tapped now? (`at` = when it was last tapped, 0 = never)
function Training.coachReady(at: number, now: number): boolean
	return at <= 0 or now - at >= Training.COACH_EVERY
end

-- Is the coach's 2x still on?
function Training.coaching(at: number, now: number): boolean
	return at > 0 and now - at < Training.COACH_SECS
end

return Training
