--!strict
-- Makes every legend car's glow (CarGlow, tag "CarGlowPulse") breathe, on this screen only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CarGlow = require(ReplicatedStorage.Shared.CarGlow)

local BREATH = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function add(inst: Instance)
	if not inst:IsA("PointLight") then
		return
	end
	local base = inst:GetAttribute("Base")
	local b = if type(base) == "number" then base else inst.Brightness
	inst.Brightness = b * 0.4
	TweenService:Create(inst, BREATH, { Brightness = b * 1.6, Range = inst.Range * 1.25 }):Play()
end

for _, l in CollectionService:GetTagged(CarGlow.PULSE_TAG) do
	add(l)
end
CollectionService:GetInstanceAddedSignal(CarGlow.PULSE_TAG):Connect(add)
