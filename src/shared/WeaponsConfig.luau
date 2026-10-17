--!strict
-- Car weapons: ALL weapon numbers live here (placeholders, tune freely).
-- A player wears ONE weapon at a time (profile.weapons.equipped); every car they drive carries it.
-- "passive" weapons work by themselves; "active" ones fire when the WEAPON button is pressed.
-- Distances are studs, times are seconds. Damage is HP and passes the shield like any hit.

export type WeaponDef = {
	id: string,
	name: string,
	blurb: string,
	rarity: string, -- "Common" | "Rare" | "Epic" (claw odds come from LobbyConfig.Gacha.odds)
	kind: "passive" | "active",
	cooldown: number, -- active only: seconds between uses
	damage: number, -- HP per hit / tick
	push: number, -- speed change given to the enemy (mass-aware)
	lift: number, -- upward speed change given to the enemy
	radius: number, -- reach in studs (meaning depends on the weapon)
	duration: number, -- how long an effect lasts
	interval: number, -- time between ticks / pulses
	speed: number, -- projectile speed, or spin speed (rad/s)
	damageMult: number, -- passive ram bonus (Saw)
	maxActive: number, -- most bombs on the floor at once
	coneDeg: number, -- flame half-angle
	color: { number }, -- placeholder block color
}

local function make(
	id: string,
	name: string,
	blurb: string,
	rarity: string,
	kind: "passive" | "active",
	cooldown: number,
	extra: { [string]: any }
): WeaponDef
	return {
		id = id,
		name = name,
		blurb = blurb,
		rarity = rarity,
		kind = kind,
		cooldown = cooldown,
		damage = extra.damage or 0,
		push = extra.push or 0,
		lift = extra.lift or 0,
		radius = extra.radius or 0,
		duration = extra.duration or 0,
		interval = extra.interval or 0,
		speed = extra.speed or 0,
		damageMult = extra.damageMult or 1,
		maxActive = extra.maxActive or 0,
		coneDeg = extra.coneDeg or 0,
		color = extra.color or { 160, 160, 170 },
	}
end

local WeaponsConfig = {}

-- Order shown in the weapon menu.
WeaponsConfig.Order = { "Saw", "Axe", "Bomb", "Rocket", "Hammer", "Shock", "Magnet", "Flame" }

-- Every new player owns and wears this one.
WeaponsConfig.Starter = "Saw"

WeaponsConfig.Weapons = {
	Saw = make("Saw", "FRONT SAW", "Rams hit much harder.", "Common", "passive", 0, {
		damageMult = 1.35,
		color = { 200, 205, 215 },
	}),
	Axe = make("Axe", "SPIN AXE", "An axe spins round your car.", "Common", "passive", 0, {
		damage = 5,
		push = 16,
		radius = 7.5, -- orbit radius
		speed = 3.2, -- rad/s
		interval = 0.8, -- time before the axe can hit the same car again
		color = { 150, 110, 70 },
	}),
	Bomb = make("Bomb", "BOMB DROP", "Toss bombs ahead of you.", "Common", "active", 5, {
		damage = 24,
		push = 38,
		lift = 12,
		radius = 13, -- blast radius
		duration = 2.2, -- fuse
		maxActive = 3,
		color = { 60, 60, 70 },
	}),
	Rocket = make("Rocket", "ROCKET", "Shoots straight ahead.", "Rare", "active", 5, {
		damage = 20,
		push = 40,
		lift = 4,
		radius = 5, -- how close counts as a hit
		speed = 100,
		duration = 1.4, -- flight time
		color = { 230, 90, 60 },
	}),
	Hammer = make("Hammer", "HAMMER", "Smashes everything close.", "Rare", "active", 6, {
		damage = 18,
		push = 30,
		lift = 14,
		radius = 12,
		duration = 0.35, -- wind-up before the smash
		color = { 120, 120, 135 },
	}),
	Shock = make("Shock", "SHOCK RING", "Zaps cars that get close.", "Rare", "passive", 0, {
		damage = 8,
		push = 25,
		radius = 16,
		interval = 3.5,
		color = { 90, 200, 255 },
	}),
	Magnet = make("Magnet", "MAGNET", "Pulls the enemy to you.", "Epic", "active", 8, {
		damage = 5,
		push = 22, -- pull speed added per tick
		radius = 38,
		duration = 1.2,
		interval = 0.2,
		color = { 200, 60, 80 },
	}),
	Flame = make("Flame", "FLAME", "Burns cars behind you.", "Epic", "active", 7, {
		damage = 4, -- per tick
		radius = 24, -- reach
		duration = 2.5,
		interval = 0.25,
		coneDeg = 40,
		color = { 255, 140, 40 },
	}),
} :: { [string]: WeaponDef }

function WeaponsConfig.get(id: any): WeaponDef?
	if type(id) ~= "string" then
		return nil
	end
	return WeaponsConfig.Weapons[id]
end

return WeaponsConfig
