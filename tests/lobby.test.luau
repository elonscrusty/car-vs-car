--!strict

local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local PickChoices = require("../src/shared/PickChoices")

local function fixed(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

H.test("gacha odds sum to 100", function()
	local sum = 0
	for _, p in LobbyConfig.Gacha.odds do
		sum += p
	end
	H.eq(sum, 100)
	local rowSum = 0
	for _, row in Gacha.oddsTable() do
		rowSum += row.percent
	end
	H.eq(rowSum, 100)
end)

H.test("every car has a rarity with odds", function()
	for _, id in CarConfig.Order do
		local r = LobbyConfig.Rarity[id]
		H.truthy(r, id .. " rarity")
		H.truthy(LobbyConfig.Gacha.odds[r], id .. " odds")
	end
	for _, id in LobbyConfig.StarterCars do
		H.truthy(CarConfig.get(id), "starter is real")
	end
end)

H.test("default profile owns starters only", function()
	local p = Inventory.default()
	H.eq(#Inventory.ownedList(p), #LobbyConfig.StarterCars)
	H.truthy(Inventory.owns(p, "Sedan"))
	H.eq(Inventory.owns(p, "Semi"), false)
	H.eq(p.coins, 0)
end)

H.test("first pull is free and costs nothing", function()
	local p = Inventory.default()
	H.truthy(Gacha.canBuy(p))
	local r = Gacha.pull(p, fixed(0.9, 0)) -- Epic -> SuperCar (first Epic)
	H.eq(r.free, true)
	H.eq(r.carId, "SuperCar")
	H.eq(r.isNew, true)
	H.eq(p.coins, 0)
	H.eq(p.freePullUsed, true)
	H.truthy(Inventory.owns(p, "SuperCar"))
end)

H.test("second pull needs coins", function()
	local p = Inventory.default()
	p.freePullUsed = true
	local ok, reason = Gacha.canBuy(p)
	H.eq(ok, false)
	H.eq(reason, "coins")
	H.eq(pcall(Gacha.pull, p, fixed(0.5)), false)
	H.eq(p.coins, 0)
	p.coins = LobbyConfig.Gacha.price
	ok = Gacha.canBuy(p)
	H.eq(ok, true)
end)

H.test("paid pull deducts price, duplicate refunds", function()
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 150
	local r = Gacha.pull(p, fixed(0.0, 0.0)) -- Common, first common = Sedan (owned)
	H.eq(r.carId, "Sedan")
	H.eq(r.isNew, false)
	H.eq(r.free, false)
	H.eq(r.refund, LobbyConfig.Gacha.duplicateRefunds.Common)
	H.eq(p.coins, 150 - LobbyConfig.Gacha.price + LobbyConfig.Gacha.duplicateRefunds.Common)
end)

H.test("pull is deterministic and maps rolls to rarity", function()
	local function carFor(roll: number): string
		local p = Inventory.default()
		p.freePullUsed = true
		p.coins = 1000
		return Gacha.pull(p, fixed(roll, 0)).carId
	end
	H.eq(carFor(0.0), "Sedan")
	H.eq(carFor(0.549), "Sedan")
	H.eq(carFor(0.55), "Muscle") -- Rare starts at 55%
	H.eq(carFor(0.829), "Muscle")
	H.eq(carFor(0.83), "SuperCar") -- Epic starts at 83%
	H.eq(carFor(0.969), "SuperCar")
	H.eq(carFor(0.97), "Formula") -- Legendary starts at 97%
	H.eq(carFor(0.9999), "Formula")
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 1000
	local common = Gacha.oddsTable()[1].cars
	H.eq(Gacha.pull(p, fixed(0.3, 0.99)).carId, common[#common]) -- second roll picks within Common
end)

H.test("duplicate refund grows with rarity", function()
	H.eq(Gacha.refundFor("Sedan"), LobbyConfig.Gacha.duplicateRefunds.Common)
	H.eq(Gacha.refundFor("Semi"), LobbyConfig.Gacha.duplicateRefunds.Epic)
	H.eq(Gacha.refundFor("Formula"), LobbyConfig.Gacha.duplicateRefunds.Legendary)
	H.truthy(Gacha.refundFor("Formula") > Gacha.refundFor("Semi"))
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 1000
	Gacha.pull(p, fixed(0.99, 0))
	local before = p.coins
	local r = Gacha.pull(p, fixed(0.99, 0)) -- Formula again
	H.eq(r.isNew, false)
	H.eq(p.coins, before - LobbyConfig.Gacha.price + r.refund)
end)

H.test("migrate sanitizes garbage", function()
	for _, bad in { "x", 5, false, {}, { coins = "9", owned = 3 } } do
		local p = Inventory.migrate(bad)
		H.eq(p.coins, 0)
		H.truthy(Inventory.owns(p, "Sedan"))
	end
	local p = Inventory.migrate({
		coins = -50.7,
		wins = 1e20,
		owned = { Compact = true, Ghost = true, Kart = "yes", Semi = false },
		freePullUsed = "true",
	})
	H.eq(p.coins, 0)
	H.eq(p.wins, 1e9)
	H.eq(p.owned.Ghost, nil)
	H.eq(p.owned.Kart, nil)
	H.eq(p.owned.Semi, nil)
	H.truthy(p.owned.Compact)
	H.eq(p.freePullUsed, false)
	H.eq(Inventory.migrate({ coins = 12.9 }).coins, 12)
	H.eq(Inventory.migrate({ coins = 0 / 0 }).coins, 0)
end)

H.test("ownedList follows CarConfig.Order, grantCar reports new", function()
	local p = Inventory.default()
	H.eq(Inventory.grantCar(p, "Semi"), true)
	H.eq(Inventory.grantCar(p, "Semi"), false)
	H.eq(Inventory.grantCar(p, "Nope"), false)
	Inventory.grantCar(p, "Compact")
	local list = Inventory.ownedList(p)
	H.eq(table.concat(list, ","), "Sedan,Compact,Semi")
	Inventory.addCoins(p, 30)
	Inventory.addCoins(p, -100)
	H.eq(p.coins, 0)
end)

H.test("PickChoices: no dupes, handles few owned", function()
	local state = 12345
	local function r()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	for _ = 1, 50 do
		local picks = PickChoices.choose({ "Sedan", "Compact", "Kart", "Semi", "Sedan" }, 3, r)
		H.eq(#picks, 3)
		local seen = {}
		for _, id in picks do
			H.eq(seen[id], nil, "dupe")
			seen[id] = true
		end
	end
	H.eq(#PickChoices.choose({ "Sedan" }, 3, r), 1)
	H.eq(#PickChoices.choose({}, 3, r), 0)
	H.eq(#PickChoices.choose({ "Sedan", "Compact" }, 3, r), 2)
	local owned = { "Sedan", "Compact", "Kart" }
	PickChoices.choose(owned, 3, r)
	H.eq(#owned, 3, "input untouched")
	H.eq(table.concat(PickChoices.choose(owned, 2, fixed(0, 0)), ","), "Sedan,Compact")
end)
