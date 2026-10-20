--!strict
-- The 1v1 auto-battle: pads, car pick, preparation, automatic fight, round and match results,
-- rewards, rematch and leaving. The server decides everything; clients only show screens and send
-- (queue, select, lock, leave...). One Heartbeat drives every match through explicit phases, so two
-- fights, pick screens or reward handlers can never overlap:
--   select -> prep -> fight -> result -> (select again | matchResult) -> rematch (select) | closed
-- Matches are small tables in `matches`; closing one frees its arena, cars, shells and players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BattleBrain = require(ReplicatedStorage.Shared.BattleBrain)
local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleAim = require(ReplicatedStorage.Shared.BattleAim)
local BattleCrash = require(ReplicatedStorage.Shared.BattleCrash)
local BattleSpecial = require(ReplicatedStorage.Shared.BattleSpecial)
local BattleHuman = require(ReplicatedStorage.Shared.BattleHuman)
local PadSlots = require(ReplicatedStorage.Shared.PadSlots)
local BattleRecap = require(ReplicatedStorage.Shared.BattleRecap)
local BattleSelect = require(ReplicatedStorage.Shared.BattleSelect)
local BattleSeries = require(ReplicatedStorage.Shared.BattleSeries)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Progress = require(ReplicatedStorage.Shared.Progress)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ResultRewards = require(ReplicatedStorage.Shared.ResultRewards)
local Steer = require(ReplicatedStorage.Shared.Steer)
local BattleArena = require(script.Parent.BattleArena)
local BattleCar = require(script.Parent.BattleCar)
local Leaderboards = require(script.Parent.Leaderboards)
local Profiles = require(script.Parent.Profiles)

type Part = {
	player: Player?,
	userId: number,
	name: string,
	bot: boolean,
	last: string?, -- last valid pick (used at timeout)
	pick: string?,
	locked: boolean,
	access: string?, -- how this round's car is used: owned | loaner | test
	rematch: boolean,
	left: boolean,
	paid: boolean, -- this match's reward was handled
	savedSpeed: number?,
	savedCf: CFrame?, -- where the character stood before it was parked under the arena
	spot: number, -- unused since manual driving: cars start on the map's spawns
	aim: number,
	steer: number, -- driving: stick / keys, -1 left .. 1 right
	gas: number, -- -1 back .. 1 forward
	inputAt: number, -- when the last drive input arrived (old input counts as 0)
	attack: boolean, -- ATTACK is held down right now (sent with the drive input)
}
type Shell = {
	owner: BattleCar.Car,
	foe: BattleCar.Car,
	part: BasePart?,
	pos: Vector3,
	dir: Vector3,
	life: number,
	speed: number,
	bounces: number, -- wall bounces so far
	dmg: number, -- damage when it lands
	homing: number, -- degrees per second it curves toward the foe
}
type Match = {
	slot: number,
	parts: { a: Part, b: Part },
	series: BattleSeries.Series,
	phase: string, -- select | prep | fight | ko | result | matchResult
	t: number,
	arena: BattleArena.Arena?,
	cars: { a: BattleCar.Car?, b: BattleCar.Car? },
	shells: { Shell },
	settled: boolean,
	hudT: number,
	vsBot: boolean,
	closed: boolean,
	lastOutcome: string?,
	prepSeconds: number, -- how long this 3-2-1 lasts (longer before round 1)
	koSeconds: number, -- how long this knock-out lasts (longer when it ends the match)
	koOutcome: string?, -- the round result waiting for the knock-out finish to play
	final: boolean, -- the announced final phase has begun
	momentum: boolean, -- the momentum prototype fight (else the steering fight)
	crashCd: number, -- seconds until the next plain crash can hurt
	touching: boolean, -- the cars' bodies were touching at the last step
	aIsRed: boolean?, -- which garage team is red this match (chosen once, at random)
}

local BattleService = {}

export type Handle = {
	-- Called by the lobby about 4 times a second: which pad (1..) each player physically stands
	-- on. Two on one pad start a fight. Returns how many wait on each pad (for the pad texts).
	padSync: (observed: { [Player]: number }) -> { number },
	padCounts: () -> { number },
	cancel: (player: Player) -> (), -- off the pad (CANCEL button / walked off)
	action: (player: Player, name: string, arg: any) -> (),
	playerRemoving: (player: Player) -> (),
	isBusy: (player: Player) -> boolean,
	steer: (player: Player, steer: any, gas: any, attack: any) -> (),
}

local T = BattleConfig.Timing
local BOT_NAME = "Test Bot"
local BOT_SIGN_NAME = "Crusher" -- what the garage sign says for the bot

