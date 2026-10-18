--!strict
local H = require("./harness")
local Abilities = require("../src/shared/Abilities")
local CarConfig = require("../src/shared/CarConfig")
local Comeback = require("../src/shared/Comeback")
local ComebackConfig = require("../src/shared/ComebackConfig")
local Fairness = require("../src/shared/Fairness")
local GameConfig = require("../src/shared/GameConfig")
local HitFeel = require("../src/shared/HitFeel")
local Pacing = require("../src/shared/Pacing")
local Progress = require("../src/shared/Progress")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("Fairness, pacing, hit feel, comeback")

test("fairness: only 2+ humans turn it on, and the flag can switch it off", function()
	truthy(not Fairness.neutral(0))
	truthy(not Fairness.neutral(1))
	truthy(Fairness.neutral(2))
	truthy(not Fairness.neutral(2, { neutralizeHumanMatches = false, humansNeeded = 2 }))
end)

test("fairness: level and rarity are neutral only in a fair match", function()
	eq(Fairness.level(9, false), 9)
	eq(Fairness.level(9, true), 1)
	eq(Fairness.rarity("Legendary", false), "Legendary")
	eq(Fairness.rarity("Legendary", true), "Common")
end)

test("fairness: a level 9 car equals a level 1 car, abilities are Common strength", function()
	local stats = CarConfig.Cars[CarConfig.Order[1]]
	local fairLevel = Fairness.level(9, true)
	eq(Progress.applyLevel(stats, fairLevel).hp, Progress.applyLevel(stats, 1).hp)
	truthy(Progress.applyLevel(stats, 9).hp > Progress.applyLevel(stats, 1).hp)
	local common = Abilities.resolve("Dash", Fairness.rarity("Legendary", true))
	local base = Abilities.resolve("Dash", "Common")
	eq((common :: any).dashForward, (base :: any).dashForward)
	eq((common :: any).cooldown, (base :: any).cooldown)
end)

test("pacing: first contact is under the target with the GameConfig numbers", function()
	local A, P = GameConfig.Arena, GameConfig.Pacing
	local slowest = math.huge
	for _, id in CarConfig.Order do
		slowest = math.min(slowest, CarConfig.Cars[id].maxSpeed)
	end
	local t = Pacing.firstContactSeconds(
		GameConfig.Match.aimTimeout,
		A.spawnRadius,
		GameConfig.Launch.minSpeed,
		slowest,
		P.detour
	)
	truthy(t < P.targetSeconds, "worst case first contact " .. t)
end)

test("pacing: a bigger gap or slower cars take longer", function()
	truthy(Pacing.travelSeconds(200, 100, 70, 1) > Pacing.travelSeconds(100, 100, 70, 1))
	truthy(Pacing.travelSeconds(100, 70, 60, 1) > Pacing.travelSeconds(100, 150, 90, 1))
	near(Pacing.travelSeconds(100, 50, 50, 1), 1)
	eq(Pacing.travelSeconds(100, 0, 0, 1), math.huge)
end)

test("pacing: the spawn spots and mode rings sit inside the smaller bowl", function()
	truthy(GameConfig.Arena.spawnRadius < GameConfig.Arena.rimRadius)
	truthy(GameConfig.Arena.rimRadius <= 90)
	truthy(GameConfig.Match.aimTimeout <= 6)
	truthy(GameConfig.Ai.maxRadius < GameConfig.Arena.rimRadius)
end)

test("hit feel: tiers by strength", function()
	local F = GameConfig.Feel
	eq(HitFeel.tier(0, F.flashFrom, F.strongFrom), 0)
	eq(HitFeel.tier(F.flashFrom, F.flashFrom, F.strongFrom), 1)
	eq(HitFeel.tier(F.strongFrom, F.flashFrom, F.strongFrom), 2)
	eq(HitFeel.tier(1, F.flashFrom, F.strongFrom), 2)
	near(HitFeel.emphasis(1, 0.25), 1)
	near(HitFeel.emphasis(0.1, 0.25), 0)
end)

test("comeback: only under the HP line, once", function()
	truthy(Comeback.canPop(25, 100, false))
	truthy(Comeback.canPop(10, 100, false))
	truthy(not Comeback.canPop(26, 100, false))
	truthy(not Comeback.canPop(10, 100, true))
	truthy(not Comeback.canPop(0, 100, false), "dead car")
	truthy(not Comeback.canPop(10, 100, false, { enabled = false, belowFrac = 0.25 }))
end)

test("comeback: the speed pop is short and fades out", function()
	local c = ComebackConfig
	near(Comeback.speedMult(0), 1 + c.speedBonus)
	truthy(Comeback.speedMult(c.seconds / 2) < Comeback.speedMult(0))
	truthy(Comeback.speedMult(c.seconds / 2) > 1)
	eq(Comeback.speedMult(c.seconds), 1)
	eq(Comeback.speedMult(-math.huge), 1)
	eq(Comeback.speedMult(math.huge), 1)
	near(Comeback.maxMult(), 1 + c.speedBonus)
	truthy(c.enabled, "default on")
end)
