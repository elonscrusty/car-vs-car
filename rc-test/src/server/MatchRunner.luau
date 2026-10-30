--!strict
-- The Smash round (FINISH-JOBS "GO 22:13", plans/smash/VIDEO-STUDY.md): players queue (the SMASH!
-- pad calls MatchRunner.join), a round starts with up to Match.MAX karts (bots fill the rest), runs
-- 3:00 in the arena, then ROUND OVER: places, coins, the end screen (MatchResult) and a 12 s break
-- before the next round, back to back. Nobody joins a round that's going (carter 22:12).
-- The server decides every hit: weapons (WeaponServer) and bumps call MatchRunner.damage; a smashed
-- kart is frozen and back in 3 s at the free spawn farthest from enemies, with a 2 s bubble.
-- The rules are Match's (plain maths, Lune-tested). Driving is not touched: the karts are the
-- players' own RC cars, put on a spawn by the same "drive" message the races used.
--
-- Contract (tell WEAPONS, BOTS, BOXES, GUNMINE, SCREENS, WINDOWS, JUICE, LOBBY if it changes):
--   MatchRunner.join(player) -> boolean, .leave(player), .damage(victimId, attackerId, amount,
--   weapon) -> (taken, smashed), .isAlive(id), .karts(), .addBot(name?, skill?) -> id?
--   Kart ids: a player's UserId; bots are negative. Kart models are workspace Car_<id>.
--   Player attributes: Health, MaxHealth, Smashes, Place, MatchEndsAt (server time), Shield,
--   InMatch, MatchQueued, RespawnAt, SmashedBy (kart id), SmashedByName, SmashedWeapon.
--   workspace attributes: MatchEndsAt, NextMatchAt (server time; nil = none planned), MatchRound.
--   RemoteEvents: SmashFeed (all: attacker, victim, weapon; each side { name, userId?, kart? }),
--   MatchResult (each player: places, coins, nextAt, xp), LeaveMatch (client: off the queue).
--   ReplicatedStorage.MatchBoard: one Configuration per kart (Name, Smashes, Level, UserId, Health).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaBrain = require(ReplicatedStorage.Shared.ArenaBrain)
local ArenaData = require(ReplicatedStorage.Shared.ArenaData)
local Barrels = require(ReplicatedStorage.Shared.Barrels)
local Crane = require(ReplicatedStorage.Shared.Crane)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local Match = require(ReplicatedStorage.Shared.Match)
local Profile = require(ReplicatedStorage.Shared.Profile)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local League = require(ReplicatedStorage.Shared.League)
local TestVeteran = require(ReplicatedStorage.Shared.TestVeteran)
local CarBuilder = require(script.Parent.CarBuilder)
local Jobs = require(script.Parent.Jobs)
local LobbyPlots = require(script.Parent.LobbyPlots)
local PlayerData = require(script.Parent.PlayerData)

local MatchRunner = {}

-- Tests (LOOPTEST) and Studio may shorten these.
MatchRunner.MATCH_SECS = Match.LENGTH
MatchRunner.BREAK_SECS = Match.BREAK
MatchRunner.START_SECS = 5 -- the first player on the pad waits this long for friends
MatchRunner.TICK = 0.1 -- respawns, places and attributes (bumps are checked every frame)
local MAX_SPEED = 40 -- studs/s: faster than any kart (RC top ~24, boost a bit more) = no bump
local TELEPORT = 80 -- studs/s of moving between two frames = a teleport (spawn, put-back)
local BUSY = 4 -- studs: a kart this close to a spawn makes it busy

export type Hooks = {
	remote: RemoteEvent, -- RCControl: ("drive", slot, spot) puts a car on a spawn
	walk: (player: Player) -> (), -- out of the arena, back to walking
}

