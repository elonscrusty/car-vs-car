--!strict
-- Twin Jets (carter's pick 1 of 3, 10-29): while the black+red car boosts, two long blue-white jets
-- stream out of its tailpipes, the rear glows hot, and the underglow brightens; with no boost it
-- only gives a quick pop now and then. Looks only: nothing here touches the driving.
--
-- Made from the skin's body (CarSkin shows it over the grey car): two Attachments at the pipes
-- (FireDrakeData.EXHAUST, fractions of the body) with ParticleEmitters, and one PointLight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.FireDrakeData)

local JET_RATE = 150 -- particles a second at full boost, a pipe
local RISE, FALL = 7, 3 -- how fast the flame grows and dies back
local POPS = 2.5 -- idle pops a second

export type ExhaustFx = {
	-- body: the skin's body (nil: no skin shown); boosting: the car is on a boost push
	step: (body: BasePart?, boosting: boolean) -> (),
}

type Rig = {
	body: BasePart,
	jets: { ParticleEmitter },
	pops: { ParticleEmitter },
	light: PointLight,
	glow: BasePart?, -- the model's Underglow
	glowBase: number,
	u: number, -- the body's size, next to the preview car's
}

local ExhaustFx = {}

local function emitter(
	u: number,
	size: number,
	life: NumberRange,
	speed: NumberRange
): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(207, 234, 255)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 176, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 48, 0)),
	})
	fx.LightEmission = 1
	fx.Size = NumberSequence.new(size * u, 0.08 * u)
	fx.Transparency = NumberSequence.new(0.1, 1)
	fx.Lifetime = life
	fx.Speed = NumberRange.new(speed.Min * u, speed.Max * u)
	fx.SpreadAngle = Vector2.new(5, 5)
	fx.EmissionDirection = Enum.NormalId.Front -- (-Z of the model: its tail)
	fx.Rate = 0
	return fx
end

local function build(body: BasePart): Rig
	local u = body.Size.Z / Data.DESIGN_LENGTH
	local jets, pops = {}, {}
	for _, side in { 1, -1 } do
		local a = Instance.new("Attachment")
		a.Name = "ExhaustPipe"
		a.Position = Vector3.new(
			side * Data.EXHAUST.x * body.Size.X,
			Data.EXHAUST.y * body.Size.Y,
			Data.EXHAUST.z * body.Size.Z
		)
		a.Parent = body
		local jet = emitter(u, 0.7, NumberRange.new(0.14, 0.26), NumberRange.new(10, 18))
		jet.Parent = a
		table.insert(jets, jet)
		local pop = emitter(u, 1.1, NumberRange.new(0.1, 0.16), NumberRange.new(4, 6))
		pop.Parent = a
		table.insert(pops, pop)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 90, 32)
	light.Range = 14 * u
	light.Brightness = 0
	light.Parent = body
	local glow = if body.Parent then body.Parent:FindFirstChild("Underglow") else nil
	local part = if glow and glow:IsA("BasePart") then glow else nil
	return {
		body = body,
		jets = jets,
		pops = pops,
		light = light,
		glow = part,
		glowBase = if part then part.Transparency else 0,
		u = u,
	}
end

function ExhaustFx.new(): ExhaustFx
	local rig: Rig? = nil
	local level = 0 -- 0 off .. 1 full boost
	local last = os.clock()
	local rng = Random.new()

	local self = {} :: ExhaustFx

	function self.step(body: BasePart?, boosting: boolean)
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if not body or body.Parent == nil then
			rig = nil -- (the skin went away with its emitters)
			level = 0
			return
		end
		local r = rig
		if not r or r.body ~= body then
			r = build(body)
			rig = r
		end
		local want = if boosting then 1 else 0
		level += (want - level) * math.min(1, dt * (if boosting then RISE else FALL))
		if level < 0.01 then
			level = 0
		end
		for _, jet in r.jets do
			jet.Rate = JET_RATE * level
		end
		if level < 0.1 and rng:NextNumber() < dt * POPS then
			for _, pop in r.pops do
				pop:Emit(1)
			end
		end
		r.light.Brightness = 3 * level
		local glow = r.glow
		if glow then
			glow.Transparency = math.max(0, r.glowBase - 0.4 * level)
		end
	end

	return self
end

return ExhaustFx
