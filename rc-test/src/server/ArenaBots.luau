--!strict
-- The arena's bot karts (Smash): ArenaBrain decides, this moves the real karts and fires.
-- MatchRunner owns the karts (model, health, respawn): MatchRunner.addBot builds an anchored,
-- non-colliding kart and calls ArenaBots.add; it calls remove when the bot is smashed, add again
-- with the spawn CFrame on respawn, and ArenaBots.step every frame of the match.
-- Bots move by pose (no physics), so the Lune bot sim (LOOPTEST) runs this file as is. Every hit
-- goes through WeaponServer.fire like a player's, so the server checks it the same way.
--
-- ctx: everything the bots read or do, each one swappable (tests, the sim). Left out = the real
-- game's (MatchRunner, WeaponServer, BoxServer's tagged boxes, ArenaData), when those are there.
-- The brain thinks in the arena's map-local big units; ctx.toLocal / toWorld convert.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaBrain = require(ReplicatedStorage.Shared.ArenaBrain)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)

local ArenaBots = {}

ArenaBots.HOVER = 2.5 -- big units: kart pivot over the floor (ArenaData's spawn height)
ArenaBots.BOX_TAG = "SmashBox" -- BoxServer's boxes (attributes Up, Home)

export type Kart = {
	id: number,
	pos: Vector3?, -- world (nil: no body yet)
	alive: boolean,
	shield: boolean?,
	human: boolean?,
	rookie: boolean?, -- a player in their first matches (ArenaBrain.ROOKIE): bots go easy on them
	cframe: CFrame?, -- (a rookie's facing, for ArenaBrain.FEED)
	rookieHit: boolean?, -- a rookie hurt it just now: leave the kill to them (Match.ROOKIE_HIT)
	smashes: number?, -- this round's (a rookie's: ArenaBrain.FEED / ROOKIE.most)
	deaths: number?,
	model: Model?,
}
export type Ctx = {
	karts: (() -> { Kart })?,
	weaponOf: ((id: number) -> (string?, number))?,
	fire: ((id: number, aim: Vector3, from: Vector3) -> ())?, -- aim and from: world spots
	boxes: (() -> { Vector3 })?, -- world spots of the boxes that are up
	place: ((id: number, cf: CFrame) -> ())?,
	-- world <-> arena (map-local big units; ArenaData). toWorld puts the spot on the floor.
	toLocal: ((p: Vector3) -> (number, number))?,
	toWorld: ((x: number, z: number) -> Vector3)?,
	world: ArenaBrain.World?, -- walls, trees, hills... (default ArenaBrain.fromArena(ArenaData))
}
export type Fleet = {
	ctx: Ctx,
	rng: ArenaBrain.Rng,
	bots: { [number]: ArenaBrain.Bot },
	world: ArenaBrain.World,
	models: { [number]: Model }, -- this frame's kart models by id (for the default place)
	startAt: number?, -- `now` at the first step: a rookie's calm (ArenaBrain.ROOKIE.calm) counts from here
	list: { ArenaBrain.Bot }, -- (reused each frame)
}

-- a sibling module of the real game, when it's been built
local function optional(parent: Instance, name: string): any
	local m = parent:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, got = pcall(require, m)
		if ok then
			return got
		end
		warn("ArenaBots: " .. name .. " did not load: " .. tostring(got))
	end
	return nil
end

-- A sibling module looked up when first needed (not at new(): MatchRunner may still be loading
-- when it makes its fleet, and WeaponServer may come in later), then kept.
local function later(name: string): () -> any
	local got: any = nil
	return function(): any
		if got == nil then
			got = optional(script.Parent, name)
		end
		return got
	end
end

-- Fill in the real game's parts of ctx that the caller left out.
local function realCtx(ctx: Ctx): Ctx
	local match = later("MatchRunner")
	local weapons = later("WeaponServer")
	local Arena = optional(ReplicatedStorage.Shared, "ArenaData")
	local out: Ctx = table.clone(ctx)
	if not out.karts then
		out.karts = function(): { Kart }
			local Match = match()
			return if Match and Match.karts then Match.karts() else {}
		end
	end
	if not out.weaponOf then
		out.weaponOf = function(id: number): (string?, number)
			local Weapons = weapons()
			-- WeaponServer.holding(id) -> (name, ammo); "" = holds nothing
			if Weapons and Weapons.holding then
				local name, ammo = Weapons.holding(id)
				if type(name) ~= "string" or name == "" then
					return nil, 0
				end
				return name, tonumber(ammo) or 0
			end
			return nil, 0
		end
	end
	if not out.fire then
		out.fire = function(id: number, aim: Vector3, from: Vector3)
			local Weapons = weapons()
			if Weapons and Weapons.fire then
				-- WeaponServer.fire takes the shot's direction (a player's remote sends one)
				Weapons.fire(id, Vector3.new(aim.X - from.X, 0, aim.Z - from.Z))
			end
		end
	end
	if not out.boxes then
		out.boxes = function(): { Vector3 }
			local up = {}
			for _, m in CollectionService:GetTagged(ArenaBots.BOX_TAG) do
				local home = m:GetAttribute("Home")
				if m:GetAttribute("Up") == true and typeof(home) == "CFrame" then
					table.insert(up, home.Position)
				end
			end
			return up
		end
	end
	if Arena then
		local t = Arena.track()
		if not out.toLocal then
			out.toLocal = function(p: Vector3): (number, number)
				local x, _, z = TrackData.toLocal(t, true, p.X, p.Y, p.Z)
				return x, z
			end
		end
		if not out.toWorld then
			out.toWorld = function(x: number, z: number): Vector3
				local y = Arena.groundAt(ArenaBrain.toPic(Arena, x, z)) + ArenaBots.HOVER
				local wx, wy, wz = TrackData.toWorld(t, true, x, y, z)
				return Vector3.new(wx, wy, wz)
			end
		end
		if not out.world then
			out.world = ArenaBrain.fromArena(Arena)
		end
	end
	if not out.toLocal then
		out.toLocal = function(p: Vector3): (number, number)
			return p.X, p.Z
		end
	end
	if not out.toWorld then
		out.toWorld = function(x: number, z: number): Vector3
			return Vector3.new(x, ArenaBots.HOVER, z)
		end
	end
	return out
