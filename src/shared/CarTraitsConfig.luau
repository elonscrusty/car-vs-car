--!strict
-- Per-car HANDLING traits (data only). Every number here is a PLACEHOLDER: retune by feel.
-- See docs/car-feel.md. A car with no row uses `Defaults` (drives exactly like before).
--   grip       side-slide killing. 0.5 = slippery, 1 = normal, 1.5 = glued to the floor.
--   drift      0..1: how much hard steering at speed breaks the tires loose (extra slide).
--   punch      acceleration curve. + = strong launch that fades near top speed, - = slow start
--              that keeps pulling at top speed. 0 = flat (old behavior).
--   highTurn   turn rate multiplier AT TOP SPEED (1 at a standstill). <1 = pushes wide (heavy),
--              >1 = darts around.
--   sizeScale  body size vs the neutral pack car (5 x 2.5 x 8). Applied to pack cars by
--              CarCatalog; for the 8 hand-written cars it is just read from their real size.

local CarTraitsConfig = {}

export type Traits = {
	grip: number,
	drift: number,
	punch: number,
	highTurn: number,
	sizeScale: number,
}

CarTraitsConfig.Defaults = {
	grip = 1,
	drift = 0,
	punch = 0,
	highTurn = 1,
	sizeScale = 1,
} :: Traits

-- Hard limits (applied by CarTraits.resolve, so a typo cannot make a car undriveable).
CarTraitsConfig.Limits = {
	grip = { 0.4, 1.8 },
	drift = { 0, 1 },
	punch = { -0.5, 0.6 },
	highTurn = { 0.4, 1.3 },
	sizeScale = { 0.7, 1.6 },
} :: { [string]: { number } }

-- Drift: at full steer and full speed, `drift` of 1 removes this fraction of the grip.
CarTraitsConfig.driftSlip = 0.65
-- Never let the combined grip fall under this (cars must stay steerable).
CarTraitsConfig.minGrip = 0.15
-- Acceleration factor stays inside this range whatever `punch` says.
CarTraitsConfig.accelRange = { 0.4, 1.7 }

-- Neutral pack car length, used to read sizeScale of hand-written cars.
CarTraitsConfig.neutralLength = 8

-- Two cars "differ" in a trait when the numbers are at least this far apart (tests).
CarTraitsConfig.differBy = 0.09

-- Per car. Missing fields fall back to Defaults.
CarTraitsConfig.Cars = {
	Heavy = { grip = 1.25, drift = 0.05, punch = -0.15, highTurn = 0.7 },
	Light = { grip = 0.7, drift = 0.7, punch = 0.35, highTurn = 1.1 },
	Sedan = { grip = 1.0, drift = 0.2, punch = 0.0, highTurn = 0.95 },
	DuneBuggy = { grip = 0.75, drift = 0.6, punch = 0.3, highTurn = 1.15, sizeScale = 0.85 },
	Ramp = { grip = 0.75, drift = 0.4, punch = 0.05, highTurn = 1.0 },
	Bulldozer = { grip = 1.3, drift = 0.05, punch = -0.25, highTurn = 0.65 },
	Drift = { grip = 0.5, drift = 1.0, punch = 0.2, highTurn = 1.2 },
	Spike = { grip = 1.1, drift = 0.1, punch = 0.25, highTurn = 0.85 },
	Rocket = { grip = 0.6, drift = 0.5, punch = 0.5, highTurn = 0.8 },
	MonsterTruck = { grip = 1.15, drift = 0.25, punch = -0.3, highTurn = 0.6, sizeScale = 1.35 },
	Formula = { grip = 1.4, drift = 0.15, punch = 0.4, highTurn = 0.95, sizeScale = 0.9 },
	ArmoredTruck = { grip = 1.5, drift = 0, punch = -0.4, highTurn = 0.55, sizeScale = 1.4 },
} :: { [string]: { [string]: number } }

-- Stat bars (CarStatsUi): value range that maps to an empty..full bar.
CarTraitsConfig.BarRanges = {
	speed = { 50, 120 }, -- maxSpeed
	weight = { 15, 160 }, -- mass
	turn = { 1.8, 5.5 }, -- turnRate
	hp = { 80, 230 },
} :: { [string]: { number } }

-- Words for CarTraits.describe. Each rule fires when its stat passes `at` (above for
-- `high`, below for `low`); the two with the biggest (distance x weight) win. Order breaks ties.
CarTraitsConfig.Words = {
	{
		key = "maxSpeed",
		weight = 1.5,
		low = { at = 66, word = "slow" },
		high = { at = 85, word = "fast" },
	},
	{
		key = "mass",
		weight = 0.5,
		low = { at = 40, word = "light" },
		high = { at = 100, word = "heavy" },
	},
	{
		key = "grip",
		weight = 1,
		low = { at = 0.8, word = "slippery" },
		high = { at = 1.25, word = "grippy" },
	},
	{
		key = "turn",
		weight = 1,
		low = { at = 2.8, word = "wide turns" },
		high = { at = 4.2, word = "sharp turns" },
	},
	{
		key = "hp",
		weight = 1.2,
		low = { at = 110, word = "fragile" },
		high = { at = 190, word = "tough" },
	},
	{
		key = "damageMult",
		weight = 1,
		low = { at = 0.5, word = "weak hits" },
		high = { at = 1.4, word = "hits hard" },
	},
} :: {
	{
		key: string,
		weight: number,
		low: { at: number, word: string },
		high: { at: number, word: string },
	}
}

return CarTraitsConfig
