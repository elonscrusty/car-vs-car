--!strict
-- Numbers for car levels, win streaks and rank badges. Placeholder values: change freely.

local ProgressConfig = {}

ProgressConfig.XpWin = 30
ProgressConfig.XpLoss = 10

-- Total XP needed to reach level i (index 1 = level 1). Length = max level.
ProgressConfig.LevelXp = { 0, 50, 120, 210, 320, 450, 600, 780, 1000, 1250 }

-- Extra coins on top of the win reward, by win streak.
ProgressConfig.StreakBonus = { [3] = 20, [5] = 40 } :: { [number]: number }
ProgressConfig.StreakBonusFrom = 7 -- from this streak on, every win pays StreakBonusMax
ProgressConfig.StreakBonusMax = 60

-- Rank by total wins, best first.
ProgressConfig.Ranks = {
	{ name = "Gold", minWins = 100 },
	{ name = "Silver", minWins = 25 },
	{ name = "Bronze", minWins = 0 },
}

-- Level-badge looks (Badge.luau): from these levels the car gets a shinier trim.
ProgressConfig.TrimLevels = { 4, 7, 10 }

return ProgressConfig
