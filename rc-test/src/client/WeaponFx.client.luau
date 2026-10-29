--!strict
-- Car VS Car SMASH weapons, drawn (plans/smash, WEAPONS row). The server moves every rocket and
-- decides every hit; this only draws what the WeaponFx remote says:
--   RocketLaunch { id, kind, pos, dir }  a low-poly rocket (or the big NUKE) flies on from pos
--   RocketTurn   { id, pos, dir }  it bent toward a kart: carry on from the new spot
--   RocketBoom   { id, kind, pos, quiet? }  it blew up there (quiet = match over, just vanish)
-- Gun and mine kinds go to client/WeaponFxGunMine (the GUNMINE row's file) when it is there.
-- Look rule: low-poly, SmoothPlastic + Neon, no text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local remote = ReplicatedStorage:WaitForChild(Weapons.FX_REMOTE) :: RemoteEvent

local CHERRY = Color3.fromRGB(230, 40, 60)
local SUNNY = Color3.fromRGB(255, 205, 40)
local FLAME = Color3.fromRGB(255, 130, 30)
local NAVY = Color3.fromRGB(30, 36, 70)

-- the arena is RC-sized: a kart is Weapons.KART studs long, so every look is sized from that
local K = Weapons.KART
-- the rocket is built about 5 studs long; it should be about 0.6 of a kart
local ROCKET_SCALE = 0.6 * K / 5.05

local bits = Instance.new("Folder")
bits.Name = "WeaponBits"
bits.Parent = workspace

-- my own shots play full; other karts' fade with distance (the SOUNDS row's Sfx)
local me = game:GetService("Players").LocalPlayer
local function at(data: any, pos: Vector3?): Vector3?
	return if data.owner == me.UserId then nil else pos
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
	return p
end

-- carter's pick (10-29, "Shark"): a black rocket with a red nose, chrome bands, a red glow stripe
-- and four red fins; a white-hot to orange fire trail with dark smoke behind it. Faces -Z.
local INK = Color3.fromRGB(22, 23, 29)
local SHARK_RED = Color3.fromRGB(232, 32, 47)
local GLOW_RED = Color3.fromRGB(255, 32, 48)
local CHROME = Color3.fromRGB(205, 210, 220)
local NOZZLE = Color3.fromRGB(58, 61, 70)
local HOT = Color3.fromRGB(255, 243, 192)
local DEEP = Color3.fromRGB(192, 16, 0)
local SOOT = Color3.fromRGB(42, 34, 36)
local SOOT_DARK = Color3.fromRGB(15, 15, 18)

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

-- a tube along Z (a Roblox cylinder lies along X, so it is turned a quarter)
local function tube(
	name: string,
	color: Color3,
	neon: boolean,
	length: number,
	width: number,
	z: number
): Part
	local p = part(name, color, neon, Vector3.new(length, width, width))
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
	return p
end

