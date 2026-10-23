--!strict
-- What a server race pays, and the "next unlock" goal shown after it.
local H = require("./harness")
local Rewards = require("../src/shared/Rewards")
local Profile = require("../src/shared/Profile")
local TrackTiles = require("../src/shared/TrackTiles")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Rewards")

test("rewards: top 3 get coins, the rest nothing, weekends double", function()
	eq(Rewards.placeCoins(1), Rewards.PLACE_COINS[1])
	eq(Rewards.placeCoins(3), Rewards.PLACE_COINS[3])
	eq(Rewards.placeCoins(4), 0)
	eq(Rewards.placeCoins(1, 2), Rewards.PLACE_COINS[1] * 2)
	truthy(Rewards.PLACE_COINS[1] > Rewards.PLACE_COINS[2])
	truthy(Rewards.PLACE_COINS[2] > Rewards.PLACE_COINS[3])
	eq(Rewards.placeName(1), "1st")
	eq(Rewards.placeName(2), "2nd")
	eq(Rewards.placeName(3), "3rd")
	eq(Rewards.placeName(4), "4th")
	eq(Rewards.placeName(11), "11th")
	eq(Rewards.placeName(22), "22nd")
end)

test("rewards: next goal is the cheapest car you don't have, race cars first", function()
	local d = Profile.new()
	local g = Rewards.next(d :: any)
	truthy(g)
	local goal = g :: Rewards.Goal
	eq(goal.kind, "car")
	eq(goal.mode, "race")
	eq(goal.ready, false)
	eq(goal.have, 0)
	d.coins = goal.price
	eq((Rewards.next(d :: any) :: Rewards.Goal).ready, true)
	-- own every shop car: the next goal is tiles (if they cost) or the bigger grid
	for _, list in (require("../src/shared/CarCatalog") :: any).SHOP do
		for _, c in list do
			d.cars[c.id] = true
		end
	end
	local after = Rewards.next(d :: any)
	if TrackTiles.ALL_FREE then
		eq((after :: Rewards.Goal).kind, "grid")
	else
		eq((after :: Rewards.Goal).kind, "tile")
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
