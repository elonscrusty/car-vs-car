--!strict
-- The dynamite kegs, drawn (server/BarrelServer decides; this only shows and shoves your own kart).
--   keg models (tag "DynamiteKeg"): the fuse spark blinks slowly, fast once the keg is lit; the
--     danger ring on the floor glows amber, and flashes red when lit. A keg that is down shows nothing.
--   remote BarrelFx "Boom" { position }: white flash, shock dome, fire column, fire ball, dust ring,
--     wood chunks, sparks and smoke. About 27 short parts, all gone in 1.5 s (light for phones).
--   remote BarrelFx "Kick" { impulse }: the server's shove for YOUR kart. Taken once, clamped to
--     what the rules can ever give. (A client that ignores it only keeps its own speed: damage is the
--     server's and has already been done.)
-- Look rule: low-poly, SmoothPlastic + Neon, no studs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Barrels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Barrels"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local me = Players.LocalPlayer
local S = Barrels.SCALE -- every size below is big units times S

local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 210, 63)
local FIRE = Color3.fromRGB(255, 106, 26)
local AMBER = Color3.fromRGB(255, 176, 42)
local RED = Color3.fromRGB(255, 58, 42)
local DUST = Color3.fromRGB(107, 90, 70)
local WOOD = Color3.fromRGB(138, 90, 52)
local SMOKE = Color3.fromRGB(46, 42, 40)

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

-- ===== the waiting keg: spark blink + ring pulse =====

local function find(keg: Instance): (BasePart?, Frame?, UIStroke?)
	local spark = keg:FindFirstChild("Spark")
	local zone = keg:FindFirstChild("Zone")
	local gui = zone and zone:FindFirstChild("Ring")
	local circle = gui and gui:FindFirstChild("Circle")
	local stroke = circle and circle:FindFirstChildOfClass("UIStroke")
	return if spark and spark:IsA("BasePart") then spark else nil,
		if circle and circle:IsA("Frame") then circle else nil,
		stroke
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, keg in CollectionService:GetTagged("DynamiteKeg") do
		if keg:GetAttribute("Up") ~= true then
			continue
		end
		local spark, circle, stroke = find(keg)
		local lit = keg:GetAttribute("Lit") == true
		if spark then
			local on = math.sin(t * (if lit then 40 else 8)) > (if lit then -0.2 else 0)
			spark.Transparency = if on then 0 else 0.8
		end
		if circle and stroke then
			if lit then
				local flash = math.sin(t * 22) > 0
				stroke.Color = if flash then RED else YELLOW
				circle.BackgroundColor3 = RED
				circle.BackgroundTransparency = if flash then 0.7 else 0.9
			else
				stroke.Color = AMBER
				circle.BackgroundColor3 = AMBER
				circle.BackgroundTransparency = 0.88 - 0.06 * math.sin(t * 3)
			end
		end
	end
end)

-- ===== the boom =====

