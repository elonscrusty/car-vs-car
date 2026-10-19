--!strict
-- A many-car match: "lastStanding" (8 cars, last one alive wins), "tag" (hot potato on the flat
-- field: pass IT on or blow up), "race" (laps round a track with jumps) or "soccer" (two teams, a giant
-- ball, goals on its own small field: SoccerArena, shared/SoccerField). One or two players, bots fill the rest. Same handle as Match,
-- so init.server treats both the same. The server owns everything: spawns, hits, eliminations,
-- ball, goals, winner. Rules and numbers: shared/Modes, shared/ModesConfig.
-- Flow: "ready" countdown -> everyone drives (no aiming) -> match end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BowlConfig = require(ReplicatedStorage.Shared.BowlConfig)
local BowlRules = require(ReplicatedStorage.Shared.BowlRules)
local BotLevels = require(ReplicatedStorage.Shared.BotLevels)
local BotNames = require(ReplicatedStorage.Shared.BotNames)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Fight = require(ReplicatedStorage.Shared.Fight)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)
local Modes = require(ReplicatedStorage.Shared.Modes)
local ModesConfig = require(ReplicatedStorage.Shared.ModesConfig)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local MovesRules = require(ReplicatedStorage.Shared.Moves)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Steer = require(ReplicatedStorage.Shared.Steer)
local SoccerField = require(ReplicatedStorage.Shared.SoccerField)
local SoccerFieldConfig = require(ReplicatedStorage.Shared.SoccerFieldConfig)
local SoccerBotRules = require(ReplicatedStorage.Shared.SoccerBotRules)
local Race = require(ReplicatedStorage.Shared.Race)
local RaceTrack = require(ReplicatedStorage.Shared.RaceTrack)
local RaceTrackConfig = require(ReplicatedStorage.Shared.RaceTrackConfig)
local SoccerBotConfig = require(ReplicatedStorage.Shared.SoccerBotConfig)
local SoccerFieldFlow = require(ReplicatedStorage.Shared.SoccerFieldFlow)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Autopilot = require(script.Parent.Autopilot)
local BotMoves = require(script.Parent.BotMoves)
local CarBuilder = require(script.Parent.CarBuilder)
local CarSanity = require(script.Parent.CarSanity)
local Dummy = require(script.Parent.Dummy)
local Impulse = require(script.Parent.Impulse)
local Match = require(script.Parent.Match)
local RaceArena = require(script.Parent.RaceArena)
local ModeFx = require(script.Parent.ModeFx)
local Telemetry = require(script.Parent.Telemetry)
local Moves = require(script.Parent.Moves)
local SoccerArena = require(script.Parent.SoccerArena)
local Specials = require(script.Parent.Specials)

local GroupMatch = {}

