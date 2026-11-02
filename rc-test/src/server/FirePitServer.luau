--!strict
-- The fire pits in the Smash arena (rules: shared/FirePits). The server alone decides: 10 times a
-- second it looks where every live kart is and burns the ones on a pit (through `damage`). No
-- remote lets a client hurt anything; the client only draws the flames (client/FirePitFx).
--
-- Use (MatchRunner, when the arena is built):
--   local pits = FirePitServer.start({
--       spots = { Vector3 },  -- world floor spots (FirePits.SPOTS through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive } end,
--       damage = MatchRunner.damage, -- (victimId, attackerId, amount, word) -> (taken, smashed)
--   })
--   pits.reset()  -- each round's start: the flare clock starts again
--   pits.stop()   -- arena gone: pits removed
-- Each pit is a Model in workspace.<name> (default "FirePits") tagged "FirePit" with attributes
-- Flare (the flames are flaring) and Warn (a flare is about to start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FirePits = require(ReplicatedStorage.Shared.FirePits)

local FirePitServer = {}

FirePitServer.TAG = "FirePit"
FirePitServer.TICK = 0.1

local SCORCH = Color3.fromRGB(28, 22, 18)
local ASH = Color3.fromRGB(74, 26, 16)
local EMBER = Color3.fromRGB(216, 74, 18)
local CORE = Color3.fromRGB(184, 30, 10)
local OUTER = Color3.fromRGB(255, 106, 20)
local INNER = Color3.fromRGB(255, 184, 31)
local AMBER = Color3.fromRGB(255, 138, 26)
local SCRAP = {
	Color3.fromRGB(122, 58, 34),
	Color3.fromRGB(90, 90, 98),
	Color3.fromRGB(138, 74, 42),
	Color3.fromRGB(58, 58, 66),
	Color3.fromRGB(154, 90, 48),
}

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	damage: (victimId: any, attackerId: any, amount: number, word: string) -> any,
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

-- A position as the built-in `vector` (in Roblox that IS Vector3; Lune's pretend Vector3 is another
-- type with only X Y Z), so the shared rules use one kind. Anything else: nil.
local function plain(x: any): vector?
	if type(x) == "vector" then
		return x
	elseif typeof(x) == "Vector3" then
		return vector.create(x.X, x.Y, x.Z)
	end
	return nil
end

local function solid(name: string, parent: Instance, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false -- flat and not solid: a kart drives straight through, nothing to stick on
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function disc(name: string, parent: Instance, color: Color3, mat: Enum.Material): Part
	local p = solid(name, parent, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Flame positions in big units (x, z, height, width): a ring of tall ones and short ones between.
local FLAMES = {
	{ -4.2, 1.6, 4.6, 1.5 },
	{ -2.4, -3.6, 5.6, 1.7 },
	{ 0.4, 0.2, 6.2, 1.9 },
	{ 2.6, -2.2, 4.8, 1.5 },
	{ 3.8, 2.4, 5.2, 1.6 },
	{ -0.6, 3.8, 4.2, 1.4 },
	{ -3.4, -0.6, 3.2, 1.2 },
	{ 1.6, -4.4, 3.4, 1.2 },
	{ 4.6, -0.2, 3.0, 1.1 },
	{ -1.8, 2.0, 3.4, 1.2 },
}

-- One pit (big units x sc): a scorched floor patch, an ember bed with a red core, a rim of bent
-- scrap plates, two scrap bits, ten flames (an outer red-orange ball and an inner yellow one each,
-- the client flickers them) and a flat amber ring on the floor showing the whole burning patch.
-- About 45 parts, no lights.
local function build(i: number, spot: Vector3, parent: Instance, sc: number): Model
	local m = Instance.new("Model")
	m.Name = "Pit" .. i
	local function flat(y: number): CFrame
		return CFrame.new(spot + Vector3.new(0, y * sc, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	local R = FirePits.RADIUS
	local ground = disc("Ground", m, SCORCH, Enum.Material.Slate)
	ground.Size = Vector3.new(0.3 * sc, (R - 0.3) * 2 * sc, (R - 0.3) * 2 * sc)
	ground.CFrame = flat(0.1)
	local ash = disc("Ash", m, ASH, Enum.Material.Slate)
	ash.Size = Vector3.new(0.34 * sc, (R - 1.4) * 2 * sc, (R - 1.4) * 2 * sc)
	ash.CFrame = flat(0.14)
	local bed = disc("Bed", m, EMBER, Enum.Material.Neon)
	bed.Size = Vector3.new(0.38 * sc, (R - 2.4) * 2 * sc, (R - 2.4) * 2 * sc)
	bed.CFrame = flat(0.17)
	local core = disc("Core", m, CORE, Enum.Material.Neon)
	core.Size = Vector3.new(0.42 * sc, (R - 4.2) * 2 * sc, (R - 4.2) * 2 * sc)
	core.CFrame = flat(0.19)
	-- rim: 12 bent plates leaning round the edge
	for n = 1, 12 do
		local a = n / 12 * math.pi * 2
		local d = R - 0.7
		local plate = solid("Plate" .. n, m, SCRAP[(n - 1) % 5 + 1], Enum.Material.Metal)
		plate.Size = Vector3.new((2.4 + (n % 3) * 0.5) * sc, (1.1 + (n % 2) * 0.6) * sc, 0.45 * sc)
		plate.CFrame = CFrame.new(
			spot + Vector3.new(math.sin(a) * d * sc, 0.7 * sc, math.cos(a) * d * sc)
		) * CFrame.Angles(0.15 * ((n % 3) - 1), a, 0.2 * ((n % 4) - 1.5))
	end
	-- a bent car door and a wheel in the fire
	local door = solid("Door", m, Color3.fromRGB(106, 42, 26), Enum.Material.Metal)
	door.Size = Vector3.new(3.2 * sc, 0.3 * sc, 1.6 * sc)
	door.CFrame = CFrame.new(spot + Vector3.new(-3.2 * sc, 0.9 * sc, 2.2 * sc))
		* CFrame.Angles(0.3, 0.6, 0.2)
	local wheel = disc("Wheel", m, Color3.fromRGB(34, 34, 40), Enum.Material.SmoothPlastic)
	wheel.Size = Vector3.new(0.5 * sc, 2.2 * sc, 2.2 * sc)
	wheel.CFrame = CFrame.new(spot + Vector3.new(3.4 * sc, 0.8 * sc, -2.6 * sc))
		* CFrame.Angles(0.4, 0, 0)
	-- flames: Ball parts stretched tall (the client flickers Size from the Base attributes)
	for n, f in FLAMES do
		for _, layer in { { "Flame", OUTER, 1, 0 }, { "Heat", INNER, 0.55, 1 } } do
			local fl = solid(layer[1] .. n, m, layer[2], Enum.Material.Neon)
			fl.Shape = Enum.PartType.Ball
			local w, h = f[4] * layer[3] * sc, f[3] * layer[3] * sc
			fl.Size = Vector3.new(w, h, w)
			fl.Position = spot + Vector3.new(f[1] * sc, h / 2 + 0.2 * sc, f[2] * sc)
			fl.Transparency = 0.12 + layer[4] * 0.05
			fl:SetAttribute("W", w)
			fl:SetAttribute("H", h)
			fl:SetAttribute("Seed", n * 1.7 + layer[4])
			fl:SetAttribute("X", fl.Position.X)
			fl:SetAttribute("Y", spot.Y + 0.2 * sc)
			fl:SetAttribute("Z", fl.Position.Z)
		end
	end
	-- embers drifting up (one light emitter)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(2 * sc * 4, 4 * sc * 4)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, 2, 0)
	pe.Color = ColorSequence.new(INNER)
	pe.LightEmission = 1
	pe.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = core
	-- the danger ring: a flat see-through part with a circle drawn on it
	local zone = solid("Zone", m, AMBER, Enum.Material.SmoothPlastic)
	zone.Size = Vector3.new(R * 2 * sc, 0.1 * sc, R * 2 * sc)
	zone.Position = spot + Vector3.new(0, 0.22 * sc, 0)
	zone.Transparency = 1
	local zg = Instance.new("SurfaceGui")
	zg.Name = "Ring"
	zg.Face = Enum.NormalId.Top
	zg.CanvasSize = Vector2.new(256, 256)
	zg.LightInfluence = 0
	zg.Brightness = 1.4
	local fill = Instance.new("Frame")
	fill.Name = "Circle"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = AMBER
	fill.BackgroundTransparency = 0.9
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = AMBER
	stroke.Thickness = 5
	stroke.Parent = fill
	fill.Parent = zg
	zg.Parent = zone
	m:SetAttribute("Flare", false)
	m:SetAttribute("Warn", false)
	m.PrimaryPart = ground
	m.Parent = parent
	return m
end

function FirePitServer.start(opts: Options): Handle
	local name = opts.name or "FirePits"
	local old = started[name]
	if old then
		old.stop()
	end
	local sc = opts.scale or FirePits.SCALE
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = opts.parent or workspace

	local spots: { vector } = {}
	local models: { Model } = {}
	for i, spot in opts.spots do
		table.insert(spots, plain(spot) :: vector)
		local m = build(i, spot, folder, sc)
		m:AddTag(FirePitServer.TAG)
		table.insert(models, m)
	end
	local state = FirePits.new(spots)

	local clock = 0
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		acc += dt
		if acc < FirePitServer.TICK then
			return
		end
		acc = 0
		local karts = {}
		for _, c in opts.karts() do
			local p = plain(c.position)
			if p then
				table.insert(karts, { id = c.id, position = p, alive = c.alive })
			end
		end
		for _, h in FirePits.step(state, karts, clock, sc) do
			local ok, err = pcall(opts.damage, h.id, nil, h.damage, FirePits.NAME)
			if not ok then
				warn("[FirePits] damage failed: " .. tostring(err))
			end
		end
		local flare, warnNow = FirePits.flaring(clock), FirePits.warning(clock)
		for _, m in models do
			if m:GetAttribute("Flare") ~= flare then
				m:SetAttribute("Flare", flare)
			end
			if m:GetAttribute("Warn") ~= warnNow then
				m:SetAttribute("Warn", warnNow)
			end
		end
	end)

	local handle: Handle
	handle = {
		reset = function()
			-- a new round: the flare clock starts again, so every round opens with a calm 8 s
			clock = 0
			FirePits.reset(state)
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

return FirePitServer
