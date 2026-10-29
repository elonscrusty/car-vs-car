--!strict
-- The "?" boxes in a smash match (shared/Boxes has the rules and odds). The server alone decides
-- a pickup: 10 times a second it looks where every live kart is and hands a touched box's weapon
-- to that kart through `give` (WeaponServer.give). No remote: a client can't ask for a box.
--
-- Use (MatchRunner, when the arena is built):
--   local boxes = BoxServer.start({
--       spots = ArenaData.boxSpots,
--       karts = function() return list of { id, position: Vector3, alive } end,
--       give = WeaponServer.give, -- (kartId, name) -> boolean; false = can't take it now
--       has = function(name) return Weapons.get(name) ~= nil end, -- weapons built so far
--   })
--   boxes.reset() -- at each match start: every box up
--   boxes.stop() -- arena gone: boxes removed
-- More than one set can run at once (the arena and the lobby's warm-up yard): give each its own
-- `name` (default "SmashBoxes"). Starting a name again stops the old set of that name first.
--
-- Each box is a Model tagged "SmashBox" in <parent>.<name> with attributes Up (bool), Home
-- (CFrame of the box's middle), TakenBy (kart id as a string), TakenWeapon and TakenCount (goes
-- up by one on every pickup: listen to this one for sounds and screens). client/BoxFx spins it,
-- plays the pop, and plays the pickup sound for the grabber: a player's kart id must be their
-- UserId (bots can use any other id).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boxes = require(ReplicatedStorage.Shared.Boxes)

local BoxServer = {}

BoxServer.TAG = "SmashBox"

-- the "Royal" look carter picked (10-29): gold box, dark frame, glowing gem corners, a gold trim
-- panel with a 3D "?" on each side, a spinning glow halo and a light beam
local GOLD = Color3.fromRGB(255, 204, 60)
local PANEL = Color3.fromRGB(255, 176, 32)
local TRIM = Color3.fromRGB(255, 226, 122)
local FRAME = Color3.fromRGB(42, 26, 58)
local GEM = Color3.fromRGB(255, 154, 30)
local HALO = Color3.fromRGB(255, 210, 74)
local BEAM = Color3.fromRGB(255, 204, 51)
local SPARK = Color3.fromRGB(255, 216, 96)
local Q_FILL = Color3.fromRGB(255, 251, 230)
local Q_EDGE = Color3.fromRGB(255, 106, 0)
local Q_DEPTH = Color3.fromRGB(122, 42, 0)
local HALO_BITS = 16

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	give: (any, string) -> boolean?,
	has: ((string) -> boolean)?,
	parent: Instance?,
	name: string?,
	seed: number?,
	-- studs per big unit (ArenaData sizes; a kart is 5.5 big). Default Boxes.SCALE = the RC arena.
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	stop: () -> (),
	odds: () -> { [string]: number },
	folder: Folder,
}

