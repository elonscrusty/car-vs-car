--!strict
-- Machine gun, mines and freeze, drawn (plans/smash, GUNMINE row). The server decides every hit;
-- client/WeaponFx hands this module every WeaponFx kind that isn't a rocket:
--   GunShot    { from, to, hit }        a sunny-yellow tracer, a muzzle flash, sparks if it hit
--   MineDrop   { position }             the drop sound (the mine is a server part, workspace.Mines)
--   MineBoom   { position }             the Spike boom: fireball, sparks, smoke, ring, chips
--   FreezeShot { from, to, hit }        a sky-blue ice bolt
--   FreezeHit  { id, position, seconds } an ice block over the kart until it melts
--   Shatter    { id, position }         the ice bursts into shards
-- Look rule: low-poly, SmoothPlastic + Neon, no text.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local me = Players.LocalPlayer

local FxGunMine = {}

local SUNNY = Color3.fromRGB(255, 205, 40)
local WHITE = Color3.new(1, 1, 1)
local FLAME = Color3.fromRGB(255, 130, 30)
local ICE = Color3.fromRGB(150, 220, 255)
local SKY = Color3.fromRGB(61, 155, 255)

-- the arena is RC size (TrackData.RC_SCALE): every size below is in big units (a kart is
-- 3 x 5.5 big) times S
local S = 0.25

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

-- `at` makes the sound fade with distance; your own kart's sounds play full (no `at`)
local function sound(name: string, data: any?, at: Vector3?)
	local fn = (Sfx :: any)[name]
	if type(fn) ~= "function" then
		return
	end
	local mine = type(data) == "table" and data.owner == me.UserId
	pcall(fn, if mine then nil else at)
end

local function part(name: string, color: Color3, neon: boolean, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.Parent = bits
	return p
end

local function fade(p: BasePart, seconds: number, goal: { [string]: any })
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad), goal):Play()
	task.delay(seconds, function()
		p:Destroy()
	end)
end

local function vec(data: any, key: string): Vector3?
	local v = type(data) == "table" and data[key]
	return if typeof(v) == "Vector3" then v else nil
end

-- a thin bright beam from a to b that fades fast
local function beam(a: Vector3, b: Vector3, color: Color3, width: number, seconds: number)
	local len = (b - a).Magnitude
	if len < 0.1 then
		return
	end
	local p = part("Tracer", color, true, Vector3.new(width * S, width * S, len))
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	fade(p, seconds, { Size = Vector3.new(width * S * 0.3, width * S * 0.3, len) })
end

-- a few faceted chips flying out from `at`
local function chips(at: Vector3, color: Color3, n: number, size: number, speed: number)
	for _ = 1, n do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Material = Enum.Material.SmoothPlastic
		w.Color = color
		w.Size = Vector3.new(size, size, size) * S
		local spin = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, 0)
		w.CFrame = CFrame.new(at) * spin
		w.Parent = bits
		local out = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5)
		local goal = w.CFrame + out.Unit * speed * S
		fade(w, 0.45, { CFrame = goal * CFrame.Angles(2, 1, 0) })
	end
end

local function flash(at: Vector3, color: Color3, from: number, to: number, seconds: number)
	local b = part("Flash", color, true, Vector3.new(from, from, from) * S)
	b.Shape = Enum.PartType.Ball
	b.Position = at
	fade(b, seconds, { Size = Vector3.new(to, to, to) * S })
end

local function onGun(data: any)
	local a, b = vec(data, "from"), vec(data, "to")
	if not a or not b then
		return
	end
	beam(a, b, SUNNY, 0.25, 0.08)
	flash(a, SUNNY, 0.8, 1.6, 0.06)
	if data.hit == true then
		flash(b, WHITE, 0.6, 2, 0.1)
		chips(b, SUNNY, 2, 0.4, 3)
	end
	sound("gun", data, a)
end

