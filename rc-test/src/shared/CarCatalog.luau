--!strict
-- Every car you can own (carter's new loop): looks only, no stats, one car per mode. The three
-- shops in the spawn lobby sell a starter (free, everyone has it), a mid car and a top car per
-- mode for coins; the gumball machine gives a random rare car, with its odds shown on screen.
-- You drive your chosen car of each mode on that mode's plots, so a drift car never enters a
-- race. Pure data + pure rules on a save, so Lune can test it (the server does the rest).

local CarCatalog = {}

export type Car = {
	id: string,
	name: string, -- made up, no real brands
	mode: string, -- "race" | "drift"
	price: number, -- coins in the shop; 0 = the free starter; rare cars aren't sold
	color: { number },
	style: string, -- Garage.toyCar style
	rare: boolean, -- gumball only (never sold in the shop)
	rarity: string, -- "common" | "rare" | "epic" | "legend" (CarCatalog.RARITY)
	source: string, -- where you get it: "shop" (coins) | "gumball" (spin)
}

-- The bits of a save this needs (Profile.Data has them).
export type Save = {
	coins: number,
	cars: { [string]: boolean },
	equipped: { [string]: string },
}

CarCatalog.MODES = { "drift", "race" }

-- The four kinds of car (carter's tycoon plan, 10-26): a glow shows which (CarGlow), and the
-- rarer a car the more coins it makes parked on your plot. `perMin` is that rate, for the
-- plot income to read from here.
export type Rarity = { id: string, label: string, color: { number }, perMin: number }
CarCatalog.RARITY = {
	common = { id = "common", label = "COMMON", color = { 200, 200, 210 }, perMin = 2 },
	rare = { id = "rare", label = "RARE", color = { 61, 155, 255 }, perMin = 6 },
	epic = { id = "epic", label = "EPIC", color = { 170, 80, 255 }, perMin = 15 },
	legend = { id = "legend", label = "LEGEND", color = { 255, 199, 44 }, perMin = 40 },
} :: { [string]: Rarity }
CarCatalog.RARITY_ORDER = { "common", "rare", "epic", "legend" }

-- Each car's own toy kart look (ToyCars: "shape/accent", "/glow" = underglow, rare and up): its shape, and an
-- accent for stripes, wings and bumpers. No two cars the same; carter's models replace these
-- through ReplicatedStorage.CarSkins.
CarCatalog.LOOKS = {
	race_bolt = "buggy/navy",
	race_dart = "formula/white",
	race_rocket = "muscle/white",
	race_lime = "truck/yellow",
	race_berry = "rally/yellow/glow",
	race_storm = "crawler/yellow/glow",
	race_tiger = "wedge/navy/glow",
	race_comet = "jet/sky/glow",
	gb_bubble = "bubble/white/glow",
	gb_night = "wedge/sky/glow",
	gb_glow = "buggy/pink/glow",
	gb_gold = "formula/red/glow",
	drift_kid = "coupe/red",
	drift_ghost = "hatch/navy",
	drift_fury = "wedge/white",
	drift_mint = "rally/navy",
	drift_cocoa = "muscle/yellow/glow",
	drift_shadow = "coupe/orange/glow",
	drift_aqua = "hatch/yellow/glow",
	drift_sunset = "coupe/purple/glow",
	gb_lime = "bubble/navy/glow",
	gb_candy = "hatch/white/glow",
	gb_lava = "crawler/navy/glow",
	gb_toxic = "truck/purple/glow",
} :: { [string]: string }

local function car(
	id: string,
	name: string,
	mode: string,
	price: number,
	color: { number },
	rarity: string,
	rare: boolean?
): Car
	return {
		id = id,
		name = name,
		mode = mode,
		price = price,
		color = color,
		style = CarCatalog.LOOKS[id] or mode,
		rare = rare == true,
		rarity = rarity,
		source = if rare == true then "gumball" else "shop",
	}
end

-- Shop cars per mode, cheapest first. Saves keep car ids (never shop places), so the order can
-- change. Prices (carter 23:43: cars are the main reward; a race pays 30 to 100 coins): the next
-- car is 2 to 4 races away early on, the last ones are long goals.
-- Rock crawlers were dropped (carter 23:42): their ids stay in old saves, so they can come back.
CarCatalog.SHOP = {
	drift = {
		car("drift_kid", "Slide Kid", "drift", 0, { 245, 245, 250 }, "common"),
		car("drift_ghost", "Neon Ghost", "drift", 120, { 0, 200, 200 }, "common"),
		car("drift_fury", "Pink Fury", "drift", 250, { 255, 111, 181 }, "common"),
		car("drift_mint", "Mint Swirl", "drift", 400, { 45, 190, 78 }, "common"),
		car("drift_cocoa", "Choco Slide", "drift", 600, { 255, 140, 30 }, "rare"),
		car("drift_shadow", "Night Fox", "drift", 850, { 27, 27, 47 }, "rare"),
		car("drift_aqua", "Aqua Glide", "drift", 1150, { 61, 155, 255 }, "epic"),
		car("drift_sunset", "Sunset", "drift", 1500, { 255, 140, 30 }, "epic"),
	},
	race = {
		car("race_bolt", "Bolt", "race", 0, { 255, 199, 44 }, "common"),
		car("race_dart", "Blue Dart", "race", 120, { 30, 111, 217 }, "common"),
		car("race_rocket", "Red Rocket", "race", 250, { 232, 53, 46 }, "common"),
		car("race_lime", "Lime Flash", "race", 400, { 45, 190, 78 }, "common"),
		car("race_berry", "Berry Blast", "race", 600, { 255, 111, 181 }, "rare"),
		car("race_storm", "Thunder Pup", "race", 850, { 61, 155, 255 }, "rare"),
		car("race_tiger", "Tiger", "race", 1150, { 255, 140, 30 }, "epic"),
		car("race_comet", "Comet Cat", "race", 1500, { 245, 245, 250 }, "epic"),
	},
} :: { [string]: { Car } }

-- The gumball machine: one spin, one rare car. `chance` is out of 100 and they add up to 100.
CarCatalog.GUMBALL_PRICE = 100
CarCatalog.GUMBALL = {
	{ car = car("gb_lime", "Lime Zip", "drift", 0, { 160, 230, 40 }, "rare", true), chance = 22 },
	{
		car = car("gb_bubble", "Bubblegum", "race", 0, { 255, 111, 181 }, "rare", true),
		chance = 18,
	},
	{
		car = car("gb_candy", "Cotton Candy", "drift", 0, { 150, 80, 255 }, "rare", true),
		chance = 16,
	},
	{ car = car("gb_night", "Midnight", "race", 0, { 150, 80, 255 }, "epic", true), chance = 12 },
	{ car = car("gb_glow", "Glow Worm", "race", 0, { 160, 230, 40 }, "rare", true), chance = 10 },
	{ car = car("gb_lava", "Lava Slide", "drift", 0, { 232, 53, 46 }, "legend", true), chance = 9 },
	{
		car = car("gb_toxic", "Slime Time", "drift", 0, { 45, 190, 78 }, "legend", true),
		chance = 8,
	},
	{ car = car("gb_gold", "Gold Rush", "race", 0, { 255, 199, 44 }, "legend", true), chance = 5 },
}
-- A car you already have: half the spin back, so a spin is never wasted.
CarCatalog.DUPLICATE_REFUND = 50

local byId: { [string]: Car } = {}
for _, list in CarCatalog.SHOP do
	for _, c in list do
		byId[c.id] = c
	end
end
for _, g in CarCatalog.GUMBALL do
	byId[g.car.id] = g.car
end

function CarCatalog.get(id: any): Car?
	return if type(id) == "string" then byId[id] else nil
end

-- Every race car's id (shop then gumball, in list order): the race bots wear these, so a
-- big race looks like a row of real cars (playtest u01).
function CarCatalog.raceIds(): { string }
	local out: { string } = {}
	for _, c in CarCatalog.SHOP.race or {} do
		table.insert(out, c.id)
	end
	for _, g in CarCatalog.GUMBALL do
		if g.car.mode == "race" then
			table.insert(out, g.car.id)
		end
	end
	return out
end

function CarCatalog.rarity(id: any): Rarity
	local c = CarCatalog.get(id)
	return CarCatalog.RARITY[if c then c.rarity else "common"] or CarCatalog.RARITY.common
end

-- The gumball's chance of each kind, out of 100 (shown on the gumball screen).
function CarCatalog.tierOdds(): { [string]: number }
	local out: { [string]: number } = {}
	for _, g in CarCatalog.GUMBALL do
		out[g.car.rarity] = (out[g.car.rarity] or 0) + g.chance
	end
	return out
end

function CarCatalog.starter(mode: string): Car
	return CarCatalog.SHOP[mode][1]
end

-- Starters are everyone's from the start.
function CarCatalog.owns(s: Save, id: string): boolean
	local c = byId[id]
	return c ~= nil and (c.price == 0 and not c.rare or s.cars[id] == true)
end

-- The car you drive in `mode`: your pick if you still own it, else the starter.
function CarCatalog.equipped(s: Save, mode: string): Car
	local id = s.equipped[mode]
	local c = if id then byId[id] else nil
	if c and c.mode == mode and CarCatalog.owns(s, c.id) then
		return c
	end
	return CarCatalog.starter(mode)
end

-- Buy a shop car. Returns ok and why not ("unknown", "owned", "coins").
function CarCatalog.buy(s: Save, id: any): (boolean, string?)
	local c = CarCatalog.get(id)
	if c == nil or c.rare then
		return false, "unknown"
	end
	if CarCatalog.owns(s, c.id) then
		return false, "owned"
	end
	if s.coins < c.price then
		return false, "coins"
	end
	s.coins -= c.price
	s.cars[c.id] = true
	return true, nil
end

function CarCatalog.equip(s: Save, id: any): boolean
	local c = CarCatalog.get(id)
	if c == nil or not CarCatalog.owns(s, c.id) then
		return false
	end
	s.equipped[c.mode] = c.id
	return true
end

-- Which gumball car a roll of 0 <= r < 100 gives.
function CarCatalog.pick(r: number): Car
	local sum = 0
	for _, g in CarCatalog.GUMBALL do
		sum += g.chance
		if r < sum then
			return g.car
		end
	end
	return CarCatalog.GUMBALL[#CarCatalog.GUMBALL].car
end

-- One gumball spin with roll r (0 <= r < 100). Returns the car (nil = not enough coins) and
-- whether it was new (a repeat gives DUPLICATE_REFUND back).
function CarCatalog.spin(s: Save, r: number): (Car?, boolean)
	if s.coins < CarCatalog.GUMBALL_PRICE then
		return nil, false
	end
	s.coins -= CarCatalog.GUMBALL_PRICE
	local c = CarCatalog.pick(r)
	if s.cars[c.id] then
		s.coins += CarCatalog.DUPLICATE_REFUND
		return c, false
	end
	s.cars[c.id] = true
	return c, true
end

return CarCatalog
