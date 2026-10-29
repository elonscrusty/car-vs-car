--!strict
-- CarBoom: the numbers for the big boom when a car gets smashed, and its 3 s come-back
-- (carter picked "New" = the Mega Fireball on the preview page,
-- project files car-vs-car/smash-boom-preview/smash-boom-pick.html, 2026-10-29).
-- Sizes and speeds are for a 6-stud car (the preview car); client/CarBoom scales them by the
-- real car's length. Looks only: the server decides every smash.
--
-- The layers, in order (VFX playbook: flash, shape, sparks, smoke, one dark layer):
--   flash (white core + light) -> 3 ground rings + a dark scorch -> fireball + a mushroom
--   column -> hot sparks + glowing chunks -> thick black smoke; car parts fly (one wheel rolls
--   far), the car goes burnt black and keeps burning (flames, embers, smoke) until it comes
--   back: a smoke poof, a light beam from the sky, rings, stars and a white flash on the car.

local CarBoom = {}

CarBoom.PREVIEW_LEN = 6 -- studs: the preview car's length (every size below is for it)

-- a particle burst or a steady stream. Colors are {r, g, b}; size = {from, to};
-- speed/life = {min, max}; up = true sends it up in a cone instead of every way
export type Layer = {
	count: number, -- burst size (or per second for a stream)
	speed: { number },
	life: { number },
	size: { number },
	from: { number },
	to: { number },
	glow: number, -- LightEmission (0 = the dark layer)
	drag: number,
	gravity: number, -- studs/s², down is negative
	spread: number, -- degrees (180 = every way)
	see: { number }?, -- transparency {from, to}; default {0.1, 1}
}

CarBoom.BURST = {
	fire = {
		count = 70,
		speed = { 6, 16 },
		life = { 0.35, 0.7 },
		size = { 2.9, 0.5 },
		from = { 255, 192, 80 },
		to = { 192, 16, 0 },
		glow = 1,
		drag = 4,
		gravity = 0,
		spread = 180,
	},
	mushroom = {
		count = 26,
		speed = { 10, 15 },
		life = { 0.5, 0.85 },
		size = { 2.5, 4 },
		from = { 255, 160, 48 },
		to = { 144, 16, 0 },
		glow = 1,
		drag = 2.2,
		gravity = 0,
		spread = 12,
	},
	sparks = {
		count = 50,
		speed = { 18, 34 },
		life = { 0.4, 0.9 },
		size = { 0.45, 0.05 },
		from = { 255, 255, 255 },
		to = { 255, 96, 16 },
		glow = 1,
		drag = 1.6,
		gravity = -34,
		spread = 100,
	},
	smoke = {
		count = 30,
		speed = { 2, 6 },
		life = { 1.4, 2.2 },
		size = { 2, 6 },
		from = { 42, 34, 36 },
		to = { 13, 13, 16 },
		glow = 0,
		drag = 1.8,
		gravity = 3,
		spread = 70,
		see = { 0.1, 1 },
	},
	-- the come-back
	poof = {
		count = 18,
		speed = { 3, 6 },
		life = { 0.5, 0.8 },
		size = { 2, 4 },
		from = { 223, 232, 255 },
		to = { 122, 134, 168 },
		glow = 0.2,
		drag = 3,
		gravity = 0,
		spread = 180,
		see = { 0.3, 1 },
	},
	stars = {
		count = 40,
		speed = { 3, 9 },
		life = { 0.4, 0.9 },
		size = { 0.7, 0.1 },
		from = { 255, 255, 255 },
		to = { 111, 212, 255 },
		glow = 1,
		drag = 0,
		gravity = 0,
		spread = 10,
	},
} :: { [string]: Layer }

-- the burning wreck: per second, while the car waits to come back
CarBoom.WRECK = {
	flames = {
		count = 40,
		speed = { 4, 6.5 },
		life = { 0.35, 0.65 },
		size = { 1.6, 0.2 },
		from = { 255, 208, 80 },
		to = { 208, 32, 0 },
		glow = 1,
		drag = 0,
		gravity = 0,
		spread = 12,
	},
	embers = {
		count = 25,
		speed = { 5, 9 },
		life = { 0.8, 1.4 },
		size = { 0.22, 0.04 },
		from = { 255, 224, 128 },
		to = { 255, 64, 0 },
		glow = 1,
		drag = 0.5,
		gravity = 0,
		spread = 25,
	},
	smoke = {
		count = 18,
		speed = { 4, 6 },
		life = { 1.6, 2.3 },
		size = { 1.4, 5.2 },
		from = { 44, 38, 40 },
		to = { 13, 13, 16 },
		glow = 0,
		drag = 0.7,
		gravity = 0,
		spread = 15,
		see = { 0.2, 1 },
	},
} :: { [string]: Layer }

-- ground rings: {color, size (diameter), seconds, delay}
CarBoom.RINGS = {
	{ color = { 255, 138, 42 }, size = 22, secs = 0.45, delay = 0 },
	{ color = { 255, 255, 255 }, size = 14, secs = 0.28, delay = 0.04 },
	{ color = { 255, 192, 64 }, size = 28, secs = 0.6, delay = 0.1 },
}
CarBoom.BACK_RINGS = {
	{ color = { 111, 212, 255 }, size = 16, secs = 0.55, delay = 0 },
	{ color = { 255, 255, 255 }, size = 9, secs = 0.35, delay = 0.08 },
}

