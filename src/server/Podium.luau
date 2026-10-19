--!strict
-- The winner's show at the end of a fight: the winning car stands on a gold podium in the middle
-- of the stadium and spins while fireworks burst above. Looks only.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Podium = {}

local COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 210, 50),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(120, 235, 110),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(255, 255, 255),
}

-- One firework: a burst of glowing dots from a point in the air.
local function burst(parent: Instance, at: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = "Firework"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Lifetime = NumberRange.new(1.0, 1.6)
	e.Speed = NumberRange.new(30, 45)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Parent = p
	e:Emit(70)
	Debris:AddItem(p, 2.5)
end

-- Puts `car` on a podium at `origin` and keeps it spinning for `seconds`. Returns the podium top
-- (a good thing for the camera to look at), or nil when the car is gone.
function Podium.celebrate(
	arenaModel: Model,
	origin: Vector3,
	car: { model: Model, body: Part },
	seconds: number
): BasePart?
	if car.model.Parent == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Podium"
	folder.Parent = arenaModel
	local base = Instance.new("Part")
	base.Name = "PodiumTop"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(5, 18, 18)
	base.CFrame = CFrame.new(origin + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	base.Color = Color3.fromRGB(255, 205, 60)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Parent = folder

	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local top = origin + Vector3.new(0, 5.2 + car.body.Size.Y / 2, 0)
	local rng = Random.new(os.clock() * 1000)
	local t = 0
	local nextBurst = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		if t >= seconds or car.model.Parent == nil or folder.Parent == nil then
			conn:Disconnect()
			folder:Destroy()
			return
		end
		car.model:PivotTo(CFrame.new(top) * CFrame.Angles(0, t * 1.6, 0))
		if t >= nextBurst then
			nextBurst = t + 0.35
			local angle = rng:NextNumber() * math.pi * 2
			local r = 6 + rng:NextNumber() * 14
			local at = origin
				+ Vector3.new(math.cos(angle) * r, 12 + rng:NextNumber() * 14, math.sin(angle) * r)
			burst(folder, at, COLORS[rng:NextInteger(1, #COLORS)])
		end
	end)
	return base
end

return Podium
