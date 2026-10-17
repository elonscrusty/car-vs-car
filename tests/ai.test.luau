--!strict
local Harness = require("./harness")
local Ai = require("../src/shared/Ai")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("Ai")

local P = GameConfig.Ai
local C = { x = 0, z = 0 } -- bowl center
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
	local c = Ai.decide("Direct", me, enemy, mem, 0.016, P, C)
	eq(c.tx, 0)
	eq(c.tz, -50)
	eq(c.throttle, 1)
end)

test(
	"BackupCharge: charges, drives away after a hit (forward, not reverse), then charges",
	function()
		local mem = Ai.newMemory("BackupCharge", 1)
		local c = Ai.decide("BackupCharge", me, enemy, mem, 0.1, P, C)
		eq(c.throttle, 1)
		eq(c.tz, -50)
		mem.hit = true
		c = Ai.decide("BackupCharge", { x = 0, z = -10 }, enemy, mem, 0.1, P, C)
		truthy(mem.retreatT > 0)
		eq(c.throttle, 1, "run-up uses forward gas")
		truthy(c.tz > -10, "aims away from the enemy")
		for _ = 1, 40 do
			Ai.decide("BackupCharge", me, enemy, mem, 0.1, P, C)
		end
		c = Ai.decide("BackupCharge", me, enemy, mem, 0.1, P, C)
		eq(c.tz, -50, "back to charging")
	end
)

test("BackupCharge runs away when a charge goes on too long", function()
	local mem = Ai.newMemory("BackupCharge", 1)
	for _ = 1, 40 do
		Ai.decide("BackupCharge", me, enemy, mem, 0.1, P, C)
	end
	truthy(mem.retreatT > 0 or mem.t < P.chargeMax)
end)

test("retreatTarget goes away from enemy and stays inside the bowl", function()
	local tx, tz = Ai.retreatTarget({ x = 0, z = 10 }, { x = 0, z = 0 }, C, P)
	near(tx, 0)
	near(tz, 10 + P.retreatDist)
	tx, tz = Ai.retreatTarget({ x = 0, z = 40 }, { x = 0, z = 0 }, C, P)
	near(math.sqrt(tx * tx + tz * tz), P.maxRadius, 1e-6)
	tx, tz = Ai.retreatTarget({ x = 3, z = 3 }, { x = 3, z = 3 }, C, P)
	truthy(tx == tx and tz == tz, "no NaN")
end)

test("CircleDive: circles, then dives, then flips side", function()
	local mem = Ai.newMemory("CircleDive", 1)
	eq(mem.phase, "circle")
	local c = Ai.decide("CircleDive", { x = 0, z = 0 }, { x = 0, z = -50 }, mem, 0.1, P, C)
	-- circle target is NOT the enemy itself
	truthy(c.tx ~= 0 or c.tz ~= -50)
	for _ = 1, 25 do
		Ai.decide("CircleDive", me, enemy, mem, 0.1, P, C)
	end
	eq(mem.phase, "dive")
	c = Ai.decide("CircleDive", me, enemy, mem, 0.1, P, C)
	eq(c.tx, 0)
	eq(c.tz, -50)
	mem.hit = true
	Ai.decide("CircleDive", me, enemy, mem, 0.1, P, C)
	eq(mem.phase, "circle")
	eq(mem.side, -1)
end)

test("CircleDive survives standing on top of the enemy", function()
	local mem = Ai.newMemory("CircleDive", 1)
	local c = Ai.decide("CircleDive", enemy, enemy, mem, 0.1, P, C)
	truthy(c.tx == c.tx and c.tz == c.tz, "no NaN")
end)

test("Direct drives away after a hit, then charges again", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.hit = true
	local c = Ai.decide("Direct", { x = 0, z = -10 }, enemy, mem, 0.1, P, C)
	eq(c.throttle, 1)
	truthy(c.tz > -10, "aims away from the enemy")
	for _ = 1, 40 do
		Ai.decide("Direct", me, enemy, mem, 0.1, P, C)
	end
	eq(Ai.decide("Direct", me, enemy, mem, 0.1, P, C).tz, -50)
end)

test("noteSpeed: stuck for a while triggers a run-up, moving resets", function()
	local mem = Ai.newMemory("Direct", 1)
	Ai.noteSpeed(mem, 0, 0.5, 0.8, 1)
	eq(mem.retreatT, 0)
	Ai.noteSpeed(mem, 20, 0.1, 0.8, 1)
	eq(mem.stuckT, 0)
	Ai.noteSpeed(mem, 0, 0.5, 0.8, 1)
	Ai.noteSpeed(mem, 0, 0.5, 0.8, 1)
	eq(mem.retreatT, 1)
	local c = Ai.decide("Direct", { x = 0, z = -10 }, enemy, mem, 0.1, P, C)
	eq(c.throttle, 1)
	truthy(c.tz > -10)
end)
