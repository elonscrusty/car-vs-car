--!strict
-- Car VS Car crates (carter 10-26): the only way to get a new car. Each kind of crate has its
-- odds of a COMMON, RARE, EPIC or LEGEND car, always shown before you open one; the car is then
-- picked evenly from the cars of that kind. A car you already have is kept as a second one
-- (the garage holds duplicates). Coins only for now: no Robux until carter gives the prices.
-- Pure rules, so Lune can test them; TrainingServer opens the crates.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end
local CarCatalog = sibling("CarCatalog")
local Economy = sibling("Economy")

local Crates = {}

export type Kind = {
	id: string,
	label: string,
	price: number, -- coins; 0 = can't be bought (the free crate from your first race)
	robux: number?, -- nil until carter gives the prices
	odds: { [string]: number }, -- out of 100, by kind of car; they add up to 100
}

-- Cheapest first. Prices live in Economy.luau.
Crates.KINDS = {
	{
		id = "free",
		label = "FREE CRATE",
		price = 0,
		odds = { common = 75, rare = 22, epic = 3, legend = 0 },
	},
	{
		id = "basic",
		label = "SMALL CRATE",
		price = Economy.CRATE_PRICE.basic,
		odds = { common = 70, rare = 25, epic = 4.5, legend = 0.5 },
	},
	{
		id = "big",
		label = "BIG CRATE",
		price = Economy.CRATE_PRICE.big,
		odds = { common = 45, rare = 40, epic = 13, legend = 2 },
	},
	{
		id = "mega",
		label = "MEGA CRATE",
		price = Economy.CRATE_PRICE.mega,
		odds = { common = 0, rare = 55, epic = 37, legend = 8 },
	},
} :: { Kind }

-- crates you can buy in the shop (the free one only comes from your first race)
Crates.SHOP = { "basic", "big", "mega" }

local byId: { [string]: Kind } = {}
for _, k in Crates.KINDS do
	byId[k.id] = k
end

function Crates.get(kind: any): Kind?
	return if type(kind) == "string" then byId[kind] else nil
end

-- The chance of each kind of car, out of 100, for the crate screen (shown before you open).
function Crates.odds(kind: any): { [string]: number }
	local k = Crates.get(kind)
	local out: { [string]: number } = {}
	for _, r in CarCatalog.RARITY_ORDER do
		out[r] = if k then k.odds[r] or 0 else 0
	end
	return out
end

-- Coins for one crate (nil: not for sale).
function Crates.price(kind: any): number?
	local k = Crates.get(kind)
	return if k and k.price > 0 then k.price else nil
end

-- Every car a crate can give, by kind of car, sorted by id so a roll is the same every time.
-- (Every car in the catalog: the Car names thread's 24 cars join it there.)
export type Pool = { [string]: { string } }
function Crates.pool(): Pool
	local out: Pool = {}
	for _, r in CarCatalog.RARITY_ORDER do
		out[r] = {}
	end
	local seen: { [string]: boolean } = {}
	local function add(c: any)
		if c and not seen[c.id] and out[c.rarity] then
			seen[c.id] = true
			table.insert(out[c.rarity], c.id)
		end
	end
	for _, mode in CarCatalog.MODES do
		for _, c in CarCatalog.SHOP[mode] or {} do
			add(c)
		end
	end
	for _, g in CarCatalog.GUMBALL or {} do
		add(g.car)
	end
	for _, list in out do
		table.sort(list)
	end
	return out
end

export type Rng = { NextNumber: (any) -> number }

-- Opens one crate of `kind`: the car's id, and its kind (common, rare...). `rng` is a Random
-- (or anything with NextNumber). A kind of car with no cars in the pool falls back to the next
-- kind down, so a roll always gives a car. Nil only for an unknown crate or an empty pool.
function Crates.roll(kind: any, rng: Rng, pool: Pool?): (string?, string?)
	local k = Crates.get(kind)
	if not k then
		return nil, nil
	end
	local cars = pool or Crates.pool()
	local r = rng:NextNumber() * 100
	local pick = CarCatalog.RARITY_ORDER[1]
	local sum = 0
	for _, tier in CarCatalog.RARITY_ORDER do
		local chance = k.odds[tier] or 0
		if chance > 0 then
			pick = tier
			sum += chance
			if r < sum then
				break
			end
		end
	end
	local i = table.find(CarCatalog.RARITY_ORDER, pick) or 1
	for j = i, 1, -1 do
		local tier = CarCatalog.RARITY_ORDER[j]
		local list = cars[tier]
		if list and #list > 0 then
			local n = math.clamp(math.floor(rng:NextNumber() * #list) + 1, 1, #list)
			return list[n], tier
		end
	end
	return nil, nil
end

return Crates
