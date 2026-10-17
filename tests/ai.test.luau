--!strict
local Harness = require("./harness")
local Ai = require("../src/shared/Ai")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("Ai")

local P = GameConfig.Ai
local me = { x = 0, z = 0 }
local enemy = { x = 0, z = -50 }

test("signedAngle: straight ahead is 0, left is positive", function()
	near(Ai.signedAngle(0, -1, 0, -10), 0)
	-- facing -Z, target at -X: Roblox +Y rotation (counter-clockwise from above) turns -Z toward -X
	truthy(Ai.signedAngle(0, -1, -10, 0) > 0)
	truthy(Ai.signedAngle(0, -1, 10, 0) < 0)
	near(math.abs(Ai.signedAngle(0, -1, 0, 10)), math.pi)
end)

test("steer is proportional and capped", function()
	near(Ai.steer(0.1, 6, 2), 0.6)
	near(Ai.steer(5, 6, 2), 2)
	near(Ai.steer(-5, 6, 2), -2)
end)

test("driveScale slows the gas when facing away, keeps reverse", function()
	near(Ai.driveScale(0, 1), 1)
	near(Ai.driveScale(math.pi, 1), 0.15)
	near(Ai.driveScale(1, -1), -1)
end)

test("Direct always aims at enemy with full gas", function()
	local mem = Ai.newMemory("Direct", 1)
	local c = Ai.decide("Direct", me, enemy, mem, 0.016, P)
	eq(c.tx, 0)
	eq(c.tz, -50)
	eq(c.throttle, 1)
end)

test("BackupCharge: charge, back up after a hit, then charge again", function()
	local mem = Ai.newMemory("BackupCharge", 1)
	eq(Ai.decide("BackupCharge", me, enemy, mem, 0.1, P).throttle, 1)
	mem.hit = true
	local c = Ai.decide("BackupCharge", me, enemy, mem, 0.1, P)
	eq(mem.phase, "backup")
	eq(c.throttle, -1)
	eq(mem.hit, false)
	for _ = 1, 20 do
		Ai.decide("BackupCharge", me, enemy, mem, 0.1, P)
	end
	eq(mem.phase, "charge")
end)

test("BackupCharge backs up when charge runs too long", function()
	local mem = Ai.newMemory("BackupCharge", 1)
	for _ = 1, 40 do
		Ai.decide("BackupCharge", me, enemy, mem, 0.1, P)
	end
	-- 4s > chargeMax(3): must have switched at least once
	truthy(mem.t < P.chargeMax + P.backupTime)
end)

test("CircleDive: circles, then dives, then flips side", function()
	local mem = Ai.newMemory("CircleDive", 1)
	eq(mem.phase, "circle")
	local c = Ai.decide("CircleDive", { x = 0, z = 0 }, { x = 0, z = -50 }, mem, 0.1, P)
	-- circle target is NOT the enemy itself
	truthy(c.tx ~= 0 or c.tz ~= -50)
	for _ = 1, 25 do
		Ai.decide("CircleDive", me, enemy, mem, 0.1, P)
	end
	eq(mem.phase, "dive")
	c = Ai.decide("CircleDive", me, enemy, mem, 0.1, P)
	eq(c.tx, 0)
	eq(c.tz, -50)
	mem.hit = true
	Ai.decide("CircleDive", me, enemy, mem, 0.1, P)
	eq(mem.phase, "circle")
	eq(mem.side, -1)
end)

test("CircleDive survives standing on top of the enemy", function()
	local mem = Ai.newMemory("CircleDive", 1)
	local c = Ai.decide("CircleDive", enemy, enemy, mem, 0.1, P)
	truthy(c.tx == c.tx and c.tz == c.tz, "no NaN")
end)
