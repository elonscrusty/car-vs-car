--!strict
-- StreakFire: the numbers for the fire on a car that smashed 3 or more in a row without being
-- smashed (carter picked "1 Hot Rod Flames" on the preview page,
-- project files car-vs-car/streak-fire-preview/streak-fire-pick.html, 2026-10-29).
-- The server counts the streak (Match karts' `streak`) and puts it on the car model as the
-- attribute "Streak"; client/StreakFire reads it and burns. Looks only.
-- Sizes and speeds are for a 6-stud car (like shared/CarBoom); the client scales them by the
-- real car's length. Spots are {x, y, z} from the car's middle: x right, y up, z BACK (the
-- front is -z, like the rest of the car code).

local StreakFire = {}

StreakFire.FROM = 3 -- smashes in a row that light the car
StreakFire.SIZE = { 1.3, 1.9, 2.6 } -- fire size at 3, 5 and 7 (or more) in a row
StreakFire.STEPS = { 3, 5, 7 } -- the streak that starts each size
StreakFire.PHONE = 0.6 -- fewer flames on a phone
StreakFire.FLARE = { count = 60, light = 14, secs = 0.5 } -- the whoosh when a size starts
StreakFire.HEAT = { light = 3, flicker = 1.5, range = 18, fill = 0.74 } -- the car glows red-hot

export type Em = {
	name: string,
	spots: { { number } }, -- the rate is shared between the spots
	rate: number, -- per second, in all (times the fire size when `grows`)
	grows: boolean,
	minLevel: number, -- 1 at 3 smashes, 2 at 5, 3 at 7
	speed: { number },
	life: { number },
	size: { number }, -- {from, to}
	from: { number }, -- color {r, g, b}
	to: { number },
	see: number, -- start transparency (0 = solid); it fades to nothing
	glow: number, -- LightEmission (0 = the dark smoke layer)
	spread: number, -- degrees
	up: number, -- acceleration up, studs/s²
	dir: "Top" | "Back",
	tex: "fire" | "smoke" | "spark",
	volume: boolean?, -- spawn all over the car's body instead of at the spot
}

StreakFire.EMITTERS = {
	-- flames licking along both sides
	{
		name = "Side",
		spots = { { -1.55, 0, -1.4 }, { 1.55, 0, -1.4 }, { -1.55, 0, 1.4 }, { 1.55, 0, 1.4 } },
		rate = 70,
		grows = true,
		minLevel = 1,
		speed = { 2.5, 5 },
		life = { 0.35, 0.6 },
		size = { 2.2, 0.15 },
		from = { 255, 160, 48 },
		to = { 208, 32, 0 },
		see = 0.2,
		glow = 1,
		spread = 25,
		up = 2,
		dir = "Top",
		tex = "fire",
	},
	-- the hood
	{
		name = "Hood",
		spots = { { 0, 0.35, -1.5 }, { 0, 0.35, -2.3 } },
		rate = 55,
		grows = true,
		minLevel = 1,
		speed = { 3, 6 },
		life = { 0.4, 0.65 },
		size = { 2.9, 0.2 },
		from = { 255, 176, 48 },
		to = { 192, 24, 0 },
		see = 0.2,
		glow = 1,
		spread = 18,
		up = 2,
		dir = "Top",
		tex = "fire",
	},
	-- out of the exhausts
	{
		name = "Tail",
		spots = { { -0.7, -0.65, 3.3 }, { 0.7, -0.65, 3.3 } },
		rate = 70,
		grows = true,
		minLevel = 1,
		speed = { 4, 8 },
		life = { 0.45, 0.75 },
		size = { 1.1, 0.2 },
		from = { 255, 184, 64 },
		to = { 255, 80, 0 },
		see = 0.2,
		glow = 1,
		spread = 14,
		up = 0,
		dir = "Back",
		tex = "fire",
	},
	-- over the wheels
	{
		name = "Wheels",
		spots = {
			{ -1.6, -0.2, -1.95 },
			{ 1.6, -0.2, -1.95 },
			{ -1.6, -0.2, 1.95 },
			{ 1.6, -0.2, 1.95 },
		},
		rate = 14,
		grows = true,
		minLevel = 1,
		speed = { 2, 4 },
		life = { 0.3, 0.5 },
		size = { 1, 0.15 },
		from = { 255, 192, 64 },
		to = { 208, 32, 0 },
		see = 0.2,
		glow = 1,
		spread = 20,
		up = 1,
		dir = "Top",
		tex = "fire",
	},
	-- embers flying off the roof
	{
		name = "Embers",
		spots = { { 0, 0.9, 0 } },
		volume = true,
		rate = 26,
		grows = true,
		minLevel = 1,
		speed = { 3, 7 },
		life = { 0.8, 1.3 },
		size = { 0.22, 0.04 },
		from = { 255, 224, 128 },
		to = { 255, 64, 0 },
		see = 0,
		glow = 1,
		spread = 40,
		up = 1,
		dir = "Top",
		tex = "spark",
	},
	-- black smoke trailing (the dark layer)
	{
		name = "Smoke",
		spots = { { 0, 0.9, 2.5 } },
		rate = 14,
		grows = true,
		minLevel = 1,
		speed = { 1.5, 3 },
		life = { 1.1, 1.6 },
		size = { 0.8, 3 },
		from = { 44, 38, 40 },
		to = { 13, 13, 16 },
		see = 0.5,
		glow = 0,
		spread = 20,
		up = 0,
		dir = "Top",
		tex = "smoke",
	},
	-- 5 in a row: a hot white core on the hood
	{
		name = "Core",
		spots = { { 0, 0.4, -1.8 } },
		rate = 50,
		grows = false,
		minLevel = 2,
		speed = { 3, 5 },
		life = { 0.35, 0.45 },
		size = { 2, 0.2 },
		from = { 255, 255, 255 },
		to = { 255, 176, 64 },
		see = 0.25,
		glow = 1,
		spread = 12,
		up = 2,
		dir = "Top",
		tex = "fire",
	},
	-- 7 in a row: a tall column of fire
	{
		name = "Column",
		spots = { { 0, 0.6, -1.8 } },
		rate = 30,
		grows = false,
		minLevel = 3,
		speed = { 7, 10 },
		life = { 0.5, 0.8 },
		size = { 2.6, 0.4 },
		from = { 255, 208, 128 },
		to = { 192, 32, 0 },
		see = 0.25,
		glow = 1,
		spread = 10,
		up = 2,
		dir = "Top",
		tex = "fire",
	},
} :: { Em }

-- 0 = no fire; 1, 2, 3 = the fire sizes at 3, 5 and 7 smashes in a row.
function StreakFire.level(streak: number?): number
	if type(streak) ~= "number" or streak ~= streak then
		return 0
	end
	local level = 0
	for i, from in StreakFire.STEPS do
		if streak >= from then
			level = i
		end
	end
	return level
end

-- The fire size multiplier for a level (a level under 1 counts as 1; no fire is level 0 above).
function StreakFire.size(level: number): number
	return StreakFire.SIZE[math.clamp(math.floor(level), 1, #StreakFire.SIZE)] or 0
end

-- The Rate for one spot of an emitter at a level; 0 when that level does not show it.
function StreakFire.rate(e: Em, level: number, phone: boolean): number
	if level < e.minLevel or level < 1 then
		return 0
	end
	local n = e.rate / #e.spots
	if e.grows then
		n *= StreakFire.size(level)
	end
	return n * (if phone then StreakFire.PHONE else 1)
end

-- How much to scale the 6-stud numbers for a car `length` studs long (same as CarBoom.unit).
function StreakFire.unit(length: number): number
	if length ~= length or length <= 0 or length == math.huge then
		return 1
	end
	return math.clamp(length / 6, 0.1, 4)
end

return StreakFire
