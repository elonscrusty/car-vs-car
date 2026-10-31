--!strict
-- The swinging crane ball in the Smash arena (rules: shared/Crane). The crane's tower, boom and
-- the spiked ball on its chain are built here; the swing itself is drawn by each client from the
-- same clock (attribute Phase0 = the server time the swing began), so it is smooth with no
-- network traffic. 10 times a second the server works out where the ball is, hurts and shoves any
-- kart it is on (through `damage` / `push`). No remote lets a client hurt or shove anything.
--
-- Use (MatchRunner, when the arena is built):
--   local crane = CraneServer.start({
--       foot = Vector3, -- world floor spot under the lane's middle (Crane.SPOT through TrackData.toWorld)
--       karts = function() return list of { id, position: Vector3, alive } end,
--       damage = MatchRunner.damage, -- (victimId, attackerId, amount, word) -> any
--       push = function(id, impulse: Vector3) end, -- a bot: set its speed; a player: kick()
--   })
--   crane.reset()                 -- each round's start: nobody on cooldown, the swing starts again
--   crane.kick(player, impulse)   -- ask a player's own client to take a shove (clamped there too)
--   crane.stop()                  -- arena gone: crane removed
-- The crane is a Model in workspace.<name> (default "CraneBall") tagged "CraneBall" with attributes
-- Phase0 and Foot. Clients: client/CraneFx.client. Remote CraneFx: server -> all "Hit" { position },
-- server -> one player "Kick" { impulse }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crane = require(ReplicatedStorage.Shared.Crane)

local CraneServer = {}

CraneServer.TAG = "CraneBall"
CraneServer.REMOTE = "CraneFx"
CraneServer.TICK = 0.1

local YELLOW = Color3.fromRGB(242, 194, 52)
local DARK = Color3.fromRGB(42, 42, 51)
local STEEL = Color3.fromRGB(138, 138, 150)
local RUST = Color3.fromRGB(74, 47, 36)
local CHAINC = Color3.fromRGB(85, 85, 95)
local HOT = Color3.fromRGB(255, 154, 42)
local RED = Color3.fromRGB(255, 90, 40)

export type KartInfo = { id: any, position: Vector3, alive: boolean }

export type Options = {
	foot: Vector3,
	karts: () -> { KartInfo },
	damage: (victimId: any, attackerId: any, amount: number, word: string) -> any,
	push: (id: any, impulse: Vector3) -> (),
	parent: Instance?,
	name: string?,
	scale: number?,
}

export type Handle = {
	reset: () -> (),
	kick: (player: Player, impulse: Vector3) -> (),
	stop: () -> (),
	folder: Folder,
}

local started: { [string]: Handle } = {}

local function remote(): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(CraneServer.REMOTE)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local made = Instance.new("RemoteEvent")
	made.Name = CraneServer.REMOTE
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

