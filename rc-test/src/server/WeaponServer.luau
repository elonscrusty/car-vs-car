--!strict
-- Car VS Car SMASH weapons on the server (plans/smash, WEAPONS row). Holds what each kart has
-- (shared/Weapons: ammo, cooldown), runs the one fire remote (rate-limited, junk-proof), and hands
-- each shot to its weapon module in server/weapons/<Name>.luau ({ ammo, cooldown, fire(kart, aim,
-- ctx) -> boolean, step(ctx)?, clear(ctx)? }). Players fire through the remote, bots call fire()
-- directly. The match (server/MatchRunner) owns the karts and their health: damage goes through
-- MatchRunner.damage. Clients only draw: the WeaponFx remote says what to show.
-- Player attributes for screens: Weapon ("" = none) and Ammo; the special move (FIRE SWARM, run
-- from its own SpecialFire remote) adds SpecialName ("" = none) and SpecialReadyAt (server time).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))
local FireSwarm = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FireSwarm"))
local Specials = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Specials"))

local WeaponServer = {}
WeaponServer.LOCK_TAG = "LockedOn"

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean }
export type Hit = { kartId: any?, position: Vector3 }
-- what a weapon module may use (the same table for every weapon)
export type Ctx = {
	now: () -> number,
	karts: () -> { Kart },
	getKart: (id: any) -> Kart?,
	raycast: (from: Vector3, to: Vector3, ignoreId: any?, worldOnly: boolean?) -> Hit?,
	-- returns the health it really took (0 = none: another place, a shield); clients show it
	damage: (victimId: any, attackerId: any, amount: number, weapon: string) -> number,
	fx: (kind: string, data: { [string]: any }) -> (),
	after: (seconds: number, fn: () -> ()) -> (),
	place: ((kind: string, at: Vector3) -> Instance?)?,
	-- FREEZE: seconds > 0 stops kart `id` (it frees itself after that); 0 lets it go now
	freeze: ((id: any, seconds: number) -> ())?,
	-- SHOCKWAVE: shoves kart `id`: v = a flat velocity to add (studs/s), up = a hop (studs/s)
	push: ((id: any, v: Vector3, up: number) -> ())?,
	-- LOCK-ON: a rocket chases kart `id` (true) or let go of it (false); the kart's model carries
	-- the "LockedOn" tag while any rocket chases it (client/LockOn draws the red brackets)
	mark: ((id: any, on: boolean) -> ())?,
}
export type Module = {
	fire: (kart: Kart, aim: Vector3, ctx: Ctx) -> boolean,
	step: ((ctx: Ctx, dt: number) -> ())?,
	clear: ((ctx: Ctx) -> ())?,
}

local held: { [any]: Weapons.Held } = {}
local buckets: { [Player]: Weapons.Bucket } = {}
local modules: { [string]: Module } = {}
-- the special move: modules by name, and each kart's own (name + the server time it is ready)
local specials: { [string]: Module } = {}
local specialOf: { [any]: { name: string, readyAt: number } } = {}
local specialBuckets: { [Player]: Weapons.Bucket } = {}
local frozenToken: { [any]: number } = {}
local emptyAt: { [any]: number } = {} -- when a kart's starter clip ran out (Weapons.STARTER_RELOAD)
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
	-- (Lune tests: a plain table with a Position and LookVector stands in for a CFrame)
	if type(k.cframe) == "table" and type(k.cframe.Position) == "vector" then
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
	if type(k.pos) == "vector" then -- (a Vector3; "vector" so plain tests can use it too)
		return CFrame.new(k.pos)
	end
	return nil
end

