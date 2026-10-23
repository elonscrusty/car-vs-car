--!strict
-- The "next unlock" goal shown in the lobby and after each race.
local H = require("./harness")
local Rewards = require("../src/shared/Rewards")
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
	eq(g.price, goals[1].price)
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
	for _, t in (require("../src/shared/TileShop") :: any).TILES do
		d.tiles[t.id] = 1
	end
	local after = Rewards.next(d :: any)
	if #TrackTiles.SIZES > 1 then
		eq((after :: Rewards.Goal).kind, "grid")
	end
end)

test("rewards: the grid goal is the next bigger size, nil at the biggest", function()
	local g = Rewards.gridGoal(0)
	local last = TrackTiles.SIZES[#TrackTiles.SIZES]
	if #TrackTiles.SIZES > 1 then
		truthy(g)
		truthy((g :: Rewards.Goal).price > 0)
	end
	eq(Rewards.gridGoal(last.stars), nil)
end)