type Info = {
	id: number,
	player: Player?,
	model: Model?,
	last: Vector3?,
	vel: Vector3,
	board: Configuration?,
	jumpedAt: number?, -- os.clock of its last teleport (boxes don't see it for a moment)
}

local hooks: Hooks? = nil
local phase: "idle" | "playing" | "break" = "idle"
local state: Match.State? = nil
local startAt: number? = nil -- server time of the next round's start
local round = 0
local queue: { Player } = {} -- waiting for the next round, in pad order
local inRound: { [Player]: boolean } = {}
local infos: { [number]: Info } = {}
local botCount = 0
local botNames: { string } = {} -- this round's (Match.botNames)
local newKids: { [number]: boolean } = {} -- players in their first round (new-kid safety)
local rookies: { [number]: boolean } = {} -- players in their first 3 matches (bots go easy)
local botSkill: number? = nil -- this round's (ArenaBrain.skillFor the least-played player)
local ROOKIE_MATCHES = 3 -- (ArenaBrain.ROOKIE.matches)
local stepWarned = 0
local fleet: any = nil
local boxes: any = nil -- BoxServer's handle (the "?" boxes in the arena)
local barrels: any = nil -- BarrelServer's handle (the dynamite kegs in the arena)
local crane: any = nil -- CraneServer's handle (the swinging crane ball in the arena)
local ArenaBots: any = nil
local lastLeave: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function remoteEvent(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = ReplicatedStorage
	return e
end

local smashFeed = remoteEvent("SmashFeed")
local matchResult = remoteEvent("MatchResult")
local leaveMatch = remoteEvent("LeaveMatch")

local board = ReplicatedStorage:FindFirstChild("MatchBoard")
if not (board and board:IsA("Folder")) then
	board = Instance.new("Folder")
	board.Name = "MatchBoard"
	board.Parent = ReplicatedStorage
end
local matchBoard = board :: Folder

-- WeaponServer (WEAPONS'), read when it's needed: it reads MatchRunner too.
local function weapons(): any?
	local mod = script.Parent:FindFirstChild("WeaponServer")
	return if mod and mod:IsA("ModuleScript") then require(mod) :: any else nil
end

local function dropWeapon(id: number)
	local W = weapons()
	if W and W.drop then
		pcall(W.drop, id)
	end
end

local function log(msg: string)
	print("[Match] " .. msg)
end

-- The arena as a track (ArenaData through LobbyLayout), nil before it's built.
local function arena(): (number?, TrackData.Track?)
	local idx = LobbyLayout.arenaIndex()
	if not idx then
		return nil, nil
	end
	return idx, LobbyLayout.track(idx)
end

local function spawnsOf(): { any }
	local data = LobbyLayout.mapAt(LobbyLayout.arenaIndex() or 0)
	return if data and type(data.spawns) == "table" then data.spawns else {}
end

local function spawnWorld(t: TrackData.Track, s: any): CFrame
	local x, y, z = TrackData.toWorld(t, true, s.x, s.y, s.z)
	local dx, dz = TrackData.dirToWorld(t, true, s.dx, s.dz)
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
end

local function bodyOf(info: Info): BasePart?
	local model = info.model
	if info.player then
		local m = workspace:FindFirstChild("Car_" .. info.id)
		model = if m and m:IsA("Model") then m else nil
		info.model = model
	end
	local body = model and model.PrimaryPart
	return if body and body.Parent then body else nil
end

local function setAttr(info: Info, name: string, value: any)
	local p = info.player
	if p and p:GetAttribute(name) ~= value then
		p:SetAttribute(name, value)
	end
	local b = info.board
	if b and (name == "Health" or name == "Smashes") and b:GetAttribute(name) ~= value then
		b:SetAttribute(name, value)
	end
end

local function feedSide(id: number?): any
	if id == nil then
		return nil
	end
	local k = state and state.karts[id]
	local info = infos[id]
	return {
		name = if k then k.name else "?",
		userId = if id > 0 then id else nil,
		kart = info and info.model,
	}
end

local function clearPlayer(p: Player)
	for _, a in
		{
			"Health",
			"MaxHealth",
			"Smashes",
			"Place",
			"MatchEndsAt",
			"Shield",
			"InMatch",
			"RespawnAt",
			"SmashedBy",
			"SmashedByName",
			"SmashedWeapon",
		}
	do
		p:SetAttribute(a, nil)
	end
end

local function setNext(at: number?)
	startAt = at
	workspace:SetAttribute("NextMatchAt", at)
end

-- Freeze a smashed kart where it is (its owner can't drive it) or let it go again.
local function freeze(info: Info, on: boolean)
	local body = bodyOf(info)
	if not body then
		return
	end
	body.Anchored = on or info.player == nil -- (bots are always anchored: ArenaBots moves them)
	if not on and info.player then
		pcall(function()
			body:SetNetworkOwner(info.player)
		end)
	end
	if info.model then
		info.model:SetAttribute("Smashed", if on then true else nil)
	end
end

-- Put a kart on spawn `i`: a player's car through its own "drive" (the client teleports it and
-- drives at once), a bot by moving its model.
local function place(info: Info, i: number)
	local idx, t = arena()
	local spawns = spawnsOf()
	local s = spawns[i]
	if not (idx and t and s) then
		return
	end
	local cf = spawnWorld(t, s)
	local p = info.player
	if p then
		local h = hooks :: Hooks
		task.spawn(function()
			-- (StreamingEnabled: the spot must be there before the car lands on it)
			pcall(function()
				p:RequestStreamAroundAsync(cf.Position, 3)
			end)
			if p.Parent and inRound[p] and infos[info.id] == info then
				-- (let go and the bubble from here: the car is on the spawn now, Studio wait or not)
				freeze(info, false)
				local k = state and state.karts[info.id]
				if k and k.alive then
					k.shieldUntil = math.max(k.shieldUntil, now() + Match.SHIELD)
				end
				h.remote:FireClient(
					p,
					"drive",
					idx,
					{ x = s.x, y = s.y, z = s.z, dx = s.dx, dz = s.dz }
				)
			end
		end)
	elseif info.model then
		info.model:PivotTo(cf)
		info.last = cf.Position
		if fleet and ArenaBots then
			local k = state and state.karts[info.id]
			pcall(
				ArenaBots.add,
				fleet,
				info.id,
				cf,
				{ skill = botSkill, easy = next(rookies) ~= nil }
			)
			if k then
				k.shieldUntil = math.max(k.shieldUntil, now() + Match.SHIELD)
			end
		end
	end
end

-- The free spawn farthest from enemies (Match.pickSpawn) for kart `id`.
local function spawnFor(id: number): number
	local _, t = arena()
	local spawns = spawnsOf()
	if not t or #spawns == 0 then
		return 1
	end
	local points, enemies, busy = {}, {}, {}
	for i, s in spawns do
		local cf = spawnWorld(t, s)
		points[i] = { x = cf.Position.X, z = cf.Position.Z }
	end
	for oid, info in infos do
		local body = bodyOf(info)
		local k = state and state.karts[oid]
		if oid == id or not body or not k then
			continue
		end
		local pos = body.Position
		if k.alive then
			table.insert(enemies, { x = pos.X, z = pos.Z })
		end
		for i, pt in points do
			if (pt.x - pos.X) ^ 2 + (pt.z - pos.Z) ^ 2 < BUSY * BUSY then
				busy[i] = true
			end
		end
	end
	return Match.pickSpawn(points, enemies, busy)
end

local function addBoard(info: Info, name: string)
	local c = Instance.new("Configuration")
	c.Name = tostring(info.id)
	c:SetAttribute("Name", name)
	c:SetAttribute("Smashes", 0)
	c:SetAttribute("Health", Match.HEALTH)
	c:SetAttribute("UserId", if info.id > 0 then info.id else 0)
	local p = info.player
	local lv = p and p:GetAttribute("Level")
	c:SetAttribute("Level", if type(lv) == "number" then lv else nil)
	c.Parent = matchBoard
	info.board = c
end

local function dropKart(id: number)
	dropWeapon(id)
	local info = infos[id]
	infos[id] = nil
	if state then
		Match.remove(state, id)
	end
	if not info then
		return
	end
	if info.board then
		info.board:Destroy()
	end
	if not info.player then
		if fleet and ArenaBots then
			pcall(ArenaBots.remove, fleet, id)
		end
		if info.model then
			info.model:Destroy()
		end
	end
	matchBoard:SetAttribute("MatchKarts", #(if state then state.list else {}))
end

-- A bot kart in this round: a little RC car the server moves (ArenaBots drives and shoots), on
-- every screen like another player's car (client OtherCars draws Car_<negative> models).
function MatchRunner.addBot(name: string?, skill: number?): number?
	local m = state
	if not m or phase ~= "playing" or #m.list >= Match.MAX then
		return nil
	end
	botCount += 1
	local id = -botCount
	local nm = name or table.remove(botNames, 1) or `Bot {botCount}`
	if not Match.add(m, id, nm, false, now()) then
		return nil
	end
	local _, t = arena()
	local spawns = spawnsOf()
	local s = spawns[(#m.list - 1) % math.max(#spawns, 1) + 1]
	local cf = if t and s then spawnWorld(t, s) else CFrame.new(0, 3, 0)
	local model = CarBuilder.build(`Car_{id}`, cf, TrackData.RC_SCALE)
	model:SetAttribute("BotName", nm)
	model:SetAttribute("KartName", nm)
	model:SetAttribute("KartId", id)
	local looks = CarCatalog.raceIds()
	local look = if #looks > 0 then looks[botCount % #looks + 1] else nil
	local car = CarCatalog.get(look)
	local body = model.PrimaryPart :: BasePart
	if car then
		model:SetAttribute("ToyCar", look)
		body.Color = Color3.fromRGB(car.color[1], car.color[2], car.color[3])
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	CollectionService:AddTag(model, "Kart")
	model.Parent = workspace
	local info: Info =
		{ id = id, player = nil, model = model, last = cf.Position, vel = Vector3.zero }
	infos[id] = info
	addBoard(info, nm)
	if fleet and ArenaBots then
		pcall(
			ArenaBots.add,
			fleet,
			id,
			cf,
			{ skill = skill or botSkill, easy = next(rookies) ~= nil }
		)
	end
	matchBoard:SetAttribute("MatchKarts", #m.list)
	return id
end

-- Hurt kart `victimId` (WeaponServer, bumps). Returns the health taken and whether it smashed.
-- The server only: never call this with a number a client sent.
function MatchRunner.damage(
	victimId: number,
	attackerId: number?,
	amount: number,
	weapon: string?
): (number, boolean)
	local m = state
	if not m or phase ~= "playing" or type(victimId) ~= "number" then
		return 0, false
	end
	local t = now()
	-- new-kid safety: no bot hurts a player in their first round's first 15 s (a stray bullet
	-- that locked on, a bump), not just the bots looking away; nor a rookie in a round's calm
	-- start (ArenaBrain.ROOKIE.calm: a nuke's splash at the kart next to them, say)
	if
		attackerId
		and attackerId < 0
		and (
			(newKids[victimId] and t - m.startAt < Match.NEW_KID_SAFE)
			or (rookies[victimId] and t - m.startAt < ArenaBrain.ROOKIE.calm)
		)
	then
		return 0, false
	end
	local took, smashed = Match.damage(m, victimId, attackerId, amount, t, weapon)
	if took <= 0 then
		return 0, false
	end
	local k = m.karts[victimId]
	local info = infos[victimId]
	if info then
		setAttr(info, "Health", k.health)
	end
	if smashed then
		local by = if attackerId then m.karts[attackerId] else nil
		local w = string.lower(weapon or "bump")
		if info then
			setAttr(info, "RespawnAt", k.respawnAt)
			setAttr(info, "SmashedBy", k.lastBy)
			setAttr(info, "SmashedByName", by and by.name)
			setAttr(info, "SmashedWeapon", w)
			freeze(info, true)
			dropWeapon(victimId)
			if not info.player and fleet and ArenaBots then
				pcall(ArenaBots.remove, fleet, victimId)
			end
		end
		local byInfo = if attackerId then infos[attackerId] else nil
		if by and byInfo then
			-- (Place first: the HUD redraws on Smashes and must not see a 0 Place with 1 smash)
			setAttr(byInfo, "Place", Match.shownPlace(by, Match.rank(m, by.id)))
			setAttr(byInfo, "Smashes", by.smashes)
			if byInfo.player then
				Jobs.fire(byInfo.player, "smash", 1)
			end
		end
		smashFeed:FireAllClients(feedSide(k.lastBy), feedSide(victimId), w)
		log(`{k.name} smashed by {if by then by.name else "the arena"} ({w})`)
	end
	return took, smashed
end

function MatchRunner.isAlive(id: number): boolean
	local m = state
	local k = m and m.karts[id]
	return k ~= nil and k.alive and phase == "playing"
end

export type KartView = {
	id: number,
	name: string,
	pos: Vector3?,
	cframe: CFrame?,
	alive: boolean,
	shield: boolean,
	human: boolean,
	model: Model?,
	hitBy: number?, -- who hurt it last, and when (Match.damage)
	hitAt: number?,
	smashes: number,
	deaths: number,
}

-- Every kart in the round (BOTS, WEAPONS and BOXES read this).
function MatchRunner.karts(): { KartView }
	local out: { KartView } = {}
	local m = state
	if not m or phase ~= "playing" then
		return out
	end
	local t = now()
	for _, k in m.list do
		local info = infos[k.id]
		local body = info and bodyOf(info)
		table.insert(out, {
			id = k.id,
			name = k.name,
			pos = body and body.Position,
			cframe = body and body.CFrame,
			alive = k.alive,
			shield = Match.shielded(k, t),
			human = k.human,
			model = info and info.model,
			hitBy = k.hitBy,
			hitAt = k.hitAt,
			smashes = k.smashes,
			deaths = k.deaths,
		})
	end
	return out
end

-- A player's kart id, and the player who drives kart `id` (nil for a bot).
function MatchRunner.kartOf(player: Player): number
	return player.UserId
end

function MatchRunner.playerOf(id: number): Player?
	local info = infos[id]
	return info and info.player
end

-- FREEZE (GUNMINE): kart `id` can't move for `seconds` (0 = let go now). A smashed kart stays as
-- it is (its respawn lets it go).
function MatchRunner.freeze(id: number, seconds: number)
	local info = infos[id]
	local m = state
	local k = m and m.karts[id]
	if not (info and k and k.alive) or type(seconds) ~= "number" or seconds ~= seconds then
		return
	end
	if seconds <= 0 then
		freeze(info, false)
		return
	end
	freeze(info, true)
	local mine = (info.model and (info.model:GetAttribute("FrozenN") or 0) or 0) + 1
	if info.model then
		info.model:SetAttribute("FrozenN", mine)
	end
	task.delay(math.min(seconds, 10), function()
		-- (only the last freeze lets go, and only if it's still that kart, alive)
		if
			infos[id] == info
			and k.alive
			and info.model
			and info.model:GetAttribute("FrozenN") == mine
		then
			freeze(info, false)
		end
	end)
end

-- The SMASH! pad: on the list for the next round (never into one that's going). true = in.
function MatchRunner.join(player: Player): boolean
	if not hooks or not arena() or player.Parent == nil then
		return false
	end
	if table.find(queue, player) or inRound[player] then
		return true
	end
	table.insert(queue, player)
	player:SetAttribute("MatchQueued", true)
	if phase == "idle" and startAt == nil then
		setNext(now() + MatchRunner.START_SECS)
	end
	return true
end

-- Off the queue and out of the round, back to walking (LEAVE, or the player left the game).
function MatchRunner.leave(player: Player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
	end
	player:SetAttribute("MatchQueued", nil)
	if inRound[player] then
		inRound[player] = nil
		-- a smashed car is let go first (walked off in its 3 s: it stayed frozen for good)
		local info = infos[player.UserId]
			or { id = player.UserId, player = player, vel = Vector3.zero }
		if player.Parent then
			freeze(info, false)
		end
		dropKart(player.UserId)
		local idx = LobbyLayout.arenaIndex()
		if hooks and player.Parent and idx and LobbyPlots.drivingOf(player) == idx then
			hooks.walk(player)
		end
		clearPlayer(player)
	end
end

local function clearBots()
	if fleet and ArenaBots then
		pcall(ArenaBots.clear, fleet)
	end
	fleet = nil
	botSkill = nil
	for id in infos do
		if id < 0 then
			dropKart(id)
		end
	end
end

-- The arena's "?" boxes (BoxServer, BOXES'): started once, every box up at each round's start.
-- A kart only picks one up where the server sees it, and not just after a teleport.
local function startBoxes()
	local mod = script.Parent:FindFirstChild("BoxServer")
	local data = LobbyLayout.mapAt(LobbyLayout.arenaIndex() or 0)
	local _, t = arena()
	if boxes or not (mod and mod:IsA("ModuleScript") and data and t) then
		return
	end
	local spots: { Vector3 } = {}
	for _, sp in (data.boxSpots or {}) :: { any } do
		local x, y, z = TrackData.toWorld(t, true, sp.x, sp.y, sp.z)
		table.insert(spots, Vector3.new(x, y, z))
	end
	local ws = script.Parent:FindFirstChild("WeaponServer")
	local wr = ReplicatedStorage.Shared:FindFirstChild("Weapons")
	local W: any = if ws and ws:IsA("ModuleScript") then require(ws) else nil
	local WR: any = if wr and wr:IsA("ModuleScript") then require(wr) else nil
	local ok, h = pcall((require(mod) :: any).start, {
		spots = spots,
		karts = function()
			local out = {}
			local clock = os.clock()
			for _, k in MatchRunner.karts() do
				local info = infos[k.id]
				local jumped = info and info.jumpedAt
				if k.pos and not (jumped and clock - jumped < 0.5) then
					table.insert(out, { id = k.id, position = k.pos, alive = k.alive })
				end
			end
			return out
		end,
		give = function(id: any, name: string): boolean
			return W ~= nil and W.give ~= nil and W.give(id, name) == true
		end,
		has = function(name: string): boolean
			return WR ~= nil and WR.get ~= nil and WR.get(name) ~= nil
		end,
	})
	if ok then
		boxes = h
	else
		warn("[Match] boxes: " .. tostring(h))
	end
end

-- The arena's dynamite kegs (BarrelServer, shared/Barrels): started once, every keg up at each
-- round's start. The server lights, hurts and shoves; a player's own client is asked to take the
-- shove (BarrelFx "Kick"), a bot is shoved here.
local function startBarrels()
	local mod = script.Parent:FindFirstChild("BarrelServer")
	local _, t = arena()
	if barrels or not (mod and mod:IsA("ModuleScript") and t) then
		return
	end
	local spots: { Vector3 } = {}
	for _, p in Barrels.SPOTS do
		local x, z = ArenaData.at(p :: any)
		local wx, wy, wz = TrackData.toWorld(t, true, x, ArenaData.groundAt(p :: any), z)
		table.insert(spots, Vector3.new(wx, wy, wz))
	end
	local ok, h = pcall((require(mod) :: any).start, {
		spots = spots,
		karts = function()
			local out = {}
			for _, k in MatchRunner.karts() do
				if k.pos then
					table.insert(out, { id = k.id, position = k.pos, alive = k.alive })
				end
			end
			return out
		end,
		damage = function(victimId: any, attackerId: any, amount: number, word: string)
			return MatchRunner.damage(victimId, attackerId, amount, string.lower(word))
		end,
		push = function(id: any, impulse: Vector3)
			local info = infos[id]
			if not info then
				return
			end
			if info.player then
				local hh = barrels
				if hh then
					hh.kick(info.player, impulse)
				end
			else
				local body = bodyOf(info)
				if body and not body.Anchored then
					body.AssemblyLinearVelocity += impulse
				end
			end
		end,
	})
	if ok then
		barrels = h
	else
		warn("[Match] barrels: " .. tostring(h))
	end
end

-- The arena's swinging crane ball (CraneServer, shared/Crane): started once, swing + cooldowns
-- restart at each round's start. The server hurts and shoves; a player's own client is asked to
-- take the shove (CraneFx "Kick"), a bot is shoved here.
local function startCrane()
	local mod = script.Parent:FindFirstChild("CraneServer")
	local _, t = arena()
	if crane or not (mod and mod:IsA("ModuleScript") and t) then
		return
	end
	local p = Crane.SPOT
	local x, z = ArenaData.at(p :: any)
	local wx, wy, wz = TrackData.toWorld(t, true, x, ArenaData.groundAt(p :: any), z)
	local ok, h = pcall((require(mod) :: any).start, {
		foot = Vector3.new(wx, wy, wz),
		karts = function()
			local out = {}
			for _, k in MatchRunner.karts() do
				if k.pos then
					table.insert(out, { id = k.id, position = k.pos, alive = k.alive })
				end
			end
			return out
		end,
		damage = function(victimId: any, attackerId: any, amount: number, word: string)
			return MatchRunner.damage(victimId, attackerId, amount, string.lower(word))
		end,
		push = function(id: any, impulse: Vector3)
			local info = infos[id]
			if not info then
				return
			end
			if info.player then
				local hh = crane
				if hh then
					hh.kick(info.player, impulse)
				end
			else
				local body = bodyOf(info)
				if body and not body.Anchored then
					body.AssemblyLinearVelocity += impulse
				end
			end
		end,
	})
	if ok then
		crane = h
	else
		warn("[Match] crane: " .. tostring(h))
	end
end

-- WeaponServer tells us what its weapons did (GunShot, RocketBoom, MineBoom): they light kegs.
function MatchRunner.weaponFx(kind: string, data: any)
	local h = barrels
	if h and phase == "playing" then
		h.weaponFx(kind, data)
	end
end

local function startRound()
	local h = hooks :: Hooks
	local idx = LobbyLayout.arenaIndex()
	if not idx then
		return
	end
	clearBots()
	-- the queue first (nobody waits for ever), then last round's players who are still in the
	-- arena (rounds roll on by themselves); one who doesn't fit waits at the front of the queue
	local list: { Player } = {}
	while #queue > 0 and #list < Match.MAX do
		local p = table.remove(queue, 1) :: Player
		if p.Parent and not table.find(list, p) then
			table.insert(list, p)
		end
	end
	local stay: { Player } = {}
	for p in inRound do
		if p.Parent and LobbyPlots.drivingOf(p) == idx and not table.find(list, p) then
			table.insert(stay, p)
		elseif p.Parent then
			clearPlayer(p)
		end
	end
	table.sort(stay, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	for _, p in stay do
		if #list < Match.MAX then
			table.insert(list, p)
		else
			-- (out of this round: no match HUD, no kart in the arena while it waits its turn; a
			-- kart smashed in the last round's final seconds is let go, as in leave)
			local info = infos[p.UserId]
			if info then
				freeze(info, false)
			end
			clearPlayer(p)
			dropWeapon(p.UserId)
			h.walk(p)
			table.insert(queue, 1, p)
			p:SetAttribute("MatchQueued", true)
		end
	end
	inRound = {}
	infos = {}
	matchBoard:ClearAllChildren()
	if #list == 0 then
		phase = "idle"
		state = nil
		setNext(nil)
		return
	end
	round += 1
	local t0 = now()
	local m = Match.new(t0, MatchRunner.MATCH_SECS)
	state = m
	phase = "playing"
	setNext(nil)
	workspace:SetAttribute("MatchEndsAt", m.endsAt)
	workspace:SetAttribute("MatchRound", round)
	local spawns = spawnsOf()
	newKids = {}
	rookies = {}
	botNames = Match.botNames(function(n: number): number
		return math.random(1, n)
	end)
	local W = weapons()
	-- (Studio only, workspace TestVeteran: the player counts as a veteran, not a rookie)
	local veteran =
		TestVeteran.wanted(RunService:IsStudio(), workspace:GetAttribute(TestVeteran.ATTR))
	local fewest = math.huge -- (the least-played player's matches: the bots' skill, RAMP)
	for i, p in list do
		-- (a fresh round: nothing held over from the last one or the warm-up yard, LOBBY)
		if W and W.drop then
			pcall(W.drop, p.UserId)
		end
		local data = PlayerData.get(p)
		-- (a faked match count of 1+ has raced before; 0 is a brand-new kid on purpose)
		if data and data.stage < Profile.STAGE.RACED and (veteran == nil or veteran < 1) then
			newKids[p.UserId] = true
		end
		-- (no save loaded yet: count them a rookie, the safe side)
		local played = TestVeteran.matches(if data then data.matches or 0 else nil, veteran)
		if played == nil or played < ROOKIE_MATCHES then
			rookies[p.UserId] = true
		end
		fewest = math.min(fewest, played or 0)
		p:SetAttribute("MatchQueued", nil)
		p:SetAttribute("StandSpot", nil) -- (a race's stand spot: not in the arena)
		Match.add(m, p.UserId, p.DisplayName, true, t0)
		inRound[p] = true
		local info: Info = { id = p.UserId, player = p, vel = Vector3.zero }
		infos[p.UserId] = info
		addBoard(info, p.DisplayName)
		local was = LobbyPlots.drivingOf(p)
		if was ~= nil and was ~= idx then
			h.walk(p)
		end
		LobbyPlots.claim(p, idx)
		p:SetAttribute("InMatch", true)
		p:SetAttribute("Health", Match.HEALTH)
		p:SetAttribute("MaxHealth", Match.HEALTH)
		p:SetAttribute("Smashes", 0)
		p:SetAttribute("Place", 0) -- (no smashes yet: "-")
		p:SetAttribute("MatchEndsAt", m.endsAt)
		p:SetAttribute("Shield", true)
		p:SetAttribute("RespawnAt", nil)
		p:SetAttribute("SmashedBy", nil)
		p:SetAttribute("SmashedByName", nil)
		p:SetAttribute("SmashedWeapon", nil)
		freeze(info, false)
		place(info, (i - 1) % math.max(#spawns, 1) + 1)
	end
	botSkill = if fewest < math.huge then ArenaBrain.skillFor(fewest) else nil
	-- bots fill the round (ArenaBots drives them when it's there)
	local mod = script.Parent:FindFirstChild("ArenaBots")
	ArenaBots = if mod and mod:IsA("ModuleScript") then require(mod) :: any else nil
	if ArenaBots then
		local startAt = t0
		local ok, f = pcall(ArenaBots.new, {
			-- (karts with a place only; a new kid hides from them for a while: Match.forBots)
			karts = function(): any
				return Match.forBots(MatchRunner.karts() :: any, newKids, now(), startAt, rookies)
			end,
			weaponOf = function(id: number): (string?, number)
				local Wn = weapons()
				if Wn and Wn.holding then
					local name, ammo = Wn.holding(id)
					return if name == "" then nil else name, tonumber(ammo) or 0
				end
				return nil, 0
			end,
		}, Random.new())
		fleet = if ok then f else nil
		if not ok then
			warn("arena bots: " .. tostring(f))
		end
	end
	for _ = #list + 1, Match.MAX do
		MatchRunner.addBot()
	end
	matchBoard:SetAttribute("MatchKarts", #m.list)
	startBoxes()
	if boxes then
		pcall(boxes.reset)
	end
	startBarrels()
	if barrels then
		pcall(barrels.reset)
	end
	startCrane()
	if crane then
		pcall(crane.reset)
	end
	log(
		`round {round} start: {#list} players + {#m.list - #list} bots, ends in {MatchRunner.MATCH_SECS} s`
	)
end

local function tell(player: Player, kind: string, value: any)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, kind, value)
	end
end

-- The save's coins (and league, trophies) on the player's attributes: the garage chip and the
-- lobby read those (Studio round 5: the chip said 25 with 75 saved after 3 rounds).
local function showCoins(player: Player, data: Profile.Data)
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("League", data.league)
	player:SetAttribute("Trophies", data.trophies)
end

local function pay(player: Player, coins: number, why: string): number
	local data = PlayerData.get(player)
	if not data or coins <= 0 then
		return 0
	end
	coins *= Profile.boost(os.time()) -- double coins on weekends
	data.coins = math.min(data.coins + coins, Profile.MAX_COINS)
	PlayerData.touch(player)
	showCoins(player, data)
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "coins", data.coins)
		stars:FireClient(player, "toast", `+{coins} coins: {why}`)
	end
	return coins
end

-- A player's first round ever ends with a free crate (FINISH-JOBS G4).
local function firstCrate(player: Player)
	local data = PlayerData.get(player)
	if not data or data.stage >= Profile.STAGE.RACED then
		return
	end
	data.crates += 1
	PlayerData.touch(player)
	PlayerData.raiseStage(player, Profile.STAGE.RACED)
	player:SetAttribute("Crates", data.crates)
	-- the crate count on the screens (they hear it with the Garage "cars" list, like the daily gift)
	local mod = script.Parent:FindFirstChild("GarageServer")
	if mod and mod:IsA("ModuleScript") then
		pcall((require(mod) :: any).refresh, player)
	end
	local stars = ReplicatedStorage:FindFirstChild("StarsEvent")
	if stars and stars:IsA("RemoteEvent") then
		stars:FireClient(player, "toast", "FREE CRATE!")
	end
end

local function endRound()
	local m = state :: Match.State
	m.over = true
	phase = "break"
	local W = weapons()
	if W and W.reset then
		pcall(W.reset) -- held weapons and rockets still in the air
	end
	if fleet and ArenaBots then
		pcall(ArenaBots.clear, fleet)
	end
	local nextAt = now() + MatchRunner.BREAK_SECS
	setNext(nextAt)
	workspace:SetAttribute("MatchEndsAt", nil)
	local places = Match.places(m)
	local rows = {}
	for _, k in places do
		local info = infos[k.id]
		local model = info and info.model
		table.insert(rows, {
			name = k.name,
			smashes = k.smashes,
			-- (the shared place the board and the chip show; 0 = no smashes, "-")
			place = Match.shownPlace(k, Match.rank(m, k.id)),
			userId = if k.human then k.id else nil,
			carId = if info and info.player
				then info.player:GetAttribute("RacerCar")
				elseif model then model:GetAttribute("ToyCar")
				else nil,
		})
		if info then
			setAttr(info, "Place", Match.shownPlace(k, Match.rank(m, k.id)))
		end
	end
	local xpMod = script.Parent:FindFirstChild("XpServer")
	local Xp: any = if xpMod and xpMod:IsA("ModuleScript") then require(xpMod) else nil
	local function payOut(i: number, k: Match.Kart, p: Player)
		-- coins first, saved, then the screen hears (LOOPTEST checks the save holds them)
		local why =
			`{i}{if i == 1 then "st" elseif i == 2 then "nd" elseif i == 3 then "rd" else "th"} place`
		local coins = 0
		local done = (League :: any).matchDone -- (SAVES: league pay, trophies, smash counts)
		local data = PlayerData.get(p)
		if done and data then
			local ok, r = pcall(done, data, i, k.smashes)
			if ok and type(r) == "table" and type(r.coins) == "number" then
				coins = r.coins
				PlayerData.touch(p)
				showCoins(p, data)
				tell(p, "coins", data.coins)
				tell(p, "toast", `+{coins} coins: {why}`)
			else
				warn("League.matchDone: " .. tostring(r))
			end
		else
			coins = pay(p, Match.coinsFor(i, k.smashes), why)
		end
		Jobs.fire(p, "matchDone", 1)
		if i <= 3 then
			Jobs.fire(p, "matchTop3", 1)
		end
		firstCrate(p)
		local xp: number? = nil
		if Xp and Xp.matchDone then
			local ok, got = pcall(Xp.matchDone, p, i, k.smashes)
			xp = if ok and type(got) == "table" and type(got.xp) == "number" then got.xp else nil
		end
		matchResult:FireClient(p, rows, coins, nextAt, xp)
	end
	for _, k in places do
		local p = if k.human then Players:GetPlayerByUserId(k.id) else nil
		if p and p.Parent then
			-- (paid by the shared place: two karts on the same smashes get the same pay)
			local ok, err = pcall(payOut, Match.payPlace(m, k.id), k, p)
			if not ok then
				warn(`[Match] pay {p.Name}: {err}`)
			end
		end
	end
	local winner = places[1]
	log(
		`round {round} over: {if winner then winner.name else "nobody"} wins with {if winner
			then winner.smashes
			else 0}`
	)
end

-- Bumps hurt (carter 22:12): each pair of touching karts, every frame, by each one's speed into
-- the other (Match.ram). Speeds come from where the server sees the karts, not what a client says.
local function bumps(dt: number)
	local m = state
	if not m or phase ~= "playing" or dt <= 0 then
		return
	end
	local t = now()
	local live: { { id: number, pos: Vector3, vel: Vector3 } } = {}
	for id, info in infos do
		local body = bodyOf(info)
		if not body then
			continue
		end
		local pos = body.Position
		local last = info.last
		info.last = pos
		-- a player's car: the speed its owner's physics has (a jump in place = a teleport, no
		-- bump); a bot: how far the server moved it. Too fast for a kart = no bump at all.
		local moved = if last then (pos - last) / dt else Vector3.zero
		local v = if info.player then body.AssemblyLinearVelocity else moved
		if moved.Magnitude > TELEPORT then
			info.jumpedAt = os.clock()
		end
		if moved.Magnitude > TELEPORT or v.Magnitude > MAX_SPEED then
			info.vel = Vector3.zero
		else
			info.vel = info.vel:Lerp(v, 0.5)
		end
		local k = m.karts[id]
		if k and k.alive then
			table.insert(live, { id = id, pos = pos, vel = info.vel })
		end
	end
	for i = 1, #live do
		for j = i + 1, #live do
			local a, b = live[i], live[j]
			if math.abs(a.pos.Y - b.pos.Y) > Match.RAM_DIST then
				continue
			end
			local toB, toA = Match.ram(
				m,
				a.id,
				{ x = a.pos.X, z = a.pos.Z },
				{ x = a.vel.X, z = a.vel.Z },
				b.id,
				{ x = b.pos.X, z = b.pos.Z },
				{ x = b.vel.X, z = b.vel.Z },
				t
			)
			if toB > 0 then
				MatchRunner.damage(b.id, a.id, toB, "bump")
			end
			if toA > 0 then
				MatchRunner.damage(a.id, b.id, toA, "bump")
			end
		end
	end
end

local function tick()
	local t = now()
	if phase == "idle" then
		if startAt and t >= startAt then
			startRound()
		end
		return
	end
	if phase == "break" then
		local at = LobbyLayout.arenaIndex()
		for p in inRound do
			if p.Parent == nil or LobbyPlots.drivingOf(p) ~= at then
				MatchRunner.leave(p)
			end
		end
		if startAt and t >= startAt then
			startRound()
		end
		return
	end
	local m = state :: Match.State
	-- a player who walked off (the stand's walk, a reset) is out of the round
	local idx = LobbyLayout.arenaIndex()
	for p in inRound do
		if p.Parent == nil or LobbyPlots.drivingOf(p) ~= idx then
			MatchRunner.leave(p)
		end
	end
	for _, k in Match.due(m, t) do
		local info = infos[k.id]
		Match.respawn(m, k.id, t)
		if info then
			setAttr(info, "Health", k.health)
			setAttr(info, "RespawnAt", nil)
			if not info.player then
				freeze(info, false)
			end
			place(info, spawnFor(k.id))
		end
	end
	for _, k in m.list do
		local info = infos[k.id]
		if info then
			setAttr(info, "Place", Match.shownPlace(k, Match.rank(m, k.id)))
			setAttr(info, "Shield", Match.shielded(k, t))
		end
	end
	local humans = 0
	for _ in inRound do
		humans += 1
	end
	if t >= m.endsAt then
		endRound()
	elseif humans == 0 then
		-- everyone left: no round for bots alone
		log(`round {round} stopped: no players`)
		clearBots()
		state = nil
		phase = "idle"
		workspace:SetAttribute("MatchEndsAt", nil)
		setNext(if #queue > 0 then t + MatchRunner.START_SECS else nil)
	end
end

-- Is player `id` a rookie this round (bots go easy on them)?
function MatchRunner.isRookie(id: number): boolean
	return rookies[id] == true
end

function MatchRunner.isNewKid(id: number): boolean
	return newKids[id] == true
end

function MatchRunner.start(h: Hooks)
	hooks = h
	if RunService:IsStudio() then
		-- (Studio proof runs: a short round from the command bar)
		local secs = workspace:GetAttribute("MatchSecs")
		if type(secs) == "number" and secs >= 10 then
			MatchRunner.MATCH_SECS = secs
		end
		-- (and everyone who comes in is on the list, with no pad needed)
		if workspace:GetAttribute("SmashAutoJoin") == true then
			Players.PlayerAdded:Connect(function(p: Player)
				task.delay(3, MatchRunner.join, p)
			end)
			for _, p in Players:GetPlayers() do
				task.delay(3, MatchRunner.join, p)
			end
		end
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		MatchRunner.leave(p)
		lastLeave[p] = nil
	end)
	leaveMatch.OnServerEvent:Connect(function(p: Player)
		local t = os.clock()
		if t - (lastLeave[p] or 0) < 1 then
			return
		end
		lastLeave[p] = t
		MatchRunner.leave(p)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if phase == "playing" then
			bumps(dt)
			if fleet and ArenaBots then
				local ok, err = pcall(ArenaBots.step, fleet, dt, now())
				if not ok and os.clock() - stepWarned > 5 then
					stepWarned = os.clock() -- (once in a while: one bad frame mustn't stop the bots)
					warn("arena bots: " .. tostring(err))
				end
			end
		end
		acc += dt
		if acc >= MatchRunner.TICK then
			acc = 0
			tick()
		end
	end)
end

return MatchRunner