-- sizes below are studs for a 4 stud box (Boxes.SIZE big units at 1 stud each); times `sc`
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	neon: boolean?,
	see: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = see or 0
	p:SetAttribute("Look", p.Transparency) -- show() puts this back when the box returns
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- `p` rides along when `root` moves (client/BoxFx moves only the root parts)
local function weld(p: BasePart, root: BasePart)
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- a "?" on the panel's front: a dark copy just behind and below it gives it depth
local function mark(panel: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mark"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 0
	gui.Brightness = 3
	for _, layer in { { Q_DEPTH, Q_DEPTH, 5 }, { Q_FILL, Q_EDGE, 0 } } do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Position = UDim2.fromOffset(layer[3], layer[3])
		t.Font = Enum.Font.FredokaOne
		t.Text = "?"
		t.TextSize = 82 -- fixed size on the 100 px canvas (TextScaled costs more on phones)
		t.TextColor3 = layer[1]
		t.TextStrokeTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = layer[2]
		stroke.Thickness = 5
		stroke.Parent = t
		t.Parent = gui
	end
	gui.Parent = panel
end

-- the 5 faces that show (no bottom), each turned so its Front points out of the box
local FACES = {
	CFrame.new(0, 0, -1),
	CFrame.new(0, 0, 1) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(1, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	CFrame.new(-1, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	CFrame.new(0, 1, 0) * CFrame.Angles(math.pi / 2, 0, 0),
}

-- One box. Body (the root) + frame, gems and panels welded to it; Halo (a hidden root) + its glowing
-- bits; Beam and Ring stay still on the ground.
local function build(i: number, spot: Vector3, parent: Instance, sc: number): Model
	local m = Instance.new("Model")
	m.Name = "Box" .. i
	local home = CFrame.new(spot + Vector3.new(0, Boxes.LIFT * sc, 0))
	local side = Boxes.SIZE * sc
	local h = side / 2

	local body = part(m, "Body", Vector3.one * side, home, GOLD)
	body.CastShadow = true

	local t = 0.6 * sc
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			for _, e in
				{
					{ Vector3.new(side + t, t, t), Vector3.new(0, a * h, b * h) },
					{ Vector3.new(t, side + t, t), Vector3.new(a * h, 0, b * h) },
					{ Vector3.new(t, t, side + t), Vector3.new(a * h, b * h, 0) },
				}
			do
				weld(part(m, "Edge", e[1], home + e[2], FRAME), body)
			end
			for _, d in { -1, 1 } do
				local at = home
					* CFrame.new(a * h, b * h, d * h)
					* CFrame.Angles(math.rad(45), math.rad(35), 0)
				weld(part(m, "Gem", Vector3.one * 0.62 * sc, at, GEM, true), body)
			end
		end
	end

	local p = side * 0.74
	for _, f in FACES do
		local fc = home * CFrame.new(f.Position * h) * f.Rotation
		local trim = part(
			m,
			"Trim",
			Vector3.new(p + 0.3 * sc, p + 0.3 * sc, 0.1 * sc),
			fc * CFrame.new(0, 0, -0.02 * sc),
			TRIM,
			true
		)
		weld(trim, body)
		local panel =
			part(m, "Panel", Vector3.new(p, p, 0.16 * sc), fc * CFrame.new(0, 0, -0.06 * sc), PANEL)
		mark(panel)
		weld(panel, body)
	end

	local light = Instance.new("PointLight")
	light.Color = SPARK
	light.Brightness = 4
	light.Range = 14 * sc
	light.Shadows = false
	light.Parent = body
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(SPARK)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6 * sc),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Rate = 12
	sparks.Speed = NumberRange.new(2 * sc, 4 * sc)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, 3 * sc, 0)
	sparks.Parent = body

	-- the halo: a ring of glowing bits around the box, tipped over; client/BoxFx spins it
	local halo = part(m, "Halo", Vector3.one * 0.2 * sc, home, HALO, false, 1)
	local tip = home * CFrame.Angles(math.rad(70), 0, math.rad(15))
	for k = 1, HALO_BITS do
		local a = k / HALO_BITS * math.pi * 2
		local at = tip * CFrame.Angles(0, 0, a) * CFrame.new(0, 3.9 * sc, 0)
		weld(part(m, "HaloBit", Vector3.new(1.4, 0.22, 0.22) * sc, at, HALO, true), halo)
	end

	part(
		m,
		"Beam",
		Vector3.new(14, 3.6, 3.6) * sc,
		CFrame.new(spot + Vector3.new(0, 7 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		BEAM,
		true,
		0.88
	).Shape =
		Enum.PartType.Cylinder

	-- the ring on the ground shows where a box comes back
	local width = Boxes.RING * sc -- the look only (the reach is wider)
	part(
		m,
		"Ring",
		Vector3.new(0.2 * sc, width, width),
		CFrame.new(spot + Vector3.new(0, 0.12 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		GOLD,
		true,
		0.45
	).Shape =
		Enum.PartType.Cylinder

	m.PrimaryPart = body
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the box arrives whole if streaming is on
	m:SetAttribute("Up", true)
	m:SetAttribute("Home", home)
	m:SetAttribute("TakenBy", "")
	m:SetAttribute("TakenWeapon", "")
	m:SetAttribute("TakenCount", 0)
	CollectionService:AddTag(m, BoxServer.TAG)
	m.Parent = parent
	return m
end

-- a taken box: everything hides but a faint ring, so you can see where it comes back
local function show(m: Model, up: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local look = d:GetAttribute("Look")
			local base = if type(look) == "number" then look else 0
			if d.Name == "Ring" then
				d.Transparency = if up then base else 0.85
			else
				d.Transparency = if up then base else 1
			end
		elseif d:IsA("SurfaceGui") then
			d.Enabled = up
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = up
		end
	end
	m:SetAttribute("Up", up)
end

local running: { [string]: Handle } = {}

function BoxServer.start(opts: Options): Handle
	local parent = opts.parent or workspace
	local name = opts.name or "SmashBoxes"
	local before = running[name]
	if before then
		before.stop()
	end
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local given = opts.scale
	local sc = if type(given) == "number" and given > 0 then given else Boxes.SCALE
	local spots = {}
	local models: { Model } = {}
	for i, v in opts.spots do
		table.insert(spots, { x = v.X, y = v.Y, z = v.Z })
		table.insert(models, build(i, v, folder, sc))
	end
	local boxes = Boxes.new(spots, sc)
	local sweepMax = Boxes.SWEEP_MAX * sc
	local prev: { [any]: Vector3 } = {} -- each kart's spot at the last check
	local rng = Random.new(opts.seed or os.clock() * 1e6)
	local last: { [any]: string } = {} -- kart id -> its last weapon from a box
	local streak: { [any]: number } = {}

	local function hasSafe(name: string): boolean
		if opts.has == nil then
			return true
		end
		local ok, yes = pcall(opts.has, name)
		return ok and yes == true
	end

	-- Called by Boxes.step for a kart touching box i: roll and try to give it.
	local function take(id: any, i: number): boolean
		local weapon = Boxes.roll(rng:NextNumber(), hasSafe, last[id], streak[id])
		if weapon == nil then
			return false -- no weapon built yet: the box stays
		end
		local ok, res = pcall(opts.give, id, weapon)
		if not ok then
			warn(`BoxServer: give failed for {tostring(id)} ({weapon}): {res}`)
			return false
		end
		if res == false then
			return false -- kart already holds a weapon: leave the box for someone else
		end
		if last[id] == weapon then
			streak[id] = (streak[id] or 0) + 1
		else
			last[id] = weapon
			streak[id] = 1
		end
		local m = models[i]
		m:SetAttribute("TakenWeapon", weapon)
		m:SetAttribute("TakenBy", tostring(id))
		local count = m:GetAttribute("TakenCount")
		m:SetAttribute("TakenCount", (if type(count) == "number" then count else 0) + 1)
		return true
	end

	local list: { Boxes.Kart } = {}
	local wait = 0
	local since = 0 -- seconds since the last check (a slow frame makes it longer)
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		wait -= dt
		since += dt
		if wait > 0 then
			return
		end
		wait = math.max(wait + 1 / Boxes.CHECK_HZ, 0)
		-- SWEEP_MAX is per normal check; a late check allows a longer drive
		local jump = sweepMax * math.max(since * Boxes.CHECK_HZ, 1)
		since = 0
		local ok, karts = pcall(opts.karts)
		if not ok or type(karts) ~= "table" then
			return
		end
		table.clear(list)
		local seen: { [any]: Vector3 } = {}
		local present: { [any]: boolean } = {}
		for _, k in karts do
			local p = k.position
			if typeof(p) == "Vector3" and k.id ~= nil then
				local alive = k.alive == true
				present[k.id] = true
				local was = prev[k.id]
				-- the path since the last check counts, unless it was a jump (respawn, teleport)
				local sweep = alive and was ~= nil and (p - was).Magnitude <= jump
				table.insert(list, {
					id = k.id,
					x = p.X,
					y = p.Y,
					z = p.Z,
					alive = alive,
					px = if sweep then (was :: Vector3).X else nil,
					pz = if sweep then (was :: Vector3).Z else nil,
				})
				if alive then
					seen[k.id] = p
				end
			end
		end
		prev = seen -- a kart missing from this check (dead, hidden after a jump) starts fresh
		for id in last do
			if not present[id] then -- left the game: forget its weapon streak
				last[id] = nil
				streak[id] = nil
			end
		end
		local taken, back = Boxes.step(boxes, list, os.clock(), take)
		for _, i in back do
			show(models[i], true)
		end
		for _, t in taken do
			show(models[t.box], false)
		end
	end)

	local handle: Handle
	handle = {
		folder = folder,
		reset = function()
			Boxes.reset(boxes)
			table.clear(prev)
			table.clear(last)
			table.clear(streak)
			for _, m in models do
				show(m, true)
			end
		end,
		stop = function()
			conn:Disconnect()
			folder:Destroy()
			if running[name] == handle then
				running[name] = nil
			end
		end,
		odds = function()
			return Boxes.odds(hasSafe)
		end,
	}
	running[name] = handle
	return handle
end

return BoxServer
