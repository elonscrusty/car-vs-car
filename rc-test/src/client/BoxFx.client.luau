--!strict
-- The "?" boxes' life on this screen (server/BoxServer makes them): each box that is up spins
-- slowly and bobs; when it's taken, red and yellow bits burst out; when it's back it pops in from
-- small. Only this screen moves the box, the server never does.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TAG = "SmashBox"
local SPIN = math.rad(90) -- turn per second
local BOB = 0.45 -- studs up and down
local BOB_SPEED = 2.4
local TILT = math.rad(14) -- leans a little so two faces and the top show

local RED = Color3.fromRGB(222, 38, 52)
local YELLOW = Color3.fromRGB(255, 214, 46)

type Live = { model: Model, body: BasePart, home: CFrame, phase: number, size: Vector3 }

local live: { [Model]: Live } = {}
local conns: { [Model]: { RBXScriptConnection } } = {}

local function burst(at: Vector3)
	for n = 1, 8 do
		local bit = Instance.new("Part")
		bit.Size = Vector3.one * (0.6 + (n % 3) * 0.25)
		bit.Color = if n % 2 == 0 then RED else YELLOW
		bit.Material = if n % 2 == 0 then Enum.Material.SmoothPlastic else Enum.Material.Neon
		bit.CFrame = CFrame.new(at) * CFrame.Angles(n, n * 2, n * 3)
		bit.Anchored = true
		bit.CanCollide = false
		bit.CanTouch = false
		bit.CanQuery = false
		bit.CastShadow = false
		local a = n / 8 * math.pi * 2
		local to = at + Vector3.new(math.cos(a) * 5, 2.5 + (n % 3), math.sin(a) * 5)
		bit.Parent = workspace
		TweenService
			:Create(bit, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(to) * CFrame.Angles(n * 3, n, n * 2),
				Size = Vector3.one * 0.1,
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(bit, 0.45)
	end
end

local function popIn(l: Live)
	l.body.Size = l.size * 0.2
	TweenService:Create(
		l.body,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = l.size }
	):Play()
end

local function add(inst: Instance)
	if not inst:IsA("Model") or live[inst] then
		return
	end
	local body = inst:WaitForChild("Body", 5)
	local home = inst:GetAttribute("Home")
	if not (body and body:IsA("BasePart")) or typeof(home) ~= "CFrame" then
		return
	end
	local l: Live = {
		model = inst,
		body = body,
		home = home,
		phase = math.random() * math.pi * 2,
		size = body.Size,
	}
	live[inst] = l
	conns[inst] = {
		inst:GetAttributeChangedSignal("Up"):Connect(function()
			if inst:GetAttribute("Up") == true then
				popIn(l)
			else
				burst(l.body.Position)
			end
		end),
	}
end

local function remove(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	live[inst] = nil
	for _, c in conns[inst] or {} do
		c:Disconnect()
	end
	conns[inst] = nil
end

for _, m in CollectionService:GetTagged(TAG) do
	task.spawn(add, m)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

local t = 0
RunService.RenderStepped:Connect(function(dt: number)
	t += dt
	for _, l in live do
		if l.model:GetAttribute("Up") == true then
			local y = math.sin(t * BOB_SPEED + l.phase) * BOB
			l.body.CFrame = l.home
				* CFrame.new(0, y, 0)
				* CFrame.Angles(0, t * SPIN + l.phase, 0)
				* CFrame.Angles(TILT, 0, 0)
		end
	end
end)
