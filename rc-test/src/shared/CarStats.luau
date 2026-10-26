--!strict
-- Car VS Car (carter 10-26, rc-game/cvc-plan.md): what each of the 24 cars starts with. Three
-- bars (speed, turning, boost) from 0 to 100. A rarer car starts higher, tops out higher and
-- trains faster. Each car leans a little to one bar so the same rarity still feels different.
-- Names and rarity live in CarCatalog; this only adds the numbers. Pure, so Lune tests it.
-- Numbers are first guesses; Economy and a play-through tune them.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local Training = sibling("Training")

local CarStats = {}

export type Bars = { speed: number, turn: number, boost: number }

-- Per kind of car: the starting bar for all three, the top, and how fast it trains
-- (1 = the plan's base training speed).
CarStats.TIERS = {
	common = { start = 20, cap = 60, rate = 1 },
	rare = { start = 30, cap = 75, rate = 1.25 },
	epic = { start = 40, cap = 90, rate = 1.5 },
	legend = { start = 50, cap = 100, rate = 2 },
} :: { [string]: { start: number, cap: number, rate: number } }

-- How a car leans: points added to / taken from its start (each row adds up to 0, so rarity
-- alone sets the total). Drift cars lean to turning, big ones to boost, quick ones to speed.
local LEAN = {
	-- race, cheapest first
	race_bolt = { 6, -2, -4 }, -- the quick starter
	race_dart = { -2, 6, -4 }, -- the steady starter
	race_rocket = { -2, -4, 6 }, -- the zoom starter
	race_lime = { 4, 0, -4 },
	race_berry = { -4, 4, 0 },
	race_storm = { 0, -4, 4 },
	race_tiger = { 6, -2, -4 },
	race_comet = { 4, -4, 0 },
	-- drift
	drift_kid = { -4, 6, -2 },
	drift_ghost = { 0, 4, -4 },
	drift_fury = { 2, 2, -4 },
	drift_mint = { -2, 4, -2 },
	drift_cocoa = { -4, 6, -2 },
	drift_shadow = { 4, 4, -8 },
	drift_aqua = { -2, 6, -4 },
	drift_sunset = { 2, 4, -6 },
	-- gumball
	gb_lime = { 0, 6, -6 },
	gb_bubble = { 4, 0, -4 },
	gb_candy = { -4, 6, -2 },
	gb_night = { 2, 2, -4 },
	gb_glow = { -2, 0, 2 },
	gb_lava = { -4, 8, -4 },
	gb_toxic = { 2, 4, -6 },
	gb_gold = { 8, -4, -4 },
} :: { [string]: { number } }

-- The three cars a new kid picks from (all common, each leans a different way).
CarStats.STARTERS = { "race_bolt", "race_dart", "race_rocket" }

local function tier(id: any)
	return CarStats.TIERS[CarCatalog.rarity(id).id] or CarStats.TIERS.common
end

-- A car's starting bars (an unknown id = a plain common).
function CarStats.base(id: any): Bars
	local t = tier(id)
	local l = if type(id) == "string" then LEAN[id] else nil
	l = l or { 0, 0, 0 }
	return { speed = t.start + l[1], turn = t.start + l[2], boost = t.start + l[3] }
end

-- The top of every bar for this car.
function CarStats.cap(id: any): number
	return tier(id).cap
end

-- How fast it trains (a rarer car trains faster).
function CarStats.rate(id: any): number
	return tier(id).rate
end

-- Everything Training needs for one car id.
function CarStats.stats(id: any): Training.Stats
	return { base = CarStats.base(id), cap = CarStats.cap(id), rate = CarStats.rate(id) }
end

-- Speed + turning + boost now (0..300): what the league looks at. `car` is a garage entry.
function CarStats.total(car: Training.Car): number
	return Training.strength(car, CarStats.stats(car.id))
end

-- What a car tag shows: its three bars as a label, the whole number and how full the bar is
-- (0..1 of the 0..100 scale, so a rare car's bar stops short of the end at its top).
CarStats.BAR_LABELS = { speed = "SPD", turn = "TURN", boost = "BOOST" }
export type BarView = { bar: string, label: string, value: number, fill: number, cap: number }
function CarStats.view(car: Training.Car): { BarView }
	local stats = CarStats.stats(car.id)
	local out: { BarView } = {}
	for _, b in Training.BARS do
		local v = math.floor(Training.bar(car, b, stats) + 0.5)
		table.insert(out, {
			bar = b,
			label = CarStats.BAR_LABELS[b],
			value = v,
			fill = math.clamp(v / Training.MAX_BAR, 0, 1),
			cap = stats.cap,
		})
	end
	return out
end

-- Every car with a row here (the 24).
function CarStats.ids(): { string }
	local out = {}
	for id in LEAN do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return CarStats
