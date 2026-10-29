--!nocheck
-- Car VS Car SMASH: a round's pay reaches the coin chip. The garage and lobby read the player's
-- Coins attribute; it must match the save after every round (Studio round 5: 25 shown, 75 saved
-- after 3 rounds). A kid who doesn't level up (a level-up also sets Coins) shows the bug.
local H = require("./harness")
local Fake = require("./fakeroblox")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: round pay on the coin chip")

test("3 rounds: Coins on the player = coins in the save after each one", function()
	local S = Fake.server(Fake.store(), { jobId = "coins-chip" })
	S.require("Shared.Features").SMASH = true
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	local MR = S.require("MatchRunner")
	local PlayerData = S.require("PlayerData")
	MR.MATCH_SECS = 20
	local kid = S.join(901)
	S.advance(3, 0.1)
	local data = PlayerData.get(kid)
	MR.join(kid)
	for n = 1, 3 do
		for _ = 1, 200 do
			if #S.got(kid, "MatchResult") >= n then
				break
			end
			S.advance(0.5, 0.1)
		end
		eq(#S.got(kid, "MatchResult"), n, `round {n} over`)
		truthy(data.coins > 0, "paid")
		eq(kid:GetAttribute("Coins"), data.coins, `the chip after round {n}`)
	end
	eq(#S.errors, 0, "errors")
end)
