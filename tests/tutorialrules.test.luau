--!strict
local H = require("./harness")
local Hints = require("../src/shared/Hints")
local Rules = require("../src/shared/TutorialRules")
local Config = require("../src/shared/TutorialConfig")

print("TutorialRules")

H.test("starting saves the tutorial flag at once, plus the two old hints it replaces", function()
	local seen: Hints.Seen = {}
	H.truthy(Rules.markStart(seen))
	H.truthy(seen.tutorial)
	H.truthy(seen.pad)
	H.truthy(seen.claw)
	H.eq(seen.aim, nil)
	H.eq(seen.tutorialDone, nil)
	-- a second start changes nothing
	H.eq(Rules.markStart(seen), false)
end)

H.test("a player who already saw the PLAY hint still gets the missing flags", function()
	local seen: Hints.Seen = { pad = true, claw = true }
	H.truthy(Rules.markStart(seen))
	H.truthy(seen.tutorial)
end)

H.test("the coin gift: once, and not before the tutorial could have been played", function()
	local seen: Hints.Seen = {}
	local ok, why = Rules.canGift(seen, nil, 1000)
	H.eq(ok, false)
	H.eq(why, "not started")
	ok, why = Rules.canGift(seen, 1000, 1000 + Config.minGiftSeconds - 1)
	H.eq(ok, false)
	H.eq(why, "too fast")
	ok, why = Rules.canGift(seen, 1000, 1000 + Config.minGiftSeconds)
	H.eq(ok, true)
	H.eq(why, nil)
	Rules.markGift(seen)
	H.truthy(seen.tutorialDone)
	ok, why = Rules.canGift(seen, 1000, 5000)
	H.eq(ok, false)
	H.eq(why, "paid")
end)

H.test("the practice yard: not while fighting, not twice", function()
	H.truthy(Rules.mayPractice(false, false))
	H.eq(Rules.mayPractice(true, false), false)
	H.eq(Rules.mayPractice(false, true), false)
	H.eq(Rules.mayPractice(true, true), false)
end)

H.test("both flags are real saved hint ids (unknown ids would be dropped on save)", function()
	H.truthy(Hints.isKnown("tutorial"))
	H.truthy(Hints.isKnown("tutorialDone"))
	local clean = Hints.clean({ tutorial = true, tutorialDone = true })
	H.truthy(clean.tutorial)
	H.truthy(clean.tutorialDone)
end)
