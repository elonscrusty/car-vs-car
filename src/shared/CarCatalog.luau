--!strict
-- The collectible cars from the 30-car pack. A car here is just DATA: id, name, model, rarity,
-- ability (+ a body color for the placeholder box). Add a car by adding one row to `Entries`.
-- Every catalog car gets the same neutral stats for now (carter: do not tune stats yet), so
-- tuning later means editing `Neutral` or giving a row its own `stats` override.
-- `model` is the FBX file name in vehicles/vehicle-pack-30.zip (without .fbx); the Studio side
-- finds the imported model by this name.

export type Entry = {
	id: string, -- saved in profiles: never rename
	name: string, -- shown in menus (caps)
	model: string, -- FBX name in the pack
	rarity: string, -- Common | Rare | Epic | Legendary
	ability: string, -- id from AbilitiesConfig
	rgb: { number },
	stats: { [string]: number }?, -- optional overrides of `Neutral` (hp, mass, maxSpeed, ...)
}

local CarCatalog = {}

-- Stats every catalog car starts with.
CarCatalog.Neutral = {
	size = { 5, 2.5, 8 },
	hp = 150,
	mass = 60,
	maxSpeed = 70,
	accel = 105,
	turnRate = 3.6,
	damageMult = 1,
	hitLift = 0,
}

local function e(
	id: string,
	name: string,
	model: string,
	rarity: string,
	ability: string,
	rgb: { number }
): Entry
	return { id = id, name = name, model = model, rarity = rarity, ability = ability, rgb = rgb }
end

-- Same order as the pack (01 to 30). Rarities and abilities are PLACEHOLDERS: carter picks later.
CarCatalog.Entries = {
	e("Compact", "COMPACT", "01_compact", "Common", "Dash", { 240, 120, 150 }),
	e("Sedan", "SEDAN", "02_sedan", "Common", "Shield", { 90, 150, 220 }),
	e("Coupe", "COUPE", "03_coupe", "Common", "Jump", { 235, 190, 60 }),
	e("Muscle", "MUSCLE", "04_muscle", "Rare", "Ram", { 200, 40, 40 }),
	e("SuperCar", "SUPER CAR", "05_super_car", "Epic", "Dash", { 250, 100, 30 }),
	e("Roadster", "ROADSTER", "06_roadster", "Rare", "Jump", { 60, 190, 160 }),
	e("LiftedPickup", "LIFTED PICKUP", "07_lifted_pickup", "Common", "Ram", { 120, 90, 60 }),
	e("MonsterTruck", "MONSTER TRUCK", "08_monster_truck", "Epic", "Slam", { 70, 170, 70 }),
	e("DuneBuggy", "DUNE BUGGY", "09_open_dune_buggy", "Common", "Jump", { 230, 170, 90 }),
	e("Rally", "RALLY", "10_rally", "Rare", "Dash", { 40, 90, 200 }),
	e("OffRoader", "OFF ROADER", "11_two_door_off_roader", "Common", "Jump", { 150, 140, 80 }),
	e("LongSUV", "LONG SUV", "12_long_suv", "Common", "Shield", { 70, 80, 100 }),
	e("Van", "VAN", "13_van", "Common", "Magnet", { 200, 200, 210 }),
	e("Camper", "CAMPER", "14_camper", "Common", "Shield", { 230, 220, 170 }),
	e("BoxTruck", "BOX TRUCK", "15_box_truck", "Common", "Slam", { 220, 220, 230 }),
	e("Semi", "SEMI", "16_semi", "Epic", "Ram", { 180, 30, 50 }),
	e("TowTruck", "TOW TRUCK", "17_tow_truck", "Rare", "Magnet", { 250, 200, 30 }),
	e("DumpTruck", "DUMP TRUCK", "18_dump_truck", "Rare", "Slam", { 240, 150, 30 }),
	e("Taxi", "TAXI", "19_taxi", "Common", "Dash", { 255, 215, 40 }),
	e("Police", "POLICE", "20_police", "Rare", "Shield", { 50, 80, 190 }),
	e("Ambulance", "AMBULANCE", "21_ambulance", "Rare", "Shield", { 245, 245, 245 }),
	e("FireTruck", "FIRE TRUCK", "22_fire_truck", "Epic", "Slam", { 220, 30, 30 }),
	e("SchoolBus", "SCHOOL BUS", "23_school_bus", "Rare", "Ram", { 250, 190, 20 }),
	e("IceCream", "ICE CREAM", "24_ice_cream", "Epic", "Magnet", { 255, 170, 200 }),
	e("HotRod", "HOT ROD", "25_exposed_engine_hot_rod", "Epic", "Dash", { 190, 40, 120 }),
	e("Kart", "RACING KART", "26_low_racing_kart", "Rare", "Jump", { 80, 220, 240 }),
	e("Formula", "FORMULA", "27_open_wheel_formula", "Legendary", "Dash", { 235, 60, 60 }),
	e(
		"ArmoredTruck",
		"ARMORED TRUCK",
		"28_wheeled_armored_truck",
		"Legendary",
		"Shield",
		{ 90, 110, 80 }
	),
	e("DriftKing", "DRIFT KING", "29_drift", "Rare", "Magnet", { 160, 80, 220 }),
	e("Future", "FUTURE", "30_future", "Legendary", "Slam", { 90, 230, 255 }),
}

-- The full stat table for one entry (same shape as a CarConfig car).
function CarCatalog.statsFor(entry: Entry): { [string]: any }
	local n = CarCatalog.Neutral
	local o = entry.stats or {}
	return {
		name = entry.name,
		blurb = entry.rarity .. " " .. entry.ability,
		rgb = entry.rgb,
		size = n.size,
		hp = o.hp or n.hp,
		mass = o.mass or n.mass,
		maxSpeed = o.maxSpeed or n.maxSpeed,
		accel = o.accel or n.accel,
		turnRate = o.turnRate or n.turnRate,
		damageMult = o.damageMult or n.damageMult,
		hitLift = o.hitLift or n.hitLift,
		ai = "Direct",
		rarity = entry.rarity,
		ability = entry.ability,
		model = entry.model,
	}
end

return CarCatalog
