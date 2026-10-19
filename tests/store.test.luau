--!strict
local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local Store = require("../src/shared/Store")

print("Store")

H.test("every car has a positive price by rarity", function()
	for _, id in CarConfig.Order do
		H.truthy(Store.price(id) > 0, id)
	end
	H.eq(Store.price("Sedan"), LobbyConfig.Store.prices.Common)
	H.eq(Store.price("Semi"), LobbyConfig.Store.prices.Epic)
	H.eq(Store.price("NoSuchCar"), LobbyConfig.Store.defaultPrice)
end)

H.test("canBuy reasons", function()
	local p = Inventory.default()
	p.coins = 10000
	local ok, why = Store.canBuy(p, "Sedan")
	H.eq(ok, false)
	H.eq(why, "owned")
	ok, why = Store.canBuy(p, "NoSuchCar")
	H.eq(why, "unknown")
	ok, why = Store.canBuy(p, 5)
	H.eq(why, "unknown")
	ok, why = Store.canBuy(p, nil)
	H.eq(why, "unknown")
	p.coins = Store.price("Semi") - 1
	ok, why = Store.canBuy(p, "Semi")
	H.eq(ok, false)
	H.eq(why, "coins")
	p.coins = Store.price("Semi")
	ok, why = Store.canBuy(p, "Semi")
	H.eq(ok, true)
	H.eq(why, nil)
end)

H.test("buy charges once and grants the car", function()
	local p = Inventory.default()
	p.coins = Store.price("Semi") + 7
	H.eq(Store.buy(p, "Semi"), true)
	H.eq(p.coins, 7)
	H.eq(Inventory.owns(p, "Semi"), true)
	H.eq(Store.buy(p, "Semi"), false) -- already owned: no second charge
	H.eq(p.coins, 7)
end)

H.test("failed buys change nothing", function()
	local p = Inventory.default()
	p.coins = 5
	H.eq(Store.buy(p, "Semi"), false)
	H.eq(Store.buy(p, "Bogus"), false)
	H.eq(p.coins, 5)
	H.eq(#Inventory.ownedList(p), 1)
end)
