--!strict
-- Car VS Car SMASH weapons on the server (plans/smash, WEAPONS row). Holds what each kart has
-- (shared/Weapons: ammo, cooldown), runs the one fire remote (rate-limited, junk-proof), and hands
-- each shot to its weapon module in server/weapons/<Name>.luau ({ ammo, cooldown, fire(kart, aim,
-- ctx) -> boolean, step(ctx)?, clear(ctx)? }). Players fire through the remote, bots call fire()
-- directly. The match (server/MatchRunner) owns the karts and their health: damage goes through
-- MatchRunner.damage. Clients only draw: the WeaponFx remote says what to show.
-- Player attributes for screens: Weapon ("" = none) and Ammo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))

local WeaponServer = {}

export type Kart = { id: any, cframe: CFrame, alive: boolean }
export type Hit = { kartId: any?, position: Vector3 }
-- what a weapon module may use (the same table for every weapon)
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	raycast: (from: Vector3, to: Vector3, ignoreId: any?, worldOnly: boolean?) -> Hit?,
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> (),
	fx: (kind: string, data: { [string]: any }) -> (),
	after: (seconds: number, fn: () -> ()) -> (),
	place: ((kind: string, at: Vector3) -> Instance?)?,
	-- FREEZE: seconds > 0 stops kart `id` (it frees itself after that); 0 lets it go now
	freeze: ((id: any, seconds: number) -> ())?,
}
export type Module = {
	fire: (kart: Kart, aim: Vector3, ctx: Ctx) -> boolean,
	step: ((ctx: Ctx, dt: number) -> ())?,
	clear: ((ctx: Ctx) -> ())?,
}

local held: { [any]: Weapons.Held } = {}
local buckets: { [Player]: Weapons.Bucket } = {}
local modules: { [string]: Module } = {}
local frozenToken: { [any]: number } = {}
local ctx: Ctx

-- ===== the match's karts (MatchRunner; read lazily so either can start first) =====

-- (tests) a stand-in match: { karts() -> {Kart}, damage(...), kartOf(player), playerOf(id),
-- model(id) }, set by start({ match = ... })
local stand: any? = nil

local function matchRunner(): any?
	if stand then
		return stand
	end
	local m = script.Parent:FindFirstChild("MatchRunner")
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
	end
	return nil
end

-- a kart's pose: MatchRunner may hand a cframe, a model or a root part
local function pose(k: any): CFrame?
	if typeof(k.cframe) == "CFrame" then
		return k.cframe
	end
	local m = k.model
	if typeof(m) == "Instance" and (m :: Instance):IsA("Model") then
		return (m :: Model):GetPivot()
	end
	local r = k.root
	if typeof(r) == "Instance" and (r :: Instance):IsA("BasePart") then
		return (r :: BasePart).CFrame
	end
	if typeof(k.pos) == "Vector3" then
		return CFrame.new(k.pos)
	end
	return nil
end

-- The weapons do their maths on vectors. A Roblox Vector3 is one, so a real pose goes as is; the
-- pretend server's (tests/fakeroblox) isn't, so there the pose becomes a plain table of vectors.
local function vec(v: any): Vector3
	return vector.create(v.X, v.Y, v.Z) :: any
end
local function plain(cf: CFrame): CFrame
	if type(cf.Position) == "vector" then
		return cf
	end
	return {
		Position = vec(cf.Position),
		LookVector = vec(cf.LookVector),
		RightVector = vec(cf.RightVector),
		UpVector = vec(cf.UpVector),
	} :: any
end

-- karts and their models are read once per server frame (rockets ask many times a frame)
local cacheKarts: { Kart }? = nil
local cacheModels: { [any]: Instance }? = nil

local function readKarts(): { Kart }
	if stand then
		return stand.karts()
	end
	local mr = matchRunner()
	local out = {}
	if not mr or type(mr.karts) ~= "function" then
		return out
	end
	for key, k in mr.karts() do
		if type(k) == "table" then
			local id = if k.id ~= nil then k.id else key
			local cf = pose(k)
			if cf then
				local alive = if type(mr.isAlive) == "function"
					then mr.isAlive(id) == true
					else true
				table.insert(out, { id = id, cframe = plain(cf), alive = alive })
			end
		end
	end
	return out
end

local function allKarts(): { Kart }
	if not cacheKarts then
		cacheKarts = readKarts()
	end
	return cacheKarts :: { Kart }
