--!strict
-- Graphics quality fallback (audit #88): watches the average frame time and, on a slow device,
-- switches particle counts down (Effects, SkidFx, goal confetti, ball trail read `scale()`).
-- The rule is FeelRules.qualityStep (pure, tested). Client only, nothing is saved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FeelRules = require(ReplicatedStorage.Shared.FeelRules)

local Quality = {}

local state = FeelRules.newQuality()
local started = false

-- Call once at startup.
function Quality.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function(dt: number)
		FeelRules.qualityStep(state, dt)
	end)
end

-- 1 = full quality, 2 = low (slow device).
function Quality.level(): number
	return state.level
end

-- Multiply particle counts by this (1 on a normal device, less on a slow one).
function Quality.scale(): number
	return FeelRules.particleScale(state.level)
end

return Quality
