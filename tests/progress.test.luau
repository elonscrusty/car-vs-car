--!strict
local H = require("./harness")
local Inventory = require("../src/shared/Inventory")
local Progress = require("../src/shared/Progress")
local ProgressConfig = require("../src/shared/ProgressConfig")

print("Progress")

local function fresh(): any
	return Inventory.default()
end

H.test("levels follow the xp thresholds", function()
	H.eq(Progress.levelForXp(0), 1)
	H.eq(Progress.levelForXp(ProgressConfig.LevelXp[2] - 1), 1)
	H.eq(Progress.levelForXp(ProgressConfig.LevelXp[2]), 2)
	H.eq(Progress.levelForXp(1e9), 10)
	H.eq(Progress.maxLevel(), 10)
	for i = 2, #ProgressConfig.LevelXp do
		H.truthy(ProgressConfig.LevelXp[i] > ProgressConfig.LevelXp[i - 1])
	end
end)

H.test("win gives more xp than loss and reports level up", function()
	local p = fresh()
	local r = Progress.applyMatchResult(p, "Heavy", false, ProgressConfig)
	H.eq(p.progress.carXp.Heavy, ProgressConfig.XpLoss)
	H.truthy(ProgressConfig.XpWin > ProgressConfig.XpLoss)
	H.eq(r.leveledUp, false)
	local up = false
	for _ = 1, 3 do
		if Progress.applyMatchResult(p, "Heavy", true, ProgressConfig).leveledUp then
			up = true
		end
	end
	H.truthy(up) -- 10 + 90 xp passes level 2 (50)
	H.eq(Progress.levelOf(p.progress, "Heavy"), 2)
	H.eq(Progress.levelOf(p.progress, "Ramp"), 1)
end)

H.test("unknown car ids gain no xp", function()
	local p = fresh()
	Progress.applyMatchResult(p, "Nope", true, ProgressConfig)
	H.eq(next(p.progress.carXp), nil)
end)

H.test("streak bonus at 3, 5 and 7+, reset on a loss", function()
	local p = fresh()
	local bonuses = {}
	for i = 1, 8 do
		bonuses[i] = Progress.applyMatchResult(p, "Heavy", true, ProgressConfig).coinsBonus
	end
	H.eq(bonuses[1], 0)
	H.eq(bonuses[2], 0)
	H.eq(bonuses[3], ProgressConfig.StreakBonus[3])
	H.eq(bonuses[4], 0)
	H.eq(bonuses[5], ProgressConfig.StreakBonus[5])
	H.eq(bonuses[6], 0)
	H.eq(bonuses[7], ProgressConfig.StreakBonusMax)
	H.eq(bonuses[8], ProgressConfig.StreakBonusMax)
	H.eq(p.progress.streak, 8)
	local lost = Progress.applyMatchResult(p, "Heavy", false, ProgressConfig)
	H.eq(lost.coinsBonus, 0)
	H.eq(lost.streak, 0)
	H.eq(p.progress.streak, 0)
end)

H.test("rank by wins", function()
	H.eq(Progress.rankFor(0), "Bronze")
	H.eq(Progress.rankFor(24), "Bronze")
	H.eq(Progress.rankFor(25), "Silver")
	H.eq(Progress.rankFor(99), "Silver")
	H.eq(Progress.rankFor(100), "Gold")
end)

H.test("old saves migrate with empty progress", function()
	local old = Inventory.migrate({ coins = 5, wins = 3, owned = { Heavy = true } })
	H.eq(old.progress.streak, 0)
	H.eq(next(old.progress.carXp), nil)
	local junk = Inventory.migrate({ progress = "x" })
	H.eq(junk.progress.streak, 0)
end)

H.test("saved progress is kept and cleaned", function()
	local p = Inventory.migrate({
		progress = { streak = 4.9, carXp = { Heavy = 120, Nope = 50, Ramp = -3, Spike = "x" } },
	})
	H.eq(p.progress.streak, 4)
	H.eq(p.progress.carXp.Heavy, 120)
	H.eq(p.progress.carXp.Nope, nil)
	H.eq(p.progress.carXp.Ramp, nil)
	local again = Inventory.migrate(p)
	H.eq(again.progress.carXp.Heavy, 120)
	local copy = Progress.copy(p.progress)
	copy.carXp.Heavy = 1
	H.eq(p.progress.carXp.Heavy, 120)
end)
