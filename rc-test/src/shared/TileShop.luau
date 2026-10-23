--!strict
-- Track tiles you can own for building your plot's track (carter's game shape v3). Ids match
-- TrackTiles.PIECES (the build helper's file): free tiles are everyone's, coin tiles are sold in
-- the shops, and legendary tiles (boost, oil spill, sharp turn) come from the tile spin with the
-- odds shown, or for lots of coins. A legendary tile hits every racer on that track, so races stay
-- fair. Looks and fun only: nothing here changes a car. Prices and odds are first guesses until
-- carter gives the real ones. Pure data + pure rules on a save, so Lune can test it.

local TileShop = {}

export type Tile = {
	id: string,
	name: string, -- what the screen calls it
	tier: string, -- "free" | "coins" | "legendary" (same as TrackTiles.PIECES[id].tier)
	price: number, -- coins to buy; 0 = free
	color: { number },
}

-- The bits of a save this needs (Profile.Data has them): tile id -> copies owned.
export type Save = {
	coins: number,
	tiles: { [string]: number },
}

local function tile(id: string, name: string, tier: string, price: number, color: { number }): Tile
	return { id = id, name = name, tier = tier, price = price, color = color }
end

-- Every tile, in screen order.
TileShop.TILES = {
	tile("start", "Start", "free", 0, { 240, 240, 240 }),
	tile("straight", "Straight", "free", 0, { 90, 90, 100 }),
	tile("turn", "Turn", "free", 0, { 90, 90, 100 }),
	tile("chicane", "Wiggle", "coins", 150, { 240, 170, 20 }),
	tile("cross", "Crossing", "coins", 300, { 40, 120, 230 }),
	tile("boost", "Boost Pad", "legendary", 500, { 60, 220, 255 }),
	tile("oil", "Oil Spill", "legendary", 500, { 30, 30, 40 }),
	tile("sharp", "Sharp Turn", "legendary", 500, { 230, 60, 50 }),
	-- more tiles (carter 22:36 "way more tiles. jump and cones and variety"); prices first guesses,
	-- cheap ones first so there is always a next tile in reach (the screen sorts by price)
	tile("split", "Split", "coins", 250, { 86, 150, 70 }),
	tile("narrow", "Squeeze", "coins", 200, { 200, 60, 50 }),
	tile("cones", "Cones", "coins", 50, { 224, 138, 58 }),
	tile("barrels", "Barrels", "coins", 150, { 200, 60, 50 }),
	tile("bumps", "Bumps", "coins", 75, { 245, 245, 245 }),
	tile("mud", "Mud", "coins", 125, { 110, 78, 46 }),
	tile("puddle", "Puddle", "coins", 100, { 70, 140, 210 }),
	tile("sand", "Sand", "coins", 100, { 222, 196, 130 }),
	tile("jump", "Jump", "legendary", 500, { 255, 200, 40 }),
} :: { Tile }

-- The tile spin: one legendary tile. `chance` is out of 100 and they add up to 100.
TileShop.SPIN_PRICE = 150
TileShop.SPIN = {
	{ id = "boost", chance = 40 },
	{ id = "sharp", chance = 25 },
	{ id = "oil", chance = 20 },
	{ id = "jump", chance = 15 },
}
-- A legendary you already have: half the spin back (while copies don't count, see LIMITED).
TileShop.DUPLICATE_REFUND = 75
-- false: one copy of a tile lets you place it as often as you like. true: each copy = one place
-- (2 boosts to put down 2 boost tiles), and a repeat spin gives a copy instead of coins.
TileShop.LIMITED = false
TileShop.MAX_COPIES = 99

local byId: { [string]: Tile } = {}
for _, t in TileShop.TILES do
	byId[t.id] = t
end

function TileShop.get(id: any): Tile?
	return if type(id) == "string" then byId[id] else nil
end

-- Free tiles are everyone's from the start.
function TileShop.owns(s: Save, id: any): boolean
	local t = TileShop.get(id)
	return t ~= nil and (t.tier == "free" or (s.tiles[t.id] or 0) > 0)
end

-- How many of this tile you may place on your track (math.huge = as many as you like).
function TileShop.count(s: Save, id: any): number
	local t = TileShop.get(id)
	if t == nil then
		return 0
	end
	if t.tier == "free" then
		return math.huge
	end
	local have = s.tiles[t.id] or 0
	if TileShop.LIMITED then
		return have
	end
	return if have > 0 then math.huge else 0
end

local function add(s: Save, id: string)
	s.tiles[id] = math.min((s.tiles[id] or 0) + 1, TileShop.MAX_COPIES)
end

-- Buy a tile for coins. Returns ok and why not ("unknown", "owned", "coins").
function TileShop.buy(s: Save, id: any): (boolean, string?)
	local t = TileShop.get(id)
	if t == nil or t.tier == "free" then
		return false, "unknown"
	end
	if TileShop.owns(s, t.id) and not TileShop.LIMITED then
		return false, "owned"
	end
	if s.coins < t.price then
		return false, "coins"
	end
	s.coins -= t.price
	add(s, t.id)
	return true, nil
end

-- Which legendary tile a roll of 0 <= r < 100 gives.
function TileShop.pick(r: number): Tile
	local sum = 0
	for _, g in TileShop.SPIN do
		sum += g.chance
		if r < sum then
			return byId[g.id]
		end
	end
	return byId[TileShop.SPIN[#TileShop.SPIN].id]
end

-- One tile spin with roll r (0 <= r < 100). Returns the tile (nil = not enough coins) and whether
-- it was new (a repeat gives DUPLICATE_REFUND back, or another copy when LIMITED).
function TileShop.spin(s: Save, r: number): (Tile?, boolean)
	if s.coins < TileShop.SPIN_PRICE then
		return nil, false
	end
	s.coins -= TileShop.SPIN_PRICE
	local t = TileShop.pick(r)
	local new = not TileShop.owns(s, t.id)
	if new or TileShop.LIMITED then
		add(s, t.id)
	else
		s.coins += TileShop.DUPLICATE_REFUND
	end
	return t, new
end

-- Tile ids you own that cost something (for the screen).
function TileShop.owned(s: Save): { string }
	local out = {}
	for _, t in TileShop.TILES do
		if t.tier ~= "free" and TileShop.owns(s, t.id) then
			table.insert(out, t.id)
		end
	end
	return out
end

return TileShop
