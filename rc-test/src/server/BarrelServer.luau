--!strict
-- The dynamite kegs in the Smash arena (rules: shared/Barrels). The server alone decides: 10 times
-- a second it looks where every live kart is, lights a keg that is touched, counts the fuse down,
-- and when it goes off hurts the karts in the ring (through `damage`) and shoves them (`push`).
-- No remote lets a client light, hurt or shove anything.
--
-- Use (MatchRunner, when the arena is built):
--   local kegs = BarrelServer.start({
--       spots = { Vector3 },  -- world floor spots (Barrels.SPOTS through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive } end,
--       damage = MatchRunner.damage, -- (victimId, attackerId, amount, word) -> (taken, smashed)
--       push = function(id, impulse: Vector3) end, -- a bot: set its speed; a player: kick()
--   })
--   kegs.reset()              -- each round's start: every keg up
--   kegs.weaponFx(kind, data)     -- WeaponServer's fx (GunShot, RocketBoom, MineBoom): light kegs
--   kegs.hitAt(pos, reach, owner) -- anything else that goes off at pos: light kegs near it
--   kegs.kick(player, impulse)    -- ask a player's own client to take a shove (clamped there too)
--   kegs.stop()               -- arena gone: kegs removed
-- Each keg is a Model in workspace.<name> (default "BarrelKegs") with attributes Up and Lit.
-- Clients: client/BarrelFx.client (spark blink, the ring, the boom, the shove). Remote BarrelFx:
-- server -> all "Boom" { position }, server -> one player "Kick" { impulse }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Barrels = require(ReplicatedStorage.Shared.Barrels)

local BarrelServer = {}

BarrelServer.TAG = "DynamiteKeg"
BarrelServer.REMOTE = "BarrelFx"
BarrelServer.TICK = 0.1

local WOOD = Color3.fromRGB(138, 90, 52)
local IRON = Color3.fromRGB(42, 42, 51)
local RED = Color3.fromRGB(200, 48, 42)
local PAPER = Color3.fromRGB(244, 239, 224)
local AMBER = Color3.fromRGB(255, 176, 42)
local SPARK = Color3.fromRGB(255, 225, 74)

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	spots: { Vector3 },
	karts: () -> { KartInfo },
	damage: (victimId: any, attackerId: any, amount: number, word: string) -> any,
	push: (id: any, impulse: Vector3) -> (),
	parent: Instance?,
	name: string?,
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	hitAt: (position: Vector3, reach: number, owner: any?) -> number,
	weaponFx: (kind: string, data: any) -> number,
	kick: (player: Player, impulse: Vector3) -> (),
	stop: () -> (),
	folder: Folder,
}

local started: { [string]: Handle } = {}

local function remote(): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(BarrelServer.REMOTE)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local made = Instance.new("RemoteEvent")
	made.Name = BarrelServer.REMOTE
	made.Parent = ReplicatedStorage
	return made
end

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

