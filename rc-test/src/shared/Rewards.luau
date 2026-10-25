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
local TileShop = sibling("TileShop")
local TrackTiles = sibling("TrackTiles")

local Rewards = {}

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
	mode: string?, -- a car's mode (drift / race)
	price: number, -- coins (car, tile) or stars (grid)
	have: number, -- coins (car, tile) or stars (grid) you have now
	ready: boolean, -- you can get it now
}

-- Everything coins can still buy, cheapest first (cars before tiles at the same price, race
-- cars first: the server race is the main game).
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
	if not TrackTiles.ALL_FREE then
		for _, t in TileShop.TILES do
			-- only tiles your stars have opened (TileShop.UNLOCK_STARS)
			if
				t.tier == "coins"
				and not TileShop.owns(s :: any, t.id)
				and TileShop.open(s :: any, t.id)
			then
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

-- The one goal to show: the next CAR first (the loop is build, race, coins, cars: carter 01:01),
-- then the cheapest tile; when coins can buy nothing more, the next bigger track from stars.
function Rewards.next(s: Save): Goal?
	local goals = Rewards.coinGoals(s)
	for _, g in goals do
		if g.kind == "car" then
			return g
		end
	end
	if goals[1] then
		return goals[1]
	end
	return Rewards.gridGoal(s.stars)
end

-- What going from `before` to `after` stars opens, as short toasts ("NEW TILE: CONES!",
-- "BIGGER TRACK: 5x6!"), in the order they open.
function Rewards.opened(before: number, after: number): { string }
	local out: { { at: number, text: string } } = {}
	if after <= before then
		return {}
	end
	if not TrackTiles.ALL_FREE then
		for _, t in TileShop.TILES do
			local at = TileShop.unlockAt(t.id)
			if t.tier == "coins" and at > before and at <= after then
				table.insert(out, { at = at, text = `NEW TILE: {string.upper(t.name)}!` })
			end
		end
	end
	for _, sz in TrackTiles.SIZES do
		if sz.stars > before and sz.stars <= after then
			table.insert(out, { at = sz.stars, text = `BIGGER TRACK: {sz.cols}x{sz.rows}!` })
		end
	end
	local order: { [any]: number } = {}
	for i, o in out do
		order[o] = i
	end
	table.sort(out, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return order[a] < order[b]
	end)
	local texts = {}
	for _, o in out do
		table.insert(texts, o.text)
	end
	return texts
end

return Rewards
