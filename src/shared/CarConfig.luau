--!strict
-- The 8 placeholder cars. ALL car numbers live here.
-- hp: health. mass: weight (bigger = harder to push). maxSpeed: top speed (auto-pilot or human gas).
-- accel: how fast it speeds up. turnRate: max spin speed (radians/sec).
-- damageMult: damage multiplier when this car is the one hitting.
-- hitLift: extra upward kick given to the enemy on hit (Ramp flips things).
-- ai: auto-pilot style ("BackupCharge", "CircleDive", "Direct").
-- rarity / ability: Common..Legendary and the one ability the car has (see AbilitiesConfig).
-- model: name of the imported 3D model (nil = the plain box body).
-- The 8 placeholder cars are written out below; the 30 pack cars come from CarCatalog.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local CarTraits = sibling("CarTraits")
local CarTraitsConfig = sibling("CarTraitsConfig")

export type AiStyle = "BackupCharge" | "CircleDive" | "Direct"

export type CarStats = {
	name: string,
	blurb: string,
	rgb: { number }, -- {r, g, b} 0-255
	size: { number }, -- {x, y, z} in studs. Car faces -Z.
	hp: number,
	mass: number,
	maxSpeed: number,
	accel: number,
	turnRate: number,
	damageMult: number,
	hitLift: number,
	ai: AiStyle,
	rarity: string,
	ability: string,
	model: string?,
	traits: CarTraits.Traits?, -- handling: grip, drift, accel curve, high-speed turn, size scale
}

local CarConfig = {}

-- Order shown in the pick menu.
CarConfig.Order = { "Heavy", "Light", "Ramp", "Spike", "Tank", "Drift", "Bulldozer", "Rocket" }

-- Rarity names, best last. Claw odds, store prices and ability strength all use these.
CarConfig.Rarities = { "Common", "Rare", "Epic", "Legendary" }

CarConfig.Cars = {
	Heavy = {
		name = "HEAVY",
		blurb = "Tank. Slow. Charges.",
		rgb = { 220, 50, 50 },
		size = { 7, 3, 11 },
		hp = 220,
		mass = 120,
		maxSpeed = 72,
		accel = 125,
		turnRate = 2.2,
		damageMult = 1.3,
		hitLift = 0,
		ai = "BackupCharge",
		rarity = "Common",
		ability = "Slam",
	},
	Light = {
		name = "LIGHT",
		blurb = "Fast. Fragile. Sneaky.",
		rgb = { 250, 210, 40 },
		size = { 4, 2, 6 },
		hp = 125,
		mass = 25,
		maxSpeed = 95,
		accel = 150,
		turnRate = 4.5,
		damageMult = 0.9,
		hitLift = 0,
		ai = "CircleDive",
		rarity = "Common",
		ability = "Dash",
	},
	Ramp = {
		name = "RAMP",
		blurb = "Flips the enemy.",
		rgb = { 60, 120, 240 },
		size = { 5, 2.2, 8 },
		hp = 150,
		mass = 55,
		maxSpeed = 68,
		accel = 100,
		turnRate = 3.8,
		damageMult = 0.8,
		hitLift = 22,
		ai = "Direct",
		rarity = "Rare",
		ability = "Jump",
	},
	Spike = {
		name = "SPIKE",
		blurb = "Ouch. Big damage.",
		rgb = { 150, 70, 220 },
		size = { 5, 2.5, 8 },
		hp = 150,
		mass = 60,
		maxSpeed = 68,
		accel = 100,
		turnRate = 3.8,
		damageMult = 1.45,
		hitLift = 0,
		ai = "Direct",
		rarity = "Epic",
		ability = "Ram",
	},
	Tank = {
		name = "TANK",
		blurb = "Huge. Barely moves.",
		rgb = { 90, 110, 70 },
		size = { 8, 3.2, 12 },
		hp = 210,
		mass = 160,
		maxSpeed = 60,
		accel = 95,
		turnRate = 1.8,
		damageMult = 1.25,
		hitLift = 0,
		ai = "BackupCharge",
		rarity = "Common",
		ability = "Shield",
	},
	Drift = {
		name = "DRIFT",
		blurb = "Slides around you.",
		rgb = { 40, 200, 190 },
		size = { 4.5, 2, 7 },
		hp = 130,
		mass = 35,
		maxSpeed = 85,
		accel = 130,
		turnRate = 5.5,
		damageMult = 0.9,
		hitLift = 0,
		ai = "CircleDive",
		rarity = "Rare",
		ability = "Dash",
	},
	Bulldozer = {
		name = "BULLDOZER",
		blurb = "Plows through. Hits hard.",
		rgb = { 240, 140, 30 },
		size = { 7.5, 3, 10 },
		hp = 190,
		mass = 110,
		maxSpeed = 68,
		accel = 110,
		turnRate = 2.4,
		damageMult = 1.25,
		hitLift = 0,
		ai = "Direct",
		rarity = "Rare",
		ability = "Ram",
	},
	Rocket = {
		name = "ROCKET",
		blurb = "Fastest. Breaks easy.",
		rgb = { 245, 245, 250 },
		size = { 3.5, 2, 7.5 },
		hp = 80,
		mass = 20,
		maxSpeed = 110,
		accel = 170,
		turnRate = 4.0,
		damageMult = 1.0,
		hitLift = 0,
		ai = "Direct",
		rarity = "Epic",
		ability = "Dash",
	},
} :: { [string]: CarStats }