local function rocketModel(nuke: boolean): Model
	local m = Instance.new("Model")
	m.Name = if nuke then "Nuke" else "Rocket"
	local main = if nuke then NAVY else INK
	local trim = if nuke then SUNNY else SHARK_RED
	local body = tube("Body", main, false, 2.8, 0.95, 0)
	body.Parent = m
	m.PrimaryPart = body
	-- a pointed nose: a stretched ball, half inside the body
	local nose = part("Nose", trim, nuke, Vector3.new(0.95, 0.95, 2.5))
	nose.CFrame = CFrame.new(0, 0, -1.4)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = nose
	nose.Parent = m
	for _, z in { -0.87, 0.77 } do
		local band = tube("Band", CHROME, false, 0.17, 1, z)
		band.Reflectance = 0.4
		band.Parent = m
	end
	tube("Stripe", if nuke then SUNNY else GLOW_RED, true, 0.7, 0.99, -0.2).Parent = m
	-- four swept fins at the tail, tall at the back
	for i = 0, 3 do
		local fin = Instance.new("WedgePart")
		fin.Name = "Fin"
		fin.Anchored, fin.CanCollide, fin.CanQuery, fin.CanTouch = true, false, false, false
		fin.CastShadow = false
		fin.Material = Enum.Material.SmoothPlastic
		fin.Color = trim
		fin.Size = Vector3.new(0.08, 0.8, 1.1)
		fin.CFrame = CFrame.Angles(0, 0, math.rad(45 + 90 * i)) * CFrame.new(0, 0.87, 0.95)
		fin.Parent = m
	end
	tube("Nozzle", NOZZLE, false, 0.45, 0.68, 1.6).Parent = m
	local jet = part("Jet", FLAME, true, Vector3.one * 0.55)
	jet.Shape = Enum.PartType.Ball
	jet.CFrame = CFrame.new(0, 0, 1.95)
	jet.Parent = m
	m.WorldPivot = CFrame.new()
	local mul = if nuke then 2.2 else 1
	m:ScaleTo(ROCKET_SCALE * mul)
	if nuke then
		TweenService:Create(
			nose,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Color = CHERRY }
		):Play()
	end

	-- the fire and smoke are added after the scale, sized in karts (s): the rocket moves about
	-- 48 of its own lengths a second, so ribbons carry the trail and particles add the puffs
	local s = K * mul
	local light = Instance.new("PointLight")
	light.Color = FLAME
	light.Range = 1.5 * s
	light.Brightness = 3
	light.Parent = jet
	local nozzle = Instance.new("Attachment")
	nozzle.Name = "Exhaust"
	nozzle.Parent = jet
	local function ribbon(name: string, half: number): (Attachment, Attachment)
		local a0 = Instance.new("Attachment")
		a0.Name = name .. "0"
		a0.Position = Vector3.new(0, half, 0)
		a0.Parent = jet
		local a1 = Instance.new("Attachment")
		a1.Name = name .. "1"
		a1.Position = Vector3.new(0, -half, 0)
		a1.Parent = jet
		return a0, a1
	end
	local f0, f1 = ribbon("Fire", 0.12 * s)
	local k0, k1 = ribbon("Smoke", 0.1 * s)
	local fire = Instance.new("Trail")
	fire.Name = "FireTrail"
	fire.Attachment0, fire.Attachment1 = f0, f1
	fire.FaceCamera = true
	fire.Lifetime = 0.1
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.35, FLAME),
		ColorSequenceKeypoint.new(1, DEEP),
	})
	fire.Transparency = seq(0, 0.3, 1)
	fire.WidthScale = seq(1, 0.25)
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Parent = jet
	local smoke = Instance.new("Trail")
	smoke.Name = "SmokeTrail"
	smoke.Attachment0, smoke.Attachment1 = k0, k1
	smoke.FaceCamera = true
	smoke.Lifetime = 0.45
	smoke.Color = ColorSequence.new(SOOT, SOOT_DARK)
	smoke.Transparency = seq(0.55, 0.7, 1)
	smoke.WidthScale = seq(0.8, 3.5)
	smoke.LightEmission = 0
	smoke.Parent = jet

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Texture = FIRE_TEX
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 210, 122), Color3.fromRGB(255, 42, 0))
	flame.Transparency = seq(0.25, 1)
	flame.Size = seq(0.35 * s, 0.05 * s)
	flame.Lifetime = NumberRange.new(0.1, 0.18)
	flame.Speed = NumberRange.new(0.5 * s, 1.5 * s)
	flame.SpreadAngle = Vector2.new(15, 15)
	flame.Rotation = NumberRange.new(0, 360)
	flame.RotSpeed = NumberRange.new(-90, 90)
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.ZOffset = 1
	flame.Rate = 100
	flame.Parent = nozzle
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "Smoke"
	puff.Texture = SMOKE_TEX
	puff.EmissionDirection = Enum.NormalId.Back
	puff.Color = ColorSequence.new(Color3.fromRGB(58, 52, 54), Color3.fromRGB(21, 21, 26))
	puff.Transparency = seq(0.5, 0.65, 1)
	puff.Size = seq(0.25 * s, 1 * s)
	puff.Lifetime = NumberRange.new(0.7, 1.1)
	puff.Speed = NumberRange.new(0.1 * s, 0.3 * s)
	puff.SpreadAngle = Vector2.new(40, 40)
	puff.Acceleration = Vector3.new(0, 0.3 * s, 0)
	puff.Drag = 1.5
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-40, 40)
	puff.LightEmission = 0
	puff.ZOffset = -1
	puff.Rate = 60
	puff.Parent = nozzle
	return m
end

-- a rocket that ends leaves its smoke behind: the puffs already out fade on their own
local function retire(model: Model)
	local jet = model:FindFirstChild("Jet") :: BasePart?
	local nozzle = jet and jet:FindFirstChild("Exhaust") :: Attachment?
	if jet and nozzle then
		local holder = part("Leftover", FLAME, false, Vector3.one * 0.1)
		holder.Transparency = 1
		holder.CFrame = jet.CFrame
		holder.Parent = bits
		nozzle.Parent = holder
		for _, e in nozzle:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.delay(1.2, function()
			holder:Destroy()
		end)
	end
	model:Destroy()
end

type Live = { model: Model, pos: Vector3, dir: Vector3, age: number, spec: Weapons.Flight }
local live: { [number]: Live } = {}

local function place(l: Live)
	l.model:PivotTo(CFrame.lookAt(l.pos, l.pos + l.dir))
end

