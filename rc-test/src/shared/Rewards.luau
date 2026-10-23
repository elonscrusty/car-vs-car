--!strict
-- What a race pays and what you're saving up for (the polish pass: "after each race, show what
-- you earned and what it unlocks next"). Pure, so Lune can test it; Stars.server pays and sends,
-- Stars.client shows it.
-- Server race: the top 3 get coins, the rest nothing (carter's loop: "loser gets nothing").

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local TileShop = sibling("TileShop")
local TrackTiles = sibling("TrackTiles")

local Rewards = {}

-- coins for 1st, 2nd, 3rd in the server race (times the weekend boost); first guesses
Rewards.PLACE_COINS = { 60, 35, 20 }

export type Save = {
	coins: number,
	stars: number,
	cars: { [string]: boolean },
	equipped: { [string]: string },
	tiles: { [string]: number },
}

-- The next thing to save up for: what it is, its name, its price (coins) or stars needed.
export type Goal = {
	kind: string, -- "car" | "tile" | "grid"
	name: string,
	mode: string?, -- a car's mode (drift / race / rock)
	price: number, -- coins (car, tile) or stars (grid)
	have: number, -- coins (car, tile) or stars (grid) you have now
	ready: boolean, -- you can get it now
}

function Rewards.placeCoins(place: number, boost: number?): number
	local c = Rewards.PLACE_COINS[place]
	if c == nil then
		return 0
	end
	return c * (boost or 1)
end

-- "1st", "2nd", "3rd", "4th" ...
function Rewards.placeName(place: number): string
	local last = place % 10
	local teen = place % 100 >= 11 and place % 100 <= 13
	local suffix = if teen
		then "th"
		elseif last == 1 then "st"
		elseif last == 2 then "nd"
		elseif last == 3 then "rd"
		else "th"
	return `{place}{suffix}`
end

-- Everything coins can still buy, cheapest first (cars before tiles at the same price, race
-- cars first: the server race is the main game).
function Rewards.coinGoals(s: Save): { Goal }
	local out: { Goal } = {}
	for _, mode in { "race", "drift", "rock" } do
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
	if not TrackTiles.ALL_FREE then
		for _, t in TileShop.TILES do
			if t.tier == "coins" and not TileShop.owns(s :: any, t.id) then
				table.insert(out, {
					kind = "tile",
					name = t.name,
					price = t.price,
					have = s.coins,
					ready = s.coins >= t.price,
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

-- The bigger track grid you get next from stars (nil when you have the biggest).
function Rewards.gridGoal(stars: number): Goal?
	local cols, rows = TrackTiles.sizeFor(stars)
	for _, sz in TrackTiles.SIZES do
		if sz.stars > stars and sz.cols * sz.rows > cols * rows then
			return {
				kind = "grid",
				name = `{sz.cols}x{sz.rows} track`,
				price = sz.stars,
				have = stars,
				ready = false,
			}
		end
	end
	return nil
end

-- The one goal to show: the cheapest thing coins can buy; when coins can buy nothing more, the
-- next bigger track from stars.
function Rewards.next(s: Save): Goal?
	local goals = Rewards.coinGoals(s)
	if goals[1] then
		return goals[1]
	end
	return Rewards.gridGoal(s.stars)
end

return Rewards
