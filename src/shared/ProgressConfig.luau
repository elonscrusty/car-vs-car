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

-- Each level above 1 adds this much HP and hit damage (0.01 = +1% per level, +9% at level 10).
-- PLACEHOLDER: kept tiny on purpose (audit #50); levels unlock cosmetics instead
-- (CarCatalog.LevelCosmetics).
ProgressConfig.LevelStatBonus = 0.01

-- One-time coins paid when a car reaches a level (index = level). PLACEHOLDER numbers.
ProgressConfig.LevelUpCoins = { 0, 20, 30, 40, 50, 60, 80, 100, 130, 200 }

-- Weekend: every coin a fight pays is multiplied (UTC days, 1 = Sunday .. 7 = Saturday). PLACEHOLDER.
ProgressConfig.Weekend = { multiplier = 2, days = { 1, 7 } :: { number } }

-- Leaderboards (Leaderboards.luau): how many rows, how often the board refreshes (seconds).
ProgressConfig.Board = {
	rows = 5, -- few rows = big, easy-to-read text
	refreshSeconds = 60,
	minSubmitGap = 20,
	spot = { x = -10, z = -94.8 }, -- middle of the row of boards on the back wall (floor point in front of the wall), relative to the lobby origin
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
