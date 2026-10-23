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
	mode: string, -- "race" | "drift" | "rock"
	price: number, -- coins in the shop; 0 = the free starter; rare cars aren't sold
	color: { number },
	style: string, -- Garage.toyCar style
	rare: boolean,
}

-- The bits of a save this needs (Profile.Data has them).
export type Save = {
	coins: number,
	cars: { [string]: boolean },
	equipped: { [string]: string },
}

CarCatalog.MODES = { "drift", "race", "rock" }

local function car(
	id: string,
	name: string,
	mode: string,
	price: number,
	color: { number },
	rare: boolean?
): Car
	return {
		id = id,
		name = name,
		mode = mode,
		price = price,
		color = color,
		style = mode,
		rare = rare == true,
	}
end

-- Shop cars, three per mode in shop order (starter, mid, top). Prices: a 2nd car in about ten
-- minutes of play, the top car a few sessions in.
CarCatalog.SHOP = {
	drift = {
		car("drift_kid", "Slide Kid", "drift", 0, { 245, 245, 250 }),
		car("drift_ghost", "Neon Ghost", "drift", 150, { 40, 200, 220 }),
		car("drift_fury", "Pink Fury", "drift", 400, { 255, 120, 190 }),
	},
	race = {
		car("race_bolt", "Bolt", "race", 0, { 246, 196, 40 }),
		car("race_dart", "Blue Dart", "race", 150, { 40, 110, 220 }),
		car("race_rocket", "Red Rocket", "race", 400, { 230, 60, 50 }),
	},
	rock = {
		car("rock_pup", "Mud Pup", "rock", 0, { 230, 120, 30 }),
		car("rock_bud", "Boulder Bud", "rock", 150, { 214, 48, 44 }),
		car("rock_blue", "Big Blue", "rock", 400, { 40, 110, 220 }),
	},
} :: { [string]: { Car } }

-- The gumball machine: one spin, one rare car. `chance` is out of 100 and they add up to 100.
CarCatalog.GUMBALL_PRICE = 100
CarCatalog.GUMBALL = {
	{ car = car("gb_lime", "Lime Zip", "drift", 0, { 150, 230, 40 }, true), chance = 35 },
	{ car = car("gb_sky", "Sky Hopper", "rock", 0, { 120, 200, 255 }, true), chance = 30 },
	{ car = car("gb_night", "Midnight", "race", 0, { 70, 40, 120 }, true), chance = 20 },
	{ car = car("gb_lava", "Lava Slide", "drift", 0, { 255, 80, 20 }, true), chance = 10 },
	{ car = car("gb_gold", "Gold Rush", "race", 0, { 255, 200, 30 }, true), chance = 5 },
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
