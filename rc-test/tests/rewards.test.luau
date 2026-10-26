--!strict
-- The "next unlock" goal shown in the lobby and after each race.
local H = require("./harness")
local Rewards = require("../src/shared/Rewards")
local Tycoon = require("../src/shared/Tycoon")
local Profile = require("../src/shared/Profile")

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
	-- own every shop car: the next goal is a bigger garage
	for _, list in (require("../src/shared/CarCatalog") :: any).SHOP do
		for _, c in list do
			d.cars[c.id] = true
		end
	end
	-- (tycoon) every shop car owned: a bigger garage next, nothing at the top level
	local after = Rewards.next(d :: any)
	eq((after :: Rewards.Goal).kind, "level")
	d.plotLevel = Tycoon.MAX_LEVEL
	eq(Rewards.next(d :: any), nil)
end)
