--!strict
-- Plays the phone buzz (shared/Buzz). Roblox only exposes motors on a gamepad, so this rumbles a
-- pad and tries the touch device too; every call is guarded, so a device without it does nothing.
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")

local Buzz = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Buzz"))

local player = Players.LocalPlayer
local last = -math.huge

local function motor(input: Enum.UserInputType, kind: Buzz.Kind): boolean
	local ok, supported = pcall(function()
		return HapticService:IsVibrationSupported(input)
			and HapticService:IsMotorSupported(input, Enum.VibrationMotor.Large)
	end)
	if not ok or not supported then
		return false
	end
	pcall(HapticService.SetMotor, HapticService, input, Enum.VibrationMotor.Large, kind.strength)
	task.delay(kind.seconds, function()
		pcall(HapticService.SetMotor, HapticService, input, Enum.VibrationMotor.Large, 0)
	end)
	return true
end

local M = {}

function M.play(kind: Buzz.Kind)
	local now = os.clock()
	if not Buzz.ready(last, now, player:GetAttribute(Buzz.ATTR) == true) then
		return
	end
	last = now
	if not motor(Enum.UserInputType.Touch, kind) then
		motor(Enum.UserInputType.Gamepad1, kind)
	end
end

function M.hit()
	M.play(Buzz.HIT)
end
function M.smash()
	M.play(Buzz.SMASH)
end

return M
