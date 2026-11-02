--!strict
-- Tailpipe flames + boost glow, as a swappable look (CarFxStyles.EXHAUST): Twin Jets (carter's
-- pick, the starter), Dragon Breath, Afterburner, Nitro Flames (carter's speed boost pick). While
-- the car boosts, two flames stream out of its tailpipes, the rear glows hot, and the underglow
-- brightens; with no boost it only gives a quick pop now and then. A style with `licks` (Nitro
-- Flames) also streams thin fire off the fenders, mirrors and rear corners while boosting.
-- Looks only: nothing here touches the driving.
--
-- Made from the skin's body (CarSkin shows it over the grey car): two Attachments at the pipes
-- (FireDrakeData.EXHAUST, fractions of the body) with ParticleEmitters, and one PointLight.
-- Changing the style rebuilds them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarFxStyles = require(ReplicatedStorage.Shared.CarFxStyles)
local Data = require(ReplicatedStorage.Shared.FireDrakeData)
local FireDrake = require(script.Parent.FireDrake)
local FxEmitter = require(script.Parent.FxEmitter)

local RISE, FALL = 7, 3 -- how fast the flame grows and dies back
local POPS = 2.5 -- idle pops a second

export type ExhaustFx = {
	-- body: the skin's body (nil: no skin shown); boosting: the car is on a boost push;
	-- styleId: the player's pick (nil or unknown: Twin Jets)
	step: (body: BasePart?, boosting: boolean, styleId: string?) -> (),
}

type Burner = { fx: ParticleEmitter, rate: number, idle: number }

type Rig = {
	body: BasePart,
	style: CarFxStyles.Exhaust,
	pipes: { Attachment }, -- the pipes and the lick spots (all made here, all destroyed together)
	burners: { Burner },
	pops: { ParticleEmitter },
	light: PointLight,
	glow: BasePart?, -- the model's Underglow
	glowBase: number,
}

local ExhaustFx = {}

local function build(body: BasePart, style: CarFxStyles.Exhaust): Rig
	local u = body.Size.Z / Data.DESIGN_LENGTH
	-- the tail is at the body's local -Z when its nose is at +Z, and the other way round if not
	local nose = if body.Parent then FireDrake.noseSign(body, body.Parent) else 1
	local tail = if nose > 0 then Enum.NormalId.Front else Enum.NormalId.Back -- (Front is -Z)
	local pipes, burners, pops = {}, {}, {}
	for _, side in { 1, -1 } do
		local a = Instance.new("Attachment")
		a.Name = "ExhaustPipe"
		a.Position = Vector3.new(
			side * Data.EXHAUST.x * body.Size.X,
			Data.EXHAUST.y * body.Size.Y,
			nose * Data.EXHAUST.z * body.Size.Z
		)
		a.Parent = body
		table.insert(pipes, a)
		local jet = FxEmitter.make(style.jet, u, tail)
		jet.Parent = a
		table.insert(burners, { fx = jet, rate = style.jet.rate, idle = style.idle })
		for _, extra in style.extras do
			local e = FxEmitter.make(extra, u, tail)
			e.Parent = a
			table.insert(burners, { fx = e, rate = extra.rate, idle = style.idle })
		end
		local pop = FxEmitter.make(style.pop, u, tail)
		pop.Parent = a
		table.insert(pops, pop)
	end
	-- fire licks off the fenders, mirrors and rear corners: only while boosting (idle 0)
	local licks = style.licks
	if licks then
		for _, p in CarFxStyles.LICK_SPOTS do
			local a = Instance.new("Attachment")
			a.Name = "ExhaustLick"
			a.Position =
				Vector3.new(p[1] * body.Size.X, p[2] * body.Size.Y, nose * p[3] * body.Size.Z)
			a.Parent = body
			table.insert(pipes, a)
			for _, lick in licks do
				local e = FxEmitter.make(lick, u, tail)
				e.Parent = a
				table.insert(burners, { fx = e, rate = lick.rate, idle = 0 })
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(style.light[1], style.light[2], style.light[3])
	light.Range = 14 * u
	light.Brightness = 0
	light.Parent = body
	local glow = if body.Parent then body.Parent:FindFirstChild("Underglow") else nil
	local part = if glow and glow:IsA("BasePart") then glow else nil
	return {
		body = body,
		style = style,
		pipes = pipes,
		burners = burners,
		pops = pops,
		light = light,
		glow = part,
		glowBase = if part then part.Transparency else 0,
	}
end

local function destroy(r: Rig)
	for _, a in r.pipes do
		a:Destroy()
	end
	r.light:Destroy()
	if r.glow then
		r.glow.Transparency = r.glowBase
	end
end

function ExhaustFx.new(): ExhaustFx
	local rig: Rig? = nil
	local level = 0 -- 0 off .. 1 full boost
	local last = os.clock()
	local rng = Random.new()

	local self = {} :: ExhaustFx

	function self.step(body: BasePart?, boosting: boolean, styleId: string?)
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		local old = rig
		if not body or body.Parent == nil then
			rig = nil -- (the skin went away with its emitters)
			level = 0
			return
		end
		local style = CarFxStyles.exhaust(styleId)
		local r = old
		if not r or r.body ~= body or r.style ~= style then
			if r and r.body == body then
				destroy(r) -- same car, new style
			end
			r = build(body, style)
			rig = r
		end
		local before = level
		local want = if boosting then 1 else 0
		level += (want - level) * math.min(1, dt * (if boosting then RISE else FALL))
		if level < 0.01 then
			level = 0
		end
		for _, b in r.burners do
			b.fx.Rate = b.rate * (b.idle + (1 - b.idle) * level)
		end
		if level < 0.1 and rng:NextNumber() < dt * POPS then
			for _, pop in r.pops do
				pop:Emit(1)
			end
		end
		if r.style.bang > 0 and before > 0.6 and level <= 0.6 then
			for _, pop in r.pops do
				pop:Emit(r.style.bang) -- the afterburner's bang when you let go
			end
		end
		r.light.Brightness = r.style.lightPower * level
		local glow = r.glow
		if glow then
			glow.Transparency = math.max(0, r.glowBase - 0.4 * level)
		end
	end

	return self
end

return ExhaustFx
