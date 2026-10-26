--!strict
-- The "next unlock" goal shown in the lobby and after each race.
local H = require("./harness")
local Rewards = require("../src/shared/Rewards")
local Tycoon = require("../src/shared/Tycoon")
local Profile = require("../src/shared/Profile")
local TrackTiles = require("../src/shared/TrackTiles")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Rewards")

test("rewards: next goal is the cheapest thing you don't have, cheapest first", function()
	local d = Profile.new()
	local goals = Rewards.coinGoals(d :: any)
	truthy(#goals > 0)
	for i = 2, #goals do
		truthy(goals[i - 1].price <= goals[i].price)
	end
	local g = Rewards.next(d :: any) :: Rewards.Goal
	-- a car first, the cheapest one
	eq(g.kind, "car")
	for _, x in goals do
		if x.kind == "car" then
			eq(g.price, x.price)
			break
		end
	end
	eq(g.ready, false)
	eq(g.have, 0)
	d.coins = g.price
	eq((Rewards.next(d :: any) :: Rewards.Goal).ready, true)
	-- the race cars come before the other cars at the same price
	local firstCar: Rewards.Goal? = nil
	for _, x in goals do
		if x.kind == "car" then
			firstCar = x
			break
		end
	end
	eq((firstCar :: Rewards.Goal).mode, "race")
	-- own every shop car and tile: the next goal is the bigger grid (or nothing)
	for _, list in (require("../src/shared/CarCatalog") :: any).SHOP do
		for _, c in list do
			d.cars[c.id] = true
		end
	end
	-- every car owned: tiles come next
	local tileNext = Rewards.next(d :: any)
	if tileNext and not TrackTiles.ALL_FREE and #Rewards.coinGoals(d :: any) > 0 then
		eq((tileNext :: Rewards.Goal).kind, "tile")
	end
	for _, t in (require("../src/shared/TileShop") :: any).TILES do
		d.tiles[t.id] = 1
	end
	-- (tycoon) every shop car owned: a bigger garage next, nothing at the top level
	local after = Rewards.next(d :: any)
	eq((after :: Rewards.Goal).kind, "level")
	d.plotLevel = Tycoon.MAX_LEVEL
	eq(Rewards.next(d :: any), nil)
end)

test("rewards: no track grid goal while tile building is off", function()
	eq(Rewards.gridGoal(0), nil)
end)

test("rewards: stars that open a tile or a bigger track say so, in order", function()
	local TileShop = require("../src/shared/TileShop")
	eq(#Rewards.opened(5, 5), 0)
	eq(#Rewards.opened(5, 4), 0)
	local bumps = Rewards.opened(0, TileShop.UNLOCK_STARS.bumps)
	eq(#bumps, 1)
	eq(bumps[1], "NEW TILE: BUMPS!")
	local grid = TrackTiles.SIZES[2]
	local at10 = Rewards.opened(grid.stars - 1, grid.stars)
	truthy(table.find(at10, `BIGGER TRACK: {grid.cols}x{grid.rows}!`) ~= nil)
	-- every coin tile with a star gate opens once on the way up
	local seen: { [string]: boolean } = {}
	for s = 1, 100 do
		for _, text in Rewards.opened(s - 1, s) do
			truthy(not seen[text], text)
			seen[text] = true
		end
	end
	for _, t in TileShop.TILES do
		if t.tier == "coins" and TileShop.unlockAt(t.id) > 0 then
			truthy(seen[`NEW TILE: {string.upper(t.name)}!`], t.id)
		end
	end
	-- a big jump lists them cheapest gate first
	local all = Rewards.opened(0, 100)
	eq(all[1], "NEW TILE: BUMPS!")
end)