local function part(
	name: string,
	color: Color3,
	neon: boolean,
	size: Vector3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.Parent = bits
	return p
end

local function tween(
	p: BasePart,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tw = TweenService:Create(
		p,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	tw:Play()
	return tw
end

local function gone(p: BasePart, seconds: number)
	task.delay(seconds, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

-- grow `p` and fade it out, then remove it
local function burst(p: BasePart, seconds: number, goal: { [string]: any })
	goal.Transparency = 1
	tween(p, seconds, goal)
	gone(p, seconds + 0.05)
end

local rng = Random.new()

local function onBoom(data: any)
	if type(data) ~= "table" or typeof(data.position) ~= "Vector3" then
		return
	end
	local at: Vector3 = data.position
	local R = Barrels.RADIUS * S
	-- white flash
	local flash = part("KegFlash", WHITE, true, Vector3.one * 2 * S, Enum.PartType.Ball)
	flash.Position = at + Vector3.new(0, 1.6 * S, 0)
	burst(flash, 0.14, { Size = Vector3.one * 11 * S })
	-- shock dome (a big see-through ball, only for an instant)
	local dome = part(
		"KegDome",
		Color3.fromRGB(255, 242, 204),
		false,
		Vector3.one * 2 * S,
		Enum.PartType.Ball
	)
	dome.Transparency = 0.7
	dome.Position = at
	burst(dome, 0.32, { Size = Vector3.one * Barrels.RADIUS * 1.9 * S })
	-- fire column: three stacked neon tubes, tall at the middle
	for i, c in { YELLOW, FIRE, YELLOW } do
		local h = (6 + i * 4) * S
		local w = (4.2 - i * 0.9) * S
		local col = part("KegColumn", c, true, Vector3.new(0.5 * S, w, w), Enum.PartType.Cylinder)
		col.CFrame = CFrame.new(at + Vector3.new(0, 0.3 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
		task.delay((i - 1) * 0.02, function()
			if col.Parent then
				col.Transparency = 0
				tween(col, 0.3, {
					Size = Vector3.new(h, w * 0.7, w * 0.7),
					CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0))
						* CFrame.Angles(0, 0, math.rad(90)),
				})
				burst(col, 0.5, {})
			end
		end)
		col.Transparency = 1
	end
	-- fire ball
	local ball = part("KegFire", FIRE, true, Vector3.one * 2 * S, Enum.PartType.Ball)
	ball.Position = at + Vector3.new(0, 1.8 * S, 0)
	burst(
		ball,
		0.45,
		{ Size = Vector3.one * 8 * S, Position = ball.Position + Vector3.new(0, 1.2 * S, 0) }
	)
	-- dust ring along the floor
	local ring =
		part("KegDust", DUST, false, Vector3.new(0.4 * S, 2 * S, 2 * S), Enum.PartType.Cylinder)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.3 * S, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.35
	burst(ring, 0.8, { Size = Vector3.new(0.4 * S, R * 2.6, R * 2.6) })
	-- wood chunks fly up and fall (two short tweens: up, then down)
	for _ = 1, 6 do
		local sz = (0.5 + rng:NextNumber() * 0.6) * S
		local chunk = part(
			"KegChunk",
			if rng:NextNumber() < 0.7 then WOOD else SMOKE,
			false,
			Vector3.new(sz, sz * 1.3, sz * 0.5)
		)
		chunk.CFrame = CFrame.new(at + Vector3.new(0, 1.5 * S, 0))
			* CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, 0)
		local a = rng:NextNumber() * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a)) * (4 + rng:NextNumber() * 7) * S
		local peak = chunk.CFrame + out * 0.5 + Vector3.new(0, (7 + rng:NextNumber() * 5) * S, 0)
		local land = chunk.CFrame * CFrame.Angles(3, 2, 1) + out + Vector3.new(0, -1.2 * S, 0)
		local up = tween(chunk, 0.25, { CFrame = peak })
		up.Completed:Once(function()
			if chunk.Parent then
				tween(
					chunk,
					0.4,
					{ CFrame = land, Transparency = 1 },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end
		end)
		gone(chunk, 0.8)
	end
	-- sparks
	for _ = 1, 8 do
		local sp = part("KegSpark", YELLOW, true, Vector3.one * 0.4 * S)
		sp.Position = at + Vector3.new(0, 1.5 * S, 0)
		local a = rng:NextNumber() * math.pi * 2
		local goal = sp.Position
			+ Vector3.new(
				math.cos(a) * (5 + rng:NextNumber() * 8) * S,
				(4 + rng:NextNumber() * 8) * S,
				math.sin(a) * (5 + rng:NextNumber() * 8) * S
			)
		burst(sp, 0.5, { Position = goal })
	end
	-- smoke
	for _ = 1, 4 do
		local sm = part("KegSmoke", SMOKE, false, Vector3.one * 1.5 * S, Enum.PartType.Ball)
		local a = rng:NextNumber() * math.pi * 2
		sm.Position = at + Vector3.new(math.cos(a) * 1.5 * S, 2 * S, math.sin(a) * 1.5 * S)
		sm.Transparency = 0.4
		task.delay(0.15, function()
			if sm.Parent then
				burst(sm, 1.2, {
					Size = Vector3.one * (3 + rng:NextNumber() * 2) * S,
					Position = sm.Position + Vector3.new(0, (7 + rng:NextNumber() * 4) * S, 0),
				})
			end
		end)
		gone(sm, 1.5)
	end
	pcall((Sfx :: any).boom, at)
end

-- ===== the shove: the server's number, for your own kart only =====

local function onKick(data: any)
	if type(data) ~= "table" or typeof(data.impulse) ~= "Vector3" then
		return
	end
	local v: Vector3 = data.impulse
	if v ~= v then
		return -- (NaN)
	end
	local cap = Barrels.KNOCK_MAX + Barrels.KNOCK_UP
	if v.Magnitude > cap then
		v = v.Unit * cap
	end
	local car = workspace:FindFirstChild("Car_" .. me.UserId)
	local body = car and car:IsA("Model") and (car :: Model).PrimaryPart
	if body and body.Parent and not body.Anchored then
		body.AssemblyLinearVelocity += v
	end
end

local remote = ReplicatedStorage:WaitForChild("BarrelFx", 30)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function(kind: unknown, data: unknown)
		if kind == "Boom" then
			onBoom(data)
		elseif kind == "Kick" then
			onKick(data)
		end
	end)
end
