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
	local function disc(
		name: string,
		height: number,
		diameter: number,
		y: number,
		color: Color3,
		neon: boolean
	)
		local d = Instance.new("Part")
		d.Name = name
		d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(height, diameter, diameter)
		d.CFrame = CFrame.new(origin + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		d.Color = color
		d.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Parent = folder
		return d
	end
	-- Three steps: dark foot, red middle, gold top with a glowing rim.
	disc("PodiumFoot", 1.6, 26, 0.8, Color3.fromRGB(60, 66, 90), false)
	disc("PodiumRim", 0.5, 22, 1.8, Color3.fromRGB(120, 215, 255), true)
	disc("PodiumStep", 2.4, 21, 2.2, Color3.fromRGB(235, 60, 55), false)
	local base = disc("PodiumTop", 1.2, 18, 3.9, Color3.fromRGB(255, 205, 60), false)
	disc("PodiumStar", 0.2, 6, 4.55, Color3.fromRGB(255, 245, 190), true)
	-- A light beam from above and a rain of confetti while the car spins.
	local beam = Instance.new("Part")
	beam.Name = "PodiumBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(40, 16, 16)
	beam.CFrame = CFrame.new(origin + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Color = Color3.fromRGB(255, 240, 180)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.88
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Parent = folder
	local confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 40
	confetti.Lifetime = NumberRange.new(2, 3)
	confetti.Speed = NumberRange.new(2, 6)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.EmissionDirection = Enum.NormalId.Bottom
	confetti.Acceleration = Vector3.new(0, -4, 0)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-200, 200)
	confetti.Size = NumberSequence.new(0.7)
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS[1]),
		ColorSequenceKeypoint.new(0.25, COLORS[2]),
		ColorSequenceKeypoint.new(0.5, COLORS[3]),
		ColorSequenceKeypoint.new(0.75, COLORS[4]),
		ColorSequenceKeypoint.new(1, COLORS[5]),
	})
	local source = Instance.new("Part")
	source.Name = "ConfettiSource"
	source.Size = Vector3.new(30, 1, 30)
	source.Position = origin + Vector3.new(0, 32, 0)
	source.Transparency = 1
	source.Anchored = true
	source.CanCollide = false
	source.CanQuery = false
	source.CanTouch = false
	source.Parent = folder
	confetti.Parent = source

	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local top = origin + Vector3.new(0, 4.7 + car.body.Size.Y / 2, 0)
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
