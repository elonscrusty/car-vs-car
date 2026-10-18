--!strict
-- The 6 car abilities and how rarity makes them stronger. ALL ability numbers live here
-- (placeholders, tune freely). A car has exactly one ability; the SPECIAL button fires it.
-- Numbers are the COMMON strength. `Rarity[...]` scales them up (see shared/Abilities.resolve).
-- kind: "dash" (burst forward), "shield" (soaks the next hit), "slam" (shockwave around you),
-- "ram" (your next hits hurt more), "magnet" (pulls the enemy to you), "jump" (big hop).

export type Kind = "dash" | "shield" | "slam" | "ram" | "magnet" | "jump"

export type Ability = {
	id: string,
	name: string,
	kind: Kind,
	blurb: string,
	cooldown: number, -- seconds
	radius: number, -- slam / magnet reach in studs
	push: number, -- speed change given to the enemy at point blank (slam: away, magnet: toward you)
	lift: number, -- upward speed change given to the enemy (slam)
	dashForward: number, -- own speed burst forward (dash)
	jumpSpeed: number, -- own upward speed (jump)
	seconds: number, -- how long a shield or ram bonus lasts
	damageMult: number, -- ram: damage multiplier while the bonus is on
}

export type RarityScale = {
	power: number, -- multiplies reach, push, lift, speed, jump and seconds; damageMult grows by it
	cooldown: number, -- multiplies the cooldown (smaller = ready sooner)
}

local function make(
	id: string,
	name: string,
	kind: Kind,
	blurb: string,
	cooldown: number,
	extra: { [string]: number }
): Ability
	return {
		id = id,
		name = name,
		kind = kind,
		blurb = blurb,
		cooldown = cooldown,
		radius = extra.radius or 0,
		push = extra.push or 0,
		lift = extra.lift or 0,
		dashForward = extra.dashForward or 0,
		jumpSpeed = extra.jumpSpeed or 0,
		seconds = extra.seconds or 0,
		damageMult = extra.damageMult or 1,
	}
end

local AbilitiesConfig = {}

-- Menu order.
AbilitiesConfig.Order = { "Dash", "Shield", "Slam", "Ram", "Magnet", "Jump" }

AbilitiesConfig.Abilities = {
	Dash = make("Dash", "DASH", "dash", "Zoom forward.", 5, { dashForward = 70 }),
	Shield = make("Shield", "SHIELD", "shield", "Blocks the next hit.", 12, { seconds = 4 }),
	Slam = make(
		"Slam",
		"SLAM",
		"slam",
		"Shockwave. Shoves cars away.",
		8,
		{ radius = 22, push = 45, lift = 8 }
	),
	Ram = make(
		"Ram",
		"RAM",
		"ram",
		"Your next hits hurt more.",
		8,
		{ seconds = 2.5, damageMult = 1.6 }
	),
	Magnet = make(
		"Magnet",
		"MAGNET",
		"magnet",
		"Pulls the other car to you.",
		9,
		{ radius = 40, push = 40 }
	),
	Jump = make("Jump", "JUMP", "jump", "Big hop.", 6, { jumpSpeed = 45 }),
} :: { [string]: Ability }

-- Better rarity = stronger and ready sooner.
AbilitiesConfig.Rarity = {
	Common = { power = 1, cooldown = 1 },
	Rare = { power = 1.2, cooldown = 0.9 },
	Epic = { power = 1.45, cooldown = 0.8 },
	Legendary = { power = 1.8, cooldown = 0.65 },
} :: { [string]: RarityScale }

-- Mass that counts as "normal" when scaling knockback (heavier enemies move less).
AbilitiesConfig.refMass = 60
AbilitiesConfig.minMassScale = 0.4
AbilitiesConfig.maxMassScale = 1.6

return AbilitiesConfig
