--!strict
-- What a cheater can send on the tycoon remotes (Plot, CarShop, PlotShopEvent, ServerRace vote):
-- junk values, free cars, money from nothing. The server passes the raw values straight into these
-- rules, so each one must refuse junk and never give coins or cars for free.
local H = require("./harness")
local Cat = require("../src/shared/CarCatalog")
local Profile = require("../src/shared/Profile")
local PlotShop = require("../src/shared/PlotShop")
local ServerRace = require("../src/shared/ServerRace")
local Tycoon = require("../src/shared/Tycoon")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Remote safety")

local NAN = 0 / 0
local junk: { any } = {
	NAN,
	math.huge,
	-math.huge,
	-1,
	0,
	1e308,
	"",
	"nope",
	string.rep("x", 5000),
	{},
	{ "gb_gold" },
	true,
	false,
}

local function ownedCount(d: any): number
	local n = 0
	for _ in d.cars do
		n += 1
	end
	return n
end

test("junk ids never buy a car, equip one or cost coins", function()
	for _, id in junk do
		local d = Profile.new()
		d.coins = 1e6
		local ok = Cat.buy(d, id)
		eq(ok, false, "buy junk")
		eq(Cat.equip(d, id), false, "equip junk")
		eq(d.coins, 1e6)
		eq(ownedCount(d), 0)
	end
end)

test("a gumball-only (rare) car can never be bought or equipped without winning it", function()
	for _, g in Cat.GUMBALL do
		local d = Profile.new()
		d.coins = 1e9
		eq(Cat.buy(d, g.car.id), false, g.car.id)
		eq(Cat.equip(d, g.car.id), false, g.car.id)
		eq(Cat.owns(d, g.car.id), false, g.car.id)
	end
end)

test("no coins, no car: buying and spinning are refused under the price", function()
	for mode, list in Cat.SHOP do
		for _, c in list do
			if c.price > 0 then
				local d = Profile.new()
				d.coins = c.price - 1
				eq(Cat.buy(d, c.id), false, `{mode} {c.id}`)
				eq(d.coins, c.price - 1)
				eq(Cat.owns(d, c.id), false)
			end
		end
	end
	local d = Profile.new()
	d.coins = Cat.GUMBALL_PRICE - 1
	local car = Cat.spin(d, 50)
	eq(car, nil)
	eq(d.coins, Cat.GUMBALL_PRICE - 1)
	eq(ownedCount(d), 0)
end)

test("a gumball spin can never make coins, whatever the roll", function()
	truthy(Cat.DUPLICATE_REFUND < Cat.GUMBALL_PRICE, "a repeat costs something")
	for _, r in { 0, 0.5, 33, 99.999, 100, 1e9, -5 } do
		local d = Profile.new()
		d.coins = Cat.GUMBALL_PRICE * 3
		for _ = 1, 3 do
			local before = d.coins
			Cat.spin(d, r)
			truthy(d.coins <= before - Cat.GUMBALL_PRICE + Cat.DUPLICATE_REFUND, "spin paid out")
			truthy(d.coins >= 0, "coins below zero")
		end
	end
end)

test("junk never buys, toggles or changes a plot look", function()
	for _, id in junk do
		local d = Profile.new()
		d.coins = 1e6
		eq(PlotShop.buy(d, id), false)
		eq(PlotShop.toggle(d, id), nil)
		eq(d.coins, 1e6)
	end
	for _, it in PlotShop.ITEMS do
		local d = Profile.new()
		d.coins = it.price - 1
		eq(PlotShop.buy(d, it.id), false, it.id)
		eq(d.coins, it.price - 1)
		eq(PlotShop.toggle(d, it.id), nil, "toggled a look not owned")
	end
end)

test("the garage: only owned cars park, none twice, never past the slots", function()
	local d = Profile.new()
	local owns = function(id: string): boolean
		return Cat.owns(d, id)
	end
	local parked: { string } = {}
	for _, g in Cat.GUMBALL do
		eq(Tycoon.park(parked, 0, g.car.id, true, owns), false, "parked a car not owned")
	end
	for _, id in { "", "nope", string.rep("y", 5000) } do
		eq(Tycoon.park(parked, 0, id, true, owns), false)
	end
	eq(#parked, 0)
	local starter = Cat.starter("race").id
	eq(Tycoon.park(parked, 0, starter, true, owns), true)
	eq(Tycoon.park(parked, 0, starter, true, owns), false, "twice")
	-- slots: owning every car still fills at most the slots
	for _, list in Cat.SHOP do
		for _, c in list do
			d.cars[c.id] = true
		end
	end
	for _, g in Cat.GUMBALL do
		d.cars[g.car.id] = true
	end
	for _, list in Cat.SHOP do
		for _, c in list do
			Tycoon.park(parked, 0, c.id, true, owns)
		end
	end
	for _, g in Cat.GUMBALL do
		Tycoon.park(parked, 0, g.car.id, true, owns)
	end
	eq(#parked, Tycoon.slots(0))
	-- junk levels never open extra slots
	for _, lvl in { math.huge, -5, 1e308 } do
		truthy(Tycoon.slots(lvl) <= Tycoon.slots(Tycoon.MAX_LEVEL), "slots past the top")
	end
end)

test("plot levels cost coins and stop at the top", function()
	eq(Tycoon.levelCost(Tycoon.MAX_LEVEL), nil)
	eq(Tycoon.levelCost(NAN), nil)
	eq(Tycoon.levelCost(1e308), nil)
	for lvl = 0, Tycoon.MAX_LEVEL - 1 do
		local cost = Tycoon.levelCost(lvl)
		truthy(cost ~= nil and cost > 0, `level {lvl + 1} is free`)
	end
end)

test("the coin pile only grows from parked cars, and never from junk", function()
	eq(Tycoon.income({}, 0, 0), 0)
	eq(Tycoon.income({ "nope", "", "gb_nope" }, math.huge, 0), 0, "unknown cars earn")
	eq(Tycoon.accrue(0, 0, 1e9), 0)
	eq(Tycoon.accrue(0, 6, -1e9), 0)
	local one = Tycoon.income({ Cat.starter("race").id }, 0, 0)
	truthy(Tycoon.accrue(0, one, 1e12) <= one * Tycoon.PILE_CAP_MIN, "pile past its cap")
end)

test("the map vote: junk votes count for nothing, one player is one vote", function()
	local ids = { "BACKYARD", "KITCHEN" }
	local votes: { [any]: string } = { a = "nope", b = "", c = string.rep("z", 5000) }
	-- only junk: a random one of the real maps, never a made-up one
	for _, r in { 0, 0.5, 0.999, 1e9, -1e9 } do
		local win = ServerRace.tally(votes, ids, r)
		truthy(win == "BACKYARD" or win == "KITCHEN", `junk vote won: {tostring(win)}`)
	end
	votes.d = "KITCHEN"
	eq(ServerRace.tally(votes, ids, 0), "KITCHEN")
	eq(ServerRace.tally(votes, {}, 0), nil)
end)

test("race pay is small and fixed: no place or junk pays more than first", function()
	local top = ServerRace.payFor(1, true)
	for _, place in { 0, -1, 2, 50, 1e9, NAN } do
		truthy(ServerRace.payFor(place, true) <= top, `place {tostring(place)} paid over first`)
	end
	truthy(ServerRace.payFor(1, false) < ServerRace.payFor(1, true), "a DNF paid like a win")
end)
