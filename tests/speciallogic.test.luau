--!strict
local H = require("./harness")
local SpecialLogic = require("../src/shared/SpecialLogic")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("SpecialLogic")

test("cooldown counts down to zero", function()
	eq(SpecialLogic.cooldownLeft(10, 4), 6)
	eq(SpecialLogic.cooldownLeft(10, 12), 0)
end)

test("falloff is 1 at centre, 0 at the edge", function()
	near(SpecialLogic.falloff(0, 20), 1)
	near(SpecialLogic.falloff(10, 20), 0.5)
	eq(SpecialLogic.falloff(20, 20), 0)
	eq(SpecialLogic.falloff(5, 0), 0)
end)

test("heavier targets move less, within clamp", function()
	near(SpecialLogic.massScale(60, 60, 0.4, 1.6), 1)
	near(SpecialLogic.massScale(120, 60, 0.4, 1.6), 0.5)
	near(SpecialLogic.massScale(1000, 60, 0.4, 1.6), 0.4)
	near(SpecialLogic.massScale(10, 60, 0.4, 1.6), 1.6)
end)

test("cone checks angle and reach", function()
	truthy(SpecialLogic.inCone(0, -1, 0, -10, 20, 35))
	eq(SpecialLogic.inCone(0, -1, 0, -30, 20, 35), false)
	eq(SpecialLogic.inCone(0, -1, 0, 10, 20, 35), false)
	eq(SpecialLogic.inCone(0, -1, 10, -10, 20, 35), false)
	truthy(SpecialLogic.inCone(0, -1, 3, -10, 20, 35))
end)

test("damage bonus expires", function()
	eq(SpecialLogic.damageMult(5, 3, 2), 2)
	eq(SpecialLogic.damageMult(5, 5, 2), 1)
end)
