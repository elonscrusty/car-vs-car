--!strict
-- NameTagLook: the rules behind the name tag over a kart (carter's pick: New Classic).

local H = require("./harness")
local Look = require("../src/shared/NameTagLook")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Name tag look")

test("the star is blue, purple from level 10 and gold from level 25; junk is blue", function()
	eq(Look.tier(1), 1)
	eq(Look.tier(9), 1)
	eq(Look.tier(10), 2)
	eq(Look.tier(24), 2)
	eq(Look.tier(25), 3)
	eq(Look.tier(300), 3)
	eq(Look.tier(nil), 1)
	eq(Look.tier(0 / 0), 1)
	for t = 1, 3 do
		eq(#Look.STAR[t], 2)
	end
end)

test("health is 0..1 of the most; junk shows full; throbs only while alive and low", function()
	eq(Look.fraction(100, 100), 1)
	eq(Look.fraction(34, 100), 0.34)
	eq(Look.fraction(-5, 100), 0)
	eq(Look.fraction(500, 100), 1)
	eq(Look.fraction(nil, 100), 1)
	eq(Look.fraction(0 / 0, 100), 1)
	eq(Look.fraction(50, 0), 1)
	truthy(Look.isLow(0.2))
	truthy(not Look.isLow(0.35))
	truthy(not Look.isLow(0))
	truthy(not Look.isLow(1))
end)

test("long names are cut with an ellipsis, short ones are left, bad text never errors", function()
	eq(Look.shortName("MIA"), "MIA")
	eq(Look.shortName("TURBO TIM"), "TURBO TIM")
	eq(Look.shortName("123456789012"), "123456789012")
	eq(Look.shortName("xXDRIFTKINGXx"), "xXDRIFTKING…")
	eq(Look.shortName("ÅÅÅÅÅÅÅÅÅÅÅÅÅÅ"), "ÅÅÅÅÅÅÅÅÅÅÅ…")
	truthy(#Look.shortName("\255\254\253") > 0)
end)

test("the crown goes to the most smashes (a tie shares it) and to nobody at 0", function()
	local none = Look.leaders({ [1] = 0, [2] = 0 })
	eq(next(none), nil)
	local one = Look.leaders({ [1] = 3, [2] = 1, [-4] = 0 })
	eq(one[1], true)
	eq(one[2], nil)
	local tie = Look.leaders({ [1] = 2, [2] = 2, [3] = 1 })
	truthy(tie[1] == true and tie[2] == true and tie[3] == nil)
	eq(next(Look.leaders({})), nil)
end)
