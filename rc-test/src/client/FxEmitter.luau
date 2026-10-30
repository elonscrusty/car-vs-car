--!strict
-- Builds a ParticleEmitter from one CarFxStyles.Emit (shared by the exhaust flames and the wheel
-- trails). `u` scales it to the car (1 = the preview car), `dir` is the attachment face it shoots
-- out of. Rate starts at 0: the caller sets it every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarFxStyles = require(ReplicatedStorage.Shared.CarFxStyles)

local FxEmitter = {}

local function colours(list: { { number } }): ColorSequence
	local n = #list
	local keys = {}
	for i, c in list do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), Color3.fromRGB(c[1], c[2], c[3]))
	end
	return ColorSequence.new(keys)
end

function FxEmitter.make(e: CarFxStyles.Emit, u: number, dir: Enum.NormalId): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Color = colours(e.colors)
	fx.LightEmission = e.glow
	fx.Size = NumberSequence.new(e.size[1] * u, e.size[2] * u)
	fx.Transparency = NumberSequence.new(e.fade[1], e.fade[2])
	fx.Lifetime = NumberRange.new(e.life[1], e.life[2])
	fx.Speed = NumberRange.new(e.speed[1] * u, e.speed[2] * u)
	fx.SpreadAngle = Vector2.new(e.spread, e.spread)
	fx.Drag = e.drag
	fx.Acceleration = Vector3.new(0, -e.gravity * u, 0)
	fx.Rotation = NumberRange.new(0, 360)
	fx.EmissionDirection = dir
	fx.Rate = 0
	return fx
end

return FxEmitter
