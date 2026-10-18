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
	H.truthy(Inventory.owns(p, "Heavy"))
	H.eq(Inventory.owns(p, "Spike"), false)
	H.eq(p.coins, 0)
end)

H.test("first pull is free and costs nothing", function()
	local p = Inventory.default()
	H.truthy(Gacha.canBuy(p))
	local r = Gacha.pull(p, fixed(0.9, 0)) -- Epic -> Spike
	H.eq(r.free, true)
	H.eq(r.carId, "Spike")
	H.eq(r.isNew, true)
	H.eq(p.coins, 0)
	H.eq(p.freePullUsed, true)
	H.truthy(Inventory.owns(p, "Spike"))
end)

H.test("second pull needs coins", function()
	local p = Inventory.default()
	p.freePullUsed = true
	local ok, reason = Gacha.canBuy(p)
	H.eq(ok, false)
	H.eq(reason, "coins")
	H.eq(pcall(Gacha.pull, p, fixed(0.5)), false)
	H.eq(p.coins, 0)
	p.coins = 100
	ok = Gacha.canBuy(p)
	H.eq(ok, true)
end)

H.test("paid pull deducts price, duplicate refunds", function()
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 150
	local r = Gacha.pull(p, fixed(0.0, 0.0)) -- Common, first common = Heavy (owned)
	H.eq(r.carId, "Heavy")
	H.eq(r.isNew, false)
	H.eq(r.free, false)
	H.eq(r.refund, LobbyConfig.Gacha.duplicateRefund)
	H.eq(p.coins, 150 - LobbyConfig.Gacha.price + LobbyConfig.Gacha.duplicateRefund)
end)

H.test("pull is deterministic and maps rolls to rarity", function()
	local function carFor(roll: number): string
		local p = Inventory.default()
		p.freePullUsed = true
		p.coins = 1000
		return Gacha.pull(p, fixed(roll, 0)).carId
	end
	H.eq(carFor(0.0), "Heavy")
	H.eq(carFor(0.549), "Heavy")
	H.eq(carFor(0.55), "Ramp") -- Rare starts at 55%
	H.eq(carFor(0.829), "Ramp")
	H.eq(carFor(0.83), "Spike") -- Epic starts at 83%
	H.eq(carFor(0.969), "Spike")
	H.eq(carFor(0.97), "Formula") -- Legendary starts at 97%
	H.eq(carFor(0.9999), "Formula")
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 1000
	local common = Gacha.oddsTable()[1].cars
	H.eq(Gacha.pull(p, fixed(0.3, 0.99)).carId, common[#common]) -- second roll picks within Common
end)

H.test("migrate sanitizes garbage", function()
	for _, bad in { "x", 5, false, {}, { coins = "9", owned = 3 } } do
		local p = Inventory.migrate(bad)
		H.eq(p.coins, 0)
		H.truthy(Inventory.owns(p, "Heavy"))
	end
	local p = Inventory.migrate({
		coins = -50.7,
		wins = 1e20,
		owned = { Light = true, Ghost = true, Ramp = "yes", Spike = false },
		freePullUsed = "true",
	})
	H.eq(p.coins, 0)
	H.eq(p.wins, 1e9)
	H.eq(p.owned.Ghost, nil)
	H.eq(p.owned.Ramp, nil)
	H.eq(p.owned.Spike, nil)
	H.truthy(p.owned.Light)
	H.eq(p.freePullUsed, false)
	H.eq(Inventory.migrate({ coins = 12.9 }).coins, 12)
	H.eq(Inventory.migrate({ coins = 0 / 0 }).coins, 0)
end)

H.test("ownedList follows CarConfig.Order, grantCar reports new", function()
	local p = Inventory.default()
	H.eq(Inventory.grantCar(p, "Spike"), true)
	H.eq(Inventory.grantCar(p, "Spike"), false)
	H.eq(Inventory.grantCar(p, "Nope"), false)
	Inventory.grantCar(p, "Light")
	local list = Inventory.ownedList(p)
	H.eq(table.concat(list, ","), "Heavy,Light,Spike")
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
		local picks = PickChoices.choose({ "Heavy", "Light", "Ramp", "Spike", "Heavy" }, 3, r)
		H.eq(#picks, 3)
		local seen = {}
		for _, id in picks do
			H.eq(seen[id], nil, "dupe")
			seen[id] = true
		end
	end
	H.eq(#PickChoices.choose({ "Heavy" }, 3, r), 1)
	H.eq(#PickChoices.choose({}, 3, r), 0)
	H.eq(#PickChoices.choose({ "Heavy", "Light" }, 3, r), 2)
	local owned = { "Heavy", "Light", "Ramp" }
	PickChoices.choose(owned, 3, r)
	H.eq(#owned, 3, "input untouched")
	H.eq(table.concat(PickChoices.choose(owned, 2, fixed(0, 0)), ","), "Heavy,Light")
end)