-- Same shape as Match.new. `mode` is "lastStanding" or "soccer".
function GroupMatch.new(
	participants: { Match.Participant },
	slot: number,
	remotes: Remotes.RemoteSet,
	mode: string
): Match.Handle
	local cfg = GameConfig
	local soccerOn = mode == "soccer"
	local tagOn = mode == "tag"
	local raceOn = mode == "race"
	local onField = soccerOn or tagOn -- both play on the small flat field (SoccerArena)
	local origin = Vector3.new(slot * cfg.Arena.slotSpacing, cfg.Arena.baseY, 0)
	local rng = Random.new()
	local total = Modes.carCount(mode)
	local teamSize = ModesConfig.Soccer.teamSize

	local destroyed = false
	local ending = false
	local phase = "ready" -- "ready" | "fight" | "matchEnd"
	local arena: Arena.Arena? = nil
	local cars: { CarBuilder.Car } = {}
	local maxHp: { number } = {}
	local spots: { Modes.Spot } = {}
	local gone: { [number]: boolean } = {}
	local clientDriven: { [number]: boolean } = {}
	local steerStates: { Steer.State } = {}
	local steerSmooth: { number } = {}
	local throttleSmooth: { number } = {}
	local moveStates: { Moves.State } = {}
	local botMem: { [number]: SoccerBotRules.Memory } = {}
	local lastHitAt: { [number]: number } = {} -- pair key -> time of the last counted hit
	local touchConns: { RBXScriptConnection } = {}
	local last = Modes.lastNew(total)
	local soccer = Modes.soccerNew()
	local tagCfg = ModesConfig.Tag
	local tag = Modes.tagNew(1, tagCfg.startFuse)
	local tagHudAt = 0
	local race = Race.new(total, RaceTrackConfig.laps, RaceTrack.count())
	local raceStarted = false
	local raceGoAt = 0
	local raceT0 = 0
	local raceHudAt = 0
	local raceShown = ""
	local raceDebugAt = 0
	local raceStuck: { [number]: { passed: number, since: number } } = {}
	local ball: Part? = nil
	local ballIdle = 0 -- seconds the ball has hardly moved (stuck check)
	local goldenGoal = false
	-- Soccer flow: "countdown" (cars frozen, 3-2-1), "play", "goal" (frozen, score banner).
	local soccerState = "countdown"
	local soccerUntil = 0
	local countdownShown = ""
	local stuckWarned = false
	local clockAt = 0
	local fightElapsed = 0
	local hudAt = 0
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local fightConn: RBXScriptConnection? = nil

	local function isHuman(i: number): boolean
		return participants[i] ~= nil and not gone[i]
	end

	local function teamOf(i: number): number
		return Modes.teamOf(i, teamSize)
	end

	local botNames: { [number]: string } = {}
	local function nameOf(i: number): string
		local p = participants[i]
		if p then
			return p.player.DisplayName
		end
		if not botNames[i] then -- a friendly random name, not just "BOT"
			local taken = {}
			for _, n in botNames do
				table.insert(taken, n)
			end
			botNames[i] = BotNames.pick(rng:NextInteger(1, 1000000), taken)
		end
		return botNames[i]
	end

	local function sendTo(i: number, update: Types.UiUpdate)
		local p = participants[i]
		if p and not gone[i] and not destroyed then
			remotes.UiUpdate:FireClient(p.player, update)
		end
	end

	local function sendAll(make: (i: number) -> Types.UiUpdate)
		for i = 1, #participants do
			sendTo(i, make(i))
		end
	end

	local function clearCars()
		table.clear(clientDriven)
		for _, c in touchConns do
			c:Disconnect()
		end
		table.clear(touchConns)
		for _, car in cars do
			car.model:Destroy()
		end
		table.clear(cars)
	end

	local function setAnchored(car: CarBuilder.Car, anchored: boolean)
		for _, part in car.model:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = anchored
			end
		end
	end

	local function flatOf(car: CarBuilder.Car): (number, number)
		local p = car.body.Position
		return p.X - origin.X, p.Z - origin.Z
	end

	-- ---- Match end -------------------------------------------------------------------------

	-- `won(i)` says whether car i's player won. Everyone sees the end screens.
	local function finish(won: (i: number) -> boolean, koText: string, focus: Vector3?)
		if ending or destroyed then
			return
		end
		ending = true
		phase = "matchEnd"
		sendAll(function()
			return { kind = "ko", text = koText, pos = focus }
		end)
		local currentArena = arena
		local dummy: BasePart? = nil
		if currentArena and focus then
			dummy = Dummy.launch(focus, currentArena.model)
		end
		sendAll(function(i)
			return { kind = "roundEnd", round = 1, youLost = not won(i), focus = dummy }
		end)
		task.delay(cfg.Match.roundEndDelay, function()
			if destroyed then
				return
			end
			for i, part in participants do
				local youWon = won(i)
				sendTo(i, { kind = "matchEnd", youWon = youWon })
				if part.onEndScreen and not gone[i] then
					part.onEndScreen()
				end
				task.delay(LobbyConfig.Rewards.endScreenSeconds, function()
					if not destroyed and not gone[i] then
						part.onFinished(youWon)
					end
				end)
			end
		end)
	end

	local function finishLast(winner: number)
		local pos = if winner > 0
				and cars[winner]
				and not cars[winner].dead
			then cars[winner].body.Position
			else origin + Vector3.new(0, 4, 0)
		finish(
			function(i)
				return i == winner
			end,
			if winner > 0
				then (if tagOn
					then "LAST ONE SAFE!"
					elseif raceOn then "WINNER!"
					else "LAST CAR STANDING!")
				else "DRAW!",
			pos
		)
	end

	local function finishSoccer(team: number)
		finish(function(i)
			return teamOf(i) == team
		end, if team > 0 then "GOAL! TEAM WINS!" else "DRAW!", origin + Vector3.new(0, 4, 0))
	end

	-- ---- Car tag: who is IT ------------------------------------------------------------------

	-- The glow on the IT car (a red Highlight); the old IT loses it.
	local function showIt()
		for i, car in cars do
			local glow = car.model:FindFirstChild("TagIt")
			if i == tag.it and not car.dead then
				if glow == nil then
					local h = Instance.new("Highlight")
					h.Name = "TagIt"
					local c = tagCfg.itColor
					h.FillColor = Color3.fromRGB(c[1], c[2], c[3])
					h.FillTransparency = 0.35
					h.OutlineColor = Color3.fromRGB(255, 230, 80)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = car.model
				end
			elseif glow then
				glow:Destroy()
			end
		end
	end

	-- A new round: a random alive car is IT, with a shorter fuse.
	local function nextRound()
		local it = Modes.tagNextIt(last, rng:NextNumber())
		if it == 0 then
			return
		end
		local fuse = Modes.tagFuse(tag.round + 1, tagCfg.startFuse, tagCfg.fuseStep, tagCfg.minFuse)
		Modes.tagNextRound(tag, it, fuse)
		showIt()
	end

	-- ---- Last car standing: eliminations and hits -------------------------------------------

	local function eliminate(car: CarBuilder.Car, text: string)
		if car.dead or not Modes.lastEliminate(last, car.idx) then
			return
		end
		car.dead = true
		car.hp = 0
		car.bar.set(0, maxHp[car.idx])
		car.bar.hide()
		local pos = car.body.Position
		local currentArena = arena
		local dummy: BasePart? = nil
		if currentArena then
			dummy = Dummy.launch(pos, currentArena.model)
		end
		sendAll(function(i)
			return { kind = "ko", text = if i == car.idx then "YOU ARE OUT!" else text, pos = pos }
		end)
		if isHuman(car.idx) then
			-- An eliminated player films their own crash dummy and stops driving.
			sendTo(car.idx, { kind = "roundEnd", round = 1, youLost = true, focus = dummy })
		end
		car.model:Destroy()
		local winner = Modes.lastWinner(last)
		if winner ~= 0 then
			finishLast(winner)
		elseif tagOn and tag.it == car.idx then
			nextRound() -- IT left the game: someone else gets the fuse
		end
	end

	local function resolveHit(a: CarBuilder.Car, b: CarBuilder.Car)
		if a.dead or b.dead or phase ~= "fight" then
			return
		end
		local offset = b.body.Position - a.body.Position
		if offset.Magnitude < 0.001 then
			return
		end
		local dir = offset.Unit
		local attacker, defender = a, b
		if Logic.attackerIndex(a.prevVel:Dot(dir), b.prevVel:Dot(-dir)) == 2 then
			attacker, defender = b, a
		end
		local rel = (a.prevVel - b.prevVel).Magnitude
		local dmg = Logic.impactDamage(
			rel,
			attacker.stats.damageMult,
			cfg.Damage.scale,
			cfg.Damage.minImpactSpeed
		)
		if dmg <= 0 then
			return
		end
		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		Telemetry.hit(participants)
		defender.bar.set(newHp, maxHp[defender.idx])
		local strength = Logic.hitStrength(rel, cfg.Feel.bigHitSpeed)
		local hitPos = (a.body.Position + b.body.Position) / 2
		sendAll(function(i)
			return {
				kind = "hit",
				pos = hitPos,
				strength = strength,
				damage = dmg,
				youHit = defender.idx == i,
			}
		end)
		local popSpeed, spinSpeed = BowlRules.smashPop(strength, BowlConfig.Smash)
		if popSpeed > 0 and not dead then
			Impulse.linear(defender.body, Vector3.yAxis * defender.body.AssemblyMass * popSpeed)
			defender.body.AssemblyAngularVelocity += Vector3.yAxis * spinSpeed
		end
		if attacker.stats.hitLift > 0 and not dead then
			Impulse.linear(
				defender.body,
				Vector3.yAxis * defender.body.AssemblyMass * attacker.stats.hitLift
			)
		end
		if dead then
			eliminate(defender, "K.O.!")
		end
	end

	local function onTouched(car: CarBuilder.Car, other: BasePart)
		if phase ~= "fight" or (mode ~= "lastStanding" and not tagOn) then
			return
		end
		local otherIdx = other:GetAttribute("CarIdx")
		if type(otherIdx) ~= "number" or otherIdx == car.idx then
			return
		end
		local enemy = cars[otherIdx]
		if enemy == nil then
			return
		end
		if tagOn then
			-- Only IT's bump counts: it passes IT on to the car it touched. No damage.
			if car.idx == tag.it and not enemy.dead and not car.dead then
				if Modes.tagPass(tag, car.idx, otherIdx, os.clock(), tagCfg.immuneSeconds) then
					showIt()
					sendAll(function(i)
						return {
							kind = "banner",
							text = if i == otherIdx then "YOU ARE IT!" else "TAGGED!",
							seconds = 1,
						}
					end)
				end
			end
			return
		end
		local key = math.min(car.idx, otherIdx) * 100 + math.max(car.idx, otherIdx)
		local now = os.clock()
		if not Logic.canHit(now, lastHitAt[key] or -math.huge, cfg.Damage.hitCooldown) then
			return
		end
		lastHitAt[key] = now
		resolveHit(car, enemy)
	end

	-- ---- Spawning ---------------------------------------------------------------------------

	-- Where a start spot sits: on the flat soccer field, or on the bowl surface.
	local function spotPosition(spot: Modes.Spot, lift: number): Vector3
		if onField or raceOn then
			return SoccerArena.spotPosition(origin, spot.x, spot.z, lift)
		end
		return ModeFx.spotPosition(origin, spot.x, spot.z, lift)
	end

	local function spawnCars()
		local a = arena :: Arena.Arena
		clearCars()
		spots = if soccerOn
			then SoccerField.spawnSpots(teamSize)
			elseif tagOn then SoccerField.spawnSpots(tagCfg.cars // 2)
			elseif raceOn then RaceTrack.grid(total)
			else Modes.ringSpots(total, ModesConfig.LastStanding.spawnRadius)
		for idx = 1, total do
			local part = participants[idx]
			local id = if part
				then part.carId
				else BotNames.pickCar(rng:NextInteger(1, 1000000), CarConfig.Order) :: string
			local stats = CarConfig.Cars[id]
			local spot = spots[idx]
			local pos = spotPosition(spot, stats.size[2] / 2 + 1.5)
			local car = CarBuilder.build(
				id,
				idx,
				CFrame.new(pos) * CFrame.Angles(0, spot.yaw, 0),
				a.model,
				nameOf(idx),
				part == nil,
				if part then part.appearance else nil,
				nil
			)
			local hp = if mode == "lastStanding"
				then stats.hp * ModesConfig.LastStanding.hpScale
				else stats.hp
			car.hp = hp
			maxHp[idx] = hp
			car.bar.set(hp, hp)
			if tagOn or raceOn then
				car.bar.hide() -- nobody loses HP in tag or the race
			end
			if soccerOn then
				local marker = car.model:FindFirstChild("Marker")
				local c = ModesConfig.Soccer.colors[teamOf(idx)]
				if marker and marker:IsA("BasePart") then
					marker.Color = Color3.fromRGB(c[1], c[2], c[3])
				end
				car.bar.hide() -- nobody loses HP in soccer
			end
			cars[idx] = car
			steerStates[idx] = Steer.newState()
			steerSmooth[idx] = 0
			throttleSmooth[idx] = 0
			moveStates[idx] = Moves.new()
		end
		local filter: { Instance } = {}
		for _, car in cars do
			table.insert(filter, car.model)
			for _, part in car.model:GetChildren() do
				if part:IsA("BasePart") and part.CanCollide then
					table.insert(
						touchConns,
						part.Touched:Connect(function(other)
							onTouched(car, other)
						end)
					)
				end
			end
		end
		rayParams.FilterDescendantsInstances = filter
	end

	local function parkCharacter(player: Player)
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if char and root and root:IsA("BasePart") then
			root.Anchored = true
			char:PivotTo(CFrame.new(origin + Vector3.new(0, -12, 0)))
		end
	end

	-- ---- Soccer ------------------------------------------------------------------------------

	local function resetBall()
		local b = ball
		if b == nil then
			return
		end
		b.AssemblyLinearVelocity = Vector3.zero
		b.AssemblyAngularVelocity = Vector3.zero
		b.Position = SoccerArena.ballPosition(origin)
		ballIdle = 0
		stuckWarned = false
	end

	local function banner(text: string, seconds: number)
		sendAll(function()
			return { kind = "banner", text = text, seconds = seconds }
		end)
	end

	-- Score line plus the match clock (or GOLDEN GOAL in overtime).
	local function soccerHud()
		local left = ModesConfig.Soccer.maxSeconds - fightElapsed
		local clock = SoccerFieldFlow.clockText(left, goldenGoal)
		sendAll(function(i)
			local mine = teamOf(i)
			return {
				kind = "modeInfo",
				text = string.format(
					"%s   YOU %d  -  %d THEM   (first to %d)",
					clock,
					soccer.goals[mine],
					soccer.goals[3 - mine],
					ModesConfig.Soccer.scoreToWin
				),
			}
		end)
	end

	-- Every car back on its start spot, standing still, ball back in the middle.
	local function resetPositions()
		for _, car in cars do
			local spot = spots[car.idx]
			car.model:PivotTo(CFrame.new(spotPosition(spot, 4)) * CFrame.Angles(0, spot.yaw, 0))
			car.body.AssemblyLinearVelocity = Vector3.zero
			car.body.AssemblyAngularVelocity = Vector3.zero
			car.prevVel = Vector3.zero
			CarSanity.rebase(car) -- a legit move: do not count it as a teleport
		end
		resetBall()
	end

	local handOver: () -> () -- forward: gives each human the network ownership of their car

	-- Frozen: nobody drives, the ball waits. `unfreeze` lets everyone go.
	local function freezeAll(on: boolean)
		for _, car in cars do
			setAnchored(car, on)
		end
		if ball then
			ball.Anchored = on
		end
		if not on then
			handOver()
		end
	end

	local function startCountdown(now: number, seconds: number)
		soccerState = "countdown"
		soccerUntil = now + seconds
		countdownShown = ""
	end

	local function stepSoccer(now: number, dt: number)
		local b = ball
		if b == nil or phase ~= "fight" then
			return
		end
		local cfgS = ModesConfig.Soccer
		if soccerState == "goal" then
			if now >= soccerUntil then
				resetPositions()
				startCountdown(now, cfgS.restartSeconds)
			end
			return
		end
		if soccerState == "countdown" then
			local remaining = soccerUntil - now
			local text = SoccerFieldFlow.countdownText(remaining)
			if text ~= countdownShown then
				countdownShown = text
				banner(text, if remaining <= 0 then cfgS.goSeconds else 1)
			end
			if remaining <= 0 then
				soccerState = "play"
				freezeAll(false)
				soccerHud()
			end
			return
		end
		local v = b.AssemblyLinearVelocity
		local vx, vy, vz = SoccerField.capVelocity(v.X, v.Y, v.Z, SoccerFieldConfig.ballMaxSpeed)
		if vx ~= v.X or vy ~= v.Y or vz ~= v.Z then
			b.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
		end
		local bx, bz = b.Position.X - origin.X, b.Position.Z - origin.Z
		local conceded = SoccerField.goalConceded(bx, bz)
		if conceded ~= 0 then
			local scorer = Modes.soccerGoal(soccer, conceded)
			local pos = b.Position
			sendAll(function(i)
				return {
					kind = "ko",
					text = if teamOf(i) == scorer then "GOAL!" else "THEY SCORED!",
					pos = pos,
				}
			end)
			sendAll(function(i)
				local mine = teamOf(i)
				return {
					kind = "banner",
					text = string.format(
						"YOU %d - %d THEM",
						soccer.goals[mine],
						soccer.goals[3 - mine]
					),
					seconds = cfgS.goalPause,
				}
			end)
			soccerHud()
			local winner = Modes.soccerWinner(soccer, cfgS.scoreToWin)
			if winner == 0 and goldenGoal then
				winner = scorer
			end
			if winner ~= 0 then
				finishSoccer(winner)
				return
			end
			-- Short celebration: everything freezes, then both teams are reset.
			soccerState = "goal"
			soccerUntil = now + cfgS.goalPause
			freezeAll(true)
			return
		end
		local stuck
		ballIdle, stuck = SoccerField.stuckStep(ballIdle, v.Magnitude, dt)
		if SoccerFieldFlow.stuckWarning(ballIdle) then
			if not stuckWarned then
				stuckWarned = true
				banner("BALL STUCK - RESETTING!", SoccerFieldConfig.stuckWarnSeconds)
			end
		else
			stuckWarned = false
		end
		if stuck or SoccerField.outOfBounds(bx, b.Position.Y - origin.Y, bz) then
			resetBall()
		end
	end

	-- ---- Driving -----------------------------------------------------------------------------

	local function limitSpeed(car: CarBuilder.Car): number
		local cap = math.max(
			cfg.Launch.maxSpeed,
			car.stats.maxSpeed * (1 + MovesConfig.Boost.speedBonus)
		) * cfg.Drive.speedCapSlack
		local v = car.body.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > cap then
			local keep = flat.Unit * cap
			car.body.AssemblyLinearVelocity = Vector3.new(keep.X, v.Y, keep.Z)
		end
		return cap
	end

	local function botLevel(): BotLevels.Level
		return BotLevels.get(if participants[1] then participants[1].botLevel else nil)
	end

	-- Last-standing bots hunt the nearest alive car. (Soccer bots drive in driveSoccerBot.)
	local function targetFor(car: CarBuilder.Car): CarBuilder.Car?
		local xs, zs = {}, {}
		for i, c in cars do
			xs[i], zs[i] = flatOf(c)
		end
		local who = Modes.nearestAlive(last, xs, zs, car.idx)
		return if who ~= 0 then cars[who] else nil
	end

	-- Nearest car on the other side (for special moves a player presses).
	local function enemyOf(car: CarBuilder.Car): CarBuilder.Car?
		local best, who = math.huge, nil :: CarBuilder.Car?
		for _, c in cars do
			if not c.dead and c ~= car and (not soccerOn or teamOf(c.idx) ~= teamOf(car.idx)) then
				local d = (c.body.Position - car.body.Position).Magnitude
				if d < best then
					best, who = d, c
				end
			end
		end
		return who
	end

	-- A soccer bot's frame: SoccerBotRules decides (keeper / chaser, boost, ability), the same
	-- manual drive a player gets carries it out. Level: the lone player's bot level.
	local function driveSoccerBot(car: CarBuilder.Car, now: number, dt: number)
		local b = ball
		if b == nil then
			return
		end
		local team = teamOf(car.idx)
		local bots: { boolean } = {}
		for k = 1, teamSize do
			bots[k] = not isHuman((team - 1) * teamSize + k)
		end
		local keeper = SoccerFieldFlow.keeperSlot(bots)
		local look = car.body.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude < 0.1 then
			return
		end
		fwd = fwd.Unit
		local cx, cz = flatOf(car)
		local vel = car.body.AssemblyLinearVelocity
		local bvel = b.AssemblyLinearVelocity
		local rival = enemyOf(car)
		local rx, rz = 0, 0
		if rival then
			rx, rz = flatOf(rival)
		end
		local ability = Specials.abilityOf(car)
		local state = moveStates[car.idx]
		local mem = botMem[car.idx]
		if mem == nil then
			mem = SoccerBotRules.newMemory()
			botMem[car.idx] = mem
		end
		local out = SoccerBotRules.step(mem, {
			now = now,
			seed = car.idx,
			team = team,
			isKeeper = keeper ~= 0 and (car.idx - 1) % teamSize + 1 == keeper,
			x = cx,
			z = cz,
			fx = fwd.X,
			fz = fwd.Z,
			speed = vel.X * fwd.X + vel.Z * fwd.Z,
			maxSpeed = car.stats.maxSpeed,
			bx = b.Position.X - origin.X,
			bz = b.Position.Z - origin.Z,
			bvx = bvel.X,
			bvz = bvel.Z,
			hasRival = rival ~= nil,
			rx = rx,
			rz = rz,
			boostReady = MovesRules.ready(state.boostAt, MovesConfig.Boost.cooldown, now),
			specialReady = ability ~= nil and Specials.cooldownLeft(car, now) <= 0,
			kind = if ability then ability.kind else "",
			radius = if ability then ability.radius else 0,
			level = botLevel(),
			useMoves = GameConfig.Ai.useMoves,
		}, dt)
		local mods = BotMoves.apply(car, rival, state, dt, rayParams, out.boost, out.special)
		Autopilot.stepManual(car, out.steer, out.throttle, dt, rayParams, mods)
	end

	-- Tag: a bot that is not IT runs away from IT (bent toward the middle near the walls).
	local function driveTagRunner(car: CarBuilder.Car, dt: number)
		local it = cars[tag.it]
		if it == nil or it.dead then
			return
		end
		local look = car.body.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude < 0.1 then
			return
		end
		fwd = fwd.Unit
		local x, z = flatOf(car)
		local ix, iz = flatOf(it)
		local d = Modes.tagFleeDir(x, z, ix, iz, SoccerField.halfLength(), SoccerField.halfWidth())
		local angle = Modes.signedAngle(fwd.X, fwd.Z, d.x, d.z)
		local steer = -math.clamp(angle / SoccerBotConfig.steerFullRad, -1, 1)
		local gas = math.max(0.3, math.cos(angle))
		Autopilot.stepManual(car, steer, gas, dt, rayParams, nil)
	end

	-- Tag: the fuse, the HUD, and cars that left the field coming back.
	local function stepTag(now: number, dt: number)
		for _, car in cars do
			local x, z = flatOf(car)
			if not car.dead and SoccerField.outOfBounds(x, car.body.Position.Y - origin.Y, z) then
				local spot = spots[car.idx]
				car.model:PivotTo(CFrame.new(spotPosition(spot, 4)) * CFrame.Angles(0, spot.yaw, 0))
				car.body.AssemblyLinearVelocity = Vector3.zero
				car.body.AssemblyAngularVelocity = Vector3.zero
				CarSanity.rebase(car)
			end
		end
		if Modes.tagTick(tag, dt) then
			local boomCar = cars[tag.it]
			if boomCar and not boomCar.dead then
				eliminate(boomCar, "BOOM!")
			end
			return
		end
		if now - tagHudAt >= tagCfg.hudSeconds then
			tagHudAt = now
			local left = math.ceil(tag.fuse)
			local n = Modes.lastAliveCount(last)
			sendAll(function(i)
				local text = if i == tag.it
					then string.format("YOU ARE IT! Bump someone! %ds  (%d cars)", left, n)
					else string.format(
						"RUN! %s is IT  %ds  (%d cars)",
						nameOf(tag.it),
						left,
						n
					)
				return { kind = "modeInfo", text = text }
			end)
		end
	end

	-- ---- Crazy Race ------------------------------------------------------------------------

	local function respawnRacer(car: CarBuilder.Car)
		local spot = RaceTrack.respawn(Race.lastPassed(race, car.idx), car.idx)
		-- Same lift as a fresh spawn (tall cars would sink into the ground at a lower one).
		local lift = car.stats.size[2] / 2 + 1.5
		car.model:PivotTo(CFrame.new(spotPosition(spot, lift)) * CFrame.Angles(0, spot.yaw, 0))
		car.body.AssemblyLinearVelocity = Vector3.zero
		car.body.AssemblyAngularVelocity = Vector3.zero
		CarSanity.rebase(car) -- a legit move: do not count it as a teleport
	end

	-- A race bot steers at the next waypoint, leaning toward the one after it near the corner.
	local function driveRaceBot(car: CarBuilder.Car, dt: number)
		local look = car.body.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude < 0.1 then
			return
		end
		fwd = fwd.Unit
		local x, z = flatOf(car)
		local c = race.cars[car.idx]
		local a, b = RaceTrack.point(c.next), RaceTrack.point(c.next + 1)
		local dist = math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
		local lean = math.clamp(1 - dist / 70, 0, 0.6)
		local tx, tz = a.x + (b.x - a.x) * lean, a.z + (b.z - a.z) * lean
		local angle = Modes.signedAngle(fwd.X, fwd.Z, tx - x, tz - z)
		local steer = -math.clamp(angle / SoccerBotConfig.steerFullRad, -1, 1)
		local gas = math.clamp(math.cos(angle) * 1.2, 0.45, 1)
		Autopilot.stepManual(car, steer, gas, dt, rayParams, nil)
	end

	-- Race: the 3-2-1, checkpoints and laps, falls, stuck bots, the HUD, time up.
	local function stepRace(now: number, dt: number)
		if not raceStarted then
			local left = math.ceil(raceGoAt - now)
			if left > 0 then
				local shown = tostring(left)
				if shown ~= raceShown then
					raceShown = shown
					banner(shown, 1)
				end
				return
			end
			raceStarted = true
			raceT0 = now
			for _, car in cars do
				setAnchored(car, false)
				pcall(function()
					car.body:SetNetworkOwner(nil)
				end)
			end
			handOver()
			banner("GO!", 0.8)
			return
		end
		local toNext: { number } = {}
		for _, car in cars do
			local x, z = flatOf(car)
			local c = race.cars[car.idx]
			local wp = RaceTrack.point(c.next)
			if
				Race.reach(
					race,
					car.idx,
					x,
					z,
					wp.x,
					wp.z,
					RaceTrackConfig.checkpointRadius,
					now - raceT0
				) and c.finishedAt ~= nil
			then
				if RaceTrackConfig.debug then
					warn(string.format("RACE END: car %d finished at %.1fs", car.idx, now - raceT0))
				end
				finishLast(car.idx)
				return
			end
			wp = RaceTrack.point(c.next)
			toNext[car.idx] = math.sqrt((wp.x - x) ^ 2 + (wp.z - z) ^ 2)
			-- Fell off the world, or a bot that has not moved on for a while: back to the last gate.
			local fell = car.body.Position.Y < origin.Y + RaceTrackConfig.fallBelow
			local mark = raceStuck[car.idx]
			if
				mark == nil
				or mark.passed ~= c.passed
				or car.body.AssemblyLinearVelocity.Magnitude > 4
			then
				mark = { passed = c.passed, since = now }
				raceStuck[car.idx] = mark
			end
			local stuck = not isHuman(car.idx) and now - mark.since > RaceTrackConfig.stuckSeconds
			if fell or stuck then
				respawnRacer(car)
				raceStuck[car.idx] = { passed = c.passed, since = now }
			end
		end
		fightElapsed += dt
		if RaceTrackConfig.debug and now - raceDebugAt >= 5 then
			raceDebugAt = now
			for _, car in cars do
				local c = race.cars[car.idx]
				local x, z = flatOf(car)
				local v = car.body.AssemblyLinearVelocity
				warn(
					string.format(
						"RACE t=%.0f car %d (%s%s) lap %d next %d passed %d at (%.0f,%.0f) speed %.0f",
						now - raceT0,
						car.idx,
						car.id,
						if isHuman(car.idx) then " HUMAN" else "",
						c.lap,
						c.next,
						c.passed,
						x,
						z,
						v.Magnitude
					)
				)
			end
		end
		if fightElapsed >= RaceTrackConfig.maxSeconds then
			if RaceTrackConfig.debug then
				warn("RACE END: time up")
			end
			local w = Race.leader(race, toNext)
			finishLast(w)
			return
		end
		if now - raceHudAt >= RaceTrackConfig.hudSeconds then
			raceHudAt = now
			local pos = Race.positions(race, toNext)
			sendAll(function(i)
				local c = race.cars[i]
				return {
					kind = "modeInfo",
					text = string.format(
						"LAP %d/%d   %s of %d",
						c.lap,
						race.laps,
						Race.ordinal(pos[i]),
						total
					),
				}
			end)
		end
	end

	-- Gives each human the physics of their own car (they drive it); the server drives the rest.
	function handOver()
		task.delay(0.15, function()
			if destroyed or phase ~= "fight" then
				return
			end
			for i, car in cars do
				local part = participants[i]
				if part and not gone[i] and not car.dead and typeof(part.player) == "Instance" then
					parkCharacter(part.player)
					local ok = pcall(function()
						car.body:SetNetworkOwner(part.player)
					end)
					if ok then
						clientDriven[i] = true
						car.model:SetAttribute("CarId", car.id)
						car.model:SetAttribute("DriverUserId", part.player.UserId)
					end
				end
			end
		end)
	end

	local function startFight()
		phase = "fight"
		fightElapsed = 0
		if soccerOn then
			-- Cars stay frozen (anchored) through the 3-2-1; the ball waits in the middle.
			startCountdown(os.clock(), ModesConfig.Soccer.kickoffSeconds)
		elseif raceOn then
			raceGoAt = os.clock() + RaceTrackConfig.goSeconds -- cars stay frozen until GO
			for _, car in cars do
				setAnchored(car, true)
			end
		else
			if tagOn then
				tag = Modes.tagNew(Modes.tagNextIt(last, rng:NextNumber()), tagCfg.startFuse)
				showIt()
			end
			for _, car in cars do
				setAnchored(car, false)
				pcall(function()
					car.body:SetNetworkOwner(nil)
				end)
			end
			handOver()
		end
		if soccerOn and arena then
			ball = SoccerArena.ball(arena.model, origin)
			ball.Anchored = true
			soccerHud()
		end
		sendAll(function(i)
			local ability = Specials.abilityOf(cars[i])
			return {
				kind = "fight",
				auto = false,
				round = 1,
				ability = if ability then ability.name else nil,
			}
		end)
	end

	fightConn = RunService.Heartbeat:Connect(function(dt)
		if phase ~= "fight" or ending then
			return
		end
		local now = os.clock()
		-- Soccer: nobody drives while the kickoff countdown or a goal celebration is on.
		local driving = (not soccerOn or soccerState == "play") and (not raceOn or raceStarted)
		for _, car in cars do
			if driving and not car.dead then
				local target = if soccerOn then nil else targetFor(car)
				local human = isHuman(car.idx)
				if human and clientDriven[car.idx] then
					local cap = limitSpeed(car)
					if
						not CarSanity.step(car, origin.Y, cap, dt)
						and not onField
						and not raceOn
					then
						eliminate(car, "RING OUT!") -- kept breaking movement limits
						if ending then
							return
						end
					end
				elseif human then
					local raw = Steer.current(steerStates[car.idx], now, cfg.Steer.staleSeconds)
					local eased = Steer.smooth(steerSmooth[car.idx], raw, dt, cfg.Steer.smoothRate)
					steerSmooth[car.idx] = eased
					local rawGas =
						Steer.currentThrottle(steerStates[car.idx], now, cfg.Steer.staleSeconds)
					local gas =
						Steer.smooth(throttleSmooth[car.idx], rawGas, dt, cfg.Steer.smoothRate)
					throttleSmooth[car.idx] = gas
					local mods = Moves.mods(moveStates[car.idx], car, eased, dt, now)
					Autopilot.stepManual(car, eased, gas, dt, rayParams, mods)
				elseif soccerOn then
					driveSoccerBot(car, now, dt)
				elseif raceOn then
					driveRaceBot(car, dt)
				elseif tagOn and car.idx ~= tag.it then
					driveTagRunner(car, dt)
				elseif target then
					local level = botLevel()
					local botMods = BotMoves.prepare(
						car,
						target,
						moveStates[car.idx],
						dt,
						rayParams,
						origin,
						level
					)
					Autopilot.step(car, target, dt, rayParams, origin, level, botMods)
				end
			end
		end
		for _, car in cars do
			if not car.dead then
				car.prevVel = car.body.AssemblyLinearVelocity
			end
		end

		if raceOn then
			stepRace(now, dt)
			return
		end

		if tagOn then
			stepTag(now, dt)
			if ending then
				return
			end
			fightElapsed += dt
			if fightElapsed >= tagCfg.maxSeconds then
				-- Time up: the alive car nearest the middle wins.
				local best, w = math.huge, 0
				for i, car in cars do
					if not car.dead then
						local x, z = flatOf(car)
						local d = x * x + z * z
						if d < best then
							best, w = d, i
						end
					end
				end
				finishLast(w)
			end
			return
		end

		if soccerOn then
			stepSoccer(now, dt)
			if soccerState ~= "play" then
				return
			end
			-- A car that leaves the field comes back at its start spot (nobody is out in soccer).
			for _, car in cars do
				local x, z = flatOf(car)
				if
					not car.dead
					and SoccerField.outOfBounds(x, car.body.Position.Y - origin.Y, z)
				then
					local spot = spots[car.idx]
					car.model:PivotTo(
						CFrame.new(spotPosition(spot, 4)) * CFrame.Angles(0, spot.yaw, 0)
					)
					car.body.AssemblyLinearVelocity = Vector3.zero
					car.body.AssemblyAngularVelocity = Vector3.zero
					CarSanity.rebase(car) -- a legit move: do not count it as a teleport
				end
			end
			fightElapsed += dt
			if now - clockAt >= ModesConfig.Soccer.hudSeconds then
				clockAt = now
				soccerHud()
			end
			if fightElapsed >= ModesConfig.Soccer.maxSeconds and not goldenGoal then
				local w = Modes.soccerTimeoutWinner(soccer)
				if w ~= 0 then
					finishSoccer(w)
					return
				end
				goldenGoal = true
				sendAll(function()
					return { kind = "ko", text = "NEXT GOAL WINS!", pos = origin }
				end)
				soccerHud()
			end
			return
		end

		-- Last car standing: ring-outs, then the clock.
		for _, car in cars do
			if not car.dead then
				local x, z = flatOf(car)
				if
					Fight.isRingOut(
						math.sqrt(x * x + z * z),
						cfg.Arena.rimRadius,
						cfg.RingOut.margin
					) or car.body.Position.Y < origin.Y - cfg.Match.outOfBoundsDrop
				then
					eliminate(car, "RING OUT!")
					if ending then
						return
					end
				end
			end
		end
		fightElapsed += dt
		if fightElapsed >= ModesConfig.LastStanding.maxSeconds then
			local hps: { number } = {}
			for i, car in cars do
				hps[i] = car.hp
			end
			local w = Modes.lastTimeoutWinner(last, hps)
			if w == 0 then
				-- A tie: the alive car closest to the middle takes it.
				local best = math.huge
				for i, car in cars do
					if not car.dead then
						local x, z = flatOf(car)
						local d = x * x + z * z
						if d < best then
							best, w = d, i
						end
					end
				end
			end
			finishLast(w)
			return
		end
		if now - hudAt >= ModesConfig.LastStanding.hudSeconds then
			hudAt = now
			local n = Modes.lastAliveCount(last)
			sendAll(function()
				return { kind = "modeInfo", text = string.format("%d CARS LEFT", n) }
			end)
		end
	end)

	local function indexOf(player: Player): number?
		for i, part in participants do
			if part.player == player then
				return i
			end
		end
		return nil
	end

	local function begin()
		if destroyed or arena == nil then
			return
		end
		local a = arena :: Arena.Arena
		local wait = if soccerOn then ModesConfig.Soccer.readySeconds else cfg.Mode.readySeconds
		sendAll(function(i)
			local other = cars[if i == 1 then 2 else 1]
			return {
				kind = "ready",
				round = 1,
				yourCar = cars[i].id,
				enemyCar = if other then other.id else cars[i].id,
				enemyName = if soccerOn
					then "THE OTHER TEAM"
					elseif tagOn or raceOn then "ALL CARS"
					else "EVERYONE",
				center = a.center,
				carPos = cars[i].body.Position,
				seconds = wait,
				soccer = soccerOn,
			}
		end)
		sendAll(function()
			return {
				kind = "modeInfo",
				text = ModesConfig.Names[mode] .. ": " .. ModesConfig.Blurbs[mode],
			}
		end)
		task.delay(wait, function()
			if not destroyed and phase == "ready" then
				startFight()
			end
		end)
	end

	local handle: Match.Handle = {
		launch = function() end, -- no aiming in the many-car modes
		steer = function(player: Player, value: any, throttle: any?)
			if destroyed or phase ~= "fight" then
				return
			end
			local i = indexOf(player)
			if i == nil or gone[i] then
				return
			end
			Steer.set(steerStates[i], value, os.clock(), throttle)
		end,
		action = function(player: Player, name: any)
			if destroyed or phase ~= "fight" or not MovesRules.isMove(name, MovesConfig.Names) then
				return
			end
			local i = indexOf(player)
			if i == nil or gone[i] or cars[i] == nil or cars[i].dead then
				return
			end
			local enemy = enemyOf(cars[i])
			if enemy == nil then
				return
			end
			local seconds = Moves.press(moveStates[i], name, cars[i], enemy, rayParams, os.clock())
			if seconds ~= nil and seconds > 0 then
				sendTo(i, { kind = "move", move = name, seconds = seconds })
			end
		end,
		playerLeft = function(player: Player)
			local i = indexOf(player)
			if i == nil or gone[i] then
				return
			end
			gone[i] = true
			local car = cars[i]
			if car == nil or car.dead then
				return
			end
			if (mode == "lastStanding" or tagOn) and phase ~= "matchEnd" then
				eliminate(car, "LEFT THE GAME")
			else
				-- Soccer: a bot takes over the car (the server drives it again).
				clientDriven[i] = nil
				pcall(function()
					car.body:SetNetworkOwner(nil)
				end)
			end
		end,
		destroy = function()
			destroyed = true
			if fightConn then
				fightConn:Disconnect()
			end
			clearCars()
			if ball then
				ball:Destroy()
			end
			if arena then
				arena.model:Destroy()
			end
		end,
	}

	arena = if onField
		then SoccerArena.build(origin)
		elseif raceOn then RaceArena.build(origin)
		else Arena.build(origin)
	spawnCars()
	begin()
	return handle
end

return GroupMatch
