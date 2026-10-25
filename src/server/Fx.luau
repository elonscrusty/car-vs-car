--!strict
-- Particle effects that live on a car (they replicate to everyone, and die with the car).

local Fx = {}

-- Dark smoke from a badly damaged car.
function Fx.smoke(body: Part)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Color = ColorSequence.new(Color3.fromRGB(60, 60, 60))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 5),
	})
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Rate = 25
	e.Speed = NumberRange.new(4, 8)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = body
end

-- Orange boost flame out the back (off until the car boosts).
function Fx.flame(body: Part): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "BoostFlame"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 60, 20))
	e.LightEmission = 1
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	e.Lifetime = NumberRange.new(0.2, 0.4)
	e.Rate = 80
	e.Speed = NumberRange.new(10, 18)
	e.EmissionDirection = Enum.NormalId.Back
	e.Enabled = false
	e.Parent = body
	return e
end

return Fx
