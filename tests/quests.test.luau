--!strict
local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local Daily = require("../src/shared/Daily")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local Quests = require("../src/shared/Quests")
local QuestsConfig = require("../src/shared/QuestsConfig")

print("Quests")

local function win(carId: string?, bot: boolean?): Quests.MatchInfo
	return { won = true, carId = carId or "Heavy", opponentIsBot = bot ~= false }
end

local function pay(p: Inventory.Profile): (number) -> ()
	return function(n: number)
		Inventory.addCoins(p, n)
	end
end

H.test("catalog is valid", function()
	H.truthy(#QuestsConfig.Catalog >= QuestsConfig.Slots + #CarConfig.Order)
	for _, def in QuestsConfig.Catalog do
		H.truthy(def.target > 0 and def.reward > 0 and #def.title > 0)
		H.eq(QuestsConfig.get(def.id), def)
	end
end)

H.test("fresh profile gets distinct starters, deterministic for a seed", function()
	local a, b = Inventory.default(), Inventory.default()
	H.eq(#a.quests, 0)
	H.truthy(Quests.ensure(a, 12345))
	Quests.ensure(b, 12345)
	H.eq(#a.quests, QuestsConfig.Slots)
	local ids: { [string]: boolean } = {}
	for i, q in a.quests do
		H.eq(q.id, b.quests[i].id)
		H.eq(q.progress, 0)
		H.eq(ids[q.id], nil)
		ids[q.id] = true
	end
	H.eq(Quests.ensure(a, 1), false)
end)

H.test("progress counts by kind and car, capped at target", function()
	local p = Inventory.default()
	p.quests = {
		{ id = "win3", progress = 0 },
		{ id = "win3_Tank", progress = 0 },
		{ id = "play5", progress = 0 },
	}
	H.truthy(Quests.onMatchEnd(p, win("Heavy")))
	H.eq(p.quests[1].progress, 1)
	H.eq(p.quests[2].progress, 0)
	H.eq(p.quests[3].progress, 1)
	Quests.onMatchEnd(p, { won = false, carId = "Tank", opponentIsBot = true })
	H.eq(p.quests[1].progress, 1)
	H.eq(p.quests[2].progress, 0)
	H.eq(p.quests[3].progress, 2)
	Quests.onMatchEnd(p, win("Tank"))
	H.eq(p.quests[2].progress, 1)
	for _ = 1, 10 do
		Quests.onMatchEnd(p, win("Tank"))
	end
	H.eq(p.quests[1].progress, 3)
	H.eq(p.quests[3].progress, 5)
	H.truthy(Quests.isDone(p.quests[1]))
	H.eq(Quests.onMatchEnd(p, win("Tank")), false) -- everything is capped
end)

H.test("beat-the-bot needs a bot opponent", function()
	local p = Inventory.default()
	p.quests = { { id = "bot2", progress = 0 } }
	Quests.onMatchEnd(p, win("Heavy", false))
	H.eq(p.quests[1].progress, 0)
	Quests.onMatchEnd(p, win("Heavy", true))
	H.eq(p.quests[1].progress, 1)
end)

H.test("claim pays once and replaces the quest", function()
	local p = Inventory.default()
	p.quests = { { id = "win3", progress = 3 }, { id = "play5", progress = 1 } }
	H.truthy(Quests.anyClaimable(p))
	H.eq(Quests.claim(p, 2, 7, pay(p)), 0) -- not done
	H.eq(Quests.claim(p, "x", 7, pay(p)), 0)
	H.eq(Quests.claim(p, 1.5, 7, pay(p)), 0)
	local paid = Quests.claim(p, 1, 7, pay(p))
	H.eq(paid, QuestsConfig.get("win3").reward)
	H.eq(p.coins, paid)
	H.eq(#p.quests, QuestsConfig.Slots)
	H.eq(Quests.claim(p, 1, 7, pay(p)), 0) -- the replacement is not done
	H.eq(p.coins, paid)
	H.eq(#Quests.views(p), QuestsConfig.Slots)
end)

H.test("saves: quests and daily default, migrate and clean", function()
	local old = Inventory.migrate({ coins = 5 })
	H.eq(#old.quests, 0)
	H.eq(old.daily.freePulls, 0)
	H.eq(old.daily.lastDay, 0)
	local kept = Inventory.migrate({
		quests = {
			{ id = "win3", progress = 2 },
			{ id = "zzz", progress = 1 },
			{ id = "win3", progress = 1 },
			5,
		},
		daily = { lastDay = 100, freePulls = 99 },
	})
	H.eq(#kept.quests, 1)
	H.eq(kept.quests[1].progress, 2)
	H.eq(kept.daily.lastDay, 100)
	H.eq(kept.daily.freePulls, QuestsConfig.Daily.maxFreePulls)
	H.eq(#Inventory.migrate({ quests = "x", daily = 4 }).quests, 0)
end)

H.test("daily gift: once per UTC day, consumable", function()
	local d = Daily.default()
	local t = 86400 * 20000 + 5
	H.truthy(Daily.canClaim(d, t))
	H.truthy(Daily.claim(d, t))
	H.eq(d.freePulls, 1)
	H.eq(Daily.claim(d, t + 3000), false)
	H.eq(d.freePulls, 1)
	H.truthy(Daily.claim(d, t + 86400))
	H.eq(d.freePulls, 2)
	H.truthy(Daily.consume(d))
	H.truthy(Daily.consume(d))
	H.eq(Daily.consume(d), false)
end)

H.test("gacha uses gift tries when the first free pull is gone", function()
	local p = Inventory.default()
	p.freePullUsed = true
	H.eq((Gacha.canBuy(p)), false)
	p.daily.freePulls = 1
	H.truthy(Gacha.canBuy(p))
	local r = Gacha.pull(p, function()
		return 0
	end)
	H.eq(r.free, true)
	H.eq(p.daily.freePulls, 0)
	H.eq(p.coins, r.refund)
	H.eq((Gacha.canBuy(p)), false)
end)
