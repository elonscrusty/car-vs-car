--!strict
local Harness = require("./harness")
local CombatConfig = require("../src/shared/CombatConfig")
local Damage = require("../src/shared/Damage")

local test, eq, near = Harness.test, Harness.eq, Harness.near
local Z = CombatConfig.Zones
local C = CombatConfig.Combo

print("Damage")

test("zone from angle", function()
	-- victim looks -Z; attacker in front (-Z), behind (+Z) or beside (+X)
	eq(Damage.zone(Damage.cosFlat(0, -1, 0, -5), Z), "front")
	eq(Damage.zone(Damage.cosFlat(0, -1, 0, 5), Z), "back")
	eq(Damage.zone(Damage.cosFlat(0, -1, 5, 0), Z), "side")
	eq(Damage.zone(Damage.cosFlat(0, -1, -5, 0), Z), "side")
	eq(Damage.zone(Damage.cosFlat(0, 0, 1, 0), Z), "front")
end)

test("zone multipliers", function()
	near(Damage.zoneMult("front", Z), 1, 1e-9)
	near(Damage.zoneMult("side", Z), 1.5, 1e-9)
	near(Damage.zoneMult("back", Z), 2, 1e-9)
end)

test("combo chains and resets", function()
	local s = Damage.newCombo()
	eq(Damage.comboHit(s, 10, C.window), 1)
	eq(Damage.comboHit(s, 11, C.window), 2)
	eq(Damage.comboHit(s, 12, C.window), 3)
	eq(Damage.comboHit(s, 13, C.window), 4)
	eq(Damage.comboHit(s, 20, C.window), 1)
	near(Damage.comboMult(1, C.mults), 1, 1e-9)
	near(Damage.comboMult(2, C.mults), 1.25, 1e-9)
	near(Damage.comboMult(3, C.mults), 1.5, 1e-9)
	near(Damage.comboMult(9, C.mults), 1.5, 1e-9)
end)

test("thresholds crossed", function()
	local t = { 0.66, 0.33 }
	eq(#Damage.crossed(100, 80, 100, t), 0)
	eq(#Damage.crossed(100, 60, 100, t), 1)
	eq(#Damage.crossed(100, 20, 100, t), 2)
	eq(#Damage.crossed(60, 50, 100, t), 0)
	eq(Damage.crossed(60, 30, 100, t)[1], 2)
end)

test("final damage and tag", function()
	near(Damage.final(10, 2, 1.25, 1, 1), 25, 1e-9)
	near(Damage.final(10, 1, 1, 2, 1.5), 30, 1e-9)
	eq(Damage.tag("front", 1), nil)
	eq(Damage.tag("back", 1), "BACK HIT!")
	eq(Damage.tag("front", 2), "COMBO x2")
	eq(Damage.tag("side", 3), "SIDE HIT! COMBO x3")
end)
