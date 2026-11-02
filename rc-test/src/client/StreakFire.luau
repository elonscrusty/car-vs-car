--!strict
-- The fire on a car that smashed 3 or more in a row (carter's pick: Hot Rod Flames).
-- Numbers live in shared/StreakFire. Looks only, on this screen only: the server counts the streak
-- and puts it on the car model as the attribute "Streak" (it is cleared when the car is smashed).
--   StreakFire.watch() - burns every Car_<id> model by its "Streak" attribute:
--     3 in a row: flames on the hood and sides, out of the exhausts, over the wheels, embers and
--     smoke, the car glowing red-hot with a flickering light; 5: a white-hot core; 7: a tall column.
--     Each new size starts with a whoosh (a burst and a flash of light).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Spec = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StreakFire"))

local TEXTURES = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
}
local HOT = Color3.fromRGB(255, 122, 32)
local RED = Color3.fromRGB(255, 48, 0)

local StreakFire = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function phone(): boolean
	local me = Players.LocalPlayer
	if me and me:GetAttribute("PhoneUi") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

type Burn = {
	level: number,
	holder: Folder,
	attached: { Attachment }, -- the emitters' attachments on the body
	light: PointLight,
	glow: Highlight,
	flare: number, -- os.clock() until the whoosh light has faded
}
local burning: { [Model]: Burn } = {}
local beating: RBXScriptConnection? = nil

local function bodyOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- one emitter per spot of a spec entry, on attachments fixed to the car's body
local function emitters(model: Model, body: BasePart, burn: Burn)
	local level = burn.level
	local mid, size = model:GetBoundingBox()
	local u = Spec.unit(math.max(size.X, size.Z))
	local isPhone = phone()
	local grow = Spec.size(level) / Spec.SIZE[1]
	for _, e in Spec.EMITTERS do
		local rate = Spec.rate(e, level, isPhone)
		if rate <= 0 then
			continue
		end
		local big = e.size[1] * u * (if e.grows then grow else 1)
		for _, at in e.spots do
			local a = Instance.new("Attachment")
			a.Name = e.name
			local off = CFrame.new(at[1] * u, at[2] * u, at[3] * u)
			a.CFrame = body.CFrame:ToObjectSpace(mid * off)
			a.Parent = body
			table.insert(burn.attached, a)
			local p = Instance.new("ParticleEmitter")
			p.Texture = TEXTURES[e.tex]
			p.Rate = rate
			p.Color = ColorSequence.new(rgb(e.from), rgb(e.to))
			p.Size = NumberSequence.new(big, e.size[2] * u)
			p.Transparency = NumberSequence.new(e.see, 1)
			p.Speed = NumberRange.new(e.speed[1] * u, e.speed[2] * u)
			p.Lifetime = NumberRange.new(e.life[1], e.life[2])
			p.LightEmission = e.glow
			p.LightInfluence = if e.glow > 0 then 0 else 1
			p.Acceleration = Vector3.new(0, e.up * u, 0)
			p.SpreadAngle = Vector2.new(e.spread, e.spread)
			p.Rotation = NumberRange.new(0, 360)
			p.RotSpeed = NumberRange.new(-90, 90)
			p.EmissionDirection = if e.dir == "Back" then Enum.NormalId.Back else Enum.NormalId.Top
			if e.volume then
				-- (the box is the body part's own size)
				p.Shape = Enum.ParticleEmitterShape.Box
				p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			end
			p.Parent = a
		end
	end
end

local function clear(burn: Burn)
	for _, a in burn.attached do
		a:Destroy()
	end
	table.clear(burn.attached)
end

local function whoosh(model: Model, body: BasePart, burn: Burn, level: number)
	local mid, size = model:GetBoundingBox()
	local u = Spec.unit(math.max(size.X, size.Z))
	local a = Instance.new("Attachment")
	a.CFrame = body.CFrame:ToObjectSpace(mid)
	a.Parent = body
	local p = Instance.new("ParticleEmitter")
	p.Texture = TEXTURES.fire
	p.Rate = 0
	p.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(208, 32, 0))
	p.Size = NumberSequence.new(2.2 * u, 0.2 * u)
	p.Transparency = NumberSequence.new(0.2, 1)
	p.Speed = NumberRange.new(6 * u, 15 * u)
	p.Lifetime = NumberRange.new(0.4, 0.8)
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Drag = 2
	p.SpreadAngle = Vector2.new(180, 180)
	p.Parent = a
	p:Emit(Spec.FLARE.count * (if phone() then Spec.PHONE else 1) * (1 + (level - 1) * 0.25))
	task.delay(1, function()
		a:Destroy()
	end)
	burn.flare = os.clock() + Spec.FLARE.secs
end

local function beat()
	local now = os.clock()
	for model, b in burning do
		if not model.Parent then
			continue
		end
		local light = Spec.HEAT.light + (math.random() - 0.3) * Spec.HEAT.flicker
		local left = b.flare - now
		if left > 0 then
			light += Spec.FLARE.light * (left / Spec.FLARE.secs)
		end
		b.light.Brightness = light
		b.glow.FillTransparency = Spec.HEAT.fill + 0.1 * math.sin(now * 14)
	end
end

local function stop(model: Model)
	local b = burning[model]
	if not b then
		return
	end
	burning[model] = nil
	clear(b)
	b.light:Destroy()
	b.glow:Destroy()
	b.holder:Destroy()
	if next(burning) == nil and beating then
		beating:Disconnect()
		beating = nil
	end
end

-- Show the fire for this streak (0 or nil = out). Safe to call again as the streak grows.
function StreakFire.set(model: Model, streak: number?)
	local level = Spec.level(streak)
	local b = burning[model]
	if level == 0 then
		stop(model)
		return
	end
	if b and b.level == level then
		return
	end
	local body = bodyOf(model)
	if not body then
		return
	end
	if not b then
		local holder = Instance.new("Folder")
		holder.Name = "StreakFire"
		holder.Parent = model
		local light = Instance.new("PointLight")
		light.Color = HOT
		light.Range = Spec.HEAT.range
		light.Brightness = Spec.HEAT.light
		light.Parent = body
		local glow = Instance.new("Highlight")
		glow.Name = "Hot"
		glow.Adornee = model
		glow.FillColor = RED
		glow.FillTransparency = Spec.HEAT.fill
		glow.OutlineTransparency = 1
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = holder
		b = { level = 0, holder = holder, attached = {}, light = light, glow = glow, flare = 0 }
		burning[model] = b
	end
	local burn = b :: Burn
	clear(burn)
	burn.level = level
	emitters(model, body, burn)
	whoosh(model, body, burn, level)
	if not beating then
		beating = RunService.Heartbeat:Connect(beat)
	end
end

local watching = false
function StreakFire.watch()
	if watching then
		return
	end
	watching = true
	local function hook(m: Instance)
		if not (m:IsA("Model") and string.match(m.Name, "^Car_%-?%d+$")) then
			return
		end
		local model = m :: Model
		local function changed()
			StreakFire.set(model, model:GetAttribute("Streak") :: any)
		end
		model:GetAttributeChangedSignal("Streak"):Connect(changed)
		model.AncestryChanged:Connect(function()
			if model.Parent == nil then
				stop(model)
			end
		end)
		changed()
	end
	for _, m in workspace:GetChildren() do
		hook(m)
	end
	workspace.ChildAdded:Connect(hook)
	for _, m in CollectionService:GetTagged("Kart") do
		if m.Parent ~= workspace then
			hook(m)
		end
	end
end

return StreakFire
