--!strict
-- The tycoon (carter 10-26): parked cars make coins into the plot's pile.
local H = require("./harness")
local Tycoon = require("../src/shared/Tycoon")
local Profile = require("../src/shared/Profile")
local CarCatalog = require("../src/shared/CarCatalog")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Tycoon")

test("tycoon: each parked car makes coins a minute, a race win doubles it", function()
	local bolt = CarCatalog.starter("race").id
	truthy(Tycoon.perMin(bolt) > 0, "the free car earns")
	eq(Tycoon.perMin("nope"), 0)
	local one = Tycoon.income({ bolt }, 0, 100)
	eq(Tycoon.income({ bolt, bolt }, 0, 100), one * 2)
	eq(Tycoon.income({ bolt }, 200, 100), one * Tycoon.WIN_BOOST)
	eq(Tycoon.income({ bolt }, 100, 100), one) -- the boost is over at its end
	-- the gold gumball car is worth more than the free one
	truthy(Tycoon.perMin("gb_gold") > Tycoon.perMin(bolt), "legend beats common")
end)

test("tycoon: the pile grows to its cap and stops (away too)", function()
	near(Tycoon.accrue(0, 6, 60), 6, 1e-9)
	near(Tycoon.accrue(0, 6, 10), 1, 1e-9)
	eq(Tycoon.accrue(0, 6, 1e9), 6 * Tycoon.PILE_CAP_MIN)
	eq(Tycoon.accrue(5, 6, -3), 5)
	-- a pile over the cap (from a bigger income before) is never cut
	eq(Tycoon.accrue(10000, 2, 60), 10000)
end)

test("tycoon: slots, levels and parking", function()
	eq(Tycoon.slots(0), 3)
	eq(Tycoon.slots(5), 8)
	eq(Tycoon.slots(99), 8)
	truthy(Tycoon.levelCost(0) ~= nil, "level 1 has a price")
	eq(Tycoon.levelCost(Tycoon.MAX_LEVEL), nil)
	truthy(Profile.MAX_PARKED >= Tycoon.slots(Tycoon.MAX_LEVEL), "the save holds a full garage")
	local have = { a = true, b = true, c = true, d = true }
	local function owns(id: string): boolean
		return have[id] == true
	end
	local parked = {}
	eq(Tycoon.park(parked, 0, "a", true, owns), true)
	eq(Tycoon.park(parked, 0, "a", true, owns), false) -- already there
	eq(Tycoon.park(parked, 0, "zz", true, owns), false) -- not owned
	eq(Tycoon.park(parked, 0, "b", true, owns), true)
	eq(Tycoon.park(parked, 0, "c", true, owns), true)
	eq(Tycoon.park(parked, 0, "d", true, owns), false) -- full at level 0
	eq(Tycoon.park(parked, 1, "d", true, owns), true)
	eq(Tycoon.park(parked, 1, "a", false, owns), true)
	eq(Tycoon.park(parked, 1, "a", false, owns), false)
	eq(#parked, 3)
end)

test("tycoon: a new player's garage starts with the free race car", function()
	local s = CarCatalog.newSave and CarCatalog.newSave() or { coins = 0, cars = {}, equipped = {} }
	local list = Tycoon.firstParked(0, function(id: string): boolean
		return CarCatalog.owns(s :: any, id)
	end)
	eq(list[1], CarCatalog.starter("race").id)
	truthy(#list <= Tycoon.slots(0), "fits the garage")
	-- someone with a gold car parks it first
	local rich = { coins = 0, cars = { gb_gold = true }, equipped = {} }
	local best = Tycoon.firstParked(0, function(id: string): boolean
		return CarCatalog.owns(rich :: any, id)
	end)
	eq(best[1], "gb_gold")
end)

test("tycoon: saved, junk cleaned", function()
	local d = Profile.new()
	eq(d.pile, 0)
	eq(#d.parked, 0)
	local back = Profile.migrate({
		version = Profile.VERSION,
		pile = 12.5,
		lastSeen = 1000,
		boostUntil = 2000,
		plotLevel = 99,
		parked = { "race_bolt", "race_bolt", 7, "drift_kid" },
	})
	eq(back.pile, 12.5)
	eq(back.lastSeen, 1000)
	eq(back.boostUntil, 2000)
	eq(back.plotLevel, Profile.MAX_PLOT_LEVEL)
	eq(#back.parked, 2)
	eq(Profile.migrate({ version = 14, pile = -5 }).pile, 0)
end)
