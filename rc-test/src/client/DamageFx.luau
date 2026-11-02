--!strict
-- The damage look (carter's pick 3 "Hot Cracks, better", 10-30): the more Health a car loses, the
-- more it shows. Lava-bright cracks open across the body (and throb), smoke rises, sparks and
-- embers fly, chunks drop off, and near the end the hood burns. Looks only: nothing here touches
-- the driving or the hits (the server decides those; we only read my Health).
--
-- Works on any skin body: cracks are found by rays onto the body's surface (no art needed), the
-- hood and boot by rays too. Numbers: shared/DamageLookData. Built once per body, the first time
-- it is hurt; they go when the skin goes (they are children of the body).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.DamageLookData)
local FireDrake = require(script.Parent.FireDrake)

local MAX_CHUNKS = 12

export type DamageFx = {
	-- body: the skin's body (nil: no skin shown). Health is read from my MatchBoard row.
	step: (body: BasePart?) -> (),
}

type Site = {
	thr: number,
	parts: { BasePart },
	att: Attachment,
	sparks: ParticleEmitter,
	embers: ParticleEmitter,
	normal: Vector3, -- world, when it was built
	open: boolean,
}

type Rig = {
	body: BasePart,
	u: number,
	sites: { Site },
	smoke: ParticleEmitter,
	smokeSoot: number, -- the soot step the smoke's colour was set for
	fire: ParticleEmitter,
	fireLight: PointLight,
	glow: PointLight,
	sparkWait: number,
	chunkWait: number,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- a ParticleEmitter with the shared defaults
local function emitter(u: number, size0: number, size1: number): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Size = NumberSequence.new(size0 * u, size1 * u)
	fx.Rate = 0
	fx.LockedToPart = false
	return fx
end

local function normalId(localDir: Vector3): Enum.NormalId
	local ax, ay, az = math.abs(localDir.X), math.abs(localDir.Y), math.abs(localDir.Z)
	if ay >= ax and ay >= az then
		return if localDir.Y >= 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
	elseif ax >= az then
		return if localDir.X >= 0 then Enum.NormalId.Right else Enum.NormalId.Left
	end
	return if localDir.Z >= 0 then Enum.NormalId.Back else Enum.NormalId.Front
end

local function surface(body: BasePart, origin: Vector3, dir: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { body }
	return workspace:Raycast(origin, dir, params)
end

type Seg = { a: Vector3, b: Vector3, n: Vector3 }

-- one crack arm: a random walk that sticks to the surface; may branch once
local function walk(
	body: BasePart,
	u: number,
	rng: Random,
	from: Vector3,
	normal: Vector3,
	dir: Vector3,
	len: number,
	branched: boolean,
	out: { Seg }
)
	local cur, cn, d = from, normal, dir
	local step = Data.STEP * u
	for i = 1, math.floor(len * u / step) do
		d = CFrame.fromAxisAngle(cn, (rng:NextNumber() - 0.5) * 0.9):VectorToWorldSpace(d)
		local want = cur + d * step
		local hit = surface(body, want + cn * 0.9 * u, -cn * 3 * u)
		if not hit or hit.Normal:Dot(cn) < 0.15 then
			break
		end
		table.insert(out, { a = cur, b = hit.Position, n = cn })
		cur, cn = hit.Position, hit.Normal
		d = d - cn * d:Dot(cn)
		if d.Magnitude < 1e-3 then
			break
		end
		d = d.Unit
		if not branched and i > 1 and rng:NextNumber() < Data.BRANCH then
			local sign = if rng:NextNumber() < 0.5 then -1 else 1
			local side = CFrame.fromAxisAngle(cn, sign * (0.5 + rng:NextNumber() * 0.6))
			walk(body, u, rng, cur, cn, side:VectorToWorldSpace(d), len * 0.55, true, out)
		end
	end
end

local function segmentPart(body: BasePart, u: number, seg: Seg): BasePart?
	local len = (seg.b - seg.a).Magnitude
	if len < 0.01 then
		return nil
	end
	local mid = (seg.a + seg.b) / 2 + seg.n * 0.04 * u
	local p = Instance.new("Part")
	p.Material = Enum.Material.Neon
	p.Color = rgb(Data.HOT)
	p.Size = Vector3.new(Data.WIDTH * u, 0.05 * u, len + 0.05 * u)
	p.CFrame = CFrame.lookAt(mid, mid + (seg.b - seg.a), seg.n)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
	p.CastShadow = false
	p.Transparency = 1
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function build(body: BasePart): Rig
	local u = body.Size.Z / Data.DESIGN_LENGTH
	local nose = if body.Parent then FireDrake.noseSign(body, body.Parent) else 1
	local size = body.Size
	local cf = body.CFrame
	local folder = Instance.new("Folder")
	folder.Name = "Damage"
	local rng = Random.new(7)

	-- the skin parts can't be hit by rays (CanQuery off); allow it while we look
	local wasQuery = body.CanQuery
	body.CanQuery = true

	local sites: { Site } = {}
	for _, s in Data.SITES do
		local origin: Vector3
		local dir: Vector3
		if s.face == "top" then
			origin = cf * Vector3.new(s.a * size.X, size.Y, nose * s.b * size.Z)
			dir = -cf.UpVector
		else
			local h = (s.h or 0.5) - 0.5
			origin = cf * Vector3.new(s.a * (size.X / 2 + 3 * u), h * size.Y, nose * s.b * size.Z)
			dir = -cf.RightVector * s.a
		end
		local hit = surface(body, origin, dir * (size.Y + size.X + 6 * u))
		if hit then
			local segs: { Seg } = {}
			local tangent = hit.Normal:Cross(
				if math.abs(hit.Normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
			).Unit
			for i = 1, Data.ARMS do
				local turn = CFrame.fromAxisAngle(
					hit.Normal,
					(i / Data.ARMS) * math.pi * 2 + rng:NextNumber() * 0.6
				)
				local len = Data.ARM_LEN[1] + rng:NextNumber() * (Data.ARM_LEN[2] - Data.ARM_LEN[1])
				walk(
					body,
					u,
					rng,
					hit.Position,
					hit.Normal,
					turn:VectorToWorldSpace(tangent),
					len,
					false,
					segs
				)
			end
			local parts: { BasePart } = {}
			for _, seg in segs do
				local p = segmentPart(body, u, seg)
				if p then
					p.Parent = folder
					table.insert(parts, p)
				end
			end
			local att = Instance.new("Attachment")
			att.Name = "CrackSite"
			att.WorldCFrame =
				CFrame.lookAt(hit.Position + hit.Normal * 0.15 * u, hit.Position + hit.Normal)
			att.Parent = body
			local face = normalId(cf:VectorToObjectSpace(hit.Normal))
			local sparks = emitter(u, 0.16, 0.04)
			sparks.Color = ColorSequence.new(rgb(Data.SPARK), Color3.new(1, 1, 1))
			sparks.LightEmission = 1
			sparks.Lifetime = NumberRange.new(0.35, 0.85)
			sparks.Speed = NumberRange.new(3 * u, 8 * u)
			sparks.Acceleration = Vector3.new(0, -30 * u, 0)
			sparks.SpreadAngle = Vector2.new(70, 70)
			sparks.EmissionDirection = face
			sparks.Parent = att
			local embers = emitter(u, 0.11, 0.02)
			embers.Color =
				ColorSequence.new(Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 50, 10))
			embers.LightEmission = 1
			embers.Lifetime = NumberRange.new(1.1, 2.2)
			embers.Speed = NumberRange.new(0.8 * u, 2 * u)
			embers.SpreadAngle = Vector2.new(35, 35)
			embers.EmissionDirection = face
			embers.Parent = att
			table.insert(sites, {
				thr = s.thr,
				parts = parts,
				att = att,
				sparks = sparks,
				embers = embers,
				normal = hit.Normal,
				open = false,
			})
		end
	end

	-- smoke and fire come out of the hood, found by a ray from above (the blower, the scoop...)
	local function topPoint(f: { x: number, z: number }): Vector3
		local at = cf * Vector3.new(f.x * size.X, size.Y, nose * f.z * size.Z)
		local hit = surface(body, at, -cf.UpVector * (size.Y * 2))
		return if hit
			then hit.Position
			else cf * Vector3.new(f.x * size.X, size.Y / 2, nose * f.z * size.Z)
	end
	local hoodAt = Instance.new("Attachment")
	hoodAt.Name = "Hood"
	hoodAt.WorldPosition = topPoint(Data.HOOD)
	hoodAt.Parent = body
	local trunkAt = Instance.new("Attachment")
	trunkAt.Name = "Trunk"
	trunkAt.WorldPosition = topPoint(Data.TRUNK)
	trunkAt.Parent = body
	body.CanQuery = wasQuery

	local smoke = emitter(u, 1.2, 4.2)
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(2.6, 4.4)
	smoke.Speed = NumberRange.new(1.7 * u, 3 * u)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Parent = hoodAt

	local fire = emitter(u, 0.75, 0.2)
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 60, 10))
	fire.LightEmission = 1
	fire.Transparency = NumberSequence.new(0.05, 1)
	fire.Lifetime = NumberRange.new(0.45, 0.8)
	fire.Speed = NumberRange.new(1.6 * u, 3 * u)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = hoodAt

	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 122, 32)
	fireLight.Range = 12 * u
	fireLight.Brightness = 0
	fireLight.Parent = hoodAt
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 74, 16)
	glow.Range = 9 * u
	glow.Brightness = 0
	glow.Parent = body

	folder.Parent = body
	return {
		body = body,
		u = u,
		sites = sites,
		smoke = smoke,
		smokeSoot = -1,
		fire = fire,
		fireLight = fireLight,
		glow = glow,
		sparkWait = 0.5,
		chunkWait = 2,
	}