end

-- A new fleet. `rng` (Random or ArenaBrain.rng) seeds every bot, so the sim's 20 runs repeat.
function ArenaBots.new(ctx: Ctx?, rng: ArenaBrain.Rng?): Fleet
	local c = realCtx(ctx or {})
	local models: { [number]: Model } = {}
	if not c.place then
		c.place = function(id: number, cf: CFrame)
			local m = models[id]
			if m then
				m:PivotTo(cf)
			end
		end
	end
	local base = c.world
	return {
		ctx = c,
		models = models,
		list = {},
		rng = rng or ArenaBrain.rng(os.clock() * 1e6),
		bots = {},
		world = {
			half = if base then base.half else 170,
			solids = if base then base.solids else {},
			zones = if base then base.zones else nil,
			boxes = {},
			karts = {},
		},
	}
end

-- A bot kart joins (or comes back after a smash) at `cf` (world). opts: skill 0..1, easy.
function ArenaBots.add(fleet: Fleet, id: number, cf: CFrame, opts: ArenaBrain.Opts?)
	local toLocal = fleet.ctx.toLocal :: (Vector3) -> (number, number)
	local x, z = toLocal(cf.Position)
	local ax, az = toLocal(cf.Position + cf.LookVector)
	local yaw = math.atan2(-(ax - x), -(az - z))
	local seed = ArenaBrain.rng(fleet.rng:NextNumber() * 2 ^ 30 + 1)
	fleet.bots[id] = ArenaBrain.new(id, x, z, yaw, opts, seed)
end

function ArenaBots.remove(fleet: Fleet, id: number)
	fleet.bots[id] = nil
