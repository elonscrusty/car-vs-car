--!strict
-- What you're saving up for (the polish pass: "after each race, show what you earned and what
-- it unlocks next"). Pure, so Lune can test it; Stars.server sends it, Stars.client shows it.
-- (Race pay is ServerRace.payFor.)

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local Tycoon = sibling("Tycoon")

local Rewards = {}

export type Save = {
	coins: number,
	stars: number,
	cars: { [string]: boolean },
	equipped: { [string]: string },
	plotLevel: number?, -- the garage level (tycoon)
}

-- The next thing to save up for: what it is, its name, its price in coins.
export type Goal = {
	kind: string, -- "car" | "level"
	name: string,
	mode: string?, -- a car's mode (drift / race)
	price: number, -- coins
	have: number, -- coins you have now
	ready: boolean, -- you can get it now
}

-- Every car coins can still buy, cheapest first (race cars first at the same price: the server
-- race is the main game).
function Rewards.coinGoals(s: Save): { Goal }
	local out: { Goal } = {}
	for _, mode in { "race", "drift" } do
		for _, c in CarCatalog.SHOP[mode] or {} do
			if c.price > 0 and not c.rare and not CarCatalog.owns(s :: any, c.id) then
				table.insert(out, {
					kind = "car",
					name = c.name,
					mode = c.mode,
					price = c.price,
					have = s.coins,
					ready = s.coins >= c.price,
				})
			end
		end
	end
	local order: { [Goal]: number } = {}
	for i, g in out do
		order[g] = i -- cars were added first, race cars first: keep that at the same price
	end
	table.sort(out, function(a, b)
		if a.price ~= b.price then
			return a.price < b.price
		end
		return order[a] < order[b]
	end)
	return out
end

-- The one goal to show: the next CAR; when coins can buy no more cars, the next garage level.
function Rewards.next(s: Save): Goal?
	local goals = Rewards.coinGoals(s)
	for _, g in goals do
		if g.kind == "car" then
			return g
		end
	end
	-- (tycoon) every shop car bought: a bigger garage next
	local cost = Tycoon.levelCost(s.plotLevel or 0)
	if cost then
		return {
			kind = "level",
			name = "Bigger garage",
			price = cost,
			have = s.coins,
			ready = s.coins >= cost,
		}
	end
	return nil
end

return Rewards
