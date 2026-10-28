--!strict
-- ROCKETS (Car VS Car SMASH): 3 per pickup, fast, bend a little toward the nearest kart ahead;
-- 3 hits smash. Flight and booms: Flight.luau; numbers: shared/Weapons ROCKET.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))
local Flight = require(script.Parent:WaitForChild("Flight"))

return Flight.weapon("Rockets", Weapons)
