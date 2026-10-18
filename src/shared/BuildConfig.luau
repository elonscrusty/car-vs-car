--!strict
-- Build-and-watch mode: every number for car parts lives here. Prices are PLACEHOLDERS.
-- A car has 3 part slots (wheels, engine, armor) on top of the body (one of your cars; the car brings its own
-- ability). Each slot has a few parts to pick and a level that you buy up with coins.
-- "mods" multiply the car's stats (1 = unchanged); hitLift is added.

export type Mods = {
	hp: number?,
	mass: number?,
	maxSpeed: number?,
	accel: number?,
	turnRate: number?,
	damageMult: number?,
	hitLift: number?,
}

export type PartDef = {
	id: string,
	name: string,
	blurb: string,
	cost: number, -- coins to buy (0 = you start with it)
	mods: Mods,
}

local BuildConfig = {}

BuildConfig.Slots = { "wheels", "engine", "armor" }
BuildConfig.SlotNames =
	{ wheels = "WHEELS", engine = "ENGINE", armor = "ARMOR" } :: { [string]: string }

BuildConfig.MaxLevel = 5
-- Coins to go from level n to n + 1 (index n).
BuildConfig.LevelCost = { 100, 200, 350, 550 }
-- What each level above 1 adds to the slot's stats (as a share of the base stat).
BuildConfig.LevelBonus = {
	wheels = { turnRate = 0.06, maxSpeed = 0.02 },
	engine = { accel = 0.08, maxSpeed = 0.03 },
	armor = { hp = 0.08, mass = 0.02 },
} :: { [string]: Mods }

BuildConfig.Order = {
	wheels = { "street", "racing", "grip" },
	engine = { "basic", "turbo", "power" },
	armor = { "none", "plates", "spikes", "ram" },
} :: { [string]: { string } }

BuildConfig.Starter =
	{ wheels = "street", engine = "basic", armor = "none" } :: { [string]: string }

-- Ids are unique across slots, so one owned-table can hold them all.
BuildConfig.Parts = {
	street = {
		id = "street",
		name = "STREET",
		blurb = "Normal wheels.",
		cost = 0,
		mods = {},
	},
	racing = {
		id = "racing",
		name = "RACING",
		blurb = "Faster. Turns wider.",
		cost = 250,
		mods = { maxSpeed = 1.15, turnRate = 0.92 },
	},
	grip = {
		id = "grip",
		name = "GRIP",
		blurb = "Turns sharp. A bit slower.",
		cost = 250,
		mods = { turnRate = 1.3, maxSpeed = 0.96 },
	},
	basic = {
		id = "basic",
		name = "BASIC",
		blurb = "Plain engine.",
		cost = 0,
		mods = {},
	},
	turbo = {
		id = "turbo",
		name = "TURBO",
		blurb = "Speeds up quick.",
		cost = 300,
		mods = { accel = 1.3, maxSpeed = 1.08 },
	},
	power = {
		id = "power",
		name = "POWER",
		blurb = "Hits harder.",
		cost = 300,
		mods = { accel = 1.1, damageMult = 1.15 },
	},
	none = {
		id = "none",
		name = "NONE",
		blurb = "No armor.",
		cost = 0,
		mods = {},
	},
	plates = {
		id = "plates",
		name = "PLATES",
		blurb = "More health. A bit heavier.",
		cost = 200,
		mods = { hp = 1.35, mass = 1.15, maxSpeed = 0.96 },
	},
	spikes = {
		id = "spikes",
		name = "SPIKES",
		blurb = "Ouch! Big damage.",
		cost = 300,
		mods = { damageMult = 1.3, hp = 1.05 },
	},
	ram = {
		id = "ram",
		name = "RAM",
		blurb = "Pops enemies up.",
		cost = 300,
		mods = { hitLift = 10, mass = 1.1 },
	},
} :: { [string]: PartDef }

-- Which slot a part belongs to (nil when it is not a part id).
function BuildConfig.slotOf(id: any): string?
	if type(id) ~= "string" then
		return nil
	end
	for _, slot in BuildConfig.Slots do
		for _, known in BuildConfig.Order[slot] do
			if known == id then
				return slot
			end
		end
	end
	return nil
end

function BuildConfig.isSlot(slot: any): boolean
	if type(slot) ~= "string" then
		return false
	end
	for _, s in BuildConfig.Slots do
		if s == slot then
			return true
		end
	end
	return false
end

return BuildConfig
