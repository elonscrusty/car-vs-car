--!strict
-- The "?" boxes' life on this screen (server/BoxServer makes them): each box that is up spins
-- slowly and bobs, and its glow halo turns; when it's taken, gold and orange bits burst out; when
-- it's back it drops in from above with a bounce. Only this screen moves the box, the server never
-- does (it moves the Body and Halo roots; everything else is welded to them).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)
local ChargeFx = require(script.Parent.ChargeFx)

local TAG = "SmashBox"
local ME = tostring(Players.LocalPlayer.UserId) -- a player's kart id is their UserId
local SPIN = math.rad(90) -- turn per second
-- sizes below are for a 4.5 stud box and shrink with the real box (RC arena boxes are ~1 stud)
local DESIGN = 4.5
local BOB = 0.45 -- up and down
local BOB_SPEED = 2.4
local TILT = math.rad(14) -- leans a little so two faces and the top show

local HALO_SPIN = math.rad(60) -- the halo turns around its own middle, per second
local HALO_TIP = CFrame.Angles(math.rad(70), 0, math.rad(15)) -- same tip as server/BoxServer's halo
local DROP = 0.45 -- seconds to drop back in
local DROP_HIGH = 3 -- box sizes above home when the drop starts

local GOLD = Color3.fromRGB(255, 194, 46)
local ORANGE = Color3.fromRGB(255, 154, 30)

type Live = {
	model: Model,
	body: BasePart,
	halo: BasePart?,
	home: CFrame,
	phase: number,
	size: Vector3,
	up: boolean,
	back: number, -- clock time the box came back (for the drop)
}

local live: { [Model]: Live } = {}
local conns: { [Model]: { RBXScriptConnection } } = {}

local function burst(at: Vector3, s: number)
	for n = 1, 8 do
		local bit = Instance.new("Part")
		bit.Size = Vector3.one * (0.6 + (n % 3) * 0.25) * s
		bit.Color = if n % 2 == 0 then GOLD else ORANGE
		bit.Material = if n % 2 == 0 then Enum.Material.SmoothPlastic else Enum.Material.Neon
		bit.CFrame = CFrame.new(at) * CFrame.Angles(n, n * 2, n * 3)
		bit.Anchored = true
		bit.CanCollide = false
		bit.CanTouch = false
		bit.CanQuery = false
		bit.CastShadow = false
		local a = n / 8 * math.pi * 2
		local to = at + Vector3.new(math.cos(a) * 5, 2.5 + (n % 3), math.sin(a) * 5) * s
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
	l.back = os.clock()
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
	local halo = inst:FindFirstChild("Halo")
	local l: Live = {
		model = inst,
		body = body,
		halo = if halo and halo:IsA("BasePart") then halo else nil,
		home = home,
		phase = math.random() * math.pi * 2,
		size = body.Size,
		up = inst:GetAttribute("Up") == true,
		back = -math.huge,
	}
	live[inst] = l
	conns[inst] = {
		inst:GetAttributeChangedSignal("Up"):Connect(function()
			l.up = inst:GetAttribute("Up") == true
			if l.up then
				popIn(l)
			else
				burst(l.body.Position, l.size.X / DESIGN)
			end
		end),
		-- every pickup bumps TakenCount; the pickup sound is only for the one who grabbed it. A
		-- charge box (no weapon) also sends its swirl into the grabber's kart, for everyone to see.
		inst:GetAttributeChangedSignal("TakenCount"):Connect(function()
			local by = inst:GetAttribute("TakenBy")
			if by == ME then
				Sfx.pickup()
			end
			local level = inst:GetAttribute("TakenLevel")
			if type(by) == "string" and by ~= "" and type(level) == "number" and level > 0 then
				ChargeFx.play(l.body.Position, by, level, l.size.X)
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

-- all boxes move in one BulkMoveTo a frame (cheap on phones)
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local t = 0
RunService.RenderStepped:Connect(function(dt: number)
	t += dt
	table.clear(parts)
	table.clear(frames)
	for _, l in live do
		if l.up then
			local y = math.sin(t * BOB_SPEED + l.phase) * BOB * l.size.X / DESIGN
			local k = math.clamp((os.clock() - l.back) / DROP, 0, 1)
			if k < 1 then
				local fall =
					TweenService:GetValue(k, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
				y += (1 - fall) * DROP_HIGH * l.size.X
			end
			local at = l.home * CFrame.new(0, y, 0)
			table.insert(parts, l.body)
			table.insert(
				frames,
				at * CFrame.Angles(0, t * SPIN + l.phase, 0) * CFrame.Angles(TILT, 0, 0)
			)
			if l.halo then
				table.insert(parts, l.halo)
				table.insert(
					frames,
					at
						* HALO_TIP
						* CFrame.Angles(0, 0, t * HALO_SPIN + l.phase)
						* HALO_TIP:Inverse()
				)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
