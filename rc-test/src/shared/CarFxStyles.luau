--!strict
-- Look-only styles for a car's tailpipe flames and wheel trails (carter 10-29: players will pick
-- looks, nothing here touches the driving). The numbers are for the preview car (9.9 long) and
-- scale with the car; colours are {r, g, b} 0-255 so this file runs in the plain-Lua tests.
-- Preview: kart-preview/trails-tries.html. Twin Jets (carter's pick) and Scrap Sparks (his pick)
-- are the starters; the other flames are options for later.
--
-- A player's choice is read from their Player attributes ExhaustStyle / TrailStyle (set by the
-- loadout when it exists); no attribute, or one we don't know, gives the starter.

export type Emit = {
	size: { number }, -- start, end
	life: { number }, -- shortest, longest (seconds)
	speed: { number }, -- slowest, fastest
	spread: number, -- degrees
	rate: number, -- a second at full strength
	colors: { { number } }, -- two or more, start to end
	glow: number, -- 0 normal .. 1 additive
	fade: { number }, -- see-through at the start, at the end
	drag: number,
	gravity: number, -- pulls down
}

export type Exhaust = {
	id: string,
	name: string,
	jet: Emit, -- the flame, per pipe
	extras: { Emit }, -- smoke, embers: keep going at `idle` strength even when not boosting
	idle: number, -- 0..1: how much of the flame/extras burn with no boost
	pop: Emit, -- one-shot puff (the idle crackle, and the bang)
	bang: number, -- pops let off when the boost ends
	light: { number }, -- rear glow colour
	lightPower: number,
}

export type Trail = {
	id: string,
	name: string,
	sparks: Emit, -- per rear wheel
	dust: Emit,
	minSpeed: number, -- studs/s (preview scale) where it starts
	fullSpeed: number, -- ... and where it is at full strength
	boostMul: number, -- more on a boost pad
}

local CarFxStyles = {}

CarFxStyles.ATTR_EXHAUST = "ExhaustStyle"
CarFxStyles.ATTR_TRAIL = "TrailStyle"
CarFxStyles.DEFAULT_EXHAUST = "twin_jets"
CarFxStyles.DEFAULT_TRAIL = "scrap_sparks"

local FLAME = { { 207, 234, 255 }, { 255, 176, 96 }, { 255, 48, 0 } }

CarFxStyles.EXHAUST = {
	twin_jets = {
		id = "twin_jets",
		name = "Twin Jets",
		jet = {
			size = { 0.7, 0.08 },
			life = { 0.14, 0.26 },
			speed = { 10, 18 },
			spread = 5,
			rate = 150,
			colors = FLAME,
			glow = 1,
			fade = { 0.1, 1 },
			drag = 0,
			gravity = 0,
		},
		extras = {},
		idle = 0,
		pop = {
			size = { 1.1, 0.08 },
			life = { 0.1, 0.16 },
			speed = { 4, 6 },
			spread = 5,
			rate = 0,
			colors = FLAME,
			glow = 1,
			fade = { 0.1, 1 },
			drag = 0,
			gravity = 0,
		},
		bang = 0,
		light = { 255, 90, 32 },
		lightPower = 3,
	},
	dragon_breath = {
		id = "dragon_breath",
		name = "Dragon Breath",
		jet = {
			size = { 0.6, 1.4 },
			life = { 0.2, 0.5 },
			speed = { 3, 8 },
			spread = 22,
			rate = 120,
			colors = { { 255, 210, 122 }, { 255, 110, 30 }, { 208, 16, 0 } },
			glow = 1,
			fade = { 0.2, 1 },
			drag = 2,
			gravity = 0,
		},
		extras = {
			{ -- smoke
				size = { 0.5, 2.2 },
				life = { 0.8, 1.3 },
				speed = { 2, 4 },
				spread = 15,
				rate = 40,
				colors = { { 58, 50, 52 }, { 21, 21, 26 } },
				glow = 0,
				fade = { 0.5, 1 },
				drag = 1,
				gravity = 0,
			},
			{ -- embers
				size = { 0.14, 0.04 },
				life = { 0.4, 0.8 },
				speed = { 8, 16 },
				spread = 30,
				rate = 50,
				colors = { { 255, 233, 160 }, { 255, 96, 16 } },
				glow = 1,
				fade = { 0, 1 },
				drag = 0,
				gravity = 14,
			},
		},
		idle = 0.2,
		pop = {
			size = { 1.4, 0.3 },
			life = { 0.12, 0.2 },
			speed = { 3, 6 },
			spread = 30,
			rate = 0,
			colors = { { 255, 210, 122 }, { 208, 16, 0 } },
			glow = 1,
			fade = { 0.2, 1 },
			drag = 2,
			gravity = 0,
		},
		bang = 0,
		light = { 255, 120, 30 },
		lightPower = 5,
	},
	afterburner = {
		id = "afterburner",
		name = "Afterburner",
		jet = {
			size = { 0.6, 0.06 },
			life = { 0.25, 0.3 },
			speed = { 28, 36 },
			spread = 1,
			rate = 130,
			colors = { { 255, 255, 255 }, { 255, 176, 96 }, { 255, 48, 0 } },
			glow = 1,
			fade = { 0.05, 1 },
			drag = 0,
			gravity = 0,
		},
		extras = {},
		idle = 0,
		pop = {
			size = { 2.6, 3.6 },
			life = { 0.12, 0.2 },
			speed = { 4, 10 },
			spread = 40,
			rate = 0,
			colors = { { 255, 240, 200 }, { 255, 192, 96 }, { 255, 32, 0 } },
			glow = 1,
			fade = { 0.1, 1 },
			drag = 3,
			gravity = 0,
		},
		bang = 6,
		light = { 160, 200, 255 },
		lightPower = 3,
	},
} :: { [string]: Exhaust }

CarFxStyles.TRAIL = {
	scrap_sparks = {
		id = "scrap_sparks",
		name = "Scrap Sparks",
		sparks = {
			size = { 0.34, 0.06 },
			life = { 0.5, 1.0 },
			speed = { 4, 12 },
			spread = 40,
			rate = 85,
			colors = { { 255, 242, 192 }, { 255, 90, 16 } },
			glow = 1,
			fade = { 0, 1 },
			drag = 0,
			gravity = 30,
		},
		dust = {
			size = { 0.6, 2.4 },
			life = { 0.7, 1.1 },
			speed = { 1, 3 },
			spread = 40,
			rate = 22,
			colors = { { 106, 90, 74 }, { 42, 38, 34 } },
			glow = 0,
			fade = { 0.6, 1 },
			drag = 1.6,
			gravity = 0,
		},
		minSpeed = 12,
		fullSpeed = 60,
		boostMul = 1.15,
	},
} :: { [string]: Trail }

-- the picked style, or the starter for nil / an unknown name
function CarFxStyles.exhaust(id: string?): Exhaust
	local s = if id then CarFxStyles.EXHAUST[id] else nil
	return s or CarFxStyles.EXHAUST[CarFxStyles.DEFAULT_EXHAUST]
end

function CarFxStyles.trail(id: string?): Trail
	local s = if id then CarFxStyles.TRAIL[id] else nil
	return s or CarFxStyles.TRAIL[CarFxStyles.DEFAULT_TRAIL]
end

return CarFxStyles
