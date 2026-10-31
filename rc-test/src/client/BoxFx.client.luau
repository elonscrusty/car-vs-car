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
local PALE = Color3.fromRGB(255, 226, 122)
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

-- Gold Pop (carter picked A, 10-31): a bright flash and a bubble where the box was, rings on the
-- floor, a spray of gold sparks and chunks that fall back down. Comes back with a softer glow pop.
-- Sizes are written for a 4 stud box (the preview) and scale with the real box.
local PREVIEW = 4
local GRAVITY = 14
local FLY_LIFE = 0.85

type Bit = {
	part: BasePart,
	from: Vector3,
	vel: Vector3,
	t0: number,
	life: number,
	grav: number,
	size: number,
	turn: Vector3,
	floor: number,
}
local bits: { Bit } = {}

local function blob(shape: Enum.PartType, color: Color3, neon: boolean): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

local function grow(
	p: Part,
	from: number,
	to: number,
	t: number,
	start: number,
	style: Enum.EasingStyle
)
	p.Size = Vector3.one * from
	p.Transparency = start
	TweenService:Create(p, TweenInfo.new(t, style, Enum.EasingDirection.Out), {
		Size = Vector3.one * to,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, t + 0.05)
end

local function floorRing(at: Vector3, u: number, reach: number, delay: number)
	task.delay(delay, function()
		local r = blob(Enum.PartType.Cylinder, GOLD, true)
		r.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		r.Size = Vector3.new(0.2 * u, 1 * u, 1 * u)
		r.Transparency = 0.2
		TweenService
			:Create(r, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.2 * u, reach * u, reach * u),
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(r, 0.6)
	end)
end

local function spray(
	at: Vector3,
	floor: number,
	u: number,
	count: number,
	speed: number,
	up: number,
	grav: number,
	chunks: boolean
)
	local now = os.clock()
	for n = 1, count do
		local a = math.random() * math.pi * 2
		local e = (math.random() - 0.15) * 1.3 * up
		local v = speed * (0.4 + math.random()) * u
		local isChunk = chunks and n % 3 == 0
		local p = blob(
			Enum.PartType.Block,
			if isChunk then (if n % 2 == 0 then GOLD else ORANGE) else PALE,
			not isChunk
		)
		local sz = (if isChunk then 0.7 else 0.35 + math.random() * 0.35) * u
		p.Size = Vector3.one * sz
		p.CFrame = CFrame.new(at)
		table.insert(bits, {
			part = p,
			from = at,
			vel = Vector3.new(
				math.cos(a) * math.cos(e) * v,
				math.sin(e) * v,
				math.sin(a) * math.cos(e) * v * 0.8
			),
			t0 = now + math.random() * 0.06,
			life = FLY_LIFE,
			grav = grav * u,
			size = sz,
			turn = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8),
			floor = floor,
		})
	end
end

local function flash(at: Vector3, u: number, big: number, t: number)
	local f = blob(Enum.PartType.Ball, Color3.fromRGB(255, 251, 230), true)
	f.CFrame = CFrame.new(at)
	grow(f, 1 * u, big * u, t, 0.1, Enum.EasingStyle.Quad)
	local sh = blob(Enum.PartType.Ball, ORANGE, true)
	sh.CFrame = CFrame.new(at)
	grow(sh, 1.5 * u, 5.7 * u, t * 1.2, 0.65, Enum.EasingStyle.Quad)
end

local function burst(at: Vector3, side: number)
	local u = side / PREVIEW
	local floor = at.Y - 3 * u -- Boxes.LIFT is 3 for a 4 stud box
	flash(at, u, 8, 0.3)
	floorRing(Vector3.new(at.X, floor + 0.15, at.Z), u, 18, 0)
	floorRing(Vector3.new(at.X, floor + 0.15, at.Z), u, 12, 0.1)
	spray(at, floor, u, 40, 15, 1, GRAVITY, true)
end

-- the box is back: a soft flash, a ring on the floor, a few sparks rising
local function comeBack(l: Live)
	local u = l.size.X / PREVIEW
	local at = l.home.Position
	flash(at, u, 6, 0.35)
	floorRing(Vector3.new(at.X, at.Y - 3 * u + 0.15, at.Z), u, 14, 0)
	spray(at, at.Y - 3 * u, u, 12, 4, 2.6, -2, false)
end

local function stepBits(now: number)
	for i = #bits, 1, -1 do
		local b = bits[i]
		local tt = now - b.t0
		if tt >= b.life then
			b.part:Destroy()
			table.remove(bits, i)
		elseif tt >= 0 then
			local f = tt / b.life
			local pos = b.from + b.vel * tt - Vector3.new(0, 0.5 * b.grav * tt * tt, 0)
			if pos.Y < b.floor + 0.2 then
				pos = Vector3.new(pos.X, b.floor + 0.2, pos.Z)
			end
			b.part.CFrame = CFrame.new(pos)
				* CFrame.Angles(b.turn.X * tt, b.turn.Y * tt, b.turn.Z * tt)
			b.part.Size = Vector3.one * b.size * (1 - f * 0.7)
			b.part.Transparency = f * f
		end
	end
end

local function popIn(l: Live)
	l.back = os.clock()
	comeBack(l)
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
				burst(l.body.Position, l.size.X)
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
	stepBits(os.clock())
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
