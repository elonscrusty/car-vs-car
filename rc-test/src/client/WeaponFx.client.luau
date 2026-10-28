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

local bits = Instance.new("Folder")
bits.Name = "WeaponBits"
bits.Parent = workspace

local function sound(name: string)
	local fn = (Sfx :: any)[name]
	if type(fn) == "function" then
		fn()
	end
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

-- a rocket: red body, yellow nose, navy fins, a flame and a short smoke trail; faces -Z
local function rocketModel(nuke: boolean): Model
	local m = Instance.new("Model")
	m.Name = if nuke then "Nuke" else "Rocket"
	local body = part("Body", if nuke then NAVY else CHERRY, false, Vector3.new(1, 1, 3.2))
	body.Parent = m
	m.PrimaryPart = body
	local nose = part("Nose", SUNNY, true, Vector3.new(0.8, 0.8, 0.9))
	nose.CFrame = CFrame.new(0, 0, -2)
	nose.Parent = m
	for i = 0, 1 do
		local fin = part(
			"Fin",
			NAVY,
			false,
			Vector3.new(if i == 0 then 2 else 0.2, if i == 0 then 0.2 else 2, 0.8)
		)
		fin.CFrame = CFrame.new(0, 0, 1.3)
		fin.Parent = m
	end
	local flame = part("Flame", FLAME, true, Vector3.new(0.7, 0.7, 1))
	flame.CFrame = CFrame.new(0, 0, 2.1)
	flame.Parent = m
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = flame
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = flame
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(FLAME, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.6
	trail.Parent = flame
	-- the parts were placed around the origin: weld them by moving as one (PivotTo)
	m.WorldPivot = CFrame.new()
	if nuke then
		-- the nuke: the same shape, twice as big, navy with a pulsing yellow nose
		m:ScaleTo(2.2)
		local n = m:FindFirstChild("Nose") :: BasePart?
		if n then
			TweenService:Create(
				n,
				TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Color = CHERRY }
			):Play()
		end
	end
	return m
end

type Live = { model: Model, pos: Vector3, dir: Vector3, age: number, spec: Weapons.Flight }
local live: { [number]: Live } = {}

local function place(l: Live)
	l.model:PivotTo(CFrame.lookAt(l.pos, l.pos + l.dir))
end

local function boom(at: Vector3, spec: Weapons.Flight, nuke: boolean)
	local size = spec.splash * 2
	local ball = part("Boom", FLAME, true, Vector3.new(2, 2, 2))
	ball.Shape = Enum.PartType.Ball
	ball.Position = at
	ball.Transparency = 0.1
	ball.Parent = bits
	TweenService:Create(
		ball,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(size, size, size), Transparency = 1, Color = SUNNY }
	):Play()
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(SUNNY, CHERRY)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(1.6, 0)
	e.Speed = NumberRange.new(18, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Drag = 4
	e.Rate = 0
	e.Parent = ball
	e:Emit(if nuke then 120 else 40)
	if nuke then
		-- a flat ring rolls out over the ground as far as the boom reaches
		local ring = part("Ring", SUNNY, true, Vector3.new(0.6, 4, 4))
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.2
		ring.Parent = bits
		TweenService:Create(
			ring,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.6, size * 1.1, size * 1.1), Transparency = 1 }
		):Play()
		task.delay(0.7, function()
			ring:Destroy()
		end)
	end
	task.delay(0.8, function()
		ball:Destroy()
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
			old.model:Destroy()
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
		sound(if name == "Nuke" then "nukeLaunch" else "rocketLaunch")
	elseif kind == "RocketTurn" and pos and dir then
		local l = live[id]
		if l then
			l.pos, l.dir = pos, dir
		end
	elseif kind == "RocketBoom" then
		local l = live[id]
		live[id] = nil
		if l then
			l.model:Destroy()
		end
		if pos and data.quiet ~= true then
			local nuke = data.kind == "Nuke"
			boom(pos, if nuke then Weapons.NUKE else Weapons.ROCKET, nuke)
			sound(if nuke then "nukeBoom" else "rocketBoom")
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
			l.model:Destroy()
			live[id] = nil
		else
			l.pos += l.dir * l.spec.speed * dt
			place(l)
		end
	end
end)
