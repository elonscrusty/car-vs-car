--!strict
-- The rolling Toxic Drums in the Smash arena (rules: shared/RollBarrels). The server alone moves
-- them: 20 times a second it looks where every live kart is and how fast it moves, runs the rules,
-- and turns the drum models. No remote, nothing a client can send.
--
-- Use (MatchRunner, when the arena is built):
--   local drums = RollBarrelServer.start({
--       spots = { Vector3 },  -- world floor spots (RollBarrels.SPOTS through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive } end,
--       blocked = function(pos: Vector3): boolean end, -- something solid (or not flat) is there
--   })
--   drums.reset()   -- each round's start: every drum home and still
--   drums.stop()    -- arena gone: drums removed
-- Each drum is a Model in workspace.<name> (default "RollBarrels"), tagged "RollingDrum", with the
-- attribute Moving. Not solid for karts (CanCollide off), so a kart can never get stuck on one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RollBarrels = require(ReplicatedStorage.Shared.RollBarrels)

local RollBarrelServer = {}

RollBarrelServer.TAG = "RollingDrum"
RollBarrelServer.TICK = 0.05

local BODY = Color3.fromRGB(58, 70, 60)
local RIB = Color3.fromRGB(42, 50, 44)
local GREEN = Color3.fromRGB(122, 255, 46)
local LID = Color3.fromRGB(74, 90, 74)

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	blocked: ((pos: Vector3) -> boolean)?,
	parent: Instance?,
	name: string?,
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	stop: () -> (),
	folder: Folder,
}

local started: { [string]: Handle } = {}

local function plain(x: any): vector?
	if type(x) == "vector" then
		return x
	elseif typeof(x) == "Vector3" then
		return vector.create(x.X, x.Y, x.Z)
	end
	return nil
end

-- A part of the drum, built in the drum's own frame: the roll axis is local Z, the drum's middle
-- is the model's origin (so PivotTo turns the whole thing). Positions are big units x sc.
local function piece(
	m: Model,
	name: string,
	color: Color3,
	mat: Enum.Material,
	size: Vector3,
	cf: CFrame,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Material = mat
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- One Toxic Drum (the look carter picked): dark green drum, three ribs, a glowing green sludge
-- band with drips toward one end, a lid with a glowing green bung. About 17 parts.
local function build(i: number, sc: number): Model
	local m = Instance.new("Model")
	m.Name = "Drum" .. i
	local R, L = RollBarrels.RADIUS_3D, RollBarrels.LENGTH
	-- (a cylinder Part's axis is X: turn it to Z)
	local axis = CFrame.Angles(0, math.rad(90), 0)
	local function ring(
		name: string,
		color: Color3,
		mat: Enum.Material,
		z: number,
		len: number,
		r: number
	)
		return piece(
			m,
			name,
			color,
			mat,
			Vector3.new(len * sc, r * 2 * sc, r * 2 * sc),
			CFrame.new(0, 0, z * sc) * axis,
			Enum.PartType.Cylinder
		)
	end
	local body = ring("Body", BODY, Enum.Material.Metal, 0, L, R)
	for n, z in { -L * 0.36, L * 0.36, 0 } do
		ring("Rib" .. n, RIB, Enum.Material.Metal, z, 0.34, R + 0.14)
	end
	ring("RimA", RIB, Enum.Material.Metal, L / 2, 0.28, R + 0.1)
	ring("RimB", RIB, Enum.Material.Metal, -L / 2, 0.28, R + 0.1)
	ring("Lid", LID, Enum.Material.Metal, L / 2 + 0.1, 0.14, R - 0.25)
	-- the sludge band round the middle, drips hanging toward the lid-less end
	ring("Sludge", GREEN, Enum.Material.Neon, 0.1, 0.9, R + 0.1)
	for n = 1, 6 do
		local a = n / 6 * math.pi * 2 + 0.3
		local len = 0.7 + (n % 3) * 0.5
		piece(
			m,
			"Drip" .. n,
			GREEN,
			Enum.Material.Neon,
			Vector3.new(0.18 * sc, 0.34 * sc, len * sc),
			CFrame.Angles(0, 0, a) * CFrame.new((R + 0.1) * sc, 0, -(0.55 + len / 2) * sc)
		)
	end
	-- the glowing bung on the lid
	piece(
		m,
		"Bung",
		GREEN,
		Enum.Material.Neon,
		Vector3.new(0.3 * sc, 0.76 * sc, 0.76 * sc),
		CFrame.new(0.7 * sc, 0.2 * sc, (L / 2 + 0.3) * sc) * axis,
		Enum.PartType.Cylinder
	)
	m:SetAttribute("Moving", false)
	m.PrimaryPart = body
	return m
end

function RollBarrelServer.start(opts: Options): Handle
	local name = opts.name or "RollBarrels"
	local old = started[name]
	if old then
		old.stop()
	end
	local sc = opts.scale or RollBarrels.SCALE
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = opts.parent or workspace

	local drums: { RollBarrels.Drum } = {}
	local models: { Model } = {}
	for i, spot in opts.spots do
		local d = RollBarrels.newDrum(plain(spot) :: vector)
		table.insert(drums, d)
		local m = build(i, sc)
		m:AddTag(RollBarrelServer.TAG)
		m.Parent = folder
		-- (it lies on its side: its middle is one round-radius above the floor)
		m:PivotTo(CFrame.new(spot + Vector3.new(0, RollBarrels.RADIUS_3D * sc, 0)))
		table.insert(models, m)
	end

	local blocked: RollBarrels.Blocked? = nil
	local isBlocked = opts.blocked
	if isBlocked then
		blocked = function(p: vector): boolean
			return isBlocked(Vector3.new(p.x, p.y, p.z))
		end
	end

	-- where each kart was last tick (its speed = the move / the tick)
	local last: { [any]: vector } = {}
	local drawn: { boolean } = {}
	local function draw(i: number, d: RollBarrels.Drum)
		local m = models[i]
		-- (a still drum that was already drawn still: nothing to send)
		if not d.moving and drawn[i] then
			return
		end
		drawn[i] = not d.moving
		local up = Vector3.new(0, RollBarrels.RADIUS_3D * sc, 0)
		m:PivotTo(
			CFrame.new(Vector3.new(d.pos.x, d.pos.y, d.pos.z) + up)
				* CFrame.Angles(0, -d.head, 0)
				* CFrame.Angles(0, 0, -d.spin)
		)
		if m:GetAttribute("Moving") ~= d.moving then
			m:SetAttribute("Moving", d.moving)
		end
	end

	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < RollBarrelServer.TICK then
			return
		end
		local step = acc
		acc = 0
		local karts: { RollBarrels.Kart } = {}
		local seen: { [any]: vector } = {}
		for _, c in opts.karts() do
			local p = plain(c.position)
			if p then
				seen[c.id] = p
				local before = last[c.id]
				local vel = if before then (p - before) / step else vector.zero
				table.insert(karts, { id = c.id, position = p, velocity = vel, alive = c.alive })
			end
		end
		last = seen
		RollBarrels.step(drums, karts, step, sc, blocked)
		for i, d in drums do
			draw(i, d)
		end
	end)

	local handle: Handle
	handle = {
		reset = function()
			for i, d in drums do
				RollBarrels.reset(d)
				drawn[i] = false
				draw(i, d)
			end
			last = {}
		end,
		stop = function()
			conn:Disconnect()
			folder:Destroy()
			if started[name] == handle then
				started[name] = nil
			end
		end,
		folder = folder,
	}
	started[name] = handle
	return handle
end

return RollBarrelServer
