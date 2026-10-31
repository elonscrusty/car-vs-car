--!strict
-- Starts the streak fire (client/StreakFire): every car with 3+ smashes in a row burns.
local StreakFire = require(script.Parent:WaitForChild("StreakFire"))

StreakFire.watch()