end

function ArenaBots.clear(fleet: Fleet)
	table.clear(fleet.bots)
	fleet.startAt = nil
	fleet.world.feed = nil
end

function ArenaBots.count(fleet: Fleet): number
	local n = 0
	for _ in fleet.bots do
		n += 1
	end
	return n
end

-- One frame: read the match, step every bot, move its kart, fire. `now` = the match clock (s).
function ArenaBots.step(fleet: Fleet, dt: number, now: number)
	if next(fleet.bots) == nil then
		return
	end
	local ctx = fleet.ctx
	local toLocal = ctx.toLocal :: (Vector3) -> (number, number)
	local toWorld = ctx.toWorld :: (number, number) -> Vector3
	local w = fleet.world
	fleet.startAt = fleet.startAt or now
	local calm = now - (fleet.startAt :: number) < ArenaBrain.ROOKIE.calm
	table.clear(w.karts)
	table.clear(fleet.models)
	for _, k in (ctx.karts :: () -> { Kart })() do
		if k.model then
			fleet.models[k.id] = k.model
		end
		local pos = k.pos
		if not pos then
			continue -- (no body yet)
		end
		local x, z = toLocal(pos)
		-- a rookie's facing and whether they hold a shot (ArenaBrain.FEED)
		local fx, fz, armed = nil, nil, nil
		local cf = k.cframe
		if k.rookie and cf then
			local ax, az = toLocal(pos + cf.LookVector)
			local d = math.sqrt((ax - x) ^ 2 + (az - z) ^ 2)
			if d > 1e-6 then
				fx, fz = (ax - x) / d, (az - z) / d
			end
			local name, ammo = (ctx.weaponOf :: (number) -> (string?, number))(k.id)
			armed = name ~= nil and ammo > 0
		end
		table.insert(w.karts, {
			id = k.id,
			x = x,
			z = z,
			alive = k.alive,
			-- (shielded to the bots: a new kid's first 15 s, Match.forBots; a rookie's calm start)
			shield = k.shield or (calm and k.rookie == true),
			human = k.human,
			rookie = k.rookie,
			rookieHit = k.rookieHit,
			smashes = k.smashes,
			deaths = k.deaths,
			fx = fx,
			fz = fz,
			armed = armed,
		})
	end
	table.clear(w.boxes)
	for _, b in (ctx.boxes :: () -> { Vector3 })() do
		local x, z = toLocal(b)
		table.insert(w.boxes, { x = x, z = z })
	end
	local list = fleet.list
	table.clear(list)
	for _, b in fleet.bots do
		table.insert(list, b)
	end
	local hunters = ArenaBrain.hunters(list)
	ArenaBrain.feeders(list, w, now)
	local step = math.clamp(dt, 0, 0.1)
	for id, bot in fleet.bots do
		local weapon, ammo = (ctx.weaponOf :: (number) -> (string?, number))(id)
		local s = ArenaBrain.step(bot, w, step, now, weapon, ammo, hunters)
		local at = toWorld(s.x, s.z)
		local fx, fz = ArenaBrain.forward(s.yaw)
		local ahead = toWorld(s.x + fx, s.z + fz)
		local look = Vector3.new(ahead.X - at.X, 0, ahead.Z - at.Z);
		(ctx.place :: (number, CFrame) -> ())(id, CFrame.lookAt(at, at + look))
		if s.fire then
			(ctx.fire :: (number, Vector3, Vector3) -> ())(id, toWorld(s.fire.x, s.fire.z), at)
		end
	end
end