local function burst(host: Attachment, name: string, count: number, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = host
	e:Emit(count)
end

-- the Shark's boom, sized by the splash (r): a white flash, an orange fireball, sparks that fall,
-- dark smoke that rises (the dark layer gives the fire its shape) and a ring on the ground
local function boom(at: Vector3, spec: Weapons.Flight, nuke: boolean)
	local r = spec.splash
	local n = if nuke then 1.8 else 1
	local host = part("Boom", FLAME, false, Vector3.one * 0.1)
	host.Transparency = 1
	host.Position = at
	host.Parent = bits
	local a = Instance.new("Attachment")
	a.Parent = host

	local flash = part("Flash", Color3.fromRGB(255, 241, 200), true, Vector3.one * 0.3 * r)
	flash.Shape = Enum.PartType.Ball
	flash.Position = at
	flash.Parent = bits
	TweenService:Create(
		flash,
		TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 1.6 * r, Transparency = 1 }
	):Play()
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 64)
	light.Range = math.min(3 * r, 60)
	light.Brightness = 6
	light.Parent = host
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()

	burst(a, "Fireball", math.floor(50 * n), {
		Texture = FIRE_TEX,
		Color = ColorSequence.new(Color3.fromRGB(255, 176, 64), DEEP),
		Transparency = seq(0.15, 1),
		Size = seq(0.45 * r, 0.1 * r),
		Speed = NumberRange.new(1.2 * r, 3 * r),
		Drag = 4,
		Lifetime = NumberRange.new(0.3, 0.6),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		ZOffset = 2,
		RotSpeed = NumberRange.new(-120, 120),
	})
	burst(a, "Sparks", math.floor(30 * n), {
		Texture = SPARK_TEX,
		Color = ColorSequence.new(Color3.fromRGB(255, 233, 160), Color3.fromRGB(255, 96, 16)),
		Size = seq(0.08 * r, 0),
		Speed = NumberRange.new(4 * r, 7 * r),
		Drag = 2.5,
		Acceleration = Vector3.new(0, -5 * r, 0),
		Lifetime = NumberRange.new(0.25, 0.6),
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = 3,
	})
	burst(a, "Smoke", math.floor(22 * n), {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(SOOT, SOOT_DARK),
		Transparency = seq(0.2, 0.5, 1),
		Size = seq(0.3 * r, 1.1 * r),
		Speed = NumberRange.new(0.4 * r, 1.2 * r),
		Acceleration = Vector3.new(0, 0.6 * r, 0),
		Drag = 2,
		Lifetime = NumberRange.new(1.2, 1.9),
		LightEmission = 0,
		ZOffset = -1,
		RotSpeed = NumberRange.new(-40, 40),
	})

	-- the ring rolls out on the floor under the boom (or at the boom if there is no floor near)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { bits }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(at, Vector3.new(0, -2 * K, 0), params)
	local floor = if hit then hit.Position + Vector3.new(0, 0.05, 0) else at
	local ring =
		part("Ring", Color3.fromRGB(255, 138, 42), true, Vector3.new(0.05 * K, 0.2 * r, 0.2 * r))
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = bits
	TweenService:Create(
		ring,
		TweenInfo.new(0.45, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05 * K, 2 * r, 2 * r), Transparency = 1 }
	):Play()
	task.delay(0.5, function()
		flash:Destroy()
		ring:Destroy()
	end)
	task.delay(2.2, function()
		host:Destroy()
	end)
end

local function fromData(data: any, key: string): Vector3?
	local v = type(data) == "table" and data[key]
	return if typeof(v) == "Vector3" then v else nil
end

local function onRocket(kind: string, data: any)
	local id = type(data) == "table" and data.id
	if type(id) ~= "number" then
		return
	end
	local pos, dir = fromData(data, "pos"), fromData(data, "dir")
	if kind == "RocketLaunch" and pos and dir then
		local old = live[id]
		if old then
			retire(old.model)
		end
		local name = if data.kind == "Nuke" then "Nuke" else "Rockets"
		local l = {
			model = rocketModel(name == "Nuke"),
			pos = pos,
			dir = dir,
			age = 0,
			spec = Weapons.FLIGHTS[name],
		}
		place(l)
		l.model.Parent = bits
		live[id] = l
		Sfx.rocket(at(data, pos))
	elseif kind == "RocketTurn" and pos and dir then
		local l = live[id]
		if l then
			l.pos, l.dir = pos, dir
		end
	elseif kind == "RocketBoom" then
		local l = live[id]
		live[id] = nil
		if l then
			if data.quiet == true then
				l.model:Destroy()
			else
				retire(l.model)
			end
		end
		if pos and data.quiet ~= true then
			local nuke = data.kind == "Nuke"
			boom(pos, if nuke then Weapons.NUKE else Weapons.ROCKET, nuke)
			Sfx.boom(at(data, pos))
		end
	end
end

-- the gun and mine row's drawing (its own file, so we never edit the same one)
local gunMine: any = nil
local function forward(kind: string, data: any)
	if gunMine == nil then
		local m = script.Parent:FindFirstChild("WeaponFxGunMine")
		local ok, mod = false, nil
		if m and m:IsA("ModuleScript") then
			ok, mod = pcall(require, m)
		end
		gunMine = if ok then mod else false
	end
	if gunMine and type(gunMine.handle) == "function" then
		gunMine.handle(kind, data)
	end
end

remote.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(kind) ~= "string" then
		return
	end
	if string.sub(kind, 1, 6) == "Rocket" then
		onRocket(kind, data)
	else
		forward(kind, data)
	end
end)

-- fly every rocket straight on between the server's words; one that outlived its flight (a lost
-- boom) is tidied away
RunService.RenderStepped:Connect(function(dt: number)
	for id, l in live do
		l.age += dt
		if l.age > l.spec.life + 1 then
			retire(l.model)
			live[id] = nil
		else
			l.pos += l.dir * l.spec.speed * dt
			place(l)
		end
	end
end)
