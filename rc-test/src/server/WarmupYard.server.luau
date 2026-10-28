--!strict
-- Car VS Car Smash: builds the WARM-UP YARD (WarmupYard) where kids waiting for the next round
-- drive. Only with Features.SMASH on. The "?" boxes (BoxServer) and target dummies (BOTS) join it
-- once those are in the game; MatchRunner moves waiting players in and out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local WarmupYard = require(ReplicatedStorage.Shared.WarmupYard)

if not (Features.CVC and (Features :: any).SMASH == true) then
	return
end

WarmupYard.build(workspace)