-- ===== practice dummies (LOBBY's warm-up yard) =====
-- A kart that sits still or drives slow circles, takes hits with its own health (no match, no
-- score, no coins), pops at 0 and is back whole DUMMY_BACK s later. The yard calls hit() when a
-- weapon hits it (the model carries Dummy = true and DummyId attributes to find it).

ArenaBots.DUMMY_HEALTH = 100
ArenaBots.DUMMY_BACK = 5 -- s from pop to back
ArenaBots.DUMMY_CIRCLE = { radius = 12, speed = 10 } -- studs, studs/s (world size)
local DUMMY_LOOKS = { "race_bolt", "drift_fury", "race_rocket", "drift_mint" }

export type Dummy = {
	id: number,
	model: Model,
	health: number,
	popped: boolean,
	gone: boolean, -- destroyed: never comes back
	hit: (self: Dummy, amount: number) -> boolean,
	destroy: (self: Dummy) -> (),
}

local dummies = 0

-- A practice dummy at `at` (world) under `parent`. mode "circle" drives slow loops round `at`.
-- `scale` = the karts' size (CarBuilder's); 1 = a full-size car.
function ArenaBots.dummy(parent: Instance, at: CFrame, mode: string?, scale: number?): Dummy
	dummies += 1
	local n = dummies
	local id = -9000 - n
	local model = CarBuilder.build(`Car_{id}`, at, scale or 1)
	model:SetAttribute("BotName", "Practice dummy")
	model:SetAttribute("Dummy", true)
	model:SetAttribute("DummyId", id)
	model:SetAttribute("Health", ArenaBots.DUMMY_HEALTH)
	local look = DUMMY_LOOKS[(n - 1) % #DUMMY_LOOKS + 1]
	local info = CarCatalog.get(look) :: any
	local body = model.PrimaryPart
	if info and body then
		model:SetAttribute("ToyCar", look)
		body.Color = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	model.Parent = parent
	local spin: RBXScriptConnection? = nil
	local dummy: Dummy = {
		id = id,
		model = model,
		health = ArenaBots.DUMMY_HEALTH,
		popped = false,
		gone = false,
		-- Take `amount` damage; true when this hit popped it.
		hit = function(d: Dummy, amount: number): boolean
			-- (NaN and inf are a caller's bug, not a hit)
			if
				d.popped
				or d.gone
				or amount ~= amount
				or amount <= 0
				or amount == math.huge
				or d.model.Parent == nil
			then
				return false
			end
			d.health = math.max(0, d.health - amount)
			d.model:SetAttribute("Health", d.health)
			if d.health > 0 then
				return false
			end
			d.popped = true
			local boom = Instance.new("Explosion")
			boom.BlastPressure = 0
			boom.BlastRadius = 0
			boom.DestroyJointRadiusPercent = 0
			boom.Position = d.model:GetPivot().Position
			boom.Parent = workspace
			d.model.Parent = nil
			task.delay(ArenaBots.DUMMY_BACK, function()
				if d.popped and not d.gone and parent:IsDescendantOf(game) then
					d.health, d.popped = ArenaBots.DUMMY_HEALTH, false
					d.model:SetAttribute("Health", d.health)
					d.model.Parent = parent
				end
			end)
			return true
		end,
		destroy = function(d: Dummy)
			if spin then
				spin:Disconnect()
			end
			d.popped, d.gone = true, true
			d.model:Destroy() -- (its Destroying sees gone and stops there)
		end,
	}
	if mode == "circle" then
		local c = ArenaBots.DUMMY_CIRCLE
		local a = n * 1.3
		spin = RunService.Heartbeat:Connect(function(dt: number)
			a += dt * c.speed / c.radius
			if dummy.popped then
				return
			end
			local pos = at * CFrame.new(math.cos(a) * c.radius, 0, math.sin(a) * c.radius)
			-- nose along the circle
			model:PivotTo(
				CFrame.lookAt(
					pos.Position,
					pos.Position + (at.Rotation * Vector3.new(-math.sin(a), 0, math.cos(a)))
				)
			)
		end)
	end
	-- the yard torn down without destroy(): stop too (no Heartbeat left running)
	model.Destroying:Connect(function()
		if not dummy.gone then
			dummy:destroy()
		end
	end)
	parent.Destroying:Connect(function()
		if not dummy.gone then
			dummy:destroy()
		end
	end)
	return dummy
end

return ArenaBots
