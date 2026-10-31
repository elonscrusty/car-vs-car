--!strict
-- Every bot in a round gets its own paint (BotPaints: carter 10-30 picked "Candy Bright").
local H = require("./harness")
local BotPaints = require("../src/shared/BotPaints")

local test, eq = H.test, H.eq

print("Bot paints")

test("the first 7 bots (a full round) all wear different paints", function()
	local seen: { [string]: boolean } = {}
	for n = 1, 7 do
		local c = BotPaints.forBot(n)
		local key = `{c[1]},{c[2]},{c[3]}`
		eq(seen[key], nil)
		seen[key] = true
	end
end)

test("paints wrap round past the list", function()
	eq(BotPaints.forBot(#BotPaints.LIST + 1), BotPaints.forBot(1))
end)
