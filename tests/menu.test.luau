--!strict
local H = require("./harness")
local BotLevels = require("../src/shared/BotLevels")
local FeatureFlags = require("../src/shared/FeatureFlags")
local Inventory = require("../src/shared/Inventory")
local MenuRules = require("../src/shared/MenuRules")

print("Menu / flags / bot auto level")

H.test("launch flags: cuts hidden, soccer kept", function()
	local off = {
		"dailySpin",
		"rankBadges",
		"paintShop",
		"perCarQuests",
		"botLevelButton",
		"lastStandingMode",
	}
	for _, f in off do
		H.truthy(not FeatureFlags.enabled(f), f)
	end
	H.truthy(FeatureFlags.enabled("soccerMode"))
	H.truthy(not FeatureFlags.enabled("nope"))
	H.truthy(FeatureFlags.enabled("x", { x = true }))
end)

H.test("menu: only GIFT until 2 matches, then QUESTS and GARAGE", function()
	local v = MenuRules.visible({ matches = 0 })
	H.truthy(v.gift and not v.quests and not v.garage)
	v = MenuRules.visible({ matches = 1 })
	H.truthy(v.gift and not v.quests and not v.garage)
	v = MenuRules.visible({ matches = 2 })
	H.truthy(v.gift and v.quests and v.garage)
	v = MenuRules.visible({ matches = 50 })
	H.truthy(v.gift and v.quests and v.garage)
	v = MenuRules.visible(nil)
	H.truthy(v.gift and not v.quests)
	v = MenuRules.visible({ matches = "x" })
	H.truthy(not v.quests)
	v = MenuRules.visible({ matches = 3 }, { matchesForFullMenu = 5 })
	H.truthy(not v.quests)
end)

H.test("matches counter: default 0, old saves migrate to 0, bad values cleaned", function()
	H.eq(Inventory.default().matches, 0)
	H.eq(Inventory.migrate({ coins = 5 }).matches, 0)
	H.eq(Inventory.migrate({ matches = 7 }).matches, 7)
	H.eq(Inventory.migrate({ matches = -3 }).matches, 0)
	H.eq(Inventory.migrate({ matches = "x" }).matches, 0)
	H.eq(Inventory.migrate({ matches = 1e20 }).matches, 1e9)
end)

H.test("bot level auto-scales by total wins", function()
	H.eq(BotLevels.forWins(0), "easy")
	H.eq(BotLevels.forWins(2), "easy")
	H.eq(BotLevels.forWins(3), "medium")
	H.eq(BotLevels.forWins(14), "medium")
	H.eq(BotLevels.forWins(15), "hard")
	H.eq(BotLevels.forWins(nil), "easy")
	H.eq(BotLevels.forWins(5, { easyUnder = 10, mediumUnder = 20 }), "easy")
end)

H.test("levelFor: saved choice only while the button is on", function()
	H.eq(BotLevels.levelFor(0, "hard", true), "hard")
	H.eq(BotLevels.levelFor(0, "hard", false), "easy")
	H.eq(BotLevels.levelFor(20, "easy", false), "hard")
	H.eq(BotLevels.levelFor(20, "bogus", true), "hard")
end)
