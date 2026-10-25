--!strict
local H = require("./harness")
local Fight = require("../src/shared/Fight")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Fight")

test("counter: tap right before a hit counts", function()
	local s = Fight.newCounter()
	truthy(Fight.tap(s, 10, 4))
	truthy(Fight.isCountered(s, 10.2, 0.25))
end)

test("counter: late hit is not countered", function()
	local s = Fight.newCounter()
	Fight.tap(s, 10, 4)
	eq(Fight.isCountered(s, 10.4, 0.25), false)
end)

test("counter: never tapped is not countered", function()
	eq(Fight.isCountered(Fight.newCounter(), 5, 0.25), false)
end)

test("counter: spamming taps does not extend the window (cooldown)", function()
	local s = Fight.newCounter()
	truthy(Fight.tap(s, 10, 4))
	eq(Fight.tap(s, 10.2, 4), false)
	eq(Fight.isCountered(s, 10.5, 0.25), false)
	truthy(Fight.tap(s, 14.1, 4))
end)

test("counter: blocks only one hit", function()
	local s = Fight.newCounter()
	Fight.tap(s, 1, 4)
	truthy(Fight.isCountered(s, 1.1, 0.25))
	Fight.consume(s)
	eq(Fight.isCountered(s, 1.15, 0.25), false)
end)

test("counter damage is reduced", function()
	H.near(Fight.counterDamage(20, 0.35), 7)
end)

test("ring-out only past rim + margin", function()
	eq(Fight.isRingOut(60, 62, 3), false)
	eq(Fight.isRingOut(65, 62, 3), false)
	truthy(Fight.isRingOut(65.1, 62, 3))
end)

test("cone: in front and close", function()
	truthy(Fight.inCone(10, 0.9, 24, 0.7))
	eq(Fight.inCone(30, 0.9, 24, 0.7), false)
	eq(Fight.inCone(10, 0.2, 24, 0.7), false)
end)

test("falloff is 1 at center, 0 at edge and beyond", function()
	H.near(Fight.falloff(0, 28), 1)
	H.near(Fight.falloff(14, 28), 0.5)
	H.near(Fight.falloff(40, 28), 0)
	H.near(Fight.falloff(5, 0), 0)
end)

test("special ready only after cooldown", function()
	truthy(Fight.canSpecial(0))
	eq(Fight.canSpecial(0.1), false)
end)
