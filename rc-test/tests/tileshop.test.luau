--!strict
-- Track tiles (TileShop.luau): free tiles are yours, coin tiles cost coins once, legendary tiles
-- come from the spin with fair odds (or lots of coins), repeats refund, and the save keeps them.
local H = require("./harness")
local Tiles = require("../src/shared/TileShop")
local Profile = require("../src/shared/Profile")
local TrackTiles = require("../src/shared/TrackTiles")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Tile shop")

test("the agreed tile ids, each with its tier", function()
	local want = {
		start = "free",
		straight = "free",
		turn = "free",
		chicane = "coins",
		cross = "coins",
		boost = "legendary",
		oil = "legendary",
		sharp = "legendary",
		split = "coins",
		narrow = "coins",
		cones = "coins",
		barrels = "coins",
		bumps = "coins",
		mud = "coins",
		puddle = "coins",
		sand = "coins",
		jump = "legendary",
	}
	local n = 0
	for _, t in Tiles.TILES do
		n += 1
		eq(t.tier, want[t.id])
		eq(t.price == 0, t.tier == "free")
	end
	eq(n, 17)
end)

test("same ids and tiers as the build pieces (TrackTiles)", function()
	for _, p in TrackTiles.PIECES do
		eq((Tiles.get(p.id) :: Tiles.Tile).tier, p.tier)
	end
	eq(#TrackTiles.PIECES, #Tiles.TILES)
end)

test("free tiles are everyone's and unlimited; others start at none", function()
	local d = Profile.new()
	for _, id in { "start", "straight", "turn" } do
		eq(Tiles.owns(d, id), true)
		eq(Tiles.count(d, id), math.huge)
	end
	for _, id in { "chicane", "cross", "boost", "oil", "sharp", "nope" } do
		eq(Tiles.owns(d, id), false)
		eq(Tiles.count(d, id), 0)
	end
	eq(Tiles.owns(d, 5 :: any), false)
end)

test("buying takes the coins once; then you can place it as often as you like", function()
	local d = Profile.new()
	local wiggle = Tiles.get("chicane") :: Tiles.Tile
	eq(select(2, Tiles.buy(d, "chicane")), "coins")
	d.coins = wiggle.price + 5
	eq(Tiles.buy(d, "chicane"), true)
	eq(d.coins, 5)
	eq(Tiles.count(d, "chicane"), math.huge)
	eq(select(2, Tiles.buy(d, "chicane")), "owned")
	eq(select(2, Tiles.buy(d, "straight")), "unknown")
	eq(select(2, Tiles.buy(d, "nope")), "unknown")
	eq(d.coins, 5)
end)

test("legendary tiles cost more than coin tiles", function()
	for _, t in Tiles.TILES do
		if t.tier == "legendary" then
			truthy(t.price > (Tiles.get("cross") :: Tiles.Tile).price)
		end
	end
end)

test("spin odds add up to 100, only legendary tiles, rarer ones are rarer", function()
	local sum, last = 0, math.huge
	for _, g in Tiles.SPIN do
		eq((Tiles.get(g.id) :: Tiles.Tile).tier, "legendary")
		truthy(g.chance > 0 and g.chance <= last)
		last = g.chance
		sum += g.chance
	end
	eq(sum, 100)
	eq(Tiles.pick(0).id, Tiles.SPIN[1].id)
	eq(Tiles.pick(99.99).id, Tiles.SPIN[#Tiles.SPIN].id)
	-- each tile's share of 10000 even rolls matches its chance
	local got: { [string]: number } = {}
	for i = 0, 9999 do
		local id = Tiles.pick(i / 100).id
		got[id] = (got[id] or 0) + 1
	end
	for _, g in Tiles.SPIN do
		eq(got[g.id], g.chance * 100)
	end
end)

test("a spin costs coins, a new tile is yours, a repeat gives coins back", function()
	local d = Profile.new()
	eq((Tiles.spin(d, 0)), nil)
	d.coins = Tiles.SPIN_PRICE * 2
	local t, new = Tiles.spin(d, 0)
	eq((t :: Tiles.Tile).id, Tiles.SPIN[1].id)
	eq(new, true)
	eq(d.coins, Tiles.SPIN_PRICE)
	eq(Tiles.owns(d, Tiles.SPIN[1].id), true)
	local _, again = Tiles.spin(d, 0)
	eq(again, false)
	eq(d.coins, Tiles.DUPLICATE_REFUND)
	eq(d.tiles[Tiles.SPIN[1].id], 1)
end)

test("LIMITED: each copy is one place, a repeat spin gives a copy", function()
	Tiles.LIMITED = true
	local d = Profile.new()
	d.coins = Tiles.SPIN_PRICE * 2
	Tiles.spin(d, 0)
	Tiles.spin(d, 0)
	eq(Tiles.count(d, Tiles.SPIN[1].id), 2)
	eq(d.coins, 0)
	eq(Tiles.count(d, "straight"), math.huge)
	Tiles.LIMITED = false
end)

test("the save keeps tiles and throws out junk", function()
	local d = Profile.new()
	d.tiles.boost = 2
	local back = Profile.migrate(d)
	eq(back.tiles.boost, 2)
	local junk = Profile.migrate({
		tiles = { oil = true, sharp = 0, cross = "yes", [string.rep("x", 50)] = 1, chicane = 1e9 },
	})
	eq(junk.tiles.oil, 1)
	eq(junk.tiles.sharp, nil)
	eq(junk.tiles.cross, nil)
	eq(junk.tiles.chicane, 99)
	eq(Profile.migrate(nil).tiles.boost, nil)
end)

test("owned lists bought tiles only", function()
	local d = Profile.new()
	d.tiles.cross = 1
	local list = Tiles.owned(d)
	eq(#list, 1)
	eq(list[1], "cross")
end)
