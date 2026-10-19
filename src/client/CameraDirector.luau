--!strict
-- Camera: fixed overview of the bowl, shakes on big hits, and a push-in on the crash dummy at a KO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoccerFieldFlow = require(ReplicatedStorage.Shared.SoccerFieldFlow)

local CameraDirector = {}

export type Director = {
	overview: (center: Vector3, side: Vector3?) -> (), -- side: flat direction from the middle to your car
	focus: (target: BasePart?) -> (), -- KO: follow the dummy and zoom in
	shake: (strength: number) -> (), -- 0..1
	punchFov: (amount: number) -> (), -- brief zoom-in punch
	soccer: (on: boolean) -> (), -- car soccer: high behind your car, keeps the ball in frame
	release: () -> (), -- back to the normal Roblox camera (lobby)
}

function CameraDirector.new(): Director
	local feel = GameConfig.Feel
	local rng = Random.new()
	local base = CFrame.identity
	local active = false
	local target: BasePart? = nil
	local goalFov = feel.normalFov
	local viewCenter = Vector3.zero
	local viewDir = Vector3.zAxis
	local myCar: BasePart? = nil -- your own car, found once the fight starts (nil in the lobby)
	local nextFind = 0
	local soccerOn = false
	local ballPart: BasePart? = nil
	local nextBallFind = 0
	local fov = feel.normalFov
	local shakeLeft, shakeSize = 0, 0

	local function cam(): Camera
		return workspace.CurrentCamera :: Camera
	end

	-- Your car is the model in an Arena that carries your user id (the server sets it at the fight).
	local function findMyCar(): BasePart?
		local uid = Players.LocalPlayer.UserId
		for _, arena in workspace:GetChildren() do
			if arena.Name == "Arena" then
				for _, m in arena:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("DriverUserId") == uid then
						return m.PrimaryPart
					end
				end
			end
		end
		return nil
	end

	-- The soccer ball is the part named "Ball" in the Arena that holds your car.
	local function findBall(car: BasePart): BasePart?
		local arena = car:FindFirstAncestor("Arena")
		local b = if arena then arena:FindFirstChild("Ball") else nil
		return if b and b:IsA("BasePart") then b else nil
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
		else
			-- Gentle follow: lean toward your car, and widen the view a little at speed.
			local car = myCar
			if (car == nil or car.Parent == nil) and os.clock() >= nextFind then
				nextFind = os.clock() + 0.3
				myCar = findMyCar()
				car = myCar
			end
			if car ~= nil and car.Parent ~= nil and soccerOn then
				local ball = ballPart
				if (ball == nil or ball.Parent == nil) and os.clock() >= nextBallFind then
					nextBallFind = os.clock() + 0.3
					ballPart = findBall(car)
					ball = ballPart
				end
				if ball ~= nil and ball.Parent ~= nil then
					local cp, bp = car.Position - viewCenter, ball.Position - viewCenter
					local look = car.CFrame.LookVector
					local f = SoccerFieldFlow.cameraFrame(cp.X, cp.Z, bp.X, bp.Z, look.X, look.Z)
					local goal = CFrame.lookAt(
						viewCenter + Vector3.new(f.camX, f.camY, f.camZ),
						viewCenter + Vector3.new(f.lookX, f.lookY, f.lookZ)
					)
					base = base:Lerp(goal, math.min(1, dt * 4))
					goalFov = feel.normalFov
				end
			elseif car ~= nil and car.Parent ~= nil then
				local pos = car.Position
				local shift = Vector3.new(pos.X - viewCenter.X, 0, pos.Z - viewCenter.Z) * 0.6
				local goal = CFrame.lookAt(
					viewCenter + viewDir * 40 + Vector3.new(0, 48, 0) + shift,
					viewCenter + shift
				)
				base = base:Lerp(goal, math.min(1, dt * 3))
				local v = car.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				goalFov = feel.normalFov + math.clamp((speed - 30) / 10, 0, 5)
			end
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

	local function overview(center: Vector3, side: Vector3?)
		target = nil
		active = true
		goalFov, fov = feel.normalFov, feel.normalFov
		-- Camera sits behind YOUR car so it is the near one, bottom of the screen.
		local flat = if side then Vector3.new(side.X, 0, side.Z) else Vector3.zero
		local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		viewCenter, viewDir = center, dir
		myCar = nil
		base = CFrame.lookAt(center + dir * 60 + Vector3.new(0, 72, 0), center)
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

	local function punchFov(amount: number)
		if active then
			fov = math.max(10, fov - amount) -- eases back to goalFov on its own
		end
	end

	local function soccer(on: boolean)
		soccerOn = on
		ballPart = nil
	end

	local function release()
		soccerOn = false
		ballPart = nil
		active = false
		target = nil
		myCar = nil
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

	return {
		overview = overview,
		focus = focus,
		shake = shake,
		punchFov = punchFov,
		soccer = soccer,
		release = release,
	}
end

return CameraDirector
