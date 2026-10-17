--!strict
local Harness = require("./harness")
local BowlConfig = require("../src/shared/BowlConfig")
local BowlRules = require("../src/shared/BowlRules")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("BowlRules")

test("only strong hits are a smash", function()
	truthy(BowlRules.isSmash(0.6, BowlConfig.Smash.from))
	truthy(not BowlRules.isSmash(0.3, BowlConfig.Smash.from))
	local up, spin = BowlRules.smashPop(0.3, BowlConfig.Smash)
	eq(up, 0)
	eq(spin, 0)
	local up2, spin2 = BowlRules.smashPop(1, BowlConfig.Smash)
	eq(up2, BowlConfig.Smash.upSpeed)
	eq(spin2, BowlConfig.Smash.spin)
end)

test("pad spots are evenly spaced on the ring", function()
	local spots = BowlRules.padSpots(4, 40, 0.5)
	eq(#spots, 4)
	for _, s in spots do
		near(math.sqrt(s.x ^ 2 + s.z ^ 2), 40, 0.001)
	end
	near(spots[1].x * spots[3].x + spots[1].z * spots[3].z, -1600, 0.001) -- opposite pads
end)

test("a car on a pad is launched toward the middle", function()
	local pad = { x = 40, z = 0 }
	truthy(BowlRules.onPad({ x = 38, z = 2 }, pad, 5.5))
	truthy(not BowlRules.onPad({ x = 20, z = 0 }, pad, 5.5))
	local vx, vy, vz = BowlRules.padLaunch(pad, 60, 30)
	near(vx, -60, 0.001)
	eq(vy, 30)
	near(vz, 0, 0.001)
end)

test("the safe ring waits, then closes, then stops", function()
	local sh = BowlConfig.Shrink
	eq(BowlRules.safeRadius(0, 62, sh), 62)
	eq(BowlRules.safeRadius(sh.startSeconds, 62, sh), 62)
	local mid = BowlRules.safeRadius(sh.startSeconds + sh.overSeconds / 2, 62, sh)
	truthy(mid < 62 and mid > sh.minRadius)
	eq(BowlRules.safeRadius(999, 62, sh), sh.minRadius)
end)

test("outside the ring hurts, inside is safe", function()
	eq(BowlRules.ringDamage(20, 30, 9, 0.5), 0)
	near(BowlRules.ringDamage(40, 30, 9, 0.5), 4.5, 0.001)
end)

test("drift gives cooldown back only while sliding", function()
	eq(BowlRules.driftRefund(false, 1, 1.4), 0)
	near(BowlRules.driftRefund(true, 0.5, 1.4), 0.7, 0.001)
end)

test("the magnet pulls only inside its range, harder when closer", function()
	eq(BowlRules.magnetPull(100, 48, 26, 1), 0)
	truthy(BowlRules.magnetPull(10, 48, 26, 1) > BowlRules.magnetPull(40, 48, 26, 1))
end)