end

-- a small dark plate flies off the site and is gone in a moment
local function chunk(r: Rig, site: Site, rng: Random)
	local u = r.u
	local w = (0.25 + rng:NextNumber() * 0.35) * u
	local p = Instance.new("Part")
	p.Size = Vector3.new(w, (0.06 + rng:NextNumber() * 0.1) * u, w * (0.6 + rng:NextNumber()))
	p.Color = rgb(Data.CHUNK)
	p.Material = Enum.Material.Metal
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = false, false, false, false
	p.CFrame = CFrame.new(site.att.WorldPosition)
		* CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, 0)
	p.Parent = workspace
	local push = site.att.WorldCFrame.LookVector
	p.AssemblyLinearVelocity = (
		push * (2.5 + rng:NextNumber() * 3)
		+ Vector3.new(
			(rng:NextNumber() - 0.5) * 3,
			2 + rng:NextNumber() * 3,
			(rng:NextNumber() - 0.5) * 3
		)
	) * u
	p.AssemblyAngularVelocity = Vector3.new(
		(rng:NextNumber() - 0.5) * 14,
		(rng:NextNumber() - 0.5) * 14,
		(rng:NextNumber() - 0.5) * 14
	)
	Debris:AddItem(p, 1.4)
end

local DamageFx = {}

