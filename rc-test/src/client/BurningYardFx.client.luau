--!strict
-- A thin grey smoke column over every fire pit (the Burning Yard look, shared/BurningYard; the
-- wreck piles' own smoke is made by server/BurningYardServer). One light emitter per pit, made
-- once. Looks only. Nothing glows (carter 10-30: daytime, calm, easy to read).
local CollectionService = game:GetService("CollectionService")

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- a thin dark column over a fire pit (one emitter on its Core, made once)
local function pitSmoke(pit: Instance)
	local core = pit:FindFirstChild("Core")
	if not (core and core:IsA("BasePart")) or core:FindFirstChild("PitSmoke") then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "PitSmoke"
	e.Texture = SMOKE
	e.Rate = 4
	e.Color = ColorSequence.new(Color3.fromRGB(60, 56, 60))
	e.LightInfluence = 0.5
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(1.5, 2.5)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Right -- the Core is a turned cylinder: its "right" is up
	e.Acceleration = Vector3.new(0.5, 0.6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = core
end
for _, pit in CollectionService:GetTagged("FirePit") do
	pitSmoke(pit)
end
CollectionService:GetInstanceAddedSignal("FirePit"):Connect(pitSmoke)
