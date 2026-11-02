--!strict
-- The health wrenches' life on this screen (server/WrenchServer makes and decides them; carter
-- picked "A Big Wrench", 10-31). A wrench that is up turns gently and bobs; when it is taken,
-- green bits burst out of it; for the one who grabbed it the pickup sound plays, and over that
-- kart (everyone sees it) green pluses float up with a "+40%". Looks only: the server already
-- mended the kart. Only this screen moves the wrench (the Body root; the rest is welded to it).
-- Page with the 3 tries: car-vs-car/wrench-preview/wrench-tries.html.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)
local Wrenches = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wrenches"))

local TAG = "Wrench"
local ME = tostring(Players.LocalPlayer.UserId) -- a player's kart id is their UserId
local SWAY = math.rad(35) -- the turn each way (the face stays readable, like the preview)
local BOB = 0.35 -- big units, up and down
local BOB_SPEED = 2.4
local DROP = 0.45 -- seconds to drop back in
local DROP_HIGH = 2 -- big units above home when the drop starts
local SC = Wrenches.SCALE

local GREEN = Color3.fromRGB(60, 255, 122)
local PALE = Color3.fromRGB(234, 255, 240)
local WORD_EDGE = Color3.fromRGB(6, 80, 31)

type Live = { model: Model, body: BasePart, home: CFrame, phase: number, up: boolean, back: number }

local live: { [Model]: Live } = {}
local conns: { [Model]: { RBXScriptConnection } } = {}

local function bit(at: Vector3, to: Vector3, size: number, life: number)
	local p = Instance.new("Part")
	p.Size = Vector3.one * size
	p.Color = GREEN
	p.Material = Enum.Material.Neon
	p.CFrame = CFrame.new(at)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = to,
		Size = Vector3.one * 0.05,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, life + 0.05)
end

local function burst(at: Vector3)
	for n = 1, 8 do
		local a = n / 8 * math.pi * 2
		bit(at, at + Vector3.new(math.cos(a) * 5, 2.5 + (n % 3), math.sin(a) * 5) * SC, 0.3, 0.45)
	end
end

-- the heal over the grabber's kart: pluses rise, a "+40%" floats up (nothing when we can't see it)
local function heal(by: string)
	local car = workspace:FindFirstChild("Car_" .. by)
	if not (car and car:IsA("Model")) then
		return
	end
	local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local from = root.Position
	for n = 1, 6 do
		task.delay(n * 0.08, function()
			if root.Parent then
				local side = Vector3.new((n % 3 - 1) * 1.2, 0, ((n + 1) % 3 - 1) * 1.2) * SC * 4
				bit(
					root.Position + side,
					root.Position + side + Vector3.new(0, 14 * SC, 0),
					0.4,
					0.9
				)
			end
		end)
	end
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.CFrame = CFrame.new(from + Vector3.new(0, 7 * SC, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffsetWorldSpace = Vector3.zero
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Oswald
	t.Text = `+{math.floor(Wrenches.HEAL * 100 + 0.5)}%`
	t.TextSize = 34
	t.TextColor3 = PALE
	local stroke = Instance.new("UIStroke")
	stroke.Color = WORD_EDGE
	stroke.Thickness = 3
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = anchor
	anchor.Parent = workspace
	TweenService
		:Create(anchor, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = anchor.Position + Vector3.new(0, 9 * SC, 0),
		})
		:Play()
	TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	Debris:AddItem(anchor, 1.3)
end

local function add(inst: Instance)
	if not inst:IsA("Model") or live[inst] then
		return
	end
	local body = inst:WaitForChild("Body", 5)
	local home = inst:GetAttribute("Home")
	if
		not (body and body:IsA("BasePart"))
		or typeof(home) ~= "CFrame"
		or inst.Parent == nil
		or live[inst]
	then
		return
	end
	local l: Live = {
		model = inst,
		body = body,
		home = home,
		phase = math.random() * math.pi * 2,
		up = inst:GetAttribute("Up") == true,
		back = -math.huge,
	}
	live[inst] = l
	conns[inst] = {
		inst:GetAttributeChangedSignal("Up"):Connect(function()
			l.up = inst:GetAttribute("Up") == true
			if l.up then
				l.back = os.clock()
			else
				burst(l.body.Position)
			end
		end),
		-- every pickup bumps TakenCount; the sound is only for the one who grabbed it
		inst:GetAttributeChangedSignal("TakenCount"):Connect(function()
			local by = inst:GetAttribute("TakenBy")
			if by == ME then
				Sfx.pickup()
			end
			if type(by) == "string" and by ~= "" then
				heal(by)
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

-- all wrenches move in one BulkMoveTo a frame (cheap on phones)
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local t = 0
RunService.RenderStepped:Connect(function(dt: number)
	t += dt
	table.clear(parts)
	table.clear(frames)
	for _, l in live do
		if l.up then
			local y = math.sin(t * BOB_SPEED + l.phase) * BOB * SC
			local k = math.clamp((os.clock() - l.back) / DROP, 0, 1)
			if k < 1 then
				local fall =
					TweenService:GetValue(k, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
				y += (1 - fall) * DROP_HIGH * SC * 4
			end
			table.insert(parts, l.body)
			table.insert(
				frames,
				l.home
					* CFrame.new(0, y, 0)
					* CFrame.Angles(0, math.sin(t * 1.4 + l.phase) * SWAY, 0)
			)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
