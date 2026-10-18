--!strict
-- Particle effects that live on a car (they replicate to everyone, and die with the car).

local Fx = {}

-- Dark smoke from a badly damaged car.
function Fx.smoke(body: Part)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Color = ColorSequence.new(Color3.fromRGB(95, 95, 98))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
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

return Fx
