--!strict
local Harness = require("./harness")
local PickupLogic = require("../src/shared/PickupLogic")
local Config = require("../src/shared/PickupsConfig")

local test, eq, near = Harness.test, Harness.eq, Harness.near

print("PickupLogic")

test("same kind refreshes, different kinds coexist", function()
	local b = PickupLogic.newBuffs()
	PickupLogic.apply(b, "speed", Config)
	PickupLogic.tick(b, 3)
	PickupLogic.apply(b, "shield", Config)
	near(b.speed, 2)
	near(b.shield, 6)
	PickupLogic.apply(b, "speed", Config)
	near(b.speed, 5)
end)

test("buffs expire", function()
	local b = PickupLogic.newBuffs()
	PickupLogic.apply(b, "speed", Config)
	PickupLogic.tick(b, 4.9)
	eq(PickupLogic.speedMult(b, Config), Config.speed.speedMult)
	PickupLogic.tick(b, 0.2)
	eq(PickupLogic.speedMult(b, Config), 1)
	eq(PickupLogic.has(b, "speed"), false)
end)

test("shield absorbs one hit then is gone", function()
	local b = PickupLogic.newBuffs()
	PickupLogic.apply(b, "shield", Config)
	eq(PickupLogic.absorb(b, 20), 0)
	eq(PickupLogic.absorb(b, 20), 20)
end)

test("big hit is used up by one hit", function()
	local b = PickupLogic.newBuffs()
	eq(PickupLogic.takeDamageMult(b, Config), 1)
	PickupLogic.apply(b, "bighit", Config)
	near(PickupLogic.peekDamageMult(b, Config), 1.6)
	near(PickupLogic.takeDamageMult(b, Config), 1.6)
	eq(PickupLogic.takeDamageMult(b, Config), 1)
end)

test("unknown kind is ignored", function()
	local b = PickupLogic.newBuffs()
	eq(PickupLogic.apply(b, "bogus", Config), 0)
	eq(next(b), nil)
end)

test("spawn timing", function()
	eq(PickupLogic.shouldSpawn(5, nil, 0, 6, 8, 2), false)
	eq(PickupLogic.shouldSpawn(6, nil, 0, 6, 8, 2), true)
	eq(PickupLogic.shouldSpawn(13, 6, 0, 6, 8, 2), false)
	eq(PickupLogic.shouldSpawn(14, 6, 1, 6, 8, 2), true)
	eq(PickupLogic.shouldSpawn(30, 6, 2, 6, 8, 2), false)
end)

test("pickSpot keeps distance and stays in the ring", function()
	local cars = { { x = 10, z = 0 } }
	local rolls = { { 0, 0.5 }, { 0.5, 0.5 } } -- first lands at (14,0): too close to the car
	local p = PickupLogic.pickSpot(rolls, 6, 22, cars, 14, {}, 10)
	assert(p ~= nil)
	near(p.x, -14, 1e-6)
	eq(PickupLogic.pickSpot({ { 0, 0.5 } }, 6, 22, cars, 14, {}, 10), nil)
	eq(PickupLogic.pickSpot({ { 0.5, 0.5 } }, 6, 22, {}, 14, { { x = -14, z = 0 } }, 10), nil)
end)

test("touches", function()
	eq(PickupLogic.touches(0, 0, 3, 4, 5), true)
	eq(PickupLogic.touches(0, 0, 3, 4.1, 5), false)
end)
