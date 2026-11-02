--!strict
-- The swinging crane ball, drawn (server/CraneServer decides; this only moves the ball, shows the
-- lane and shoves your own kart).
--   crane models (tag "CraneBall"): the "Swing" model is turned about the boom tip every frame from
--     the server clock (attribute Phase0), the same formula the server uses (shared/Crane). The
--     lane on the floor pulses red; its light blinks.
--   remote CraneFx "Hit" { position }: a hot flash and sparks where the ball hit (about 9 short parts).
--   remote CraneFx "Kick" { impulse }: the server's shove for YOUR kart. Taken once, clamped to
--     what the rules can ever give. (A client that ignores it only keeps its own speed: damage is
--     the server's and has already been done.)
-- Look rule: low-poly, SmoothPlastic + Neon, no studs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Crane = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Crane"))

local me = Players.LocalPlayer
local S = Crane.SCALE

local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 210, 63)
local HOT = Color3.fromRGB(255, 154, 42)
local RED = Color3.fromRGB(255, 90, 40)

local bits = workspace:FindFirstChild("WeaponBits")
if not bits then
	bits = Instance.new("Folder")
	bits.Name = "WeaponBits"
	bits.Parent = workspace
end

-- ===== the swing: every frame, from the server clock =====

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	for _, crane in CollectionService:GetTagged("CraneBall") do
		local phase = crane:GetAttribute("Phase0")
		local foot = crane:GetAttribute("Foot")
		local swing = crane:FindFirstChild("Swing")
		if
			type(phase) == "number"
			and typeof(foot) == "Vector3"
			and swing
			and swing:IsA("Model")
		then
			local a = Crane.angle(now - phase)
			-- turn about the boom tip (the swing model's pin sits on it, so the whole chain + ball turns)
			local pivot = foot + Vector3.new(0, Crane.PIVOT_H * S, 0)
			swing:PivotTo(CFrame.new(pivot) * CFrame.Angles(0, 0, a))
		end
		local lane = crane:FindFirstChild("Lane")
		local gui = lane and lane:FindFirstChild("Stripes")
		local fill = gui and gui:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			fill.BackgroundTransparency = 0.88 - 0.06 * math.sin(t * 3)
		end
		local lamp = swing and swing:FindFirstChild("Light")
		if lamp and lamp:IsA("BasePart") then
			lamp.Transparency = if math.sin(t * 7) > 0 then 0 else 0.8
		end
	end
end)

-- ===== the hit =====

local rng = Random.new()

local function spark(color: Color3, size: Vector3, ball: boolean): Part
	local p = Instance.new("Part")
	p.Name = "CraneBit"
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Block
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = bits
	return p
end

local function fade(p: BasePart, seconds: number, goal: { [string]: any })
	goal.Transparency = 1
	TweenService
		:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
	task.delay(seconds + 0.05, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

local function onHit(data: any)
	if type(data) ~= "table" or typeof(data.position) ~= "Vector3" then
		return
	end
	local at: Vector3 = data.position
	local flash = spark(WHITE, Vector3.one * 2 * S, true)
	flash.Position = at
	fade(flash, 0.15, { Size = Vector3.one * 10 * S })
	local glow = spark(HOT, Vector3.one * 3 * S, true)
	glow.Position = at
	glow.Transparency = 0.3
	fade(glow, 0.3, { Size = Vector3.one * 7 * S })
	for _ = 1, 8 do
		local sp =
			spark(if rng:NextNumber() < 0.5 then YELLOW else RED, Vector3.one * 0.4 * S, false)
		sp.Position = at
		local a = rng:NextNumber() * math.pi * 2
		fade(sp, 0.45, {
			Position = at + Vector3.new(
				math.cos(a) * (3 + rng:NextNumber() * 6) * S,
				(2 + rng:NextNumber() * 6) * S,
				math.sin(a) * (3 + rng:NextNumber() * 6) * S
			),
		})
	end
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
	local cap = Crane.KNOCK_MAX + Crane.KNOCK_UP
	if v.Magnitude > cap then
		v = v.Unit * cap
	end
	local car = workspace:FindFirstChild("Car_" .. me.UserId)
	local body = car and car:IsA("Model") and (car :: Model).PrimaryPart
	if body and body.Parent and not body.Anchored then
		body.AssemblyLinearVelocity += v
	end
end

local remote = ReplicatedStorage:WaitForChild("CraneFx", 30)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function(kind: unknown, data: unknown)
		if kind == "Hit" then
			onHit(data)
		elseif kind == "Kick" then
			onKick(data)
		end
	end)
end
