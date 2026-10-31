--!strict
-- Things that move and sparkle in a match (JUICE row, auditor "Cheap tells" #1). Numbers and
-- rules: shared/ArenaLife. Looks only, this screen only:
--   * dust kicked up behind every kart by its speed, and little exhaust puffs while it drives
--   * sparkles over every "?" box that is up (client/BoxFx spins it and bursts it on pickup)
--   * a shower of sparks where two karts bump (client/SmashHits calls ArenaLifeFx.spark)
-- Cheap for phones: one dust and one puff emitter per kart and one per box, made once and reused,
-- emitting by hand (Emit) so nothing runs past ArenaLife.FAR studs from the camera or outside a
-- match. Built-in particle textures only.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaLife = require(Shared:WaitForChild("ArenaLife"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxLevel = require(Shared:WaitForChild("FxLevel"))

local player = Players.LocalPlayer

local ArenaLifeFx = {}

-- 1, or less on a slow screen (client/FxLevel)
local function fxLevel(): number
	local v = workspace:GetAttribute("FxLevel")
	return if type(v) == "number" then v else 1
end

local K = Weapons.KART
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST = Color3.fromRGB(232, 220, 190)
local PUFF = Color3.fromRGB(200, 200, 205)
local SUNNY = Color3.fromRGB(255, 215, 80)
local FLAME = Color3.fromRGB(255, 140, 40)

local function emitter(parent: Instance, texture: string, color: ColorSequence): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = color
	e.Rate = 0
	e.LightInfluence = 0.6
	e.Parent = parent
	return e
end

-- ===== karts: dust and puffs =====
type Rig = {
	model: Model,
	part: BasePart,
	dust: ParticleEmitter,
	puff: ParticleEmitter,
	last: Vector3?,
	lastAt: number,
	speed: number,
	owedDust: number,
	owedPuff: number,
}
local rigs: { [Model]: Rig } = {}

local function rig(m: Model): Rig?
	local part = m.PrimaryPart
	if not part then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "ArenaLife"
	-- behind the kart, low (a kart faces -Z)
	att.Position = Vector3.new(0, -0.2 * K, 0.45 * K)
	att.Parent = part
	local dust = emitter(att, SMOKE, ColorSequence.new(DUST))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12 * K),
		NumberSequenceKeypoint.new(1, 0.4 * K),
	})
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Lifetime = NumberRange.new(0.45, 0.8)
	dust.Speed = NumberRange.new(0.6 * K, 1.4 * K)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Acceleration = Vector3.new(0, 0.5 * K, 0)
	dust.Drag = 3
	dust.Rotation = NumberRange.new(0, 360)
	local puff = emitter(att, SMOKE, ColorSequence.new(PUFF))
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06 * K),
		NumberSequenceKeypoint.new(1, 0.18 * K),
	})
	puff.Transparency = NumberSequence.new(0.4, 1)
	puff.Lifetime = NumberRange.new(0.3, 0.5)
	puff.Speed = NumberRange.new(0.3 * K, 0.6 * K)
	puff.EmissionDirection = Enum.NormalId.Back
	puff.Acceleration = Vector3.new(0, 0.8 * K, 0)
	local r: Rig = {
		model = m,
		part = part,
		dust = dust,
		puff = puff,
		last = nil,
		lastAt = 0,
		speed = 0,
		owedDust = 0,
		owedPuff = 0,
	}
	rigs[m] = r
	return r
end

-- ===== boxes: sparkles while up =====
type Box = { model: Model, body: BasePart, sparkle: ParticleEmitter, conn: RBXScriptConnection }
local boxes: { [Model]: Box } = {}
local inMatch = false
local eyeAt = Vector3.zero -- the camera, last frame

local function boxRig(m: Instance)
	if not m:IsA("Model") or boxes[m] then
		return
	end
	-- (with streaming the Body can come later; BoxFx waits the same)
	local body = m:WaitForChild("Body", 5)
	if not (body and body:IsA("BasePart")) or boxes[m] or m.Parent == nil then
		return
	end
	-- the full size, not a pop-in's small one (BoxFx grows a box back from 0.2 over 0.3 s)
	local s = body.Size.X
	if m:GetAttribute("Up") == true then
		task.wait(0.35)
		s = math.max(s, body.Size.X)
		if boxes[m] or m.Parent == nil then
			return
		end
	end
	local e = emitter(body, SPARKLE, ColorSequence.new(SUNNY, Color3.new(1, 1, 1)))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25 * s),
		NumberSequenceKeypoint.new(0.5, 0.35 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(0.4 * s, 0.8 * s)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 0.8
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	local function update()
		e.Rate = if inMatch
			then ArenaLife.sparkles(m:GetAttribute("Up") == true, (body.Position - eyeAt).Magnitude)
				* fxLevel()
			else 0
	end
	boxes[m] = {
		model = m,
		body = body,
		sparkle = e,
		-- taken: off at once (BoxFx bursts it)
		conn = m:GetAttributeChangedSignal("Up"):Connect(update),
	}
	update()
end

-- ===== the karts in the world (Car_<id>), kept by events, shared with client/SmashHits =====
local karts: { [Model]: boolean } = {}
local function isKart(c: Instance): boolean
	return c:IsA("Model") and string.match(c.Name, "^Car_%-?%d+$") ~= nil
end
function ArenaLifeFx.karts(): { [Model]: boolean }
	return karts
end

-- ===== sparks where karts bump =====
local sparkPart: Part? = nil
local sparkEmitter: ParticleEmitter? = nil
local function sparks(): (Part, ParticleEmitter)
	local p, e = sparkPart, sparkEmitter
	if p and e and p.Parent then
		return p, e
	end
	local np = Instance.new("Part")
	np.Name = "BumpSparks"
	np.Anchored = true
	np.CanCollide = false
	np.CanQuery = false
	np.CanTouch = false
	np.Transparency = 1
	np.Size = Vector3.one * 0.1
	np.Parent = workspace
	local ne = emitter(np, SPARKLE, ColorSequence.new(SUNNY, FLAME))
	ne.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * K),
		NumberSequenceKeypoint.new(1, 0),
	})
	ne.Lifetime = NumberRange.new(0.25, 0.45)
	ne.Speed = NumberRange.new(2 * K, 4 * K)
	ne.SpreadAngle = Vector2.new(70, 70)
	ne.EmissionDirection = Enum.NormalId.Top
	ne.Acceleration = Vector3.new(0, -6 * K, 0)
	ne.LightEmission = 1
	sparkPart, sparkEmitter = np, ne
	return np, ne
