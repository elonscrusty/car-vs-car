--!strict
-- Watches the frame rate and sets workspace attribute "FxLevel" (1, 0.5 or 0.25) for the dust,
-- sparks and sparkles to read (shared/FxLevel). Phones that keep up stay at 1. No menu.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxLevel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FxLevel"))

local s = FxLevel.new()
workspace:SetAttribute("FxLevel", 1)
RunService.RenderStepped:Connect(function(dt)
	if FxLevel.tick(s, dt) then
		workspace:SetAttribute("FxLevel", FxLevel.level(s))
	end
end)