CarBoom.FLASH = { size = 7, secs = 0.14, light = 18, range = 22 }
CarBoom.SCORCH = { size = 11, secs = 3.2, see = 0.25 } -- the dark mark under the wreck
CarBoom.HEAT = { light = 3, flicker = 1.6, range = 16 } -- the wreck's flickering orange light
CarBoom.BURNT = { 16, 11, 9 } -- the wreck's color
CarBoom.BURN_IN = 0.15 -- seconds to go black
CarBoom.BEAM = { width = 4, core = 1.2, height = 40, secs = 0.8 }
CarBoom.BACK_FLASH = 0.5 -- seconds of white on the car that came back

CarBoom.GRAVITY = 38 -- flying parts and chunks, studs/s²
CarBoom.FLY_SECS = 3 -- flying parts stay this long (the wait), then fade
CarBoom.CHUNKS = 14 -- small glowing bits (every 3rd one glows)
CarBoom.FIND_BACK = 1 -- seconds to wait for the car to land on its new spot
CarBoom.PHONE = 0.6 -- bursts are this much smaller on a phone

-- the car parts that fly off (blocks shaped like the car's parts, made in the car's colors).
-- size/at are for the 6-stud car (at = from the car's middle: x right, y up, z front).
export type Piece = {
	name: string,
	size: { number },
	at: { number },
	wheel: boolean?,
	paint: "body" | "trim" | "tire",
	smoke: boolean?,
	roll: boolean?, -- this one rolls far away
}
CarBoom.PIECES = {
	{
		name = "Wheel",
		size = { 0.62, 1.24, 1.24 },
		at = { -1.6, -0.4, 1.95 },
		wheel = true,
		paint = "tire",
		smoke = true,
		roll = true,
	},
	{
		name = "Wheel",
		size = { 0.62, 1.24, 1.24 },
		at = { 1.6, -0.4, 1.95 },
		wheel = true,
		paint = "tire",
		smoke = true,
	},
	{
		name = "Wheel",
		size = { 0.62, 1.24, 1.24 },
		at = { 1.6, -0.4, -1.95 },
		wheel = true,
		paint = "tire",
		smoke = true,
	},
	{
		name = "Wing",
		size = { 3.2, 0.14, 0.7 },
		at = { 0, 1.0, -2.9 },
		paint = "trim",
		smoke = true,
	},
	{
		name = "Roof",
		size = { 2.4, 0.14, 2.3 },
		at = { 0, 1.35, -0.6 },
		paint = "body",
		smoke = true,
	},
	{ name = "Door", size = { 0.08, 0.7, 1.9 }, at = { -1.58, 0.05, 0.2 }, paint = "body" },
	{ name = "Door", size = { 0.08, 0.7, 1.9 }, at = { 1.58, 0.05, 0.2 }, paint = "body" },
	{ name = "Hood", size = { 2.4, 0.12, 1.6 }, at = { 0, 0.5, 2.1 }, paint = "trim" },
	{ name = "Bumper", size = { 3, 0.3, 0.3 }, at = { 0, -0.3, 3.2 }, paint = "trim" },
} :: { Piece }

-- How much to scale the 6-stud numbers for a car `length` studs long.
function CarBoom.unit(length: number): number
	if length ~= length or length <= 0 or length == math.huge then
		return 1
	end
	return math.clamp(length / CarBoom.PREVIEW_LEN, 0.1, 4)
end

-- How many of a burst to throw (phones throw fewer; always at least 1).
function CarBoom.count(n: number, phone: boolean): number
	return math.max(1, math.floor(n * (if phone then CarBoom.PHONE else 1) + 0.5))
end

-- A flying part's start velocity (x, y, z) for the 6-stud car: up and out, from 3 random numbers
-- in 0..1 (a, b, c). The rolling wheel goes far along the ground to one side.
function CarBoom.fling(p: Piece, a: number, b: number, c: number): (number, number, number)
	if p.roll then
		local side = if p.at[1] < 0 then -1 else 1
		return side * 14, 7, 4 + 4 * c
	end
	local out = 9 + 8 * a
	local ang = math.atan2(p.at[3], p.at[1]) + (b - 0.5) * 1.2
	return math.cos(ang) * out * 0.7, 12 + out * 0.6, math.sin(ang) * out * 0.7 + (c - 0.5) * 4
end

-- A bounce on the ground: the new (vx, vy, vz) after hitting the floor going down at vy.
function CarBoom.bounce(vx: number, vy: number, vz: number): (number, number, number)
	local up = if math.abs(vy) > 2 then -vy * 0.38 else 0
	return vx * 0.72, up, vz * 0.72
end

-- The 3-2-1 over a wreck `t` seconds after the smash (nil when no number shows).
function CarBoom.countdown(t: number, wait: number): number?
	if t < 0 or t >= wait then
		return nil
	end
	return math.clamp(math.ceil(wait - t), 1, 3)
end

-- 0..1 of a ring's growth `t` seconds into it (ease out cubic); nil before its delay.
function CarBoom.ringGrow(t: number, secs: number, delay: number): number?
	local k = (t - delay) / secs
	if k < 0 then
		return nil
	end
	k = math.min(k, 1)
	return 1 - (1 - k) ^ 3
end

return CarBoom
