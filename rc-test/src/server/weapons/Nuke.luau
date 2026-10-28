--!strict
-- NUKE (Car VS Car SMASH): 1 per pickup, a slow big rocket with a huge boom that smashes a crowd.
-- Flight and booms: Flight.luau; numbers: shared/Weapons NUKE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))
local Flight = require(script.Parent:WaitForChild("Flight"))

return Flight.weapon("Nuke", Weapons)
