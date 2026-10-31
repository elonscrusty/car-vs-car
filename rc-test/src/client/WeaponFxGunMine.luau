--!strict
-- Machine gun, mines and freeze, drawn (plans/smash, GUNMINE row). The server decides every hit;
-- client/WeaponFx hands this module every WeaponFx kind that isn't a rocket:
--   GunShot    { from, to, hit }        a sunny-yellow tracer, a muzzle flash, sparks if it hit
--   MineDrop   { position, from? }      the drop sound; the mine is a server part (workspace.Mines), a toy
--                                       one is flung from the dropper's spoon `from` to it
--   MineBoom   { position }             a flat pink-orange blast ring and a flash
--   FreezeShot { from, to, hit }        a sky-blue ice bolt
--   FreezeHit  { id, position, seconds } an ice block over the kart until it melts
--   Shatter    { id, position }         the ice bursts into shards
--   FlameBurst { pos, to, life, range } a stream of fire balls out of the Flame Nozzle (FlameTick: nothing to draw,
--                                       SmashHits flashes the karts it burned)
-- Look rule: low-poly, SmoothPlastic + Neon, no text.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local me = Players.LocalPlayer

local FxGunMine = {}

local SUNNY = Color3.fromRGB(255, 205, 40)
local WHITE = Color3.new(1, 1, 1)
local CHERRY = Color3.fromRGB(230, 40, 60)
local PINK = Color3.fromRGB(255, 111, 181)
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

local function onMineBoom(data: any)
	local at = vec(data, "position")
	if not at then
		return
	end
	-- a flat blast disc that grows out along the road, and a hot flash
	local ring = part("MineBlast", FLAME, true, Vector3.new(0.4, 2, 2) * S)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	fade(ring, 0.4, { Size = Vector3.new(0.4, 12, 12) * S, Color = PINK })
	flash(at + Vector3.new(0, 1.5 * S, 0), SUNNY, 2, 9, 0.3)
	chips(at, CHERRY, 6, 0.8, 7)
	sound("mineBoom", nil, at)
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

-- a stream of fire balls from the nozzle along the burst, over its `life`; the hot yellow ones
-- stay near the nozzle, the orange and red ones carry the whole range and swell as they go
local function onFlame(data: any)
	local a, b = vec(data, "pos"), vec(data, "to")
	if not a or not b or type(data) ~= "table" then
		return
	end
	local life = if type(data.life) == "number" then math.clamp(data.life, 0.2, 2) else 1
	local dir = b - a
	if dir.Magnitude < 0.1 then
		return
	end
	sound("flame", data, a)
	flash(a, SUNNY, 1.5, 4, 0.12)
	local steps = math.floor(life / 0.04)
	for i = 0, steps do
		task.delay(i * 0.04, function()
			for j = 1, 2 do
				local hot = j == 1
				local ball = part(
					"Flame",
					if hot then SUNNY else FLAME,
					true,
					Vector3.new(1, 1, 1) * 1.2 * S
				)
				ball.Shape = Enum.PartType.Ball
				ball.Position = a
				local reach = if hot then 0.55 else 0.7 + math.random() * 0.3
				local spread = Vector3.new(
					math.random() - 0.5,
					math.random() * 0.4,
					math.random() - 0.5
				) * dir.Magnitude * 0.22
				local to = a + dir * reach + spread
				fade(ball, 0.3 + math.random() * 0.15, {
					Position = to,
					Size = Vector3.new(1, 1, 1) * (if hot then 2.4 else 4.2) * S,
					Color = if hot then FLAME else CHERRY,
				})
			end
		end)
	end
end

-- the Mine Dropper's "Fling" (carter 10-30): the arm lets go at the spoon on the roof and the mine
-- sails back in an arc to where the server put it. The server's mine is already there, so it is
-- hidden on this screen until the toy mine lands; a puff of dust marks the landing.
local FLING = 0.4 -- seconds in the air
local function onMineDrop(data: any)
	local from, to = vec(data, "from"), vec(data, "position")
	if not from or not to then
		return
	end
	local toy = Instance.new("Model")
	toy.Name = "FlungMine"
	local base = part("Base", Color3.fromRGB(34, 36, 64), false, Vector3.new(0.6, 2.4, 2.4) * S)
	base.Shape = Enum.PartType.Cylinder
	base.Parent = toy
	local light = part("Light", Color3.fromRGB(232, 53, 46), true, Vector3.new(0.8, 0.8, 0.8) * S)
	light.Shape = Enum.PartType.Ball
	light.Parent = toy
	toy.Parent = bits
	-- hide the real one (it may take a moment to arrive) until the toy has landed
	local hidden: { BasePart } = {}
	local folder = workspace:FindFirstChild("Mines")
	local function hideReal()
		if not folder then
			folder = workspace:FindFirstChild("Mines")
		end
		if not folder or #hidden > 0 then
			return
		end
		for _, m in folder:GetChildren() do
			local b = m:FindFirstChild("Base") :: BasePart?
			if b and (b.Position - to).Magnitude < 1.5 * S then
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p.Transparency == 0 then
						p.Transparency = 1
						table.insert(hidden, p)
					end
				end
			end
		end
	end
	local t = 0
	local spin = math.random() * 6.28
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		local a = math.min(1, t / FLING)
		hideReal()
		local at = from:Lerp(to, a) + Vector3.new(0, 4 * a * (1 - a) * 3 * S, 0)
		spin += dt * 12
		local cf = CFrame.new(at) * CFrame.Angles(spin, 0, spin * 0.6)
		base.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		light.CFrame = cf * CFrame.new(0, 0.4 * S, 0)
		if a >= 1 then
			conn:Disconnect()
			toy:Destroy()
			for _, p in hidden do
				if p.Parent then
					p.Transparency = 0
				end
			end
			chips(to, Color3.fromRGB(120, 112, 100), 6, 0.5, 2)
		end
	end)
end

function FxGunMine.handle(kind: string, data: any)
	if kind == "FlameBurst" then
		onFlame(data)
	elseif kind == "GunShot" then
		onGun(data)
	elseif kind == "MineDrop" then
		sound("mineDrop", data, vec(data, "position"))
		onMineDrop(data)
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

-- mines blink their red light (server parts in workspace.Mines)
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
		local light = m:FindFirstChild("Light")
		if light and light:IsA("BasePart") then
			light.Transparency = if on then 0 else 0.6
		end
	end
end)

return FxGunMine
