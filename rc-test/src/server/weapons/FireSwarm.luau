--!strict
-- FIRE SWARM, the special (not a pickup: it is not in Weapons.NAMES). WeaponServer loads it and
-- runs it from the SpecialFire remote; the engine is Swarm.luau, the numbers shared/FireSwarm.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local Data = require(Shared:WaitForChild("FireSwarm"))
local Swarm = require(script.Parent:WaitForChild("Swarm"))

return Swarm.weapon(Weapons, Data)
