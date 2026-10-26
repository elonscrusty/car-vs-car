--!strict
-- Cars (CarCatalog.luau): starters are free and yours, buying takes coins once, equipping only
-- what you own and only in its own mode, gumball odds add up and are fair, repeats refund.
local H = require("./harness")
local Cat = require("../src/shared/CarCatalog")
local Profile = require("../src/shared/Profile")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Car catalog")

test("every mode has a free starter you already own and drive", function()
	local d = Profile.new()
	for _, mode in Cat.MODES do
		local s = Cat.starter(mode)
		eq(s.price, 0)
		eq(s.mode, mode)
		eq(Cat.owns(d, s.id), true)
		eq(Cat.equipped(d, mode).id, s.id)
	end
end)

test("buying takes the coins once; not enough coins or owned already does nothing", function()
	local d = Profile.new()
	local mid = Cat.SHOP.race[2]
	eq(select(2, Cat.buy(d, mid.id)), "coins")
	d.coins = mid.price + 5
	eq(Cat.buy(d, mid.id), true)
	eq(d.coins, 5)
	eq(select(2, Cat.buy(d, mid.id)), "owned")
	eq(select(2, Cat.buy(d, Cat.starter("race").id)), "owned")
	eq(select(2, Cat.buy(d, "nope")), "unknown")
	eq(select(2, Cat.buy(d, Cat.GUMBALL[1].car.id)), "unknown") -- rare cars aren't sold
	eq(d.coins, 5)
end)

test("equip: only cars you own, each in its own mode (a drift car never races)", function()
	local d = Profile.new()
	local mid = Cat.SHOP.drift[2]
	eq(Cat.equip(d, mid.id), false)
	d.cars[mid.id] = true
	eq(Cat.equip(d, mid.id), true)
	eq(Cat.equipped(d, "drift").id, mid.id)
	eq(Cat.equipped(d, "race").mode, "race")
	-- a save that says a drift car is the race car still races the race starter
	d.equipped.race = mid.id
	eq(Cat.equipped(d, "race").id, Cat.starter("race").id)
end)

test("gumball odds add up to 100 and every roll lands on one car", function()
	local sum = 0
	for _, g in Cat.GUMBALL do
		truthy(g.chance > 0, g.car.name)
		truthy(g.car.rare, g.car.name .. " rare")
		sum += g.chance
	end
	eq(sum, 100)
	eq(Cat.pick(0).id, Cat.GUMBALL[1].car.id)
	eq(Cat.pick(99.99).id, Cat.GUMBALL[#Cat.GUMBALL].car.id)
end)

test("a spin costs its price; a repeat gives half back; no coins, no spin", function()
	local d = Profile.new()
	eq(Cat.spin(d, 0), nil)
	d.coins = 2 * Cat.GUMBALL_PRICE
	local c, new = Cat.spin(d, 0)
	truthy(c ~= nil and new, "first spin new")
	eq(d.coins, Cat.GUMBALL_PRICE)
	local _, again = Cat.spin(d, 0)
	eq(again, false)
	eq(d.coins, Cat.DUPLICATE_REFUND)
end)

test("cars and picks survive a save round trip", function()
	local d = Profile.new()
	d.cars.race_dart = true
	d.equipped.race = "race_dart"
	local back = Profile.migrate(d)
	eq(back.cars.race_dart, true)
	eq(back.equipped.race, "race_dart")
	local junk = Profile.migrate({ cars = { x = "yes", [5] = true }, equipped = { space = "a" } })
	eq(next(junk.cars), nil)
	eq(next(junk.equipped), nil)
end)

test("every car is one of the four kinds; rarer kinds make more coins", function()
	for _, mode in Cat.MODES do
		for _, c in Cat.SHOP[mode] do
			truthy(Cat.RARITY[c.rarity] ~= nil, c.id .. " has a kind")
		end
	end
	for _, g in Cat.GUMBALL do
		truthy(Cat.RARITY[g.car.rarity] ~= nil, g.car.id .. " has a kind")
	end
	local last = 0
	for _, r in Cat.RARITY_ORDER do
		truthy(Cat.RARITY[r].perMin > last, r .. " pays more than the kind below")
		last = Cat.RARITY[r].perMin
	end
	eq(Cat.rarity("no_such_car").id, "common")
end)

test("the gumball odds per kind add up to 100", function()
	local sum = 0
	for _, n in Cat.tierOdds() do
		sum += n
	end
	eq(sum, 100)
	truthy((Cat.tierOdds().legend or 0) > 0, "legends can drop")
end)
