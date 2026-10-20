--!strict
local H = require("./harness")
local LobbyCars = require("../src/shared/LobbyCars")
local BattleConfig = require("../src/shared/BattleConfig")
local eq, truthy = H.eq, H.truthy

print("LobbyCars")

H.test("a new player parks the free starter", function()
	eq(LobbyCars.bestOwned({}), "RamTruck")
end)

H.test("the rarest owned car is the one parked", function()
	eq(LobbyCars.bestOwned({ CannonVan = true }), "CannonVan")
	eq(LobbyCars.bestOwned({ CannonVan = true, SawBuggy = true }), "SawBuggy")
	eq(LobbyCars.bestOwned({ SawBuggy = true, CannonVan = true, Unknown = true }), "SawBuggy")
end)

H.test("the stage shows the rarest car the machine drops", function()
	local id = LobbyCars.rarestGumball()
	truthy(id ~= nil)
	truthy(BattleConfig.Fighters[id :: string].gumball)
	eq(id, "SawBuggy")
end)

H.test("the shop shows three battle cars", function()
	local list = LobbyCars.shopDisplay()
	eq(#list, 3)
	eq(list[1], "RamTruck")
	eq(list[2], "CannonVan")
	eq(list[3], "SawBuggy")
end)

H.test("rare pulls are Epic and up", function()
	truthy(not LobbyCars.isRarePull("RamTruck"))
	truthy(not LobbyCars.isRarePull("CannonVan"))
	truthy(LobbyCars.isRarePull("SawBuggy"))
	eq(LobbyCars.nameOf("SawBuggy"), "Saw Buggy")
	eq(LobbyCars.nameOf("x"), "x")
end)
