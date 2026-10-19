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
	Dash = make("Dash", "DASH", "dash", "Rocket forward.", 10, { dashForward = 110 }),
	Shield = make("Shield", "SHIELD", "shield", "Blocks hits for a while.", 18, { seconds = 5 }),
	Slam = make(
		"Slam",
		"SLAM",
		"slam",
		"Huge shockwave. Launches cars.",
		14,
		{ radius = 30, push = 80, lift = 16 }
	),
	Ram = make(
		"Ram",
		"RAM",
		"ram",
		"Your hits hurt a lot more.",
		14,
		{ seconds = 4, damageMult = 2.5 }
	),
	Magnet = make(
		"Magnet",
		"MAGNET",
		"magnet",
		"Pulls the other car to you.",
		15,
		{ radius = 48, push = 40 }
	),
	Jump = make("Jump", "JUMP", "jump", "Giant leap.", 10, { jumpSpeed = 65 }),
} :: { [string]: Ability }

-- Better rarity = stronger and ready sooner.
AbilitiesConfig.Rarity = {
	Common = { power = 1, cooldown = 1 },
	Rare = { power = 1.2, cooldown = 0.9 },
	Epic = { power = 1.45, cooldown = 0.8 },
	Legendary = { power = 1.8, cooldown = 0.65 },
} :: { [string]: RarityScale }

-- What each ability DOES in each mode (audit #22). Pure data: the pick screen can show `text`,
-- Specials (server) reads the effect fields. Modes are the lowercase GameMode attribute values
-- GroupMatch sets on the Arena folder: "soccer", "tag", "race". A mode with no row for an
-- ability (or an unknown mode) = the old behaviour.
--   ball        "push" = shoves the ball away like it shoves cars; "pull" = pulls the ball in
--   tagImmune   seconds the car cannot be tagged IT after using the ability (tag mode)
AbilitiesConfig.ModeUse =
	{
		soccer = {
			Slam = { text = "Shoves the ball and nearby cars away.", ball = "push" },
			Magnet = { text = "Pulls the ball and the other car to you.", ball = "pull" },
			Dash = { text = "Zoom to the ball." },
			Shield = { text = "Blocks the next hit." },
			Ram = { text = "Your next hits hurt more." },
			Jump = { text = "Hop over the ball." },
		},
		tag = {
			Shield = { text = "Nobody can tag you for 2 seconds.", tagImmune = 2 },
			Dash = { text = "Zoom away from IT, or catch someone." },
			Jump = { text = "Hop away." },
			Slam = { text = "Shoves nearby cars away." },
			Magnet = { text = "Pulls the other car to you." },
			Ram = { text = "Your next hits hurt more." },
		},
		race = {
			Dash = { text = "Speed boost down the track." },
			Jump = { text = "Hop over bumps and gaps." },
			Shield = { text = "Blocks the next hit." },
			Slam = { text = "Shoves rivals aside." },
			Magnet = { text = "Pulls the rival to you." },
			Ram = { text = "Your next hits hurt more." },
		},
	} :: { [string]: { [string]: { text: string, ball: string?, tagImmune: number? } } }

-- Mass that counts as "normal" when scaling knockback (heavier enemies move less).
AbilitiesConfig.refMass = 60
AbilitiesConfig.minMassScale = 0.4
AbilitiesConfig.maxMassScale = 1.6

return AbilitiesConfig