-- the Spike mine's boom (carter picked "A Pro" on the preview page, 10-29): a white flash, a
-- hot core and an orange fireball that rise, sparks that fall, black smoke going up, dust rolling
-- out over the road, a thin ring, black/red/steel chips and a dark scorch that fades. Sizes are
-- the page's in big units times S.
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxassetid://6101261905" -- the Roblox explosion tutorial's spark

local function seq(...: number): NumberSequence
	local v = { ... }
	local keys = {}
	for i, x in v do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / (#v - 1), x))
	end
	return NumberSequence.new(keys)
end

local function burst(host: Attachment, count: number, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = host
	e:Emit(count)
end

local function onMineBoom(data: any)
	local at = vec(data, "position")
	if not at then
		return
	end
	local host = part("MineBoom", FLAME, false, Vector3.one * 0.1)
	host.Transparency = 1
	host.Position = at + Vector3.new(0, 0.8 * S, 0)
	local a = Instance.new("Attachment")
	a.Parent = host
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 14 * S * 2
	light.Brightness = 6
	light.Parent = host
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()

	flash(at + Vector3.new(0, 1.2 * S, 0), Color3.fromRGB(255, 241, 200), 2, 11, 0.09)
	burst(a, 14, { -- hot core
		Texture = FIRE_TEX,
		Color = ColorSequence.new(Color3.fromRGB(255, 224, 128), Color3.fromRGB(255, 64, 0)),
		Transparency = seq(0.1, 1),
		Size = seq(2.6 * S, 3.8 * S),
		Speed = NumberRange.new(1.5 * S, 4 * S),
		Acceleration = Vector3.new(0, 6 * S, 0),
		Drag = 3,
		Lifetime = NumberRange.new(0.35, 0.6),
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 3,
	})
	burst(a, 22, { -- orange fireball
		Texture = FIRE_TEX,
		Color = ColorSequence.new(Color3.fromRGB(255, 160, 64), Color3.fromRGB(176, 16, 0)),
		Transparency = seq(0.1, 1),
		Size = seq(2.8 * S, 4.6 * S),
		Speed = NumberRange.new(1.5 * S, 4 * S),
		Acceleration = Vector3.new(0, 3.5 * S, 0),
		Drag = 3,
		Lifetime = NumberRange.new(0.35, 0.6),
		LightEmission = 1,
		Brightness = 1.5,
		ZOffset = 2,
	})
	burst(a, 30, { -- sparks that fall
		Texture = SPARK_TEX,
		Color = ColorSequence.new(Color3.fromRGB(255, 233, 160), Color3.fromRGB(255, 64, 16)),
		Size = seq(0.35 * S, 0),
		Speed = NumberRange.new(16 * S, 30 * S),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -30 * S, 0),
		Drag = 1.8,
		Lifetime = NumberRange.new(0.4, 0.9),
		LightEmission = 1,
		ZOffset = 3,
	})
	burst(a, 20, { -- black smoke going up (the dark layer gives the fire its shape)
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(Color3.fromRGB(42, 34, 36), Color3.fromRGB(15, 15, 18)),
		Transparency = seq(0.15, 0.5, 1),
		Size = seq(1.8 * S, 6 * S),
		Speed = NumberRange.new(4 * S, 9 * S),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 1.6,
		Lifetime = NumberRange.new(1.4, 2.2),
		LightEmission = 0,
		ZOffset = -1,
		RotSpeed = NumberRange.new(-40, 40),
	})
	burst(a, 14, { -- dust rolling out over the road
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(Color3.fromRGB(74, 68, 70), Color3.fromRGB(37, 35, 38)),
		Transparency = seq(0.5, 1),
		Size = seq(1 * S, 3 * S),
		Speed = NumberRange.new(7 * S, 11 * S),
		SpreadAngle = Vector2.new(180, 8),
		EmissionDirection = Enum.NormalId.Right,
		Drag = 2.5,
		Lifetime = NumberRange.new(0.8, 1.2),
		LightEmission = 0,
		ZOffset = -2,
	})

	-- a thin ring and a dark scorch on the road
	local ring = part("MineRing", Color3.fromRGB(255, 74, 32), true, Vector3.new(0.05, 1, 1) * S)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.5
	fade(ring, 0.45, { Size = Vector3.new(0.05, 18, 18) * S })
	local scorch = part("Scorch", Color3.new(0, 0, 0), false, Vector3.new(0.02, 4, 4) * S)
	scorch.Shape = Enum.PartType.Cylinder
	scorch.CFrame = CFrame.new(at - Vector3.new(0, 0.15 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
	scorch.Transparency = 0.3
	fade(scorch, 1.8, {})
	chips(at, Color3.fromRGB(20, 21, 25), 4, 0.5, 9)
	chips(at, Color3.fromRGB(232, 32, 47), 4, 0.5, 9)
	chips(at, Color3.fromRGB(106, 112, 124), 2, 0.5, 9)
	sound("mineBoom", nil, at)
	task.delay(2.4, function()
		host:Destroy()
	end)
end

-- ice blocks on frozen karts, by kart id
local ice: { [any]: BasePart } = {}

local function melt(id: any)
	local b = ice[id]
	ice[id] = nil
	if b and b.Parent then
		fade(b, 0.25, {})
	end
end

local function onFreezeHit(data: any)
	local at = vec(data, "position")
	if not at or type(data) ~= "table" then
		return
	end
	local id = data.id
	local seconds = if type(data.seconds) == "number" then math.clamp(data.seconds, 0, 10) else 2.5
	melt(id)
	local b = part("Ice", ICE, false, Vector3.new(4.5, 4, 7.5) * S)
	b.Transparency = 0.35
	b.Reflectance = 0.2
	b.CFrame = CFrame.new(at + Vector3.new(0, S, 0)) * CFrame.Angles(0, math.rad(12), 0)
	ice[id] = b
	flash(at, WHITE, 3, 10, 0.2)
	sound("freeze", nil, at)
	task.delay(seconds, function()
		if ice[id] == b then
			melt(id)
		end
	end)
end

local function onShatter(data: any)
	local at = vec(data, "position")
	if type(data) ~= "table" then
		return
	end
	local b = ice[data.id]
	ice[data.id] = nil
	if b then
		b:Destroy()
	end
	if at then
		chips(at + Vector3.new(0, S, 0), ICE, 10, 1.2, 9)
		chips(at + Vector3.new(0, S, 0), WHITE, 4, 0.8, 6)
		flash(at, SKY, 3, 12, 0.25)
	end
	sound("shatter", nil, at)
end

function FxGunMine.handle(kind: string, data: any)
	if kind == "GunShot" then
		onGun(data)
	elseif kind == "MineDrop" then
		sound("mineDrop", data, vec(data, "position"))
	elseif kind == "MineBoom" then
		onMineBoom(data)
	elseif kind == "FreezeShot" then
		local a, b = vec(data, "from"), vec(data, "to")
		if a and b then
			beam(a, b, ICE, 0.6, 0.45) -- (fades early: still clear at 0.3 s, auditor Road to 9/10 item 2)
			sound("freezeShot", data, a)
		end
	elseif kind == "FreezeHit" then
		onFreezeHit(data)
	elseif kind == "Shatter" then
		onShatter(data)
	end
end

-- mines blink their red dome, side slits and road glow (server parts in workspace.Mines)
local blink = 0
local wasOn = false
RunService.RenderStepped:Connect(function(dt: number)
	blink += dt
	local mines = workspace:FindFirstChild("Mines")
	if not mines then
		return
	end
	local on = blink % 0.6 < 0.3
	if on == wasOn then
		return
	end
	wasOn = on
	for _, m in mines:GetChildren() do
		for _, p in m:GetChildren() do
			if p.Name == "Light" and p:IsA("BasePart") then
				p.Transparency = if on then 0 else 0.6
				local glow = p:FindFirstChildOfClass("PointLight")
				if glow then
					glow.Enabled = on
				end
			elseif p.Name == "Slit" and p:IsA("BasePart") then
				p.Color = if on then Color3.fromRGB(255, 26, 42) else Color3.fromRGB(58, 5, 8)
			end
		end
	end
end)

return FxGunMine