function BattleService.start(
	opts: {
		remotes: Remotes.RemoteSet,
		sendProfile: (player: Player) -> (),
		padCount: number?, -- PLAY pads in the lobby (default 4); 2 players on one pad fight
		park: ((player: Player) -> ())?, -- a fight begins: take the character out of the lobby
		returnToLobby: ((player: Player) -> ())?, -- a fight is over: put the character back by the pads
	}
): Handle
	local remotes = opts.remotes
	local pads = PadSlots.new(opts.padCount or 4, 2)
	local matches: { [Match]: boolean } = {}
	local inMatch: { [Player]: Match } = {}
	local usedSlots: { [number]: boolean } = {}
	local limiter = RateLimiter.new(12, 2)
	local isStudio = RunService:IsStudio()

	local arenaTable: BattleBrain.Arena = {
		halfX = BattleConfig.Arena.halfX,
		halfZ = BattleConfig.Arena.halfZ,
		obstacles = BattleConfig.Arena.obstacles,
	}

	-- who may start a fight against a bot without other players: Studio, the game's owner, and
	-- anyone listed in BattleConfig.Test.devUserIds. Everyone else never sees the button.
	local function devBotAllowed(player: Player): boolean
		if isStudio or player.UserId == game.CreatorId then
			return true
		end
		return table.find(BattleConfig.Test.devUserIds, player.UserId) ~= nil
	end
	local function markDev(player: Player)
		player:SetAttribute(BattleConfig.Test.devBotAttribute, devBotAllowed(player))
	end
	Players.PlayerAdded:Connect(markDev)
	for _, p in Players:GetPlayers() do
		markDev(p)
	end

	local function testUnlock(): boolean
		return isStudio and workspace:GetAttribute(BattleConfig.Test.unlockAttribute) == true
	end

	local function ctxFor(part: Part): BattleSelect.Context
		if part.bot then
			return {
				owned = { RamTruck = true, CannonVan = true, SawBuggy = true },
				testUnlock = false,
			}
		end
		local p = if part.player then Profiles.get(part.player) else nil
		return { owned = if p then p.owned else {}, testUnlock = testUnlock() }
	end

	local function send(part: Part, msg: { [string]: any })
		local pl = part.player
		if pl and not part.left and pl.Parent ~= nil then
			remotes.BattleUpdate:FireClient(pl, msg)
		end
	end

	local function other(m: Match, side: string): Part
		return if side == "a" then m.parts.b else m.parts.a
	end

	local function sides(): { string }
		return { "a", "b" }
	end

	local function scoreFor(m: Match, side: string): { me: number, opp: number }
		local s = m.series
		return if side == "a"
			then { me = s.winsA, opp = s.winsB }
			else { me = s.winsB, opp = s.winsA }
	end

	local function freeSlot(): number
		local s = 0
		while usedSlots[s] do
			s += 1
		end
		return s
	end

	-- Players stand still in the lobby while their view is the arena.
	local function hold(part: Part)
		local pl = part.player
		local hum = if pl and pl.Character
			then pl.Character:FindFirstChildOfClass("Humanoid")
			else nil
		if hum and part.savedSpeed == nil then
			part.savedSpeed = hum.WalkSpeed
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
		if pl then
			pl:SetAttribute("InBattle", true)
			if opts.park then
				opts.park(pl)
			end
		end
	end

	-- A device only simulates parts near its character, and the arena is far from the lobby, so the
	-- (still, anchored) character waits under the arena floor while the player drives their car.
	local function park(part: Part, origin: Vector3)
		local pl = part.player
		local char = if pl then pl.Character else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if char and root and root:IsA("BasePart") and part.savedCf == nil then
			part.savedCf = root.CFrame
			root.Anchored = true
			char:PivotTo(CFrame.new(origin + Vector3.new(0, -12, 0)))
		end
	end

	local function unpark(part: Part)
		local pl = part.player
		local char = if pl then pl.Character else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if part.savedCf ~= nil and char and root and root:IsA("BasePart") then
			char:PivotTo(part.savedCf)
			root.Anchored = false
		end
		part.savedCf = nil
	end

	local function release(part: Part, toLobby: boolean)
		local pl = part.player
		if pl == nil or pl.Parent == nil then
			return
		end
		unpark(part)
		local hum = if pl.Character then pl.Character:FindFirstChildOfClass("Humanoid") else nil
		if hum and part.savedSpeed ~= nil then
			hum.WalkSpeed = part.savedSpeed
			hum.JumpPower = 50
		end
		part.savedSpeed = nil
		pl:SetAttribute("InBattle", nil)
		if opts.returnToLobby then
			opts.returnToLobby(pl)
		end
		if toLobby then
			remotes.BattleUpdate:FireClient(pl, { kind = "end" })
			remotes.LobbyUpdate:FireClient(
				pl,
				{ kind = "toLobby", coinsEarned = 0, won = false, left = true }
			)
			opts.sendProfile(pl)
		end
	end

	local function clearShells(m: Match)
		for _, s in m.shells do
			if s.part then
				s.part:Destroy()
			end
		end
		table.clear(m.shells)
	end

	local function clearCars(m: Match)
		for _, side in sides() do
			local c = (m.cars :: any)[side]
			if c then
				BattleCar.destroy(c);
				(m.cars :: any)[side] = nil
			end
		end
	end

	local function closeMatch(m: Match)
		if m.closed then
			return
		end
		m.closed = true
		clearShells(m)
		clearCars(m)
		if m.arena then
			m.arena.destroy()
			m.arena = nil
		end
		usedSlots[m.slot] = nil
		matches[m] = nil
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			if part.player and inMatch[part.player] == m then
				inMatch[part.player] = nil
			end
			if not part.left then
				release(part, true)
			end
		end
	end

	-- Fighter cards for one player's pick screen.
	local function choicesFor(part: Part): { any }
		local list = {}
		for _, c in BattleSelect.choices(ctxFor(part)) do
			local f = BattleConfig.Fighters[c.id]
			table.insert(list, {
				id = c.id,
				state = c.state,
				selectable = c.selectable,
				enabled = f.enabled,
			})
		end
		return list
	end

	local function startSelect(m: Match)
		clearShells(m)
		clearCars(m)
		m.phase, m.t = "select", 0
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			part.pick, part.locked, part.access = nil, false, nil
			if part.bot then
				local ids = BattleConfig.activeOrder()
				part.pick = ids[math.random(1, #ids)]
				part.locked = true
			end
		end
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			local opp = other(m, side)
			local p = if part.player then Profiles.get(part.player) else nil
			send(part, {
				kind = "select",
				round = m.series.round,
				rounds = BattleConfig.Series.rounds,
				score = scoreFor(m, side),
				seconds = T.selectSeconds,
				choices = choicesFor(part),
				selected = part.pick,
				last = part.last,
				coins = if p then p.coins else 0,
				opp = { name = opp.name, bot = opp.bot },
			})
		end
	end

	local function labelFor(part: Part): string
		return BattleSelect.label(part.access)
	end

	local function startPrep(m: Match): boolean
		clearShells(m)
		clearCars(m)
		-- lock in everyone's car for this round
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			local ctx = ctxFor(part)
			local id = BattleSelect.resolve(if part.locked then part.pick else part.last, ctx)
			if id == nil then
				return false
			end
			part.last = id
			part.pick = id
			part.access = BattleSelect.access(id, ctx)
		end
		if m.arena == nil then
			m.arena = BattleArena.build(m.slot)
		end
		local arena = m.arena :: BattleArena.Arena
		if m.aIsRed == nil then
			m.aIsRed = math.random() < 0.5
		end
		arena.setTeams(m.aIsRed :: boolean)
		arena.closeDoors()
		local spawnOf = { a = "a", b = "b" }
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			-- sides swap every round so both spawn spots get used
			local spawnSide = if (m.series.round % 2 == 1) == (side == "a") then "a" else "b";
			(spawnOf :: any)[side] = spawnSide
			local pos, facing = arena.spawnPoint(spawnSide)
			local car, err = BattleCar.spawn(part.pick :: string, side, arena.folder, pos, facing)
			if car == nil then
				warn("[Battle] cannot start: " .. tostring(err))
				for _, s2 in sides() do
					local p2 = (m.parts :: any)[s2] :: Part
					send(p2, { kind = "error", text = "Cars are not ready yet: " .. tostring(err) })
				end
				return false
			end
			(m.cars :: any)[side] = car
		end
		-- the garage signs: whoever starts at the west garage is on the left sign
		local signs = { a = "", b = "" }
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part;
			(signs :: any)[(spawnOf :: any)[side]] = if part.bot then BOT_SIGN_NAME else part.name
		end
		arena.setNames(signs.a, signs.b)
		for _, side in sides() do
			park((m.parts :: any)[side], arena.origin)
		end
		m.prepSeconds = if m.series.round == 1 then T.firstPrepSeconds else T.prepSeconds
		m.phase, m.t = "prep", 0
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			local opp = other(m, side)
			send(part, {
				kind = "prep",
				momentum = m.momentum,
				seconds = m.prepSeconds,
				round = m.series.round,
				score = scoreFor(m, side),
				arena = {
					x = arena.origin.X,
					y = arena.origin.Y,
					z = arena.origin.Z,
					halfX = arena.halfX,
					halfZ = arena.halfZ,
					wall = BattleConfig.Arena.wallHeight,
				},
				side = side,
				spawn = (spawnOf :: any)[side],
				me = {
					id = part.pick,
					name = part.name,
					label = labelFor(part),
					line = BattleConfig.driverLine(part.pick),
				},
				opp = {
					id = opp.pick,
					name = opp.name,
					label = labelFor(opp),
					bot = opp.bot,
					line = BattleConfig.driverLine(opp.pick),
				},
			})
		end
		return true
	end

	local function startFight(m: Match)
		for _, side in sides() do
			local car = (m.cars :: any)[side] :: BattleCar.Car
			local part = (m.parts :: any)[side] :: Part
			if part.player ~= nil then
				-- a player drives this car: stick / keys and the ATTACK button
				car.human = true
				part.steer, part.gas, part.attack = 0, 0, false
				BattleCar.arm(car, BattleHuman.new(car.fighter.id), part.player)
				BattleCar.launch(car, false)
			else
				car.human = false
				BattleCar.arm(car, BattleBrain.new(car.fighter.id, car.L, arenaTable, m.momentum))
				BattleCar.launch(car, m.momentum)
			end
		end
		m.phase, m.t, m.hudT = "fight", 0, 0
		if m.arena then
			m.arena.openDoors()
		end
		m.final = false
		m.crashCd, m.touching = 0, false
		for _, side in sides() do
			send((m.parts :: any)[side], { kind = "fight", seconds = T.fightSeconds })
		end
	end

	local function hudFor(m: Match, side: string): { [string]: any }
		local mine = (m.cars :: any)[side] :: BattleCar.Car
		local foe = (m.cars :: any)[BattleSeries.other(side :: any)] :: BattleCar.Car
		local function view(c: BattleCar.Car): { [string]: any }
			return {
				hp = math.ceil(c.hp),
				max = c.maxHp,
				ready = if c.lastOut then c.lastOut.ready else 1,
				state = if c.lastOut then c.lastOut.state else "approach",
				energy = c.energy,
			}
		end
		return {
			kind = "hud",
			left = math.max(0, T.fightSeconds - m.t),
			me = view(mine),
			opp = view(foe),
		}
	end

	local function sendEvent(m: Match, fromSide: string, text: string)
		for _, side in sides() do
			send((m.parts :: any)[side], { kind = "event", text = text, mine = side == fromSide })
		end
	end

	-- `dmg` and `victim` (the side that was hit) let the client pop a damage number and shake the
	-- view harder when it is YOUR car; `ko` = the final blow (wreck explosion).
	local function sendHit(
		m: Match,
		pos: Vector3,
		big: boolean,
		dmg: number?,
		victim: string?,
		ko: boolean?
	)
		for _, side in sides() do
			send((m.parts :: any)[side], {
				kind = "hit",
				pos = pos,
				big = big,
				dmg = dmg,
				victim = victim,
				ko = ko,
				koSeconds = m.koSeconds,
			})
		end
	end

	-- Pays the match result ONCE per player. A bot match pays nothing.
	local function settle(m: Match)
		if m.settled then
			return
		end
		m.settled = true
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			local result = BattleSeries.resultFor(m.series, side :: any)
			local coins, total, wins = 0, 0, 0
			local p = if part.player and not part.left then Profiles.get(part.player) else nil
			if p and not part.paid and not m.vsBot then
				part.paid = true
				local won = result == "win"
				coins = ResultRewards.compute({ mode = "duel", won = won }).coins
				coins = math.floor(coins * Progress.coinMultiplier(os.time()))
				Inventory.addCoins(p, coins)
				if won then
					p.wins += 1
					Leaderboards.recordWin(part.player :: Player)
				end
				p.matches = math.min(p.matches + 1, 1e9)
				Profiles.markDirty(part.player :: Player)
				Profiles.saveNow(part.player :: Player)
				Leaderboards.submit(part.player :: Player, p)
			end
			if p then
				total, wins = p.coins, p.wins
			end
			send(part, {
				kind = "matchResult",
				result = result,
				score = scoreFor(m, side),
				forfeit = m.series.forfeit ~= nil,
				youLeft = false,
				coins = coins,
				total = total,
				wins = wins,
				vsBot = m.vsBot,
				opp = { name = other(m, side).name, left = other(m, side).left },
				seconds = T.rematchSeconds,
			})
			if part.player and not part.left then
				opts.sendProfile(part.player)
			end
		end
		m.phase, m.t = "matchResult", 0
	end

	local function endRound(m: Match, outcome: BattleSeries.Outcome)
		for _, side in sides() do
			local car = (m.cars :: any)[side]
			if car then
				BattleCar.freeze(car)
			end
		end
		clearShells(m)
		BattleSeries.record(m.series, outcome)
		m.lastOutcome = outcome
		m.phase, m.t = "result", 0
		for _, side in sides() do
			local res = if outcome == "draw"
				then "draw"
				elseif outcome == side then "win"
				else "loss"
			local mineCar = (m.cars :: any)[side] :: BattleCar.Car?
			local foeCar = (m.cars :: any)[BattleSeries.other(side :: any)] :: BattleCar.Car?
			local recap: { string } = if mineCar and foeCar
				then BattleRecap.lines(mineCar.fighter.id, mineCar.stats, foeCar.stats)
				else {}
			send((m.parts :: any)[side], {
				kind = "roundResult",
				recap = recap,
				result = res,
				round = #m.series.results,
				score = scoreFor(m, side),
				seconds = T.resultSeconds,
				matchOver = m.series.over,
			})
		end
	end

	local function fireShell(
		m: Match,
		car: BattleCar.Car,
		foe: BattleCar.Car,
		shellOpts: {
			yawDeg: number?,
			dmg: number?,
			scale: number?,
			homing: number?,
			color: Color3?,
		}?
	)
		local o = shellOpts or {}
		local muzzle = car.muzzle
		local cfg = BattleConfig.Cannon
		-- only the van has a muzzle; other cars' specials launch from just ahead of the nose
		local pos = if muzzle
			then muzzle.WorldPosition
			else car.body.Position + car.body.CFrame.LookVector * (0.6 * car.L) + Vector3.new(
				0,
				0.2 * car.L,
				0
			)
		-- flat aim along the car's facing, tilted to the foe's body height so a low car is not overshot
		local flat = car.lastForward
		local toFoe = foe.body.Position - pos
		local run = math.max(toFoe.Magnitude, 1)
		local rise = math.clamp(toFoe.Y / run, -0.5, 0.5)
		-- the shot leaves along the nose; auto-aim then curves it toward the foe in stepShells
		local dir = Vector3.new(flat.X, rise, flat.Z).Unit
		if o.yawDeg then
			dir = (CFrame.Angles(0, math.rad(o.yawDeg), 0) * dir).Unit
		end
		local ball = Instance.new("Part")
		ball.Name = "Shell"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * (0.42 * car.L * (o.scale or 1))
		ball.Material = Enum.Material.Neon
		ball.Color = o.color or Color3.fromRGB(255, 160, 40)
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Position = pos
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.5 * ball.Size.Y, 0)
		top.Parent = ball
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.5 * ball.Size.Y, 0)
		bottom.Parent = ball
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = top, bottom
		trail.Lifetime = 0.35
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 80, 20))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.LightEmission = 1
		trail.Parent = ball
		ball.Parent = (m.arena :: BattleArena.Arena).folder
		table.insert(m.shells, {
			owner = car,
			foe = foe,
			part = ball,
			pos = pos,
			dir = dir,
			life = cfg.shellLifeSeconds,
			speed = cfg.shellSpeedL * car.L,
			bounces = 0,
			dmg = o.dmg or cfg.damage,
			homing = o.homing or cfg.homingDegPerSec,
		})
		car.stats.shots += 1
	end

	-- Moves every shell; returns damage dealt to each side this step.
	local function stepShells(m: Match, dt: number, dmg: { a: number, b: number })
		local arena = m.arena :: BattleArena.Arena
		for i = #m.shells, 1, -1 do
			local s = m.shells[i]
			-- auto-aim: the shell curves a little toward the foe it is already flying at
			do
				local toFoe = s.foe.body.Position - s.pos
				local cfg = BattleConfig.Cannon
				local nx, nz = BattleAim.curve(
					s.dir.X,
					s.dir.Z,
					toFoe.X,
					toFoe.Z,
					math.rad(s.homing) * dt,
					math.rad(cfg.homingConeDeg)
				)
				local flat = math.sqrt(s.dir.X * s.dir.X + s.dir.Z * s.dir.Z)
				s.dir = Vector3.new(nx * flat, s.dir.Y, nz * flat).Unit
			end
			local step = s.dir * s.speed * dt
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local include: { Instance } = table.clone(arena.solids)
			table.insert(include, s.foe.body)
			params.FilterDescendantsInstances = include
			-- point blank: a shell born inside the foe's box would never "hit" it, so count that as a hit
			local rel = s.foe.body.CFrame:PointToObjectSpace(s.pos)
			local half = s.foe.body.Size / 2 + Vector3.one * (0.15 * s.owner.L)
			local inside = math.abs(rel.X) <= half.X
				and math.abs(rel.Y) <= half.Y
				and math.abs(rel.Z) <= half.Z
			local hit = if inside
				then nil
				else workspace:Spherecast(s.pos, 0.15 * s.owner.L, step, params)
			local done = false
			local landed = false
			if
				hit
				and hit.Instance ~= s.foe.body
				and s.bounces < BattleConfig.Cannon.ricochets
				and math.abs(hit.Normal.Y) < 0.5
			then
				-- a wall: the shell bounces off once (flat reflection) and flies on
				local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
				local d = s.dir
				local r = d - 2 * d:Dot(n) * n
				s.dir = Vector3.new(r.X, d.Y, r.Z).Unit
				s.pos = hit.Position + n * (0.4 * s.owner.L)
				s.bounces += 1
				s.life -= dt
				if s.life <= 0 then
					done = true
				end
				if s.part then
					s.part.Position = s.pos
				end
				sendHit(m, hit.Position, false)
			elseif hit or inside then
				done = true
				local hitPos = if hit then hit.Position else s.pos
				if inside or (hit and hit.Instance == s.foe.body) then
					landed = true
					s.owner.stats.shotHits += 1
					if s.foe.side == "a" then
						dmg.a += s.dmg
					else
						dmg.b += s.dmg
					end
					BattleCar.knock(
						s.foe,
						s.dir,
						BattleConfig.Cannon.knockSpeed,
						BattleConfig.Cannon.knockStagger
					)
					sendHit(m, hitPos, false, s.dmg, s.foe.side)
				end
			else
				s.pos += step
				s.life -= dt
				if s.life <= 0 then
					done = true
				end
				if s.part then
					s.part.Position = s.pos
				end
			end
			if done then
				local brain = s.owner.brain
				local text = if brain then brain.shellResolved(landed) else nil
				if text then
					sendEvent(m, s.owner.side, text)
				end
				if s.part then
					s.part:Destroy()
				end
				table.remove(m.shells, i)
			end
		end
	end

	local function fightStep(m: Match, dt: number)
		local arena = m.arena :: BattleArena.Arena
		local a, b = m.cars.a :: BattleCar.Car, m.cars.b :: BattleCar.Car
		m.t += dt
		local dmg = { a = 0, b = 0 }
		local cars = { a, b }
		if not m.final and m.t >= BattleConfig.Final.startSeconds then
			m.final = true
			for _, side in sides() do
				send((m.parts :: any)[side], { kind = "phase", text = BattleConfig.Final.text })
			end
		end
		for _, car in cars do
			BattleCar.checkFlip(car, dt)
			local lx, lz = arena.toLocal(car.body.Position)
			-- a car that leaves the arena loses the round: all its HP is gone at once
			if
				BattleCrash.outside(
					lx,
					lz,
					car.body.Position.Y - arena.origin.Y,
					arena.halfX,
					arena.halfZ
				)
			then
				if car.hp > 0 then
					if car.side == "a" then
						dmg.a += car.hp
					else
						dmg.b += car.hp
					end
					sendEvent(m, if car.side == "a" then "b" else "a", "Out of the arena!")
				end
				continue
			end
			BattleCar.keepInside(
				car,
				arena.origin.Y,
				lx,
				lz,
				arena.halfX,
				arena.halfZ,
				arena.origin
			)
		end
		for _, car in cars do
			local foe = if car == a then b else a
			local brain = car.brain
			if brain then
				local lx, lz = arena.toLocal(car.body.Position)
				local fx, fz = arena.toLocal(foe.body.Position)
				local cf, ff = BattleCar.forward(car), BattleCar.forward(foe)
				local touching = BattleCar.overlaps(car, foe)
				if car.human then
					local part = (m.parts :: any)[car.side] :: Part
					local fresh = os.clock() - part.inputAt <= GameConfig.Steer.staleSeconds
					local hb: any = brain
					hb.setInput(
						if fresh then part.steer else 0,
						if fresh then part.gas else 0,
						fresh and part.attack
					)
				end
				local cruise = BattleCar.topSpeed(car)
				local fwdSpeed = car.body.AssemblyLinearVelocity:Dot(Vector3.new(cf.X, 0, cf.Z))
				local out = brain.step(
					dt,
					{ x = lx, z = lz, fx = cf.X, fz = cf.Z },
					{ x = fx, z = fz, fx = ff.X, fz = ff.Z },
					{
						ram = touching,
						saw = touching,
						speedFrac = math.max(0, fwdSpeed) / (cruise * BattleConfig.Ram.chargeMult),
						tempo = if m.final then BattleConfig.Final.tempo else 1,
					}
				)
				car.lastOut = out
				if car.clientDriven then
					-- the owner's device moves the car; it needs the weapon states that force movement
					local forced = out.state == "charge"
						or out.state == "recoil"
						or out.state == "skid"
					car.model:SetAttribute("BState", if forced then out.state else "drive")
					car.model:SetAttribute("BDrive", if forced then out.drive else 0)
					car.model:SetAttribute("BTurn", if forced then out.turn else 0)
					-- the device is trusted with movement, not with speed
					local vel = car.body.AssemblyLinearVelocity
					local flat = Vector3.new(vel.X, 0, vel.Z)
					local cap = BattleCar.topSpeed(car)
						* math.max(1, BattleConfig.Ram.chargeMult)
						* 1.3
					if flat.Magnitude > cap then
						local k = cap / flat.Magnitude
						car.body.AssemblyLinearVelocity = Vector3.new(vel.X * k, vel.Y, vel.Z * k)
					end
				end
				BattleCar.drive(car, out, dt)
				BattleCar.lunge(car, dt)
				BattleCar.rememberVelocity(car)
				if out.fire then
					fireShell(m, car, foe)
					sendEvent(m, car.side, "Fire!")
				end
				if out.damage > 0 then
					if foe.side == "a" then
						dmg.a += out.damage
					else
						dmg.b += out.damage
					end
					if out.event == "Ram hit" then
						car.stats.ramHits += 1
						-- a ram shoves the foe away; the truck bounces back (its brain recoils)
						BattleCar.knock(
							foe,
							foe.body.Position - car.body.Position,
							BattleConfig.Ram.knockSpeed,
							BattleConfig.Ram.knockStagger
						)
					end
					if car.fighter.id == "SawBuggy" then
						car.stats.sawHits += 1
					end
					sendHit(m, foe.body.Position, out.event == "Ram hit", out.damage, foe.side)
				end
				if out.event == "Ram hit" or out.event == "Ram missed" then
					car.stats.charges += 1
				end
				if out.event then
					sendEvent(m, car.side, out.event)
				end
			end
		end
		-- plain crashes: the car that gets hit takes damage by how fast the OTHER car drove into it
		-- (a charge, a saw or a shell has its own damage). Walls only bounce.
		if a.brain and b.brain then
			m.crashCd = math.max(0, m.crashCd - dt)
			local touching = BattleCar.bodiesTouch(a, b)
			if touching and not m.touching and m.crashCd <= 0 then
				local function striking(c: BattleCar.Car): boolean
					local st = if c.lastOut then c.lastOut.state else "drive"
					return st == "charge" or st == "recoil"
				end
				if not striking(a) and not striking(b) then
					local ab = b.body.Position - a.body.Position
					local sA = BattleCrash.speedToward(a.prevVel.X, a.prevVel.Z, ab.X, ab.Z)
					local sB = BattleCrash.speedToward(b.prevVel.X, b.prevVel.Z, -ab.X, -ab.Z)
					local hitB = BattleCrash.damage(b.maxHp, sA, BattleCar.topSpeed(a))
					local hitA = BattleCrash.damage(a.maxHp, sB, BattleCar.topSpeed(b))
					if hitA > 0 or hitB > 0 then
						m.crashCd = BattleConfig.Crash.cooldownSeconds
						dmg.a += hitA
						dmg.b += hitB
						local mid = (a.body.Position + b.body.Position) / 2
						if hitA > 0 then
							sendHit(m, mid, hitA >= a.maxHp * 0.15, hitA, "a")
						end
						if hitB > 0 then
							sendHit(m, mid, hitB >= b.maxHp * 0.15, hitB, "b")
						end
					end
				end
			end
			m.touching = touching
		end
		stepShells(m, dt, dmg)
		-- all damage of this update lands together, so a double knock-out is a draw
		a.hp = math.max(0, a.hp - dmg.a)
		b.hp = math.max(0, b.hp - dmg.b)
		-- hitting the foe fills the special energy bar
		if dmg.b > 0 and a.hp > 0 then
			a.energy = BattleSpecial.gain(a.energy, dmg.b)
		end
		if dmg.a > 0 and b.hp > 0 then
			b.energy = BattleSpecial.gain(b.energy, dmg.a)
		end
		-- the clients smoke the cars more as HP drops
		a.model:SetAttribute("HpFrac", a.hp / a.maxHp)
		b.model:SetAttribute("HpFrac", b.hp / b.maxHp)
		local outcome =
			BattleSeries.roundOutcome(a.hp, a.maxHp, b.hp, b.maxHp, m.t >= T.fightSeconds)
		if outcome then
			for _, side in sides() do
				send((m.parts :: any)[side], hudFor(m, side))
			end
			if a.hp <= 0 or b.hp <= 0 then
				-- knock-out: both cars stop, the loser is wrecked, then the result shows
				clearShells(m)
				m.koSeconds = if BattleSeries.endsMatch(m.series, outcome)
					then T.koLastSeconds
					else T.koSeconds
				for _, car in cars do
					car.brain = nil
					if car.hp <= 0 then
						BattleCar.wreck(car)
						sendHit(m, car.body.Position, true, nil, car.side, true)
					end
				end
				sendEvent(m, if a.hp <= 0 then "b" else "a", "K.O.")
				m.koOutcome = outcome
				m.phase, m.t = "ko", 0
			else
				endRound(m, outcome)
			end
			return
		end
		m.hudT += dt
		if m.hudT >= 1 / T.hudRate then
			m.hudT = 0
			for _, side in sides() do
				send((m.parts :: any)[side], hudFor(m, side))
			end
		end
	end

	-- SPECIAL button: spends a full energy bar on the car's own special move.
	local function useSpecial(m: Match, side: string)
		local car = (m.cars :: any)[side] :: BattleCar.Car?
		local foe = (m.cars :: any)[BattleSeries.other(side :: any)] :: BattleCar.Car?
		if car == nil or foe == nil or car.brain == nil or not BattleSpecial.ready(car.energy) then
			return
		end
		car.energy = 0
		local S = BattleConfig.Special
		local id = car.fighter.id
		if id == "RamTruck" then
			-- shockwave: a ring blasts out; a foe inside it is hurt and shoved away
			local ring = Instance.new("Part")
			ring.Name = "Shockwave"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.Material = Enum.Material.Neon
			ring.Color = Color3.fromRGB(255, 220, 90)
			ring.Transparency = 0.2
			ring.Size = Vector3.new(1, 2, 2)
			ring.CFrame = CFrame.new(car.body.Position) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = (m.arena :: BattleArena.Arena).folder
			local reach = S.shockRadiusL * car.L
			TweenService:Create(
				ring,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(1, reach * 2, reach * 2), Transparency = 1 }
			):Play()
			Debris:AddItem(ring, 0.6)
			local d = foe.body.Position - car.body.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude <= reach then
				foe.hp = math.max(0, foe.hp - S.shockDamage)
				BattleCar.knock(foe, d, S.shockKnockSpeed, S.shockStagger)
				sendHit(m, foe.body.Position, true, S.shockDamage, foe.side)
			end
		elseif id == "CannonVan" then
			for _, yaw in { -S.tripleSpreadDeg, 0, S.tripleSpreadDeg } do
				fireShell(m, car, foe, { yawDeg = yaw })
			end
		else
			fireShell(m, car, foe, {
				dmg = S.sawThrowDamage,
				scale = S.sawThrowScale,
				homing = S.sawThrowHomingDeg,
				color = Color3.fromRGB(215, 220, 232),
			})
		end
		for _, sd in sides() do
			send((m.parts :: any)[sd], { kind = "special", side = side, id = id })
		end
	end

	-- HORN button: a honk everyone in the match hears and sees.
	local function honk(m: Match, side: string)
		local car = (m.cars :: any)[side] :: BattleCar.Car?
		if car == nil or os.clock() - car.hornAt < BattleConfig.Special.hornSeconds then
			return
		end
		car.hornAt = os.clock()
		for _, sd in sides() do
			send((m.parts :: any)[sd], { kind = "horn", side = side })
		end
	end

	local function newSeries(m: Match)
		m.series = BattleSeries.new()
		m.settled = false
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			part.paid, part.rematch = false, false
		end
		startSelect(m)
	end

	local function bothReady(m: Match): boolean
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			if part.left then
				return false
			end
			if not (part.bot or part.rematch) then
				return false
			end
		end
		return true
	end

	local function update(m: Match, dt: number)
		m.t += if m.phase == "fight" then 0 else dt
		if m.phase == "select" then
			local allLocked = m.parts.a.locked and m.parts.b.locked
			if m.t >= T.selectSeconds or allLocked then
				if not startPrep(m) then
					closeMatch(m)
				end
			end
		elseif m.phase == "prep" then
			if m.t >= m.prepSeconds then
				startFight(m)
			end
		elseif m.phase == "fight" then
			fightStep(m, dt)
		elseif m.phase == "ko" then
			for _, side in sides() do
				local car = (m.cars :: any)[side]
				if car then
					BattleCar.coast(car, dt)
				end
			end
			if m.t >= m.koSeconds then
				endRound(m, (m.koOutcome :: any) or "draw")
			end
		elseif m.phase == "result" then
			if m.t >= T.resultSeconds then
				if m.series.over then
					settle(m)
				elseif not startPrep(m) then
					-- same cars, straight to the next 3-2-1 (the pick screen is only before round 1)
					closeMatch(m)
				end
			end
		elseif m.phase == "matchResult" then
			if bothReady(m) then
				newSeries(m)
			elseif m.t >= T.rematchSeconds then
				closeMatch(m)
			end
		end
	end

	local function humanPart(player: Player): Part
		return {
			player = player,
			userId = player.UserId,
			name = player.DisplayName,
			bot = false,
			last = nil,
			pick = nil,
			locked = false,
			access = nil,
			rematch = false,
			left = false,
			paid = false,
			savedSpeed = nil,
			spot = 0,
			aim = 0,
			steer = 0,
			gas = 0,
			inputAt = 0,
			attack = false,
		}
	end

	local function botPart(): Part
		return {
			player = nil,
			userId = -1,
			name = BOT_NAME,
			bot = true,
			last = nil,
			pick = nil,
			locked = true,
			access = "owned",
			rematch = true,
			left = false,
			paid = true,
			savedSpeed = nil,
			spot = 0,
			aim = 0,
			steer = 0,
			gas = 0,
			inputAt = 0,
			attack = false,
		}
	end

	local function createMatch(a: Part, b: Part, momentum: boolean?)
		local slot = freeSlot()
		usedSlots[slot] = true
		local m: Match = {
			slot = slot,
			parts = { a = a, b = b },
			series = BattleSeries.new(),
			phase = "select",
			t = 0,
			arena = nil,
			cars = {},
			shells = {},
			settled = false,
			hudT = 0,
			vsBot = a.bot or b.bot,
			closed = false,
			lastOutcome = nil,
			prepSeconds = T.prepSeconds,
			koSeconds = T.koSeconds,
			koOutcome = nil,
			final = false,
			momentum = if momentum == nil then BattleConfig.defaultMomentum else momentum,
			crashCd = 0,
			touching = false,
		}
		matches[m] = true
		for _, part in { a, b } do
			if part.player then
				inMatch[part.player] = m
				hold(part)
				send(part, {
					kind = "found",
					opp = { name = other(m, if part == a then "a" else "b").name },
				})
			end
		end
		startSelect(m)
	end

	-- A player leaves (voluntarily or by disconnecting). The other side wins by forfeit, once.
	local function leave(m: Match, part: Part, toLobby: boolean)
		if part.left or m.closed then
			return
		end
		local side = if m.parts.a == part then "a" else "b"
		local foe = other(m, side)
		part.left = true
		if part.player and inMatch[part.player] == m then
			inMatch[part.player] = nil
		end
		release(part, toLobby)
		if foe.left or foe.bot then
			-- nobody human is left: just clean up (a bot match pays nothing)
			closeMatch(m)
			return
		end
		if m.phase ~= "matchResult" and not m.series.over then
			BattleSeries.forfeit(m.series, side :: any)
			for _, s in sides() do
				local car = (m.cars :: any)[s]
				if car then
					BattleCar.freeze(car)
				end
			end
			clearShells(m)
			settle(m)
		elseif m.phase == "matchResult" then
			send(foe, { kind = "rematch", mine = foe.rematch, theirs = false, oppLeft = true })
		else
			-- the final round result is showing; the match result will say the opponent left
			m.t = math.max(m.t, T.resultSeconds)
		end
	end

	local handle: Handle
	handle = {
		steer = function(player: Player, steer: any, gas: any, attack: any)
			local m = inMatch[player]
			if m == nil or m.phase ~= "fight" then
				return
			end
			local part = if m.parts.a.player == player then m.parts.a else m.parts.b
			part.steer, part.gas, part.inputAt =
				Steer.sanitize(steer), Steer.sanitize(gas), os.clock()
			part.attack = attack == true
		end,
		isBusy = function(player: Player): boolean
			return inMatch[player] ~= nil or PadSlots.padOf(pads, player.UserId) ~= nil
		end,
		padCounts = function(): { number }
			return PadSlots.counts(pads)
		end,
		padSync = function(observed: { [Player]: number }): { number }
			local ids: { [number]: number } = {}
			local byId: { [number]: Player } = {}
			local busy: { [number]: boolean } = {}
			for player, pad in observed do
				ids[player.UserId] = pad
				byId[player.UserId] = player
				if inMatch[player] or Profiles.get(player) == nil then
					busy[player.UserId] = true -- in a fight, or the profile is still loading
				end
			end
			for _, ev in PadSlots.update(pads, ids, busy) do
				local pl = if ev.id then byId[ev.id] or Players:GetPlayerByUserId(ev.id) else nil
				if ev.kind == "joined" and pl then
					remotes.BattleUpdate:FireClient(pl, {
						kind = "queue",
						searching = true,
						pad = ev.pad,
						studioBot = devBotAllowed(pl),
					})
				elseif ev.kind == "left" and pl then
					remotes.BattleUpdate:FireClient(pl, { kind = "queue", searching = false })
				elseif ev.kind == "full" and pl then
					remotes.BattleUpdate:FireClient(
						pl,
						{ kind = "error", text = "That pad is full." }
					)
				elseif ev.kind == "ready" and ev.ids then
					local pa = Players:GetPlayerByUserId(ev.ids[1])
					local pb = Players:GetPlayerByUserId(ev.ids[2])
					if pa and pb and not inMatch[pa] and not inMatch[pb] then
						local ok, err = pcall(createMatch, humanPart(pa), humanPart(pb))
						if not ok then
							warn("[BattleService] could not start a pad match: " .. tostring(err))
							PadSlots.leave(pads, pa.UserId)
							PadSlots.leave(pads, pb.UserId)
							for _, x in { pa, pb } do
								remotes.BattleUpdate:FireClient(
									x,
									{ kind = "queue", searching = false }
								)
							end
						end
					else
						-- one of them left or is already fighting: free the survivor to wait again
						for _, x in { pa, pb } do
							if x then
								PadSlots.leave(pads, x.UserId)
								remotes.BattleUpdate:FireClient(
									x,
									{ kind = "queue", searching = false }
								)
							end
						end
					end
				end
			end
			return PadSlots.counts(pads)
		end,
		cancel = function(player: Player)
			if PadSlots.leave(pads, player.UserId) then
				remotes.BattleUpdate:FireClient(player, { kind = "queue", searching = false })
			end
		end,
		action = function(player: Player, name: string, arg: any)
			if not limiter.allow(player, os.clock()) then
				return
			end
			if name == "special" or name == "horn" then
				local m = inMatch[player]
				if m ~= nil and m.phase == "fight" then
					local side = if m.parts.a.player == player then "a" else "b"
					if name == "special" then
						useSpecial(m, side)
					else
						honk(m, side)
					end
				end
				return
			end
			if name == "queueBot" then
				-- Studio, the owner or a listed dev only. The opponent is labeled Test Bot everywhere.
				if
					devBotAllowed(player)
					and not inMatch[player]
					and Profiles.get(player) ~= nil
				then
					PadSlots.leave(pads, player.UserId)
					createMatch(
						humanPart(player),
						botPart(),
						if arg == "momentum" then true elseif arg == "steering" then false else nil
					)
				end
				return
			end
			if name == "cancel" then
				handle.cancel(player)
				return
			end
			local m = inMatch[player]
			if m == nil then
				return
			end
			local part = if m.parts.a.player == player then m.parts.a else m.parts.b
			if name == "select" then
				if m.phase == "select" and not part.locked and type(arg) == "string" then
					if BattleSelect.isEligible(arg, ctxFor(part)) then
						part.pick = arg
						send(part, { kind = "selected", id = arg, locked = false })
					end
				end
			elseif name == "lock" then
				if m.phase == "select" and not part.locked then
					local id = BattleSelect.resolve(part.pick or part.last, ctxFor(part))
					part.pick, part.locked = id, true
					send(part, { kind = "selected", id = id, locked = true })
				end
			elseif name == "rematch" then
				if
					m.phase == "matchResult"
					and not other(m, if part == m.parts.a then "a" else "b").left
				then
					part.rematch = true
					local foe = other(m, if part == m.parts.a then "a" else "b")
					send(part, { kind = "rematch", mine = true, theirs = foe.rematch or foe.bot })
					send(foe, { kind = "rematch", mine = foe.rematch, theirs = true })
				end
			elseif name == "leave" then
				leave(m, part, true)
			end
		end,
		playerRemoving = function(player: Player)
			PadSlots.leave(pads, player.UserId)
			local m = inMatch[player]
			if m then
				local part = if m.parts.a.player == player then m.parts.a else m.parts.b
				leave(m, part, false)
			end
			limiter.clear(player)
		end,
	}

	-- One loop for every match.
	RunService.Heartbeat:Connect(function(dt: number)
		for m in matches do
			local ok, err = pcall(update, m, dt)
			if not ok then
				warn("[Battle] match error, closing it: " .. tostring(err))
				closeMatch(m)
			end
		end
	end)

	return handle
end

return BattleService