for _, entry in CarCatalog.Entries do
	assert(CarConfig.Cars[entry.id] == nil, "duplicate car id " .. entry.id)
	CarConfig.Cars[entry.id] = CarCatalog.statsFor(entry) :: any
	table.insert(CarConfig.Order, entry.id)
end

-- Handling traits for every car (CarTraitsConfig rows; a car without a row drives as before).
for id, car in CarConfig.Cars do
	car.traits = CarTraits.resolve(CarTraitsConfig.Cars[id], car.size)
end

-- LAUNCH ROSTER: only these ~12 cars are live (claw prizes, store, pick choices, quests, bots,
-- odds). The rest stay in the code and in saves, but hidden, unless `useFullRoster` is true.
-- Spans roles and all 4 rarities. Compact is the free starter (LobbyConfig.StarterCars).
--   Common: Compact, Sedan, Coupe, DuneBuggy
--   Rare: Muscle, Roadster, Rally
--   Epic: SuperCar, MonsterTruck, HotRod
--   Legendary: Formula, ArmoredTruck
CarConfig.useFullRoster = false
CarConfig.LaunchRoster = {
	"Compact",
	"Sedan",
	"Coupe",
	"DuneBuggy",
	"Muscle",
	"Roadster",
	"Rally",
	"SuperCar",
	"MonsterTruck",
	"HotRod",
	"Formula",
	"ArmoredTruck",
}

-- Power score weights (simple sum, see CarPower). PLACEHOLDERS.
CarConfig.PowerWeights = {
	hp = 1,
	mass = 0.5,
	maxSpeed = 1.5,
	accel = 0.3,
	turnRate = 12,
	damageMult = 100,
	-- Handling traits (CarTraits): good grip, a strong launch and a sharp high-speed turn are
	-- worth a little. Only counted when a stats table has traits.
	grip = 25,
	punch = 20,
	highTurn = 20,
}
-- Max a car's power may be above the average of its rarity tier (0.2 = 20%); checked by tests.
CarConfig.PowerTolerance = 0.2

-- Every car id that exists (valid in saves/remotes), in pick-menu order.
CarConfig.FullOrder = table.clone(CarConfig.Order)
do
	local live: { [string]: boolean } = {}
	for _, id in CarConfig.LaunchRoster do
		assert(CarConfig.Cars[id], "launch roster car missing: " .. id)
		live[id] = true
	end
	local filtered: { string } = {}
	for _, id in CarConfig.FullOrder do
		if CarConfig.useFullRoster or live[id] then
			table.insert(filtered, id)
		end
	end
	-- Order = the live cars. Everything that lists cars (claw, store, picks, quests) uses it.
	CarConfig.Order = filtered
end

-- True when the id is a live (launch roster) car.
function CarConfig.isLive(id: any): boolean
	return type(id) == "string" and table.find(CarConfig.Order, id) ~= nil
end

-- Returns the stats for an id, or nil if the id is not a real car.
-- Takes `any` because the id can come from a client.
function CarConfig.get(id: any): CarStats?
	if type(id) ~= "string" then
		return nil
	end
	for _, known in CarConfig.FullOrder do
		if known == id then
			return CarConfig.Cars[id]
		end
	end
	return nil
end

return CarConfig
