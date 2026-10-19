--!strict
-- The 1v1 auto-battle: queue, car pick, preparation, automatic fight, round and match results,
-- rewards, rematch and leaving. The server decides everything; clients only show screens and send
-- (queue, select, lock, leave...). One Heartbeat drives every match through explicit phases, so two
-- fights, pick screens or reward handlers can never overlap:
--   select -> prep -> fight -> result -> (select again | matchResult) -> rematch (select) | closed
-- Matches are small tables in `matches`; closing one frees its arena, cars, shells and players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleBrain = require(ReplicatedStorage.Shared.BattleBrain)
local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleQueue = require(ReplicatedStorage.Shared.BattleQueue)
local BattleRecap = require(ReplicatedStorage.Shared.BattleRecap)
local BattleSelect = require(ReplicatedStorage.Shared.BattleSelect)
local BattleSeries = require(ReplicatedStorage.Shared.BattleSeries)
local BattleSetup = require(ReplicatedStorage.Shared.BattleSetup)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Progress = require(ReplicatedStorage.Shared.Progress)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ResultRewards = require(ReplicatedStorage.Shared.ResultRewards)
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
	spot: number, -- opening choice: start spot (-1 far, 0 middle, 1 near)
	aim: number, -- opening choice: launch aim (-1 right, 0 straight, 1 left)
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
	koOutcome: string?, -- the round result waiting for the knock-out finish to play
	final: boolean, -- the announced final phase has begun
	momentum: boolean, -- the momentum prototype fight (else the steering fight)
}

local BattleService = {}

export type Handle = {
	play: (player: Player) -> (),
	cancel: (player: Player) -> (),
	action: (player: Player, name: string, arg: any) -> (),
	playerRemoving: (player: Player) -> (),
	isBusy: (player: Player) -> boolean,
}

local T = BattleConfig.Timing
local BOT_NAME = "Test Bot"

