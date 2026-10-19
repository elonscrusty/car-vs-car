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
	local r = Progress.applyMatchResult(p, "Sedan", false, ProgressConfig)
	H.eq(p.progress.carXp.Sedan, ProgressConfig.XpLoss)
	H.truthy(ProgressConfig.XpWin > ProgressConfig.XpLoss)
	H.eq(r.leveledUp, false)
	local up = false
	for _ = 1, 3 do
		if Progress.applyMatchResult(p, "Sedan", true, ProgressConfig).leveledUp then
			up = true
		end
	end
	H.truthy(up) -- 10 + 90 xp passes level 2 (50)
	H.eq(Progress.levelOf(p.progress, "Sedan"), 2)
	H.eq(Progress.levelOf(p.progress, "Kart"), 1)
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
		local r = Progress.applyMatchResult(p, "Sedan", true, ProgressConfig)
		bonuses[i] = r.coinsBonus - r.levelCoins -- streak part only
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
	local lost = Progress.applyMatchResult(p, "Sedan", false, ProgressConfig)
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
	local old = Inventory.migrate({ coins = 5, wins = 3, owned = { Sedan = true } })
	H.eq(old.progress.streak, 0)
	H.eq(next(old.progress.carXp), nil)
	local junk = Inventory.migrate({ progress = "x" })
	H.eq(junk.progress.streak, 0)
end)

H.test("saved progress is kept and cleaned", function()
	local p = Inventory.migrate({
		progress = { streak = 4.9, carXp = { Sedan = 120, Nope = 50, Kart = -3, Semi = "x" } },
	})
	H.eq(p.progress.streak, 4)
	H.eq(p.progress.carXp.Sedan, 120)
	H.eq(p.progress.carXp.Nope, nil)
	H.eq(p.progress.carXp.Kart, nil)
	local again = Inventory.migrate(p)
	H.eq(again.progress.carXp.Sedan, 120)
	local copy = Progress.copy(p.progress)
	copy.carXp.Sedan = 1
	H.eq(p.progress.carXp.Sedan, 120)
end)

H.test("level gives more hp and damage, level 1 is unchanged", function()
	local base: any = { hp = 100, damageMult = 1 }
	local one = Progress.applyLevel(base, 1)
	H.eq(one.hp, 100)
	H.eq(one.damageMult, 1)
	local ten = Progress.applyLevel(base, 10)
	H.eq(ten.hp, 109)
	H.near(ten.damageMult, 1.09, 1e-9)
	H.eq(base.hp, 100) -- input untouched
	H.eq(Progress.applyLevel(base, nil).hp, 100)
	H.eq(Progress.applyLevel(base, 99).hp, 109) -- clamped to max level
	H.eq(Progress.applyLevel(base, -5).hp, 100)
end)

H.test("level-up coins are paid once per level, included in the bonus", function()
	local c = ProgressConfig
	H.eq(Progress.levelCoins(1, 1), 0)
	H.eq(Progress.levelCoins(1, 2), c.LevelUpCoins[2])
	H.eq(Progress.levelCoins(1, 3), c.LevelUpCoins[2] + c.LevelUpCoins[3])
	local p = fresh()
	p.progress.carXp.Sedan = c.LevelXp[2] - c.XpWin
	local r = Progress.applyMatchResult(p, "Sedan", true, c)
	H.eq(r.leveledUp, true)
	H.eq(r.levelCoins, c.LevelUpCoins[2])
	H.eq(r.coinsBonus, c.LevelUpCoins[2]) -- streak 1 has no streak bonus
	local again = Progress.applyMatchResult(p, "Sedan", true, c)
	H.eq(again.levelCoins, 0)
end)

H.test("best streak keeps the record after a loss and survives clean/copy", function()
	local p = fresh()
	for _ = 1, 4 do
		Progress.applyMatchResult(p, "Sedan", true, ProgressConfig)
	end
	Progress.applyMatchResult(p, "Sedan", false, ProgressConfig)
	Progress.applyMatchResult(p, "Sedan", true, ProgressConfig)
	H.eq(p.progress.streak, 1)
	H.eq(p.progress.bestStreak, 4)
	H.eq(Progress.copy(p.progress).bestStreak, 4)
	H.eq(Progress.clean({ streak = 6, bestStreak = 2 }).bestStreak, 6)
	H.eq(Progress.clean({ bestStreak = "x" }).bestStreak, 0)
	H.eq(Progress.clean(nil).bestStreak, 0)
end)

H.test("weekend: coins x2 on Saturday and Sunday (UTC), x1 on other days", function()
	local day = 86400
	-- 2026-10-17 was a Saturday, 2026-10-18 a Sunday, 2026-10-19 a Monday.
	local sat = 20743 * day
	H.eq(Progress.coinMultiplier(sat + 3600), 2)
	H.eq(Progress.coinMultiplier(sat + day + 3600), 2)
	H.eq(Progress.coinMultiplier(sat + 2 * day + 3600), 1)
	H.eq(Progress.coinMultiplier(sat - day + 3600), 1)
end)

H.test("login streak: next day grows it, a missed day restarts, coins by day", function()
	local Daily = require("../src/shared/Daily")
	local d = Daily.default()
	local day = 86400
	H.eq(Daily.claim(d, 100 * day), true)
	H.eq(d.streak, 1)
	H.eq(Daily.claim(d, 100 * day + 5), false) -- same day: nothing
	H.eq(Daily.claim(d, 101 * day), true)
	H.eq(d.streak, 2)
	H.truthy(Daily.streakCoins(d) > 0)
	H.eq(Daily.claim(d, 103 * day), true) -- skipped a day
	H.eq(d.streak, 1)
	d.streak = 50
	H.eq(Daily.streakCoins(d), Daily.streakCoins({ lastDay = 0, freePulls = 0, streak = 7 }))
end)
