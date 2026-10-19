--!strict
-- Car stats. ALL car numbers live here (the cars themselves are rows in CarCatalog: carter's 30-car pack).
-- hp: health. mass: weight (bigger = harder to push). maxSpeed: top speed (auto-pilot or human gas).
-- accel: how fast it speeds up. turnRate: max spin speed (radians/sec).
-- damageMult: damage multiplier when this car is the one hitting.
-- hitLift: extra upward kick given to the enemy on hit (Ramp flips things).
-- ai: auto-pilot style ("BackupCharge", "CircleDive", "Direct").
-- rarity / ability: Common..Legendary and the one ability the car has (see AbilitiesConfig).
-- model: name of the imported 3D model (nil = the plain box body).
-- The old blocky built-in cars are gone (carter: only the pack cars stay); see `Retired`.

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
CarConfig.Order = {} :: { string } -- filled from CarCatalog below

-- Rarity names, best last. Claw odds, store prices and ability strength all use these.
CarConfig.Rarities = { "Common", "Rare", "Epic", "Legendary" }

CarConfig.Cars = {} :: { [string]: CarStats }

-- The removed blocky cars -> the rarity they had. Old saves that still own one get coins back for
-- it (Inventory.migrate), so nobody loses value. Never reuse these ids.
CarConfig.Retired = {
	Heavy = "Common",
	Light = "Common",
	Tank = "Common",
	Ramp = "Rare",
	Drift = "Rare",
	Bulldozer = "Rare",
	Spike = "Epic",
	Rocket = "Epic",
} :: { [string]: string }

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
-- Spans roles and all 4 rarities. Sedan is the free starter (LobbyConfig.StarterCars).
--   Common: Sedan (balanced), Compact (fast, fragile), DuneBuggy (bouncy turner), BoxTruck (heavy)
--   Rare: Muscle (plow), Kart (grippy, tiny), DriftKing (slides)
--   Epic: SuperCar (fast), MonsterTruck (heavy smasher), Semi (huge hitter)
--   Legendary: Formula (speed demon), ArmoredTruck (steel wall)
CarConfig.useFullRoster = false
CarConfig.LaunchRoster = {
	"Sedan",
	"Compact",
	"DuneBuggy",
	"BoxTruck",
	"Muscle",
	"Kart",
	"DriftKing",
	"SuperCar",
	"MonsterTruck",
	"Semi",
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

-- Touch steering smoothing for small, twitchy cars (audit #52). The client helper eases its steer
-- value toward the stick with Steer.smooth(current, target, dt, rate), rate = steerSmoothRate(turnRate).
-- Cars at or below `fromTurnRate` are not smoothed (rate `offRate` = effectively instant); at or
-- above that the rate eases from `startRate` down to `minRate` at `fullTurnRate` (full stick travel takes 1/minRate seconds).
-- PLACEHOLDERS: phone-test with kids and tune.
CarConfig.SteerSmooth = {
	enabled = true,
	fromTurnRate = 3.6,
	fullTurnRate = 5.0,
	startRate = 12, -- rate just above fromTurnRate
	minRate = 4,
	offRate = 100,
}

-- Steer-input change allowed per second for a car with this turnRate (pure).
function CarConfig.steerSmoothRate(turnRate: number, cfg: any?): number
	local c = cfg or CarConfig.SteerSmooth
	if not c.enabled or turnRate ~= turnRate or turnRate <= c.fromTurnRate then
		return c.offRate
	end
	local t = math.clamp((turnRate - c.fromTurnRate) / (c.fullTurnRate - c.fromTurnRate), 0, 1)
	return c.startRate + (c.minRate - c.startRate) * t
end

-- Every car id that exists (valid in saves/remotes), in pick-menu order.
CarConfig.FullOrder = table.clone(CarConfig.Order)
do
	local live: { [string]: boolean } = {}
	for _, id in CarConfig.LaunchRoster do
		assert(CarConfig.Cars[id], "launch roster car missing: " .. id)
		live[id] = true
	end
	-- Order = the live cars, in launch roster order (Sedan the free starter first). Everything that
	-- lists cars (claw, store, picks, quests) uses it.
	local filtered: { string } = {}
	if CarConfig.useFullRoster then
		filtered = table.clone(CarConfig.FullOrder)
	else
		for _, id in CarConfig.LaunchRoster do
			table.insert(filtered, id)
		end
	end
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