function BattleService.start(opts: {
	remotes: Remotes.RemoteSet,
	sendProfile: (player: Player) -> (),
}): Handle
	local remotes = opts.remotes
	local queue = BattleQueue.new()
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
		end
	end

	local function release(part: Part, toLobby: boolean)
		local pl = part.player
		if pl == nil or pl.Parent == nil then
			return
		end
		local hum = if pl.Character then pl.Character:FindFirstChildOfClass("Humanoid") else nil
		if hum and part.savedSpeed ~= nil then
			hum.WalkSpeed = part.savedSpeed
			hum.JumpPower = 50
		end
		part.savedSpeed = nil
		pl:SetAttribute("InBattle", nil)
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
			if not part.bot then
				send(part, { kind = "setup", spot = part.spot, aim = part.aim })
			end
			if part.bot then
				local ids = BattleConfig.activeOrder()
				part.pick = ids[math.random(1, #ids)]
				part.spot, part.aim = math.random(-1, 1), math.random(-1, 1)
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
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			-- sides swap every round so both spawn spots get used
			local spawnSide = if (m.series.round % 2 == 1) == (side == "a") then "a" else "b"
			local pos, facing = arena.spawnPoint(spawnSide, part.spot, part.aim)
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
		m.phase, m.t = "prep", 0
		for _, side in sides() do
			local part = (m.parts :: any)[side] :: Part
			local opp = other(m, side)
			send(part, {
				kind = "prep",
				momentum = m.momentum,
				seconds = T.prepSeconds,
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
				me = { id = part.pick, name = part.name, label = labelFor(part) },
				opp = { id = opp.pick, name = opp.name, label = labelFor(opp), bot = opp.bot },
			})
		end
		return true
	end

	local function startFight(m: Match)
		for _, side in sides() do
			local car = (m.cars :: any)[side] :: BattleCar.Car
			BattleCar.arm(car, BattleBrain.new(car.fighter.id, car.L, arenaTable, m.momentum))
			BattleCar.launch(car, m.momentum)
		end
		m.phase, m.t, m.hudT = "fight", 0, 0
		m.final = false
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

	local function sendHit(m: Match, pos: Vector3, big: boolean)
		for _, side in sides() do
			send((m.parts :: any)[side], { kind = "hit", pos = pos, big = big })
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

	local function fireShell(m: Match, car: BattleCar.Car, foe: BattleCar.Car)
		local muzzle = car.muzzle
		if muzzle == nil then
			return
		end
		local cfg = BattleConfig.Cannon
		local pos = muzzle.WorldPosition
		-- flat aim along the car's facing, tilted to the foe's body height so a low car is not overshot
		local flat = car.lastForward
		local toFoe = foe.body.Position - pos
		local run = math.max(toFoe.Magnitude, 1)
		local rise = math.clamp(toFoe.Y / run, -0.5, 0.5)
		local dir = Vector3.new(flat.X, rise, flat.Z).Unit
		local ball = Instance.new("Part")
		ball.Name = "Shell"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * (0.42 * car.L)
		ball.Material = Enum.Material.Neon
		ball.Color = Color3.fromRGB(255, 160, 40)
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
		})
		car.stats.shots += 1
	end

	-- Moves every shell; returns damage dealt to each side this step.
	local function stepShells(m: Match, dt: number, dmg: { a: number, b: number })
		local arena = m.arena :: BattleArena.Arena
		for i = #m.shells, 1, -1 do
			local s = m.shells[i]
			local step = s.dir * s.speed * dt
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local include: { Instance } = table.clone(arena.solids)
			table.insert(include, s.foe.body)
			params.FilterDescendantsInstances = include
			local hit = workspace:Spherecast(s.pos, 0.15 * s.owner.L, step, params)
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
			elseif hit then
				done = true
				if hit.Instance == s.foe.body then
					landed = true
					s.owner.stats.shotHits += 1
					if s.foe.side == "a" then
						dmg.a += BattleConfig.Cannon.damage
					else
						dmg.b += BattleConfig.Cannon.damage
					end
					BattleCar.knock(
						s.foe,
						s.dir,
						BattleConfig.Cannon.knockSpeed,
						BattleConfig.Cannon.knockStagger
					)
					sendHit(m, hit.Position, false)
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
				local cruise = car.fighter.cruiseL * car.L
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
				BattleCar.drive(car, out, dt)
				BattleCar.lunge(car, dt)
				if out.fire then
					fireShell(m, car, foe)
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
					sendHit(m, foe.body.Position, out.event == "Ram hit")
				end
				if out.event == "Ram hit" or out.event == "Ram missed" then
					car.stats.charges += 1
				end
				if out.event then
					sendEvent(m, car.side, out.event)
				end
			end
		end
		stepShells(m, dt, dmg)
		-- all damage of this update lands together, so a double knock-out is a draw
		a.hp = math.max(0, a.hp - dmg.a)
		b.hp = math.max(0, b.hp - dmg.b)
		local outcome =
			BattleSeries.roundOutcome(a.hp, a.maxHp, b.hp, b.maxHp, m.t >= T.fightSeconds)
		if outcome then
			for _, side in sides() do
				send((m.parts :: any)[side], hudFor(m, side))
			end
			if a.hp <= 0 or b.hp <= 0 then
				-- knock-out: both cars stop, the loser is wrecked, then the result shows
				clearShells(m)
				for _, car in cars do
					car.brain = nil
					if car.hp <= 0 then
						BattleCar.wreck(car)
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
			if m.t >= T.prepSeconds then
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
			if m.t >= T.koSeconds then
				endRound(m, (m.koOutcome :: any) or "draw")
			end
		elseif m.phase == "result" then
			if m.t >= T.resultSeconds then
				if m.series.over then
					settle(m)
				else
					startSelect(m)
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
			koOutcome = nil,
			final = false,
			momentum = if momentum == nil then BattleConfig.defaultMomentum else momentum,
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
		isBusy = function(player: Player): boolean
			return inMatch[player] ~= nil or BattleQueue.has(queue, player.UserId)
		end,
		play = function(player: Player)
			if inMatch[player] or BattleQueue.has(queue, player.UserId) then
				return
			end
			if Profiles.get(player) == nil then
				return
			end
			BattleQueue.join(queue, player.UserId, os.clock())
			remotes.BattleUpdate:FireClient(
				player,
				{ kind = "queue", searching = true, studioBot = isStudio }
			)
		end,
		cancel = function(player: Player)
			if BattleQueue.leave(queue, player.UserId) then
				remotes.BattleUpdate:FireClient(player, { kind = "queue", searching = false })
			end
		end,
		action = function(player: Player, name: string, arg: any)
			if not limiter.allow(player, os.clock()) then
				return
			end
			if name == "queueBot" then
				-- Studio only. The opponent is labeled Test Bot everywhere.
				if isStudio and not inMatch[player] and Profiles.get(player) ~= nil then
					BattleQueue.leave(queue, player.UserId)
					createMatch(humanPart(player), botPart(), arg == "momentum")
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
			elseif name == "setup" then
				if m.phase == "select" and not part.locked and type(arg) == "table" then
					part.spot, part.aim = BattleSetup.clean((arg :: any).spot, (arg :: any).aim)
					send(part, { kind = "setup", spot = part.spot, aim = part.aim })
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
			BattleQueue.leave(queue, player.UserId)
			local m = inMatch[player]
			if m then
				local part = if m.parts.a.player == player then m.parts.a else m.parts.b
				leave(m, part, false)
			end
			limiter.clear(player)
		end,
	}

	-- One loop for the line and for every match.
	RunService.Heartbeat:Connect(function(dt: number)
		for _, id in BattleQueue.expire(queue, os.clock(), T.queueSeconds) do
			local pl = Players:GetPlayerByUserId(id)
			if pl then
				remotes.BattleUpdate:FireClient(
					pl,
					{ kind = "queue", searching = false, timedOut = true }
				)
			end
		end
		while true do
			local ida, idb = BattleQueue.popPair(queue)
			if ida == nil or idb == nil then
				break
			end
			local pa, pb = Players:GetPlayerByUserId(ida), Players:GetPlayerByUserId(idb)
			if pa and pb and Profiles.get(pa) and Profiles.get(pb) then
				createMatch(humanPart(pa), humanPart(pb))
			else
				-- one of them is gone: the other goes back in line
				for _, pl in { pa, pb } do
					if pl then
						BattleQueue.join(queue, pl.UserId, os.clock())
					end
				end
				break
			end
		end
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
