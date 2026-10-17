--!strict
-- Per-car special move numbers. ALL special numbers live here (placeholders, tune freely).
-- kind: "slam" (radial shockwave), "cone" (flip things in front), "dash" (burst of own speed),
-- "spin" (next hit deals more damage). Speeds are studs/sec added (mass-aware for the enemy).

export type Special = {
	id: string,
	name: string,
	kind: "slam" | "cone" | "dash" | "spin",
	cooldown: number, -- seconds
	radius: number, -- slam/cone reach in studs
	push: number, -- speed change given to the enemy at point blank
	lift: number, -- upward speed change given to the enemy
	spin: number, -- spin (rad/sec) given to the enemy
	coneDeg: number, -- cone half-angle in degrees
	dashForward: number, -- own speed burst forward
	dashSide: number, -- own speed burst sideways
	duration: number, -- how long a "spin" bonus lasts
	damageMult: number, -- damage multiplier while the bonus is on
}

local function make(
	id: string,
	name: string,
	kind: "slam" | "cone" | "dash" | "spin",
	cooldown: number,
	extra: { [string]: number }
): Special
	return {
		id = id,
		name = name,
		kind = kind,
		cooldown = cooldown,
		radius = extra.radius or 0,
		push = extra.push or 0,
		lift = extra.lift or 0,
		spin = extra.spin or 0,
		coneDeg = extra.coneDeg or 0,
		dashForward = extra.dashForward or 0,
		dashSide = extra.dashSide or 0,
		duration = extra.duration or 0,
		damageMult = extra.damageMult or 1,
	}
end

local SpecialsConfig = {}

-- Mass that counts as "normal" when scaling knockback (heavier enemies move less).
SpecialsConfig.refMass = 60
SpecialsConfig.minMassScale = 0.4
SpecialsConfig.maxMassScale = 1.6

SpecialsConfig.ByCar = {
	Heavy = make("GroundSlam", "GROUND SLAM", "slam", 7, { radius = 22, push = 45, lift = 8 }),
	Light = make("Dodge", "DODGE DASH", "dash", 4, { dashSide = 70 }),
	Ramp = make(
		"Flip",
		"FLIP",
		"cone",
		7,
		{ radius = 20, coneDeg = 35, push = 10, lift = 40, spin = 8 }
	),
	Spike = make("SpinAttack", "SPIN ATTACK", "spin", 7, { duration = 2, damageMult = 2 }),
	Tank = make("Smash", "SMASH", "slam", 9, { radius = 30, push = 60, lift = 5 }),
	Drift = make("Slide", "SLIDE DASH", "dash", 5, { dashForward = 60, dashSide = 25 }),
	Bulldozer = make("Charge", "CHARGE", "dash", 8, { dashForward = 75 }),
	Rocket = make("Boost", "ROCKET DASH", "dash", 6, { dashForward = 110 }),
} :: { [string]: Special }

return SpecialsConfig