end

-- sparks fly at `at` (a bump between two karts, or a kart into a wall)
local lastSpark, lastSparkAt = Vector3.zero, -math.huge
function ArenaLifeFx.spark(at: Vector3)
	-- (a bump hurts both karts: one burst for the pair)
	if os.clock() - lastSparkAt < 0.15 and (at - lastSpark).Magnitude < K then
		return
	end
	lastSpark, lastSparkAt = at, os.clock()
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude > ArenaLife.FAR then
		return
	end
	local p, e = sparks()
	p.CFrame = CFrame.new(at)
	e:Emit(FxLevel.count(ArenaLife.SPARK_BITS, fxLevel()))
end

-- ===== the loop =====
local started = false
function ArenaLifeFx.start()
	if started then
		return
	end
	started = true
	inMatch = player:GetAttribute("InMatch") == true
	for _, m in CollectionService:GetTagged("SmashBox") do
		task.spawn(boxRig, m)
	end
	CollectionService:GetInstanceAddedSignal("SmashBox"):Connect(function(m)
		task.spawn(boxRig, m)
	end)
	CollectionService:GetInstanceRemovedSignal("SmashBox"):Connect(function(m)
		local b = if m:IsA("Model") then boxes[m] else nil
		if b then
			b.conn:Disconnect()
			boxes[m :: Model] = nil
		end
	end)
	for _, c in workspace:GetChildren() do
		if isKart(c) then
			karts[c :: Model] = true
		end
	end
	workspace.ChildAdded:Connect(function(c)
		if isKart(c) then
			karts[c :: Model] = true
		end
	end)
	workspace.ChildRemoved:Connect(function(c)
		if c:IsA("Model") then
			karts[c] = nil
			rigs[c] = nil
		end
	end)

	local boxAt = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local cam = workspace.CurrentCamera
		if not cam or not inMatch then
			return
		end
		local eye = cam.CFrame.Position
		eyeAt = eye
		for m in karts do
			if not rigs[m] and m.PrimaryPart then
				rig(m)
			end
		end
		for m, r in rigs do
			if m.Parent == nil or r.part.Parent == nil then
				rigs[m] = nil
				continue
			end
			local pos = r.part.Position
			local last = r.last
			if not last then
				r.last, r.lastAt = pos, now
				continue
			end
			-- the speed over at least SAMPLE s (bots step in network batches)
			if now - r.lastAt >= ArenaLife.SAMPLE then
				r.speed = ArenaLife.speed(pos.X - last.X, pos.Z - last.Z, now - r.lastAt)
				r.last, r.lastAt = pos, now
			end
			local speed = r.speed
			local dist = (pos - eye).Magnitude
			local n
			n, r.owedDust = ArenaLife.owe(r.owedDust, ArenaLife.dust(speed, dist), dt)
			if n > 0 then
				r.dust:Emit(FxLevel.count(n, fxLevel()))
			end
			n, r.owedPuff = ArenaLife.owe(r.owedPuff, ArenaLife.puffs(speed, dist), dt)
			if n > 0 then
				r.puff:Emit(FxLevel.count(n, fxLevel()))
			end
		end
		-- the boxes' sparkles: on or off 4 times a second
		if now >= boxAt then
			boxAt = now + 0.25
			for m, b in boxes do
				if m.Parent == nil then
					boxes[m] = nil
					continue
				end
				local up = m:GetAttribute("Up") == true
				b.sparkle.Rate = ArenaLife.sparkles(up, (b.body.Position - eye).Magnitude) * fxLevel()
			end
		end
	end)
	-- out of a match: the boxes stop sparkling
	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		inMatch = player:GetAttribute("InMatch") == true
		if not inMatch then
			for _, b in boxes do
				b.sparkle.Rate = 0
			end
		end
	end)
end

return ArenaLifeFx