function DamageFx.new(): DamageFx
	local player = Players.LocalPlayer
	local health: number? = nil -- my Health, from my MatchBoard row (as LowHealthEdge reads it)
	local rowConn: RBXScriptConnection? = nil
	local function watchRow(row: Instance)
		if row.Name ~= tostring(player.UserId) then
			return
		end
		if rowConn then
			rowConn:Disconnect()
		end
		local function read()
			local hp = row:GetAttribute("Health")
			health = if type(hp) == "number" then hp else nil
		end
		read()
		rowConn = row:GetAttributeChangedSignal("Health"):Connect(read)
		row.Destroying:Once(function()
			health = nil
		end)
	end
	task.spawn(function()
		local board = ReplicatedStorage:WaitForChild("MatchBoard")
		for _, row in board:GetChildren() do
			watchRow(row)
		end
		board.ChildAdded:Connect(watchRow)
	end)

	local rig: Rig? = nil
	local last = os.clock()
	local lastHealth: number? = nil
	local live = 0 -- chunks in the air
	local rng = Random.new()
	local self = {} :: DamageFx

	local function newestOpen(r: Rig): Site?
		local found: Site? = nil
		for _, s in r.sites do
			if s.open then
				found = s
			end
		end
		return found
	end

	local function burst(r: Rig, site: Site, sparks: number, chunks: number)
		site.sparks:Emit(sparks)
		for _ = 1, math.min(chunks, MAX_CHUNKS - live) do
			live += 1
			chunk(r, site, rng)
			task.delay(1.4, function()
				live = math.max(0, live - 1)
			end)
		end
	end

	local function clear(r: Rig)
		r.smoke.Rate = 0
		r.fire.Rate = 0
		r.fireLight.Brightness = 0
		r.glow.Brightness = 0
		for _, s in r.sites do
			s.embers.Rate = 0
			if s.open then
				s.open = false
				for _, p in s.parts do
					p.Transparency = 1
				end
			end
		end
	end

	function self.step(body: BasePart?)
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		local hp = health
		if not body or body.Parent == nil or not hp then
			rig = nil -- (the skin went away with its parts)
			lastHealth = hp
			return
		end
		local r = rig
		if not r or r.body ~= body then
			if hp >= Data.SITES[1].thr then
				lastHealth = hp
				return -- whole: don't build anything yet
			end
			r = build(body)
			rig = r
		end

		-- a hit (Health went down): sparks and chunks from the newest crack
		if lastHealth and hp < lastHealth - 0.5 then
			local site = newestOpen(r)
			if site then
				burst(r, site, 22, 5)
			end
		end
		lastHealth = hp

		-- cracks open and close with Health, and throb
		for i, s in r.sites do
			local want = hp < s.thr
			local heat = Data.pulse(now, i)
			if want then
				s.embers.Rate = 1.6
				local c = rgb(Data.mix(Data.HOT, Data.WHITE_HOT, heat * 0.8))
				for _, p in s.parts do
					p.Color = c
					p.Transparency = 0
				end
			elseif s.open then
				s.embers.Rate = 0
				for _, p in s.parts do
					p.Transparency = 1
				end
			end
			s.open = want
		end

		-- smoke, darker and sootier as it gets worse
		r.smoke.Rate = Data.smokeRate(hp)
		local soot = math.floor(Data.soot(hp) * 10) / 10
		if soot ~= r.smokeSoot then
			r.smokeSoot = soot
			local a, b = Data.SMOKE[1], Data.SMOKE[2]
			r.smoke.Color = ColorSequence.new(
				rgb(Data.mix(a, b, soot)),
				rgb(Data.mix(a, b, math.min(1, soot + 0.3)))
			)
		end
		r.smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.45 - 0.3 * Data.damage(hp)),
			NumberSequenceKeypoint.new(1, 1),
		})

		-- hood fire
		local fire = Data.fire(hp)
		r.fire.Rate = 40 * fire
		r.fireLight.Brightness = if fire > 0
			then (1.8 + math.sin(now * 23) * 0.6 + math.sin(now * 37) * 0.4) * fire * 2.2
			else 0
		r.glow.Brightness = if Data.open(hp) > 0 then Data.glow(hp, now) else 0

		-- now and then a spark burst, and a chunk, from an open crack
		local gap = Data.sparkGap(hp, rng:NextNumber())
		if gap then
			r.sparkWait -= dt
			if r.sparkWait <= 0 then
				r.sparkWait = gap
				local open: { Site } = {}
				for _, s in r.sites do
					if s.open then
						table.insert(open, s)
					end
				end
				if #open > 0 then
					local s = open[rng:NextInteger(1, #open)]
					burst(
						r,
						s,
						rng:NextInteger(7, 14),
						if hp < Data.CHUNK_AT and rng:NextNumber() < 0.5 then 2 else 0
					)
				end
			end
		end
	end

	return self
end

return DamageFx