end

local function readModel(id: any): Instance?
	if stand then
		return if type(stand.model) == "function" then stand.model(id) else nil
	end
	local mr = matchRunner()
	if not mr or type(mr.karts) ~= "function" then
		return nil
	end
	for key, k in mr.karts() do
		if type(k) == "table" and (k.id == id or (k.id == nil and key == id)) then
			local m = k.model
			return if typeof(m) == "Instance" then m else nil
		end
	end
	return nil
end

local function kartModel(id: any): Instance?
	if not cacheModels then
		local map = {}
		for _, k in allKarts() do
			local m = readModel(k.id)
			if m then
				map[k.id] = m
			end
		end
		cacheModels = map
	end
	return (cacheModels :: { [any]: Instance })[id]
end

-- the kart a player drives (MatchRunner.kartOf if it has one, else the player's UserId)
local function kartIdOf(player: Player): any
	local mr = matchRunner()
	if mr and type(mr.kartOf) == "function" then
		return mr.kartOf(player)
	end
	return player.UserId
end

local function playerOf(id: any): Player?
	if stand and type(stand.playerOf) == "function" then
		return stand.playerOf(id)
	end
	if type(id) == "number" and id > 0 then
		return Players:GetPlayerByUserId(id)
	end
	local mr = matchRunner()
	if mr and type(mr.playerOf) == "function" then
		local p = mr.playerOf(id)
		return if typeof(p) == "Instance" and p:IsA("Player") then p else nil
	end
	return nil
end

local function show(id: any)
	local p = playerOf(id)
	local h = held[id]
	if p then
		p:SetAttribute("Weapon", if h then h.name else "")
		p:SetAttribute("Ammo", if h then h.ammo else 0)
	end
end

-- ===== the context every weapon gets =====

local function makeCtx(fxRemote: RemoteEvent): Ctx
	local c: Ctx
	c = {
		now = function()
			return workspace:GetServerTimeNow()
		end,
		karts = allKarts,
		getKart = function(id: any): Kart?
			for _, k in allKarts() do
				if k.id == id then
					return k
				end
			end
			return nil
		end,
		-- the first thing between from and to: a living kart (any part of its model) or the world.
		-- worldOnly: karts (and smashed ones) are see-through, only walls and ground stop it.
		raycast = function(from: Vector3, to: Vector3, ignoreId: any?, worldOnly: boolean?): Hit?
			local skip = {}
			local fxFolder = workspace:FindFirstChild("WeaponBits")
			if fxFolder then
				table.insert(skip, fxFolder)
			end
			local live = {}
			for _, k in allKarts() do
				local m = kartModel(k.id)
				if m then
					if worldOnly or k.id == ignoreId or not k.alive then
						table.insert(skip, m)
					else
						live[m] = k.id
					end
				end
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = skip
			local res = workspace:Raycast(from, to - from, params)
			if not res then
				return nil
			end
			local hitId = nil
			for m, id in live do
				if res.Instance:IsDescendantOf(m) then
					hitId = id
					break
				end
			end
			return { kartId = hitId, position = res.Position }
		end,
		damage = function(victimId: any, attackerId: any, amount: number, weapon: string)
			local mr = matchRunner()
			if mr and type(mr.damage) == "function" then
				-- MatchRunner's words are lowercase and one of a kind: "rocket", "nuke", "gun"
				mr.damage(victimId, attackerId, amount, Weapons.feedWord(weapon))
			end
		end,
		fx = function(kind: string, data: { [string]: any })
			fxRemote:FireAllClients(kind, data)
		end,
		after = function(seconds: number, fn: () -> ())
			task.delay(seconds, fn)
		end,
		place = nil,
		freeze = function(id: any, seconds: number)
			local mr = matchRunner()
			if mr and type(mr.freeze) == "function" then
				mr.freeze(id, seconds)
				return
			end
			-- no MatchRunner.freeze: hold the kart's main part still and mark it Frozen
			local m = kartModel(id)
			local root = m and m:IsA("Model") and (m :: Model).PrimaryPart
			if not root then
				return
			end
			local on = seconds > 0
			root.Anchored = on
			m:SetAttribute("Frozen", on)
			local token = (frozenToken[id] or 0) + 1
			frozenToken[id] = token
			if on then
				task.delay(seconds, function()
					-- (only if nothing froze or freed it again since)
					if frozenToken[id] == token and root.Parent then
						root.Anchored = false
						m:SetAttribute("Frozen", false)
					end
				end)
			end
		end,
	}
	return c
end

-- ===== give and fire =====

-- A pickup ("?" box): kart `id` now holds `name` with full ammo. False if it isn't a weapon.
function WeaponServer.give(id: any, name: string): boolean
	if id == nil or not Weapons.isName(name) or not modules[name] then
		return false
	end
	local h = held[id] or Weapons.held()
	held[id] = h
	Weapons.give(h, name)
	show(id)
	return true
end

-- Can a box hand out `name` now (its weapon module is built and loaded)?
function WeaponServer.has(name: string): boolean
	return Weapons.isName(name) and modules[name] ~= nil
end

-- What kart `id` holds now (name "" = nothing), for bots and screens.
function WeaponServer.holding(id: any): (string, number)
	local h = held[id]
	if not h then
		return "", 0
	end
	return h.name, h.ammo
end

-- Kart `id` fires what it holds toward `aim` (anything: it is checked). True if a shot went.
function WeaponServer.fire(id: any, aim: any): boolean
	local h = held[id]
	if not h or h.name == "" then
		return false
	end
	local kart = ctx and ctx.getKart(id)
	if not kart or not kart.alive then
		return false
	end
	local before = { name = h.name, ammo = h.ammo, readyAt = h.readyAt }
	local name = Weapons.take(h, ctx.now())
	if not name then
		return false
	end
	local dir = Weapons.aim(aim, kart.cframe.LookVector)
	local ok, shot = pcall(modules[name].fire, kart, dir, ctx)
	if not ok then
		warn("[WeaponServer] " .. name .. " fire failed: " .. tostring(shot))
	end
	if not ok or shot ~= true then
		-- nothing went out (too many in the air, or it broke): the shot isn't spent
		h.name, h.ammo, h.readyAt = before.name, before.ammo, before.readyAt
		return false
	end
	show(id)
	return true
end

-- A kart is smashed or left: it drops what it held.
function WeaponServer.drop(id: any)
	held[id] = nil
	frozenToken[id] = nil
	show(id)
end

-- Match over: everyone's hands empty, every weapon tidies up (rockets in the air, mines).
function WeaponServer.reset()
	for id in held do
		held[id] = nil
		show(id)
	end
	table.clear(frozenToken)
	for _, m in modules do
		if m.clear then
			pcall(m.clear, ctx)
		end
	end
end

local function remoteNamed(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local made = Instance.new("RemoteEvent")
	made.Name = name
	made.Parent = ReplicatedStorage
	return made
end

local started = false
-- opts (tests only): { match = a stand-in for MatchRunner }
function WeaponServer.start(opts: { match: any? }?)
	if started then
		return
	end
	started = true
	stand = opts and opts.match
	local folder = script.Parent:FindFirstChild("weapons")
	if folder then
		for _, name in Weapons.NAMES do
			local m = folder:FindFirstChild(name)
			if m and m:IsA("ModuleScript") then
				local ok, mod = pcall(require, m)
				if ok and type(mod) == "table" and type(mod.fire) == "function" then
					modules[name] = mod :: any
				else
					warn("[WeaponServer] weapon " .. name .. " did not load: " .. tostring(mod))
				end
			end
		end
	end
	ctx = makeCtx(remoteNamed(Weapons.FX_REMOTE))
	local fire = remoteNamed(Weapons.REMOTE)
	-- one ask: (aim: Vector3?). Anything else in the call is ignored; bursts are dropped.
	fire.OnServerEvent:Connect(function(player: Player, aim: unknown)
		if player.Parent == nil then
			return -- (an ask that arrived after the player left)
		end
		local now = os.clock()
		local b = buckets[player]
		if not b then
			b = Weapons.bucket(now)
			buckets[player] = b
		end
		if not Weapons.allow(b, now) then
			return
		end
		WeaponServer.fire(kartIdOf(player), aim)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		buckets[player] = nil
		held[player.UserId] = nil
		local ok, id = pcall(kartIdOf, player)
		if ok and id ~= nil then
			held[id] = nil
			frozenToken[id] = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		cacheKarts, cacheModels = nil, nil
		for name, m in modules do
			if m.step then
				local ok, err = pcall(m.step, ctx, dt)
				if not ok then
					warn("[WeaponServer] " .. name .. " step failed: " .. tostring(err))
				end
			end
		end
	end)
end

return WeaponServer
