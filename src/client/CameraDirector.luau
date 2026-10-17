--!strict
-- Camera: fixed overview of the bowl, shakes on big hits, and a push-in on the crash dummy at a KO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CameraDirector = {}

export type Director = {
	overview: (center: Vector3) -> (),
	focus: (target: BasePart?) -> (), -- KO: follow the dummy and zoom in
	shake: (strength: number) -> (), -- 0..1
	release: () -> (), -- back to the normal Roblox camera (lobby)
}

function CameraDirector.new(): Director
	local feel = GameConfig.Feel
	local rng = Random.new()
	local base = CFrame.identity
	local active = false
	local target: BasePart? = nil
	local goalFov = feel.normalFov
	local fov = feel.normalFov
	local shakeLeft, shakeSize = 0, 0

	local function cam(): Camera
		return workspace.CurrentCamera :: Camera
	end

	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		local t = target
		if t ~= nil and t.Parent ~= nil then
			local pos = t.Position
			local goal = CFrame.lookAt(pos + Vector3.new(0, feel.koCamUp, feel.koCamBack), pos)
			base = base:Lerp(goal, math.min(1, dt * 7))
		end
		fov += (goalFov - fov) * math.min(1, dt * 4)
		local c = cam()
		c.FieldOfView = fov
		local offset = Vector3.zero
		if shakeLeft > 0 then
			shakeLeft = math.max(0, shakeLeft - dt)
			local k = shakeSize * (shakeLeft / feel.shakeTime)
			offset = Vector3.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
		end
		c.CFrame = base * CFrame.new(offset)
	end)

	local function overview(center: Vector3)
		target = nil
		active = true
		goalFov, fov = feel.normalFov, feel.normalFov
		base = CFrame.lookAt(center + Vector3.new(0, 100, 88), center)
		local c = cam()
		c.CameraType = Enum.CameraType.Scriptable
	end

	local function focus(part: BasePart?)
		target = part
		if part ~= nil then
			goalFov = feel.koFov
		end
	end

	local function shake(strength: number)
		local size = feel.shakeMax * math.clamp(strength, 0, 1)
		if size >= shakeSize * (shakeLeft / feel.shakeTime) then
			shakeSize, shakeLeft = size, feel.shakeTime
		end
	end

	local function release()
		active = false
		target = nil
		shakeLeft = 0
		goalFov, fov = feel.normalFov, feel.normalFov
		local c = cam()
		c.FieldOfView = feel.normalFov
		c.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			c.CameraSubject = humanoid
		end
	end

	return { overview = overview, focus = focus, shake = shake, release = release }
end

return CameraDirector