local function cyl(name: string, parent: Instance, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false -- karts drive through a keg (it goes off first): nothing to get stuck on
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- One keg (big units x sc): a wooden keg with two iron bands, a TNT tag, five red dynamite sticks
-- with a burning fuse on top, and a flat amber ring on the floor showing the whole danger zone.
-- About 16 parts. `parts` collects the ones that hide when the keg is down.
local function build(
	i: number,
	spot: Vector3,
	parent: Instance,
	sc: number
): (Model, { BasePart }, BasePart)
	local m = Instance.new("Model")
	m.Name = "Keg" .. i
	local parts: { BasePart } = {}
	local function up(y: number): CFrame
		return CFrame.new(spot + Vector3.new(0, y * sc, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	local body = cyl("Body", m, WOOD, Enum.Material.Wood)
	body.Size = Vector3.new(3 * sc, 3.2 * sc, 3.2 * sc) -- (a cylinder's height runs along X)
	body.CFrame = up(1.5)
	table.insert(parts, body)
	for n, y in { 0.55, 2.5 } do
		local b = cyl("Band" .. n, m, IRON, Enum.Material.Metal)
		b.Size = Vector3.new(0.3 * sc, 3.3 * sc, 3.3 * sc)
		b.CFrame = up(y)
		table.insert(parts, b)
	end
	-- the TNT tag, on the side facing +Z
	local tag = Instance.new("Part")
	tag.Name = "Tag"
	tag.Size = Vector3.new(1.7 * sc, 0.85 * sc, 0.1 * sc)
	tag.CFrame = CFrame.new(spot + Vector3.new(0, 1.6 * sc, 1.66 * sc))
	tag.Color = PAPER
	tag.Material = Enum.Material.SmoothPlastic
	tag.Anchored, tag.CanCollide, tag.CanQuery, tag.CanTouch, tag.CastShadow =
		true, false, false, false, false
	tag.Parent = m
	table.insert(parts, tag)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(170, 85)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "TNT"
	label.TextSize = 70 -- fixed on the canvas (TextScaled costs more on phones)
	label.TextColor3 = Color3.fromRGB(22, 22, 26)
	label.Parent = gui
	gui.Parent = tag
	-- dynamite
	for n, o in { { -0.5, 0 }, { 0.5, 0.05 }, { 0, 0.5 }, { 0, -0.5 }, { 0, 0 } } do
		local s = cyl("Stick" .. n, m, RED, Enum.Material.SmoothPlastic)
		s.Size = Vector3.new(2 * sc, 0.56 * sc, 0.56 * sc)
		s.CFrame = CFrame.new(spot + Vector3.new(o[1] * sc, 4 * sc, o[2] * sc))
			* CFrame.Angles(0, 0, math.rad(90))
		table.insert(parts, s)
	end
	local fuse = cyl("Fuse", m, IRON, Enum.Material.SmoothPlastic)
	fuse.Size = Vector3.new(0.9 * sc, 0.1 * sc, 0.1 * sc)
	fuse.CFrame = CFrame.new(spot + Vector3.new(0.1 * sc, 5.3 * sc, 0))
		* CFrame.Angles(0, 0, math.rad(60))
	table.insert(parts, fuse)
	local spark = Instance.new("Part")
	spark.Name = "Spark"
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.one * 0.6 * sc
	spark.Position = spot + Vector3.new(0.3 * sc, 5.7 * sc, 0)
	spark.Color = SPARK
	spark.Material = Enum.Material.Neon
	spark.Anchored, spark.CanCollide, spark.CanQuery, spark.CanTouch, spark.CastShadow =
		true, false, false, false, false
	spark.Parent = m
	table.insert(parts, spark)
	-- the danger ring: a flat see-through part with a circle drawn on it
	local zone = Instance.new("Part")
	zone.Name = "Zone"
	zone.Size = Vector3.new(Barrels.RADIUS * 2 * sc, 0.1 * sc, Barrels.RADIUS * 2 * sc)
	zone.Position = spot + Vector3.new(0, 0.1 * sc, 0)
	zone.Transparency = 1
	zone.Anchored, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow =
		true, false, false, false, false
	zone.Parent = m
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
	fill.BackgroundTransparency = 0.88
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = AMBER
	stroke.Thickness = 5
	stroke.Parent = fill
	fill.Parent = zg
	zg.Parent = zone
	m:SetAttribute("Up", true)
	m:SetAttribute("Lit", false)
	m.PrimaryPart = body
	m.Parent = parent
	return m, parts, zone
end

local function show(parts: { BasePart }, zone: BasePart, on: boolean)
	for _, p in parts do
		p.Transparency = if on then 0 else 1
	end
	local g = zone:FindFirstChild("Ring")
	if g and g:IsA("SurfaceGui") then
		g.Enabled = on
	end
end

function BarrelServer.start(opts: Options): Handle
	local name = opts.name or "BarrelKegs"
	local old = started[name]
	if old then
		old.stop()
	end
	local sc = opts.scale or Barrels.SCALE
	local parent = opts.parent or workspace
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local fx = remote()

	local kegs: { Barrels.Keg } = {}
	local models: { Model } = {}
	local shown: { { parts: { BasePart }, zone: BasePart } } = {}
	for i, spot in opts.spots do
		table.insert(kegs, Barrels.newKeg(plain(spot) :: vector))
		local m, parts, zone = build(i, spot, folder, sc)
		m:AddTag(BarrelServer.TAG)
		table.insert(models, m)
		table.insert(shown, { parts = parts, zone = zone })
	end

	local function sync()
		for i, k in kegs do
			local m = models[i]
			if m:GetAttribute("Up") ~= k.up then
				m:SetAttribute("Up", k.up)
				show(shown[i].parts, shown[i].zone, k.up)
			end
			local lit = k.litAt ~= nil
			if m:GetAttribute("Lit") ~= lit then
				m:SetAttribute("Lit", lit)
			end
		end
	end

	local function boom(b: any)
		local k = kegs[b.keg]
		for _, h in b.hurt do
			local ok, err = pcall(opts.damage, h.id, b.owner, h.damage, Barrels.NAME)
			if not ok then
				warn("[Barrels] damage failed: " .. tostring(err))
			end
			local okp, errp = pcall(opts.push, h.id, Vector3.new(h.shove.x, h.shove.y, h.shove.z))
			if not okp then
				warn("[Barrels] push failed: " .. tostring(errp))
			end
		end
		fx:FireAllClients("Boom", { position = opts.spots[b.keg] })
	end

	local clock = 0
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		acc += dt
		if acc < BarrelServer.TICK then
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
		for _, b in Barrels.step(kegs, karts, clock, sc) do
			boom(b)
		end
		sync()
	end)

	local handle: Handle
	handle = {
		reset = function()
			for _, k in kegs do
				Barrels.reset(k)
			end
			sync()
		end,
		hitAt = function(position: Vector3, reach: number, owner: any?): number
			local at = plain(position)
			local n = if at then Barrels.hitAt(kegs, at, reach, clock, owner, sc) else 0
			if n > 0 then
				sync()
			end
			return n
		end,
		weaponFx = function(kind: string, data: any): number
			if type(data) ~= "table" then
				return 0
			end
			local d = {
				from = plain(data.from),
				to = plain(data.to),
				pos = plain(data.pos),
				position = plain(data.position),
				owner = data.owner,
				quiet = data.quiet,
			}
			local n = Barrels.lightFromFx(kegs, kind, d, clock, sc)
			if n > 0 then
				sync()
			end
			return n
		end,
		kick = function(player: Player, impulse: Vector3)
			if player.Parent == nil then
				return
			end
			-- (never bigger than the rules ever give; the client clamps it again)
			local m = impulse.Magnitude
			local cap = Barrels.KNOCK_MAX + Barrels.KNOCK_UP
			if m > cap then
				impulse = impulse.Unit * cap
			end
			fx:FireClient(player, "Kick", { impulse = impulse })
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

return BarrelServer
