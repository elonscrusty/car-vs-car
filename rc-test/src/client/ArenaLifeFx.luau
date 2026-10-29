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

local player = Players.LocalPlayer

local ArenaLifeFx = {}

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
		owedDust = 0,
		owedPuff = 0,
	}
	rigs[m] = r
	return r
end

-- ===== boxes: sparkles while up =====
type Box = { model: Model, body: BasePart, sparkle: ParticleEmitter }
local boxes: { [Model]: Box } = {}

local function boxRig(m: Instance)
	if not m:IsA("Model") or boxes[m] then
		return
	end
	local body = m:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then
		return
	end
	local s = body.Size.X
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
	boxes[m] = { model = m, body = body, sparkle = e }
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
function ArenaLifeFx.spark(at: Vector3)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude > ArenaLife.FAR then
		return
	end
	local p, e = sparks()
	p.CFrame = CFrame.new(at)
	e:Emit(ArenaLife.SPARK_BITS)
end

-- ===== the loop =====
local started = false
function ArenaLifeFx.start()
	if started then
		return
	end
	started = true
	for _, m in CollectionService:GetTagged("SmashBox") do
		boxRig(m)
	end
	CollectionService:GetInstanceAddedSignal("SmashBox"):Connect(function(m)
		task.defer(boxRig, m) -- (its Body may come a moment later)
	end)
	CollectionService:GetInstanceRemovedSignal("SmashBox"):Connect(function(m)
		if m:IsA("Model") then
			boxes[m] = nil
		end
	end)

	local scanAt = 0
	local boxAt = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local cam = workspace.CurrentCamera
		local inMatch = player:GetAttribute("InMatch") == true
		if not cam or not inMatch then
			return
		end
		local eye = cam.CFrame.Position
		-- new karts, once a second (bots and players come and go)
		if now >= scanAt then
			scanAt = now + 1
			for _, c in workspace:GetChildren() do
				if c:IsA("Model") and not rigs[c] and string.match(c.Name, "^Car_%-?%d+$") then
					rig(c)
				end
			end
		end
		for m, r in rigs do
			if m.Parent == nil or r.part.Parent == nil then
				rigs[m] = nil
				continue
			end
			local pos = r.part.Position
			local last = r.last
			r.last = pos
			if not last then
				continue
			end
			local dist = (pos - eye).Magnitude
			local speed = ArenaLife.speed(pos.X - last.X, pos.Z - last.Z, dt)
			local n
			n, r.owedDust = ArenaLife.owe(r.owedDust, ArenaLife.dust(speed, dist), dt)
			if n > 0 then
				r.dust:Emit(n)
			end
			n, r.owedPuff = ArenaLife.owe(r.owedPuff, ArenaLife.puffs(speed, dist), dt)
			if n > 0 then
				r.puff:Emit(n)
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
				b.sparkle.Rate = ArenaLife.sparkles(up, (b.body.Position - eye).Magnitude)
			end
		end
	end)
	-- out of a match: the boxes stop sparkling
	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if player:GetAttribute("InMatch") ~= true then
			for _, b in boxes do
				b.sparkle.Rate = 0
			end
		end
	end)
end

return ArenaLifeFx