local function block(
	name: string,
	parent: Instance,
	color: Color3,
	mat: Enum.Material,
	size: Vector3,
	cf: CFrame
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = mat
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false -- (the crane is for looking at; only its ball hurts)
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The crane (big units x sc), lane along X through `foot`: a yellow tower behind the lane, a boom
-- out over it, and a "Swing" model hanging from the boom tip (chain + spiked ball), centred on the
-- tip so the client can turn the whole thing with one PivotTo. About 55 parts.
local function build(foot: Vector3, parent: Instance, sc: number): (Model, Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "Crane"
	local function at(x: number, y: number, z: number): Vector3
		return foot + Vector3.new(x * sc, y * sc, z * sc)
	end
	local H = Crane.PIVOT_H
	-- tower: four legs, cross rungs, a base plate and a cab
	for _, o in { { -1.6, -1.6 }, { 1.6, -1.6 }, { 1.6, 1.6 }, { -1.6, 1.6 } } do
		block(
			"Leg",
			m,
			YELLOW,
			Enum.Material.SmoothPlastic,
			Vector3.new(0.5, H + 3, 0.5) * sc,
			CFrame.new(at(o[1], (H + 3) / 2, -9 + o[2]))
		)
	end
	for y = 2, H, 4 do
		for _, z in { -1.6, 1.6 } do
			block(
				"Rung",
				m,
				YELLOW,
				Enum.Material.SmoothPlastic,
				Vector3.new(3.4, 0.3, 0.3) * sc,
				CFrame.new(at(0, y, -9 + z))
			)
		end
		block(
			"Brace",
			m,
			YELLOW,
			Enum.Material.SmoothPlastic,
			Vector3.new(0.25, 0.25, 4.8) * sc,
			CFrame.new(at(1.6, y + 2, -9)) * CFrame.Angles(0.6, 0, 0)
		)
	end
	block(
		"Base",
		m,
		Color3.fromRGB(58, 58, 68),
		Enum.Material.SmoothPlastic,
		Vector3.new(8, 1.2, 8) * sc,
		CFrame.new(at(0, 0.6, -9))
	)
	block(
		"Cab",
		m,
		YELLOW,
		Enum.Material.SmoothPlastic,
		Vector3.new(5, 2.4, 5) * sc,
		CFrame.new(at(0, H + 4.2, -9))
	)
	block(
		"Roof",
		m,
		DARK,
		Enum.Material.SmoothPlastic,
		Vector3.new(4, 1.6, 4) * sc,
		CFrame.new(at(0, H + 6, -9))
	)
	-- boom out over the lane (+Z), ending over the lane's middle
	block(
		"Boom",
		m,
		YELLOW,
		Enum.Material.SmoothPlastic,
		Vector3.new(1.6, 1.6, 22) * sc,
		CFrame.new(at(0, H + 1.2, 2))
	)
	block(
		"Tip",
		m,
		DARK,
		Enum.Material.SmoothPlastic,
		Vector3.new(2.4, 2.4, 2.4) * sc,
		CFrame.new(at(0, H + 1, 0))
	)
	-- the swinging part
	local swing = Instance.new("Model")
	swing.Name = "Swing"
	local origin = at(0, H, 0)
	local sp = block(
		"Pin",
		swing,
		DARK,
		Enum.Material.SmoothPlastic,
		Vector3.new(1.2, 1.2, 1.2) * sc,
		CFrame.new(origin)
	)
	swing.PrimaryPart = sp
	local CH = Crane.CHAIN
	for i = 0, 11 do
		local y = -1.2 - i * (CH - 4.5) / 11
		block(
			"Link",
			swing,
			CHAINC,
			Enum.Material.Metal,
			Vector3.new(0.9, 1.5, 0.5) * sc,
			CFrame.new(origin + Vector3.new(0, y * sc, 0))
				* CFrame.Angles(0, if i % 2 == 0 then 0 else math.rad(90), 0)
		)
	end
	local bc = origin + Vector3.new(0, -CH * sc, 0)
	block(
		"Hook",
		swing,
		DARK,
		Enum.Material.SmoothPlastic,
		Vector3.new(1.4, 1.2, 1.4) * sc,
		CFrame.new(bc + Vector3.new(0, 3.6 * sc, 0))
	)
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 5.8 * sc
	ball.Color = RUST
	ball.Material = Enum.Material.SmoothPlastic
	ball.CFrame = CFrame.new(bc)
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow =
		true, false, false, false, false
	ball.Parent = swing
	local band = block(
		"Band",
		swing,
		STEEL,
		Enum.Material.Metal,
		Vector3.new(0.4, 6.1, 6.1) * sc,
		CFrame.new(bc) * CFrame.Angles(0, 0, math.rad(90))
	)
	band.Shape = Enum.PartType.Cylinder
	-- spikes: 18 steel studs spread round the ball (golden-angle spiral), a few with a hot bead
	for i = 1, 18 do
		local y = 1 - 2 * (i - 0.5) / 18
		local r = math.sqrt(1 - y * y)
		local a = i * 2.399
		local dir = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local sk = block(
			"Spike",
			swing,
			STEEL,
			Enum.Material.Metal,
			Vector3.new(0.5, 0.5, 2.4) * sc,
			CFrame.lookAt(bc + dir * 3.9 * sc, bc + dir * 8 * sc)
		)
		sk.Shape = Enum.PartType.Block
		if i % 3 == 0 then
			local bead = block(
				"Glow",
				swing,
				HOT,
				Enum.Material.Neon,
				Vector3.one * 0.6 * sc,
				CFrame.new(bc + dir * 2.95 * sc)
			)
			bead.Shape = Enum.PartType.Ball
		end
	end
	local lamp = block(
		"Light",
		swing,
		RED,
		Enum.Material.Neon,
		Vector3.one * 0.7 * sc,
		CFrame.new(bc + Vector3.new(0, 4.6 * sc, 0))
	)
	lamp.Shape = Enum.PartType.Ball
	swing.Parent = m
	-- the lane on the floor: a flat see-through part with stripes drawn on it
	local w = (Crane.reach() + Crane.LANE_W)
	local zone = Instance.new("Part")
	zone.Name = "Lane"
	zone.Size = Vector3.new(w * 2 * sc, 0.1 * sc, Crane.LANE_W * 2 * sc)
	zone.Position = foot + Vector3.new(0, 0.1 * sc, 0)
	zone.Transparency = 1
	zone.Anchored, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow =
		true, false, false, false, false
	zone.Parent = m
	local zg = Instance.new("SurfaceGui")
	zg.Name = "Stripes"
	zg.Face = Enum.NormalId.Top
	zg.CanvasSize = Vector2.new(w * 2 * 4, Crane.LANE_W * 2 * 4)
	zg.LightInfluence = 0
	zg.Brightness = 1.4
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BackgroundTransparency = 0.86
	local stroke = Instance.new("UIStroke")
	stroke.Color = RED
	stroke.Thickness = 5
	stroke.Parent = fill
	fill.Parent = zg
	zg.Parent = zone
	m:AddTag(CraneServer.TAG)
	m.PrimaryPart = zone
	m.Parent = parent
	return m, swing, zone
end

function CraneServer.start(opts: Options): Handle
	local name = opts.name or "CraneBall"
	local old = started[name]
	if old then
		old.stop()
	end
	local sc = opts.scale or Crane.SCALE
	local parent = opts.parent or workspace
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local fx = remote()
	local foot = plain(opts.foot) :: vector
	local m = build(opts.foot, folder, sc)
	local t0 = workspace:GetServerTimeNow()
	m:SetAttribute("Phase0", t0)
	m:SetAttribute("Foot", opts.foot)
	local state = Crane.newState()

	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < CraneServer.TICK then
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
		local now = workspace:GetServerTimeNow() - (m:GetAttribute("Phase0") :: number)
		for _, h in Crane.step(state, foot, karts, now, sc) do
			local ok, err = pcall(opts.damage, h.id, nil, h.damage, string.lower(Crane.NAME))
			if not ok then
				warn("[Crane] damage failed: " .. tostring(err))
			end
			local okp, errp = pcall(opts.push, h.id, Vector3.new(h.shove.x, h.shove.y, h.shove.z))
			if not okp then
				warn("[Crane] push failed: " .. tostring(errp))
			end
			fx:FireAllClients("Hit", { position = Vector3.new(h.at.x, h.at.y, h.at.z) })
		end
	end)

	local handle: Handle
	handle = {
		reset = function()
			Crane.reset(state)
			m:SetAttribute("Phase0", workspace:GetServerTimeNow()) -- (clients follow the new start)
		end,
		kick = function(player: Player, impulse: Vector3)
			if player.Parent == nil then
				return
			end
			-- (never bigger than the rules ever give; the client clamps it again)
			local cap = Crane.KNOCK_MAX + Crane.KNOCK_UP
			if impulse.Magnitude > cap then
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

return CraneServer
