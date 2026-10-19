--!strict
-- Rolls the wheels of every car in a fight: the server gives each wheel a Motor6D, and here the
-- client sets its Transform from the car's forward speed. Client only, nothing is sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarLook = require(ReplicatedStorage.Shared.CarLook)

local FIND_EVERY = 0.5

type Wheel = {
	motor: Motor6D,
	body: BasePart,
	radius: number,
	angle: number,
}

local WheelFx = {}

local function isCar(m: Instance): boolean
	return m:IsA("Model")
		and (string.sub(m.Name, 1, 10) == "PlayerCar_" or string.sub(m.Name, 1, 7) == "BotCar_")
end

function WheelFx.start()
	local wheels: { Wheel } = {}
	local nextFind = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now >= nextFind then
			nextFind = now + FIND_EVERY
			local found: { Wheel } = {}
			local arena = workspace:FindFirstChild("Arena")
			if arena then
				for _, m in arena:GetChildren() do
					if isCar(m) and m:IsA("Model") and m.PrimaryPart then
						for _, d in m:GetDescendants() do
							if d:IsA("Motor6D") and d.Name == "WheelMotor" then
								local old: Wheel? = nil
								for _, w in wheels do
									if w.motor == d then
										old = w
										break
									end
								end
								local radius = (d.Parent :: Instance):GetAttribute("WheelRadius")
								found[#found + 1] = old
									or {
										motor = d,
										body = m.PrimaryPart,
										radius = if type(radius) == "number" then radius else 1,
										angle = 0,
									}
							end
						end
					end
				end
			end
			wheels = found
		end
		for _, w in wheels do
			if w.body.Parent then
				local forward = w.body.AssemblyLinearVelocity:Dot(w.body.CFrame.LookVector)
				w.angle += CarLook.spinStep(forward, w.radius, dt)
				w.motor.Transform = CFrame.Angles(w.angle, 0, 0)
			end
		end
	end)
end

return WheelFx
