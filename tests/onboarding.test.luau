--!strict
local H = require("./harness")
local FirstWin = require("../src/shared/FirstWin")
local FirstWinConfig = require("../src/shared/FirstWinConfig")
local Hints = require("../src/shared/Hints")
local Inventory = require("../src/shared/Inventory")
local PickChoices = require("../src/shared/PickChoices")

print("Onboarding")

H.test("pick screen is skipped only when exactly one car is offered", function()
	H.truthy(PickChoices.shouldSkip(1))
	H.eq(PickChoices.shouldSkip(0), false)
	H.eq(PickChoices.shouldSkip(2), false)
	H.eq(PickChoices.shouldSkip(3), false)
	-- a player who owns only Heavy gets exactly one offered car
	local offered = PickChoices.choose({ "Heavy", "Heavy" }, 3, function()
		return 0
	end)
	H.eq(#offered, 1)
	H.truthy(PickChoices.shouldSkip(#offered))
end)

H.test("first win: only a win with zero wins saved", function()
	H.truthy(FirstWin.isFirstWin(0, true))
	H.eq(FirstWin.isFirstWin(0, false), false)
	H.eq(FirstWin.isFirstWin(1, true), false)
	H.eq(FirstWin.isFirstWin(25, true), false)
	H.eq(FirstWin.isFirstWin(nil, true), false)
	H.eq(FirstWin.isFirstWin("0", true), false)
	-- an old save (no wins field) migrates to 0 wins, so the first win still counts
	local old = Inventory.migrate({ coins = 5, owned = { Heavy = true } })
	H.truthy(FirstWin.isFirstWin(old.wins, true))
end)

H.test("first win texts and config", function()
	H.eq(FirstWin.headline(), FirstWinConfig.headline)
	H.eq(FirstWin.toastText(25), "FIRST WIN!   +25 COINS")
	H.eq(FirstWin.toastText(-3), "FIRST WIN!   +0 COINS")
	H.truthy(FirstWinConfig.confettiCount > 0)
	H.truthy(FirstWinConfig.coinCount <= 30)
	H.truthy(FirstWinConfig.bannerScale > 1)
end)

H.test("hint texts are short and match the plan", function()
	H.eq(Hints.text("aim"), "Drag back from your car and let go")
	H.eq(Hints.text("claw"), "Try the claw, first try is free")
	for _, id in Hints.Order do
		H.truthy(#Hints.text(id) <= 40)
	end
end)

H.test("aim nudge shows after 3 s without a drag", function()
	H.eq(Hints.AimNudgeSeconds, 3)
	H.eq(Hints.aimNudgeDue(2.9, false), false)
	H.truthy(Hints.aimNudgeDue(3, false))
	H.truthy(Hints.aimNudgeDue(6, false))
	H.eq(Hints.aimNudgeDue(6, true), false)
end)
