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

-- Each level above 1 adds this much HP and hit damage (0.03 = +3% per level, +27% at level 10).
ProgressConfig.LevelStatBonus = 0.03

-- One-time coins paid when a car reaches a level (index = level). PLACEHOLDER numbers.
ProgressConfig.LevelUpCoins = { 0, 20, 30, 40, 50, 60, 80, 100, 130, 200 }

-- Leaderboards (Leaderboards.luau): how many rows, how often the board refreshes (seconds).
ProgressConfig.Board = {
	rows = 10,
	refreshSeconds = 60,
	minSubmitGap = 20,
	spot = { x = -24, z = -60 }, -- middle of the two boards, relative to the lobby origin (move if it hides behind a prop)
}

-- Rank by total wins, best first.
ProgressConfig.Ranks = {
	{ name = "Gold", minWins = 100 },
	{ name = "Silver", minWins = 25 },
	{ name = "Bronze", minWins = 0 },
}

-- Level-badge looks (Badge.luau): from these levels the car gets a shinier trim.
ProgressConfig.TrimLevels = { 4, 7, 10 }

return ProgressConfig
