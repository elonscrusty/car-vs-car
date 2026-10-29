--!strict
-- Machine gun, mines and freeze, drawn (plans/smash, GUNMINE row). The server decides every hit;
-- client/WeaponFx hands this module every WeaponFx kind that isn't a rocket:
--   GunShot    { from, to, hit }        "Hot Lead+": twin star flash, glowing bullet, shell, sparks
--   MineDrop   { position }             the drop sound (the mine is a server part, workspace.Mines)
--   MineBoom   { position }             a flat pink-orange blast ring and a flash
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

-- Machine gun look "Hot Lead+" (carter picked it on the gun preview page,
-- car-vs-car/gun-preview/gun-pick.html, style A; numbers are the page's, times S).
local GOLD = Color3.fromRGB(255, 197, 58)
local HOT = Color3.fromRGB(255, 160, 32)
local EMBER = Color3.fromRGB(255, 106, 16)
local CREAM = Color3.fromRGB(255, 246, 208)
local BRASS = Color3.fromRGB(216, 160, 48)
local SMOKE = Color3.fromRGB(122, 112, 104)
local TWIN = 0.75 -- the shots come from 2 spots on the nose, left then right
local BULLET_SPEED = 400 -- big units a second (the server already hit: the bullet only shows it)
local BULLET_MAX = 0.12 -- seconds, however far

-- one shared spark spray: moved to a spot, then Emit (the default texture is a bright spark)
local sparkHost = part("SparkHost", WHITE, false, Vector3.new(0.1, 0.1, 0.1))
sparkHost.Transparency = 1
local sparks = Instance.new("ParticleEmitter")
sparks.Enabled = false
sparks.LightEmission = 1
sparks.LightInfluence = 0
sparks.Color = ColorSequence.new(CREAM, EMBER)
sparks.Size = NumberSequence.new(0.26 * S, 0.04 * S)
sparks.Lifetime = NumberRange.new(0.3, 0.6)
sparks.Speed = NumberRange.new(9 * S, 18 * S)
sparks.SpreadAngle = Vector2.new(70, 70)
sparks.Acceleration = Vector3.new(0, -30 * S, 0)
sparks.Drag = 1
sparks.Parent = sparkHost

local function spray(at: Vector3, toward: Vector3, n: number)
	sparkHost.CFrame = CFrame.lookAt(at, at + toward) * CFrame.Angles(-math.rad(90), 0, 0)
	sparks:Emit(n)
end

-- a 4-point star: two thin neon bars crossed, facing along `dir`, that pop and fade
local function star(at: Vector3, dir: Vector3, color: Color3, size: number, seconds: number)
	local face = CFrame.lookAt(at, at + dir) * CFrame.Angles(0, 0, math.random() * 1.5)
	for i = 0, 1 do
		local bar = part("Star", color, true, Vector3.new(size, size * 0.12, 0.05) * S)
		bar.CFrame = face * CFrame.Angles(0, 0, i * math.rad(90))
		fade(bar, seconds, { Size = Vector3.new(size * 1.3, size * 0.04, 0.05) * S })
	end
end

local function puff(at: Vector3, from: number, to: number, seconds: number)
	local b = part("Smoke", SMOKE, false, Vector3.new(from, from, from) * S)
	b.Shape = Enum.PartType.Ball
	b.Transparency = 0.6
	b.Position = at
	fade(
		b,
		seconds,
		{ Size = Vector3.new(to, to, to) * S, Position = at + Vector3.new(0, 1.2 * S, 0) }
	)
end

-- a brass shell kicked up and back off the car, landing about where it started
local function shell(at: Vector3, back: Vector3)
	local c = part("Shell", BRASS, false, Vector3.new(0.25, 0.14, 0.14) * S)
	c.CFrame = CFrame.new(at)
	local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2 * S
	local top = at + back * 1.2 * S + side + Vector3.new(0, 1.6 * S, 0)
	local land = at + back * 2 * S + side * 2 - Vector3.new(0, 1.1 * S, 0)
	local up = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local down = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local t = TweenService:Create(c, up, { CFrame = CFrame.new(top) * CFrame.Angles(3, 2, 0) })
	t.Completed:Connect(function()
		TweenService:Create(c, down, { CFrame = CFrame.new(land) * CFrame.Angles(6, 4, 0) }):Play()
	end)
	t:Play()
	task.delay(0.9, function()
		c:Destroy()
	end)
end

-- the glowing bullet: a cream core in an orange glow, flying from a to b, with a thin gold streak
local function bullet(a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	if len < 0.1 then
		return
	end
	local seconds = math.min(len / (BULLET_SPEED * S), BULLET_MAX)
	local glow = part("Bullet", HOT, true, Vector3.new(0.3, 0.3, 3.4) * 0.6 * S)
	glow.Transparency = 0.3
	local core = part("BulletCore", CREAM, true, Vector3.new(0.17, 0.17, 2.4) * 0.6 * S)
	local start = CFrame.lookAt(a, b)
	local goal = start + (b - a)
	glow.CFrame = start
	core.CFrame = start
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear)
	TweenService:Create(glow, info, { CFrame = goal }):Play()
	TweenService:Create(core, info, { CFrame = goal }):Play()
	task.delay(seconds, function()
		glow:Destroy()
		core:Destroy()
	end)
	beam(a, b, GOLD, 0.1, seconds + 0.06)
end

local function hitFx(at: Vector3, back: Vector3, kart: boolean)
	star(at, back, WHITE, 2.2, 0.07)
	flash(at, CREAM, 1.8, 0.6, 0.12)
	spray(at, back, if kart then 14 else 5)
	if kart then
		-- a hot mark that glows and cools, two dark chips, a little smoke
		local mark = part("HotSpot", EMBER, true, Vector3.new(0.55, 0.55, 0.55) * S)
		mark.Shape = Enum.PartType.Ball
		mark.Position = at + back * 0.05 * S
		fade(
			mark,
			1.2,
			{ Size = Vector3.new(0.35, 0.35, 0.35) * S, Color = Color3.fromRGB(64, 16, 0) }
		)
		chips(at, Color3.fromRGB(40, 40, 46), 2, 0.18, 7)
		puff(at, 0.5, 1.7, 0.8)
	end
end

-- left then right, per shooter
local side: { [any]: number } = {}

local function onGun(data: any)
	local a, b = vec(data, "from"), vec(data, "to")
	if not a or not b then
		return
	end
	local dir = (b - a).Unit
	if dir ~= dir then
		return
	end
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude > 1e-3 then
		local owner = if type(data) == "table" then data.owner else nil
		local k = if owner ~= nil then owner else 0
		side[k] = -(side[k] or 1)
		a += right.Unit * side[k] * TWIN * S
	end
	-- muzzle: a big star, a hot ball, a few sparks forward, a puff, a shell
	star(a, dir, CREAM, 3.4, 0.06)
	star(a + dir * 0.6 * S, dir, WHITE, 2, 0.05)
	local light = part("MuzzleLight", HOT, true, Vector3.new(1.6, 1.6, 1.6) * S)
	light.Shape = Enum.PartType.Ball
	light.Position = a + dir * S
	local glow = Instance.new("PointLight")
	glow.Color = HOT
	glow.Range = 9 * S * 2
	glow.Brightness = 6
	glow.Parent = light
	TweenService:Create(glow, TweenInfo.new(0.08), { Brightness = 0 }):Play()
	fade(light, 0.08, { Size = Vector3.new(0.4, 0.4, 0.4) * S })
	spray(a, dir, 3)
	puff(a, 0.35, 1.4, 0.6)
	shell(a, -dir)
	bullet(a, b)
	local hitKart = type(data) == "table" and data.hit == true
	task.delay(math.min((b - a).Magnitude / (BULLET_SPEED * S), BULLET_MAX), function()
		hitFx(b, -dir, hitKart)
	end)
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