-- other places with karts that can shoot and be hit, outside a match (the lobby's warm-up yard):
-- name -> { karts() -> { {id, cframe|pos|model, alive?} }, damage(victim, attacker, amount,
-- weapon), model(id) -> Instance?, playerOf((id) -> Player?)?, freeze((id, s))? }
local sources: { [string]: any } = {}

-- The weapons do their maths on vectors. A Roblox Vector3 is one, so a real pose goes as is; the
-- pretend server's (tests/fakeroblox) isn't, so there the pose becomes a plain table of vectors.
local function plain(cf: CFrame): CFrame
	if type(cf.Position) == "vector" then
		return cf
	end
	return {
		Position = Weapons.vec(cf.Position),
		LookVector = Weapons.vec(cf.LookVector),
		RightVector = Weapons.vec(cf.RightVector),
		UpVector = Weapons.vec(cf.UpVector),
	} :: any
end

-- karts and their models are read once per server frame (rockets ask many times a frame)
local cacheKarts: { Kart }? = nil
local cacheModels: { [any]: Instance }? = nil
local cacheOwner: { [any]: any } = {} -- kart id -> the source it came from (none = the match)
local cacheMatch: { [any]: boolean } = {} -- ids of the match's own karts this frame

local function readSources(out: { Kart })
	table.clear(cacheOwner)
	table.clear(cacheMatch)
	for _, k in out do
		cacheMatch[k.id] = true
	end
	for name, src in sources do
		local ok, list = pcall(src.karts)
		if not ok or type(list) ~= "table" then
			warn("[WeaponServer] source " .. name .. " karts failed: " .. tostring(list))
			continue
		end
		for _, k in list do
			-- (an id the match already has stays the match's: a player in both counts as playing)
			if
				type(k) == "table"
				and k.id ~= nil
				and cacheOwner[k.id] == nil
				and not cacheMatch[k.id]
			then
				local cf = pose(k)
				if cf then
					cacheOwner[k.id] = src
					table.insert(out, {
						id = k.id,
						cframe = plain(cf),
						alive = k.alive ~= false,
						shield = k.shield == true,
					})
				end
			end
		end
	end
end

local function readKarts(): { Kart }
	if stand then
		local out = table.clone(stand.karts())
		readSources(out)
		return out
	end
	local mr = matchRunner()
	local out = {}
	if not mr or type(mr.karts) ~= "function" then
		readSources(out)
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
				table.insert(
					out,
					{ id = id, cframe = plain(cf), alive = alive, shield = k.shield == true }
				)
			end
		end
	end
	readSources(out)
	return out
end

local function allKarts(): { Kart }
	if not cacheKarts then
		cacheKarts = readKarts()
	end
	return cacheKarts :: { Kart }
end

-- the source kart `id` came from (nil = the match)
local function ownerOf(id: any): any?
	allKarts()
	return cacheOwner[id]
end

local function readModel(id: any): Instance?
	local src = ownerOf(id)
	if src then
		local ok, m = false, nil
		if type(src.model) == "function" then
			ok, m = pcall(src.model, id)
		end
		return if ok and typeof(m) == "Instance" then m else nil
	end
	if stand and type(stand.model) == "function" then
		return stand.model(id)
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
		local id = mr.kartOf(player)
		if id ~= nil then
			return id
		end
	end
	-- not in a match: their UserId (a warm-up yard source lists them by it)
	return player.UserId
end

local function playerOf(id: any): Player?
	local src = ownerOf(id)
	if src and type(src.playerOf) == "function" then
		local ok, p = pcall(src.playerOf, id)
		return if ok and typeof(p) == "Instance" and p:IsA("Player") then p else nil
	end
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
	local name, ammo = if h then h.name else "", if h then h.ammo else 0
	if p then
		p:SetAttribute("Weapon", name)
		p:SetAttribute("Ammo", ammo)
	end
	-- on the kart too, so everyone (bots included) sees what it holds: client/KartWeaponIcon
	local m = readModel(id)
	if m then
		m:SetAttribute("Weapon", name)
		m:SetAttribute("Ammo", ammo)
	end
end

local function showSpecial(id: any)
	local p = playerOf(id)
	local s = specialOf[id]
	if p then
		p:SetAttribute("SpecialName", if s then s.name else "")
		p:SetAttribute("SpecialReadyAt", if s then s.readyAt else 0)
	end
end

-- ===== the context every weapon gets =====

-- how many rockets chase each kart right now (LOCK-ON tag)
local chasers: { [any]: number } = {}

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
		-- Hurts only karts in the same place as the shooter: yard shots never reach the match, a
		-- match shot never pops a yard dummy, and a shot landing after its target left hurts nothing.
		damage = function(victimId: any, attackerId: any, amount: number, weapon: string): number
			local src = ownerOf(victimId)
			if src ~= ownerOf(attackerId) then
				return 0
			end
			if src then
				if type(src.damage) == "function" then
					local ok, taken =
						pcall(src.damage, victimId, attackerId, amount, Weapons.feedWord(weapon))
					if not ok then
						warn("[WeaponServer] source damage failed: " .. tostring(taken))
						return 0
					end
					return if type(taken) == "number" then taken else amount
				end
				return 0
			end
			if not cacheMatch[victimId] then
				return 0
			end
			local mr = matchRunner()
			if mr and type(mr.damage) == "function" then
				-- MatchRunner's words are lowercase and one of a kind: "rocket", "nuke", "gun"
				-- (pcall: one bad hit mustn't stop a boom hurting the rest, or its fx)
				local ok, taken =
					pcall(mr.damage, victimId, attackerId, amount, Weapons.feedWord(weapon))
				if not ok then
					warn("[WeaponServer] match damage failed: " .. tostring(taken))
					return 0
				end
				return if type(taken) == "number" then taken else amount
			end
			return 0
		end,
		fx = function(kind: string, data: { [string]: any })
			fxRemote:FireAllClients(kind, data)
			-- (guns, rockets and mines break the arena's crates)
			local mr = matchRunner()
			if mr and type(mr.crateFx) == "function" then
				pcall(mr.crateFx, kind, data)
			end
			-- (guns, rockets and mines light the arena's dynamite kegs)
			if mr and type(mr.weaponFx) == "function" then
				pcall(mr.weaponFx, kind, data)
			end
		end,
		after = function(seconds: number, fn: () -> ())
			task.delay(seconds, fn)
		end,
		place = nil,
		-- A player's car is driven by their own client (its owner moves it), so that client is told
		-- ("Knock") and shoves its own car; a bot is moved by MatchRunner.knock (ArenaBots).
		push = function(id: any, v: Vector3, up: number)
			local p = playerOf(id)
			if p then
				fxRemote:FireClient(p, "Knock", { v = v, up = up })
				return
			end
			local mr = matchRunner()
			if mr and type(mr.knock) == "function" then
				pcall(mr.knock, id, v, up)
			end
		end,
		mark = function(id: any, on: boolean)
			local n = math.max(0, (chasers[id] or 0) + (if on then 1 else -1))
			chasers[id] = if n > 0 then n else nil
			local m = kartModel(id)
			if m then
				if n > 0 then
					CollectionService:AddTag(m, WeaponServer.LOCK_TAG)
				else
					CollectionService:RemoveTag(m, WeaponServer.LOCK_TAG)
				end
			end
		end,
		freeze = function(id: any, seconds: number)
			local src = ownerOf(id)
			if src and type(src.freeze) == "function" then
				pcall(src.freeze, id, seconds)
				return
			end
			local mr = matchRunner()
			if not src and mr and type(mr.freeze) == "function" then
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
	-- a smashed kart waiting to respawn can't take one: it couldn't fire it, and the HUD would
	-- show a weapon its hand can't use (Studio 10-29: a Nuke given then did nothing on FIRE)
	local kart = ctx and ctx.getKart(id)
	if kart and not kart.alive then
		return false
	end
	local h = held[id] or Weapons.held()
	held[id] = h
	Weapons.give(h, name)
	show(id)
	return true
end

-- The starter (MatchRunner's tick, every live kart in a round): a kart with empty hands gets
-- Weapons.STARTER, at once the first time (and after a respawn), else STARTER_RELOAD s after it
-- ran out. A kart holding something else keeps it. True when a clip was given.
function WeaponServer.starter(id: any, now: number): boolean
	local h = held[id]
	if h and h.name ~= "" then
		emptyAt[id] = nil
		return false
	end
	if h then
		local since = emptyAt[id]
		if not since then
			emptyAt[id] = now
			return false
		end
		if now - since < Weapons.STARTER_RELOAD then
			return false
		end
	end
	emptyAt[id] = nil
	return WeaponServer.give(id, Weapons.STARTER)
end

-- Another place with karts that shoot and get hit outside a match (the warm-up yard). Its karts
-- join the match's for aiming, hits and booms; damage to them goes to src.damage. Same name
-- again replaces it.
function WeaponServer.addSource(name: string, src: { [string]: any })
	assert(type(name) == "string" and type(src) == "table" and type(src.karts) == "function")
	sources[name] = src
	cacheKarts, cacheModels = nil, nil
end

function WeaponServer.removeSource(name: string)
	sources[name] = nil
	cacheKarts, cacheModels = nil, nil
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

-- (the name bots use)
WeaponServer.held = WeaponServer.holding

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

-- The special move of kart `id` (nil = none): it starts empty and is ready FIRST_WAIT seconds
-- later. Any kart may call it again to change the special; a smashed kart gets it back (empty)
-- on its next respawn.
function WeaponServer.setSpecial(id: any, name: string?)
	if id == nil then
		return
	end
	if name ~= nil and specials[name] ~= nil and ctx then
		specialOf[id] = { name = name, readyAt = ctx.now() + FireSwarm.FIRST_WAIT }
	else
		specialOf[id] = nil
	end
	showSpecial(id)
end

-- A charge box (or anything else): add `fraction` (0 to 1) of a full refill to kart `id`'s special.
function WeaponServer.chargeSpecial(id: any, fraction: number)
	local s = specialOf[id]
	if not s or not ctx then
		return
	end
	s.readyAt = FireSwarm.charged(s.readyAt, ctx.now(), fraction)
	showSpecial(id)
end

-- Is kart `id`'s special ready? (name, or nil when it has none or is still charging)
function WeaponServer.specialReady(id: any): string?
	local s = specialOf[id]
	if s and ctx and ctx.now() >= s.readyAt then
		return s.name
	end
	return nil
end

-- Kart `id` uses its special toward `aim` (anything: it is checked). True if it went off.
function WeaponServer.special(id: any, aim: any): boolean
	local name = WeaponServer.specialReady(id)
	local kart = ctx and ctx.getKart(id)
	if not name or not kart or not kart.alive then
		return false
	end
	local dir = Weapons.aim(aim, kart.cframe.LookVector)
	local ok, shot = pcall(specials[name].fire, kart, dir, ctx)
	if not ok then
		warn("[WeaponServer] special " .. name .. " failed: " .. tostring(shot))
	end
	if not ok or shot ~= true then
		return false
	end
	local s = specialOf[id]
	if s then
		s.readyAt = ctx.now() + FireSwarm.REFILL
	end
	showSpecial(id)
	return true
end

-- A kart is smashed or left: it drops what it held.
function WeaponServer.drop(id: any)
	if specialOf[id] then
		specialOf[id] = nil
		showSpecial(id)
	end
	held[id] = nil
	frozenToken[id] = nil
	emptyAt[id] = nil
	show(id)
end

-- Match over: everyone's hands empty, every weapon tidies up (rockets in the air, mines).
function WeaponServer.reset()
	for id in held do
		held[id] = nil
		show(id)
	end
	table.clear(frozenToken)
	table.clear(emptyAt)
	for id in specialOf do
		specialOf[id] = nil
		showSpecial(id)
	end
	for _, m in modules do
		if m.clear then
			pcall(m.clear, ctx)
		end
	end
	for _, m in specials do
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
local grantAt = 0
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
	if folder then
		for name in Specials.LOOKS do
			local m = folder:FindFirstChild(name)
			if m and m:IsA("ModuleScript") then
				local ok, mod = pcall(require, m)
				if ok and type(mod) == "table" and type(mod.fire) == "function" then
					specials[name] = mod :: any
				else
					warn("[WeaponServer] special " .. name .. " did not load: " .. tostring(mod))
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
	-- the special's own remote: one ask (aim: Vector3?), its own rate limit; the kart's own
	-- charge timer is the real gate
	remoteNamed(FireSwarm.REMOTE).OnServerEvent:Connect(function(player: Player, aim: unknown)
		if player.Parent == nil then
			return
		end
		local now = os.clock()
		local b = specialBuckets[player]
		if not b then
			b = Weapons.bucket(now)
			specialBuckets[player] = b
		end
		if not Weapons.allow(b, now) then
			return
		end
		WeaponServer.special(kartIdOf(player), aim)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		specialBuckets[player] = nil
		buckets[player] = nil
		held[player.UserId] = nil
		specialOf[player.UserId] = nil
		local ok, id = pcall(kartIdOf, player)
		if ok and id ~= nil then
			held[id] = nil
			specialOf[id] = nil
			frozenToken[id] = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		cacheKarts, cacheModels = nil, nil
		-- every player's kart in a match gets its car's one special (shared/Specials)
		grantAt -= dt
		if grantAt <= 0 then
			grantAt = 1
			for _, k in allKarts() do
				local p = if k.alive and specialOf[k.id] == nil then playerOf(k.id) else nil
				if p ~= nil then
					local name = Specials.forCar(p:GetAttribute("RacerCar"))
					if specials[name] == nil then
						name = Specials.DEFAULT
					end
					if specials[name] ~= nil then
						WeaponServer.setSpecial(k.id, name)
					end
				end
			end
		end
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
