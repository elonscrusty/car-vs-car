--!strict
-- A quiet hum for every kind of training station that has a car on it, heard only near your own
-- plot (it fades out by SoundLevels.HUM_RANGE studs). Uses the motor loop the cars already have.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Features = require(ReplicatedStorage.Shared.Features)
if not Features.CVC then
	return
end

local PlotTraining = require(ReplicatedStorage.Shared.PlotTraining)
local SoundLevels = require(ReplicatedStorage.Shared.SoundLevels)

local MOTOR_SOUND = "rbxassetid://137730930796096" -- "ENV Electric Motor Steady" (Effects.luau)
local PITCH = { treadmill = 0.8, ramp = 1.0, track = 1.25 } -- each kind hums its own note

local me = Players.LocalPlayer
local hums: { [string]: Sound } = {}

local function hum(kind: string): Sound
	local s = hums[kind]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Hum_" .. kind
		s.SoundId = MOTOR_SOUND
		s.Looped = true
		s.Volume = 0
		s.PlaybackSpeed = PITCH[kind] or 1
		s.Parent = SoundService
		s:Play()
		hums[kind] = s
	end
	return s
end

local function myPlot(plots: Instance): Instance?
	for _, p in plots:GetChildren() do
		if tonumber(p:GetAttribute("OwnerId")) == me.UserId then
			return p
		end
	end
	return nil
end

local plots = workspace:WaitForChild("Plots")
task.spawn(function()
	while true do
		task.wait(0.25)
		local want: { [string]: boolean } = {}
		local plot = myPlot(plots)
		local char = me.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if plot and plot:IsA("Model") and root and root:IsA("BasePart") then
			local near = SoundLevels.humAt((plot:GetPivot().Position - root.Position).Magnitude)
			if near > 0 then
				for _, pad in PlotTraining.parse(tostring(plot:GetAttribute("Stations") or "")) do
					if pad.car ~= "" then
						want[pad.kind] = true
						hum(pad.kind).Volume = near
					end
				end
			end
		end
		for kind, s in hums do
			if not want[kind] then
				s.Volume = 0
			end
		end
	end
end)
