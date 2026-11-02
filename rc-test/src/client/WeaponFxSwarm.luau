--!strict
-- FIRE SWARM, drawn (shared/FireSwarm, server/weapons/Swarm). The server decides every hit;
-- client/WeaponFx hands this module every WeaponFx kind that starts with "Swarm":
--   SwarmLaunch { owner, from, dir, to, count }  4 fire rockets climb out of the car and fan out
--   SwarmLock   { owner, to }                    the red lock ring slides to the target
--   SwarmDive   { owner, i, to, arrive }         rocket i dives onto `to`
--   SwarmBoom   { owner, i, pos, hurt }          rocket i blew up there
--   SwarmClear  { }                              match over, everything vanishes
-- The look is "3 Meteor Rain" from the preview page: up high, a beat of hang, then all dive.
-- Look rule: low-poly, SmoothPlastic + Neon, no text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local FireSwarm = require(Shared:WaitForChild("FireSwarm"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local me = Players.LocalPlayer

local FxSwarm = {}

local CHERRY = Color3.fromRGB(230, 40, 60)
local SUNNY = Color3.fromRGB(255, 205, 40)
local FLAME = Color3.fromRGB(255, 130, 30)
local RING = Color3.fromRGB(255, 42, 42)

local K = Weapons.KART
local HEIGHT = 7 * K -- how high the rockets climb
local FAN = { -1, 1, -0.45, 0.45 } -- left to right, by rocket
local MAX_LIFE = 4 -- a swarm whose boom was lost is tidied away after this long

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

local function at(data: any, pos: Vector3?): Vector3?
	return if data.owner == me.UserId then nil else pos
end

local function part(name: string, color: Color3, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	return p
end

-- one fire rocket: a hot red body with a flame trail behind it (faces -Z)
local function rocketPart(): Part
	local p = part("SwarmRocket", CHERRY, Vector3.new(0.07, 0.07, 0.3) * K)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.04 * K, 0.15 * K)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.04 * K, 0.15 * K)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(SUNNY, FLAME)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = 0.4
	trail.LightEmission = 0.8
	trail.Parent = p
	return p
end

local function boom(pos: Vector3)
	local size = FireSwarm.SPEC.splash * 2
	local ball = part("SwarmBoom", FLAME, Vector3.one * 0.3 * K)
	ball.Shape = Enum.PartType.Ball
	ball.Position = pos
	ball.Transparency = 0.1
	ball.Parent = bits
	TweenService:Create(
		ball,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size, Transparency = 1, Color = SUNNY }
	):Play()
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(SUNNY, CHERRY)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(0.25 * K, 0)
	e.Speed = NumberRange.new(size * 1.5, size * 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Drag = 4
	e.Rate = 0
	e.Parent = ball
	e:Emit(28)
	task.delay(0.8, function()
		ball:Destroy()
	end)
end

-- a swarm in the air, keyed by its owner (one swarm per kart at a time: the refill is longer)
type Rocket = { p: Part, diveFrom: Vector3?, diveTo: Vector3?, diveAge: number, arrive: number }
type Swarm = { age: number, from: Vector3, dir: Vector3, rockets: { [number]: Rocket }, ring: Part }
local swarms: { [any]: Swarm } = {}

local function drop(owner: any)
	local s = swarms[owner]
	if not s then
		return
	end
	swarms[owner] = nil
	for _, r in s.rockets do
		r.p:Destroy()
	end
	s.ring:Destroy()
end

local function ringPart(to: Vector3): Part
	local ring = part("SwarmRing", RING, Vector3.new(0.05 * K, 3 * K, 3 * K))
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.3
	ring.CFrame = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = bits
	return ring
end

local function vec(data: any, key: string): Vector3?
	local v = type(data) == "table" and data[key]
	return if typeof(v) == "Vector3" then v else nil
end

local function launch(data: any)
	local from, dir, to = vec(data, "from"), vec(data, "dir"), vec(data, "to")
	local owner = data.owner
	local count = if type(data.count) == "number" then math.clamp(data.count, 1, 4) else 4
	if not from or not dir or not to or owner == nil then
		return
	end
	drop(owner)
	local s: Swarm = { age = 0, from = from, dir = dir, rockets = {}, ring = ringPart(to) }
	for i = 0, count - 1 do
		local p = rocketPart()
		p.Parent = bits
		s.rockets[i] = { p = p, diveAge = 0, arrive = FireSwarm.DIVE }
	end
	swarms[owner] = s
	Sfx.rocket(at(data, from))
end

function FxSwarm.handle(kind: string, data: any)
	if kind == "SwarmClear" then
		for owner in swarms do
			drop(owner)
		end
		return
	end
	if type(data) ~= "table" then
		return
	end
	if kind == "SwarmLaunch" then
		launch(data)
		return
	end
	local s = swarms[data.owner]
	if not s then
		return
	end
	local to = vec(data, "to")
	if kind == "SwarmLock" and to then
		s.ring.CFrame = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90))
	elseif kind == "SwarmDive" and to and type(data.i) == "number" then
		local r = s.rockets[data.i]
		if r then
			r.diveFrom = r.p.Position
			r.diveTo = to
			r.diveAge = 0
			r.arrive = if type(data.arrive) == "number" then math.max(0.1, data.arrive) else 0.35
			s.ring.CFrame = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90))
		end
	elseif kind == "SwarmBoom" and type(data.i) == "number" then
		local r = s.rockets[data.i]
		local pos = vec(data, "pos")
		if r then
			r.p:Destroy()
			s.rockets[data.i] = nil
		end
		if pos then
			boom(pos)
			Sfx.boom(at(data, pos))
		end
		if next(s.rockets) == nil then
			drop(data.owner)
		end
	end
end

RunService.RenderStepped:Connect(function(dt: number)
	for owner, s in swarms do
		s.age += dt
		if s.age > MAX_LIFE then
			drop(owner)
			continue
		end
		-- the lock ring pulses and shrinks toward the dive
		local shrink = 1 - 0.45 * math.clamp(s.age / FireSwarm.DIVE_AT, 0, 1)
		s.ring.Size = Vector3.new(0.05 * K, 3 * K * shrink, 3 * K * shrink)
		s.ring.Transparency = 0.2 + 0.4 * math.abs(math.sin(s.age * 16))
		local side = s.dir:Cross(Vector3.yAxis)
		side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
		for i, r in s.rockets do
			local goal: Vector3
			local aim: Vector3
			if r.diveFrom and r.diveTo then
				r.diveAge += dt
				local t = math.clamp(r.diveAge / r.arrive, 0, 1)
				goal = r.diveFrom:Lerp(r.diveTo, t * t) -- speeding up as it falls
				aim = r.diveTo - r.diveFrom
			else
				-- climb: up, a little forward, fanned out left to right; then a gentle hang
				local k = math.clamp(s.age / FireSwarm.CLIMB, 0, 1)
				local up = math.sin(k * math.pi / 2)
				local bob = if k >= 1 then 0.1 * K * math.sin(s.age * 9 + i) else 0
				goal = s.from
					+ Vector3.new(0, HEIGHT * up + bob, 0)
					+ s.dir * (2 * K * k)
					+ side * ((FAN[i + 1] or 0) * 3 * K * k)
				aim = Vector3.yAxis * (1 - k) + s.dir * 0.2
			end
			if aim.Magnitude < 1e-3 then
				aim = s.dir
			end
			r.p.CFrame = CFrame.lookAt(goal, goal + aim)
		end
	end
end)

return FxSwarm
