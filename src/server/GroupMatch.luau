--!strict
-- A many-car match: "lastStanding" (ModesConfig.LastStanding.cars cars, last one alive wins), "tag" (hot potato on the flat
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
local PickupsConfig = require(ReplicatedStorage.Shared.PickupsConfig)
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
local SoccerBoost = require(ReplicatedStorage.Shared.SoccerBoost)
local SoccerChaos = require(ReplicatedStorage.Shared.SoccerChaos)
local SoccerOrbs = require(ReplicatedStorage.Shared.SoccerOrbs)
local BrawlRules = require(ReplicatedStorage.Shared.BrawlRules)
local CarSmash = require(script.Parent.CarSmash)
local Crown = require(script.Parent.Crown)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local Buffs = require(script.Parent.Buffs)
local Pickups = require(script.Parent.Pickups)
local Podium = require(script.Parent.Podium)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local Damage = require(ReplicatedStorage.Shared.Damage)
local SoccerStats = require(ReplicatedStorage.Shared.SoccerStats)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Atmosphere = require(script.Parent.Atmosphere)
local Autopilot = require(script.Parent.Autopilot)
local BotMoves = require(script.Parent.BotMoves)
local CarBuilder = require(script.Parent.CarBuilder)
local CarSanity = require(script.Parent.CarSanity)
local Dummy = require(script.Parent.Dummy)
local GroupResults = require(script.Parent.GroupResults)
local Impulse = require(script.Parent.Impulse)
local Match = require(script.Parent.Match)
local Profiles = require(script.Parent.Profiles)
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
	local brawlOn = mode == "lastStanding" -- the car fight: flat floor, last car alive
	local brawlArena = table.clone(cfg.Arena)
	for k, v in ModesConfig.LastStanding.Arena do
		brawlArena[k] = v
	end
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
	local raceProg: { [number]: Race.Progress } = {}
	local raceCanReset: { [number]: boolean } = {}
	local raceResetAt: { [number]: number } = {}
	local racePlace: { number } = {} -- finishing place of every car, set when the race ends
	local tagsMade: { [number]: number } = {} -- tag: cars each car tagged
	local itemsUsed: { [number]: number } = {} -- fight: item boxes each car drove over
	local outAt: { [number]: number } = {} -- tag / last standing: match seconds when a car fell
	local rematchAsked: { [number]: boolean } = {}
	local allOutAt: number? = nil -- tag: every human is out, the round ends at this time
	local finalWinner = 0
	local stats = SoccerStats.new()
	local pads = SoccerBoost.new()
	local chaos = SoccerChaos.new(ModesConfig.Soccer.Chaos)
	local chaosRng = Random.new()
	local orbs = SoccerOrbs.new(ModesConfig.Soccer.Orbs)
	local orbParts: { BasePart } = {}
	local kickUntil: { [number]: number } = {} -- car idx -> when its SUPER KICK runs out
	local markUntil: number? = nil -- soccer: when the KickoffMark attribute goes off (math.huge = until play)
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
	-- The car fight: best of 3 rounds, shield items, walls that close in.
	local roundNo = 1
	local roundWins: { [number]: number } = {}
	local pickups: Pickups.Handle? = nil
	local wallParts: { { part: BasePart, dir: Vector3, y: number } } = {}
	local safeRadius = brawlArena.rimRadius
	local startNextRound: (() -> ())? = nil -- defined after begin()
	local tutorial: { [number]: Tutorial.State } = {} -- fight: a new player's first-fight lessons
	local lastHitBy: { [number]: { by: number, at: number } } = {} -- car -> who hit it last, and when
	local kos: { [number]: number } = {} -- fight: knock-outs made over the whole match
	local bounties: { [number]: number } = {} -- fight: crown cars knocked out
	local shrinkAt = 0

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
		if pickups then
			pickups.destroy()
			pickups = nil
		end
		for _, car in cars do
			Buffs.clear(car)
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
	local function humanFlags(): { boolean }
		local flags: { boolean } = {}
		for i = 1, total do
			flags[i] = isHuman(i)
		end
		return flags
	end

	local function clearOutFlags()
		for _, part in participants do
			pcall(function()
				part.player:SetAttribute("MatchOut", nil)
			end)
		end
	end

	-- The result for human `i` (audit #24, #28, #32): see GroupResults for the fields.
	local function resultFor(i: number, youWon: boolean): GroupResults.Result
		local r: GroupResults.Result = { mode = mode, won = youWon, coinsBonus = 0 }
		if soccerOn then
			local goals = stats.goals[i] or 0
			r.goals = goals
			r.ownGoals = stats.ownGoals[i] or 0
			r.touches = stats.touches[i] or 0
			r.coinsBonus = SoccerStats.goalBonus(goals, ModesConfig.Soccer.goalCoins)
		elseif raceOn then
			local place = racePlace[i] or total
			r.place, r.placeOf = place, total
			r.coinsBonus = Race.placeBonus(
				place,
				ModesConfig.Race.placeCoins,
				if youWon then LobbyConfig.Rewards.winCoins else LobbyConfig.Rewards.loseCoins
			)
		else
			local place = Modes.lastPlace(last, i)
			if last.alive[i] and i ~= finalWinner then
				place = 2 -- alive at time up but not the winner
			end
			if i == finalWinner then
				place = 1 -- best of 3: the match winner may not have won the last round
			end
			r.place, r.placeOf = place, total
			r.survivedSeconds = outAt[i] or fightElapsed
			r.tags = tagsMade[i] or 0
			if brawlOn then
				local lc = ModesConfig.LastStanding
				r.kos = kos[i] or 0
				r.items = itemsUsed[i] or 0
				r.coinsBonus = (if youWon then lc.winBonus else 0)
					+ (lc.placeCoins[place] or 0)
					+ (kos[i] or 0) * lc.koCoins
					+ (bounties[i] or 0) * lc.bountyCoins
			end
		end
		return r
	end

	local function finish(
		won: (i: number) -> boolean,
		koText: string,
		focus: Vector3?,
		focusPart: BasePart?
	)
		if ending or destroyed then
			return
		end
		ending = true
		phase = "matchEnd"
		clearOutFlags()
		if soccerOn and ModesConfig.Soccer.logStats then
			print(SoccerStats.summary(stats, humanFlags(), total))
		end
		sendAll(function()
			return { kind = "ko", text = koText, pos = focus }
		end)
		local currentArena = arena
		local dummy: BasePart? = focusPart
		if dummy == nil and currentArena and focus then
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
				local result = resultFor(i, youWon)
				GroupResults.set(part.player, result) -- the lobby reads it once (GroupResults.take)
				pcall(function()
					for name, value in GroupResults.attributes(result) do
						part.player:SetAttribute(name, value)
					end
				end)
				-- Coins so far (base + this fight's bonuses) so the result screen is not empty;
				-- the lobby's final number replaces it a moment later.
				local base = if youWon
					then LobbyConfig.Rewards.winCoins
					else LobbyConfig.Rewards.loseCoins
				sendTo(i, {
					kind = "matchEnd",
					youWon = youWon,
					coins = base,
					bonus = result.coinsBonus or 0,
				})
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

	local function showLesson(i: number, step: Tutorial.Step?)
		local part = participants[i]
		if part == nil then
			return
		end
		pcall(function()
			part.player:SetAttribute("TutorialStep", if step then step.id else nil)
		end)
		if step then
			local text = step.text
			if step.id == "ability" then
				local ability = Specials.abilityOf(cars[i])
				text = Tutorial.abilityLine(if ability then ability.name else nil)
			end
			sendTo(i, { kind = "modeInfo", text = text })
		end
	end

	local function lessonEvent(i: number, event: string)
		local st = tutorial[i]
		if st == nil then
			return
		end
		local nextStep = Tutorial.event(st, event, fightElapsed)
		if nextStep then
			showLesson(i, nextStep)
		end
	end

	local function finishLast(roundWinner: number)
		local winner = roundWinner
		if brawlOn and roundWinner > 0 and not ending then
			-- Best of 3: a round win is not the match yet.
			roundWins[roundWinner] = (roundWins[roundWinner] or 0) + 1
			local rc = ModesConfig.LastStanding.Rounds
			winner =
				BrawlRules.matchWinner(roundWins, roundNo, rc.winsNeeded, rc.maxRounds, roundWinner)
			-- Show the true result at once: one car left and the new round wins (no stale "2 LEFT").
			sendAll(function(i)
				local mine = cars[i]
				return {
					kind = "fightHud",
					carsLeft = 1,
					wins = roundWins[i] or 0,
					round = roundNo,
					hp = if mine then math.max(0, mine.hp) else 0,
					hpMax = maxHp[i],
				}
			end)
			if winner == 0 then
				phase = "roundBreak"
				local who = nameOf(roundWinner)
				sendAll(function()
					return {
						kind = "banner",
						text = string.format("ROUND %d: %s WINS!", roundNo, who),
						seconds = rc.breakSeconds - 3,
					}
				end)
				-- A clear countdown into the next round (carter's review: the reset felt abrupt).
				for step = 1, 3 do
					task.delay(rc.breakSeconds - 4 + step, function()
						if destroyed or ending then
							return
						end
						sendAll(function()
							return {
								kind = "banner",
								text = "NEXT ROUND IN " .. tostring(4 - step),
								seconds = 1,
							}
						end)
					end)
				end
				task.delay(rc.breakSeconds, function()
					if not destroyed and not ending and startNextRound then
						startNextRound()
					end
				end)
				return
			end
		end
		finalWinner = winner
		if brawlOn and winner > 0 and isHuman(winner) then
			Crown.set(participants[winner].player.UserId) -- worn in the next fight
		end
		local pos = if winner > 0
				and cars[winner]
				and not cars[winner].dead
			then cars[winner].body.Position
			else origin + Vector3.new(0, 4, 0)
		-- The fight winner stands on a podium and spins while fireworks burst (carter's pick).
		local podiumTop: BasePart? = nil
		local winCar = cars[winner]
		if brawlOn and winner > 0 and winCar and not winCar.dead and arena then
			podiumTop = Podium.celebrate(
				arena.model,
				origin,
				winCar,
				cfg.Match.roundEndDelay + LobbyConfig.Rewards.endScreenSeconds
			)
		end
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
			pos,
			podiumTop
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
			-- Data for every client (audit #29): who is IT and when the fuse ends (server clock).
			local isIt = i == tag.it and not car.dead
			car.model:SetAttribute("TagIt", if isIt then true else nil)
			car.model:SetAttribute(
				"TagFuseEndsAt",
				if isIt then workspace:GetServerTimeNow() + tag.fuse else nil
			)
			car.model:SetAttribute("TagFuseLeft", if isIt then math.ceil(tag.fuse) else nil)
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
		outAt[car.idx] = fightElapsed
		local killer: CarBuilder.Car? = nil -- the car that smashed this one out (the camera follows it)
		if brawlOn and text ~= "LEFT THE GAME" then
			local credit = lastHitBy[car.idx]
			if credit and os.clock() - credit.at <= ModesConfig.LastStanding.creditSeconds then
				local k = cars[credit.by]
				if k and not k.dead and k ~= car then
					killer = k
				end
				kos[credit.by] = (kos[credit.by] or 0) + 1
				if car.model:GetAttribute("Crown") then
					bounties[credit.by] = (bounties[credit.by] or 0) + 1
				end
			end
		end
		car.bar.set(0, maxHp[car.idx])
		car.bar.hide()
		local pos = car.body.Position
		local currentArena = arena
		local dummy: BasePart? = nil
		if currentArena then
			dummy = Dummy.launch(pos, currentArena.model)
		end
		-- Everyone else reads WHO is out and who did it (plain text only for the other modes).
		local shown = text
		if brawlOn and (text == "K.O.!" or text == "RING OUT!") then
			local who = nameOf(car.idx)
			if killer then
				shown = who .. " SMASHED BY " .. nameOf(killer.idx)
			elseif text == "RING OUT!" then
				shown = who .. " FELL OFF!"
			else
				shown = who .. " IS OUT!"
			end
		end
		sendAll(function(i)
			return { kind = "ko", text = if i == car.idx then "YOU ARE OUT!" else shown, pos = pos }
		end)
		if isHuman(car.idx) then
			-- An eliminated player films their own crash dummy and stops driving.
			-- Out: watch whoever smashed you (their car), else your own crash dummy.
			local watch: BasePart? = if killer then killer.body else dummy
			sendTo(car.idx, { kind = "roundEnd", round = 1, youLost = true, focus = watch })
			-- "Out" state (audit #28): the player spectates; MatchOut lets the client show it.
			local part = participants[car.idx]
			Telemetry.eliminated(part.player)
			pcall(function()
				part.player:SetAttribute("MatchOut", true)
			end)
			sendTo(car.idx, {
				kind = "modeInfo",
				text = "WATCHING THE FIGHT. TAP LOBBY TO LEAVE",
			})
		end
		if currentArena and text ~= "LEFT THE GAME" then
			CarSmash.blowUp(car, currentArena.model, rng) -- a player who leaves just vanishes
		end
		car.model:Destroy()
		local winner = Modes.lastWinner(last)
		if winner ~= 0 then
			finishLast(winner)
		elseif tagOn and tag.it == car.idx then
			nextRound() -- IT left the game: someone else gets the fuse
		end
		-- Tag: no human left to play = end the round soon instead of watching bots for minutes.
		if tagOn and not ending and allOutAt == nil and Modes.allHumansOut(last, humanFlags()) then
			allOutAt = os.clock() + tagCfg.allOutEndSeconds
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
		if brawlOn then
			-- Side and back hits hurt more; a SHIELD soaks the whole hit.
			local toAttacker = attacker.body.Position - defender.body.Position
			local look = defender.body.CFrame.LookVector
			local zone = Damage.zone(
				Damage.cosFlat(look.X, look.Z, toAttacker.X, toAttacker.Z),
				CombatConfig.Zones
			)
			dmg = Buffs.absorb(defender, dmg * Damage.zoneMult(zone, CombatConfig.Zones))
			if dmg <= 0 then
				return
			end
		end
		lastHitBy[defender.idx] = { by = attacker.idx, at = os.clock() }
		lessonEvent(attacker.idx, "hit")
		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		Telemetry.hit(participants)
		defender.bar.set(newHp, maxHp[defender.idx])
		local strength = Logic.hitStrength(rel, cfg.Feel.bigHitSpeed)
		local hitPos = (a.body.Position + b.body.Position) / 2
		-- the damage number floats over the car that got hit
		local victimPos = defender.body.Position
		sendAll(function(i)
			return {
				kind = "hit",
				pos = hitPos,
				damagePos = victimPos,
				strength = strength,
				damage = dmg,
				youHit = defender.idx == i,
			}
		end)
		local popSpeed, spinSpeed = BowlRules.smashPop(strength, BowlConfig.Smash)
		if brawlOn then
			-- Big hit: the car that got hit is LAUNCHED away from the attacker and bits fly off.
			local hit = ModesConfig.LastStanding.Hit
			local push, up, spin = BrawlRules.launch(strength, hit)
			push *= BrawlRules.massFactor(attacker.body.AssemblyMass, defender.body.AssemblyMass) -- heavy cars push harder
			if push > 0 and not dead then
				local away = defender.body.Position - attacker.body.Position
				away = Vector3.new(away.X, 0, away.Z)
				away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
				Impulse.linear(
					defender.body,
					(away * push + Vector3.yAxis * up) * defender.body.AssemblyMass
				)
				defender.body.AssemblyAngularVelocity += Vector3.new(0, spin, 0)
			end
			local currentArena = arena
			if currentArena and not dead then
				local n = BrawlRules.scrapCount(strength, hit)
				if n > 0 then
					CarSmash.scrap(defender, n, currentArena.model, rng, 0.6 + strength)
				end
				if BrawlRules.peels(strength, hit) then
					CarSmash.peel(defender, currentArena.model, rng)
				end
			end
		elseif popSpeed > 0 and not dead then
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
			if
				car.idx == tag.it
				and not enemy.dead
				and not car.dead
				and not Specials.tagImmune(enemy)
			then
				if Modes.tagPass(tag, car.idx, otherIdx, os.clock(), tagCfg.immuneSeconds) then
					tagsMade[car.idx] = (tagsMade[car.idx] or 0) + 1
					if isHuman(car.idx) then
						Telemetry.firstScore(participants[car.idx].player, "tag")
					end
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
		if onField or raceOn or brawlOn then
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
		if raceOn then
			-- A player's first matches start on the front row (audit #33); bots fill the rest.
			local front: { boolean } = {}
			local humans: { boolean } = {}
			for idx = 1, total do
				local part = participants[idx]
				humans[idx] = part ~= nil
				local profile = if part then Profiles.get(part.player) else nil
				front[idx] = part ~= nil
					and RaceTrack.humanFront(
						if profile then profile.matches else 0,
						RaceTrackConfig.frontRowMatches
					)
			end
			local slotOf = RaceTrack.startOrder(total, front, humans)
			local grid = spots
			spots = {}
			for idx = 1, total do
				spots[idx] = grid[slotOf[idx]]
			end
		end
		for idx = 1, total do
			local part = participants[idx]
			local id = if part
				then part.carId
				else BotNames.pickCar(rng:NextInteger(1, 1000000), CarConfig.Order) :: string
			local carStats = CarConfig.Cars[id]
			local spot = spots[idx]
			local pos = spotPosition(spot, carStats.size[2] / 2 + 1.5)
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
				then carStats.hp * ModesConfig.LastStanding.hpScale
				else carStats.hp
			car.hp = hp
			maxHp[idx] = hp
			car.model:SetAttribute("RoundWins", roundWins[idx] or 0)
			if part then
				car.model:SetAttribute("OwnerUserId", part.player.UserId) -- the client draws a ring under its own car
			end
			if brawlOn and part and Crown.has(part.player.UserId) then
				Crown.attach(car.model, car.body, carStats.size[2] / 2 + 3)
			end
			car.bar.set(hp, hp)
			if brawlOn then
				car.bar.compact() -- carter: names and big bars covered the cars
			end
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

	-- Your own car carries KickoffMark for the first seconds of every kickoff (audit #16). The
	-- client reads it with DriverUserId to draw the ring / arrow; the server only sets the data.
	local function markHumans(on: boolean)
		for i, car in cars do
			if isHuman(i) and not car.dead then
				car.model:SetAttribute("KickoffMark", if on then true else nil)
			end
		end
	end

	local function startCountdown(now: number, seconds: number)
		markHumans(true)
		markUntil = math.huge
		soccerState = "countdown"
		soccerUntil = now + seconds
		countdownShown = ""
	end

	-- Boost pads: a car on a lit pad gets its BOOST ready again; the pad dims until it is lit again.
	local function stepPads(now: number)
		local model = if arena then arena.model else nil
		for _, car in cars do
			if not car.dead then
				local x, z = flatOf(car)
				local taken = SoccerBoost.take(pads, x, z, now)
				if taken ~= 0 then
					moveStates[car.idx].boostAt = -math.huge
					SoccerStats.pad(stats, car.idx)
					car.model:SetAttribute("BoostPadAt", workspace:GetServerTimeNow())
				end
			end
		end
		if model then
			for i = 1, SoccerBoost.count() do
				local pad = model:FindFirstChild("BoostPad" .. i)
				if pad and pad:IsA("BasePart") then
					pad.Transparency = if SoccerBoost.lit(pads, i, now) then 0.15 else 0.85
				end
			end
		end
	end

	-- SUPER KICK orbs: glowing balls on the floor; drive over one, your next touch shoots the ball.
	local function stepOrbs(now: number)
		local model = if arena then arena.model else nil
		local oc = ModesConfig.Soccer.Orbs
		if model and #orbParts == 0 then
			for i, spot in oc.spots do
				local o = Instance.new("Part")
				o.Name = "KickOrb" .. i
				o.Shape = Enum.PartType.Ball
				o.Size = Vector3.one * 4
				o.Color = Color3.fromRGB(oc.color[1], oc.color[2], oc.color[3])
				o.Material = Enum.Material.Neon
				o.Anchored = true
				o.CanCollide = false
				o.CanQuery = false
				o.Position = origin + Vector3.new(spot.x, 3.5, spot.z)
				o.Parent = model
				orbParts[i] = o
			end
		end
		for _, car in cars do
			if not car.dead then
				local x, z = flatOf(car)
				if SoccerOrbs.take(orbs, oc, x, z, now) ~= 0 then
					kickUntil[car.idx] = now + oc.holdSeconds
					car.model:SetAttribute("SuperKick", true)
					if isHuman(car.idx) then
						banner("SUPER KICK! HIT THE BALL!", 1.5)
					end
				end
			end
		end
		for i, o in orbParts do
			o.Transparency = if SoccerOrbs.lit(orbs, i, now) then 0.1 else 0.9
		end
		for idx, untilAt in kickUntil do
			if now >= untilAt then
				kickUntil[idx] = nil
				cars[idx].model:SetAttribute("SuperKick", nil)
			end
		end
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
				markUntil = now + cfgS.markSeconds
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
			local _, ownBy = SoccerStats.goal(stats, conceded, teamSize)
			for i, part in participants do
				if isHuman(i) and (stats.goals[i] or 0) > 0 then
					Telemetry.firstScore(part.player, "goal")
				end
			end
			local pos = b.Position
			sendAll(function(i)
				-- An own goal says so (audit #26) and never costs coins: the team still gets the point.
				return {
					kind = "ko",
					text = SoccerStats.goalText(teamOf(i), scorer, ownBy ~= 0),
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
		-- Stats (audit #19) and boost pads (audit #20): touches by distance, idle time per car.
		local ballRadius = SoccerFieldConfig.ballDiameter / 2
		for _, car in cars do
			if not car.dead then
				local off = car.body.Position - b.Position
				local half = math.max(car.stats.size[1], car.stats.size[3]) / 2
				if
					SoccerStats.isTouching(
						off.X,
						off.Y,
						off.Z,
						ballRadius,
						half,
						SoccerFieldConfig.touchSlack
					)
				then
					SoccerStats.touch(stats, car.idx, now, cfgS.touchCooldown)
					if kickUntil[car.idx] then
						kickUntil[car.idx] = nil
						car.model:SetAttribute("SuperKick", nil)
						local kx, ky, kz = SoccerOrbs.kick(cfgS.Orbs, -off.X, -off.Z)
						b.AssemblyLinearVelocity = Vector3.new(kx, ky, kz)
					end
				end
				local cv = car.body.AssemblyLinearVelocity
				SoccerStats.idleStep(
					stats,
					car.idx,
					Vector3.new(cv.X, 0, cv.Z).Magnitude,
					dt,
					SoccerFieldConfig.statsIdleSpeed
				)
			end
		end
		stepPads(now)
		stepOrbs(now)
		local mu = markUntil
		if mu ~= nil and now >= mu then
			markUntil = nil
			markHumans(false)
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

	local function tagTimeoutWinner(): number
		local xs: { number }, zs: { number } = {}, {}
		for i, car in cars do
			if not car.dead then
				xs[i], zs[i] = flatOf(car)
			end
		end
		return Modes.tagTimeoutWinner(last, xs, zs)
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
			local itCar = cars[tag.it]
			if itCar and not itCar.dead then
				itCar.model:SetAttribute("TagFuseLeft", left) -- everyone can show the fuse (audit #29)
			end
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

	-- A race bot steers at the next waypoint.
	local function driveRaceBot(car: CarBuilder.Car, dt: number)
		local look = car.body.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude < 0.1 then
			return
		end
		fwd = fwd.Unit
		local x, z = flatOf(car)
		local c = race.cars[car.idx]
		-- Aim straight at the next gate: the checkpoint test then switches to the one after it.
		local wp = RaceTrack.point(c.next)
		local tx, tz = wp.x, wp.z
		local angle = Modes.signedAngle(fwd.X, fwd.Z, tx - x, tz - z)
		local steer = -math.clamp(angle / SoccerBotConfig.steerFullRad, -1, 1)
		local gas = math.clamp(math.cos(angle) * 1.2, 0.45, 1)
		Autopilot.stepManual(car, steer, gas, dt, rayParams, nil)
	end

	-- The race is over: every car's place (1..N) for the result, and each human is told theirs
	-- ("2ND OF 6", audit #32) instead of only win / lose.
	local function raceFinish()
		local toNext: { number } = {}
		for _, car in cars do
			local x, z = flatOf(car)
			local wp = RaceTrack.point(race.cars[car.idx].next)
			toNext[car.idx] = math.sqrt((wp.x - x) ^ 2 + (wp.z - z) ^ 2)
		end
		racePlace = Race.positions(race, toNext)
		for i, part in participants do
			if isHuman(i) then
				Telemetry.firstScore(part.player, "finish")
			end
		end
		sendAll(function(i)
			return {
				kind = "banner",
				text = string.format(
					"%s OF %d",
					string.upper(Race.ordinal(racePlace[i] or total)),
					total
				),
				seconds = 3,
			}
		end)
	end

	-- Race: the 3-2-1, checkpoints and laps, falls, stuck cars, the HUD, time up.
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
			local reached = Race.reach(
				race,
				car.idx,
				x,
				z,
				wp.x,
				wp.z,
				RaceTrackConfig.checkpointRadius,
				now - raceT0
			)
			if reached and c.finishedAt ~= nil then
				if RaceTrackConfig.debug then
					warn(string.format("RACE END: car %d finished at %.1fs", car.idx, now - raceT0))
				end
				raceFinish()
				finishLast(car.idx)
				return
			end
			if reached and isHuman(car.idx) then
				-- Checkpoint feedback (audit #36): the flash says the gate counted.
				sendTo(car.idx, {
					kind = "banner",
					text = Race.checkpointText(
						Race.lastPassed(race, car.idx),
						race.count,
						c.lap,
						race.laps
					),
					seconds = 0.9,
				})
			end
			wp = RaceTrack.point(c.next)
			toNext[car.idx] = math.sqrt((wp.x - x) ^ 2 + (wp.z - z) ^ 2)
			-- Fell off the world / flew out (cheat guard) / no progress for a while: back to the last gate.
			local fell =
				RaceTrack.outOfWorld(x, car.body.Position.Y - origin.Y, z, RaceTrackConfig.ceiling)
			local prog = raceProg[car.idx]
			if prog == nil then
				prog = Race.progressNew(now)
				raceProg[car.idx] = prog
			end
			local noProgress = Race.progressStep(
				prog,
				c.passed,
				toNext[car.idx],
				now,
				RaceTrackConfig.progressGain
			)
			local human = isHuman(car.idx)
			-- The client may show a RESET button while this attribute is on (audit #34).
			local canReset = human
				and Race.canManualReset(
					noProgress,
					now - (raceResetAt[car.idx] or -math.huge),
					RaceTrackConfig.resetButtonSeconds,
					0
				)
			if canReset ~= (raceCanReset[car.idx] == true) then
				raceCanReset[car.idx] = canReset
				car.model:SetAttribute("RaceCanReset", if canReset then true else nil)
			end
			if
				fell
				or Race.shouldReset(
					noProgress,
					human,
					RaceTrackConfig.stuckSeconds,
					RaceTrackConfig.humanStuckSeconds
				)
			then
				respawnRacer(car)
				raceProg[car.idx] = Race.progressNew(now)
				raceResetAt[car.idx] = now
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
			raceFinish()
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
				-- Never a human first (audit #27) when a bot is in the match.
				local first = if tagCfg.firstItBot
					then Modes.tagFirstIt(last, humanFlags(), rng:NextNumber())
					else Modes.tagNextIt(last, rng:NextNumber())
				tag = Modes.tagNew(first, tagCfg.startFuse)
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
		table.clear(tutorial)
		if brawlOn and roundNo == 1 then
			for i, part in participants do
				local profile = Profiles.get(part.player)
				if profile and profile.matches == 0 and not gone[i] then
					tutorial[i] = Tutorial.new()
				end
			end
		end
		if brawlOn and arena then
			pickups = Pickups.start(arena, cars, rng, function(car, update)
				if update.kind == "buff" and update.buff == "shield" then
					car.model:SetAttribute("Shielded", (update.seconds or 0) > 0 or nil)
				end
				sendTo(car.idx, update)
			end, function(car, kind)
				itemsUsed[car.idx] = (itemsUsed[car.idx] or 0) + 1
				if kind == "repair" and not car.dead then
					local top = maxHp[car.idx]
					car.hp = math.min(top, car.hp + top * PickupsConfig.repair.fraction)
					car.bar.set(car.hp, top)
				end
			end, ModesConfig.LastStanding.Items)
		end
		sendAll(function(i)
			local ability = Specials.abilityOf(cars[i])
			return {
				kind = "fight",
				auto = false,
				round = roundNo,
				wins = roundWins[i] or 0,
				carsLeft = total,
				hp = maxHp[i],
				hpMax = maxHp[i],
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
			if allOutAt ~= nil and now >= allOutAt then
				finishLast(tagTimeoutWinner()) -- every human is out: no dead time (audit #28)
				return
			end
			if fightElapsed >= tagCfg.maxSeconds then
				-- Time up: the alive car nearest the middle wins.
				finishLast(tagTimeoutWinner())
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
			local chaosKind = SoccerChaos.step(chaos, ModesConfig.Soccer.Chaos, fightElapsed)
			if chaosKind == "boostAll" then
				SoccerBoost.reset(pads)
				for _, car in cars do
					moveStates[car.idx].boostAt = -math.huge
					car.model:SetAttribute("BoostPadAt", workspace:GetServerTimeNow())
				end
				banner("BOOST FOR EVERYONE!", 2)
			elseif chaosKind == "blast" and ball then
				local a = chaosRng:NextNumber(0, math.pi * 2)
				local cc = ModesConfig.Soccer.Chaos
				ball.AssemblyLinearVelocity = Vector3.new(
					math.cos(a) * cc.blastSpeed,
					cc.blastLift,
					math.sin(a) * cc.blastSpeed
				)
				banner("BALL BLAST!", 2)
			end
			if now - clockAt >= ModesConfig.Soccer.hudSeconds then
				clockAt = now
				soccerHud()
			end
			if
				SoccerStats.suddenDeathNow(
					soccer.goals[1],
					soccer.goals[2],
					fightElapsed,
					ModesConfig.Soccer.suddenDeathAt,
					goldenGoal
				)
			then
				goldenGoal = true -- 0-0 for too long: the next goal wins (audit #25)
				sendAll(function()
					return { kind = "ko", text = "SUDDEN DEATH! NEXT GOAL WINS!", pos = origin }
				end)
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
		if brawlOn then
			-- Walls close in over time; items run out.
			safeRadius = BrawlRules.safeRadius(
				fightElapsed,
				brawlArena.rimRadius,
				ModesConfig.LastStanding.Shrink
			)
			if now - shrinkAt >= 0.2 then
				shrinkAt = now
				for _, w in wallParts do
					w.part.CFrame = CFrame.new(
						origin.X + w.dir.X * (safeRadius + 0.5),
						w.y,
						origin.Z + w.dir.Z * (safeRadius + 0.5)
					) * w.part.CFrame.Rotation
				end
				if arena then
					arena.model:SetAttribute("SafeRadius", safeRadius)
				end
			end
			for _, car in cars do
				if not car.dead then
					Buffs.tick(car, dt)
				end
			end
			for i, st in tutorial do
				local step = Tutorial.tick(st, fightElapsed)
				if step then
					showLesson(i, step)
				elseif Tutorial.finished(st) then
					tutorial[i] = nil
					showLesson(i, nil)
				end
			end
		end
		for _, car in cars do
			if not car.dead then
				local x, z = flatOf(car)
				if
					Fight.isRingOut(
						Fight.edgeDistance(x, z, brawlOn and brawlArena.square == true),
						if brawlOn then safeRadius else cfg.Arena.rimRadius,
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
			for i = 1, total do
				-- Numbers for the fight HUD (cars left, my round wins); words stay free for the lessons.
				local mine = cars[i]
				sendTo(i, {
					kind = "fightHud",
					carsLeft = n,
					wins = roundWins[i] or 0,
					round = roundNo,
					hp = if mine then math.max(0, mine.hp) else 0,
					hpMax = maxHp[i],
				})
			end
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
		for _, part in participants do
			pcall(function()
				for _, name in GroupResults.attributeNames do
					part.player:SetAttribute(name, nil) -- a fresh match starts without the last result
				end
			end)
		end
		local wait = if soccerOn then ModesConfig.Soccer.readySeconds else cfg.Mode.readySeconds
		sendAll(function(i)
			local other = cars[if i == 1 then 2 else 1]
			return {
				kind = "ready",
				round = roundNo,
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

	startNextRound = function()
		if destroyed or ending then
			return
		end
		roundNo += 1
		clearOutFlags()
		last = Modes.lastNew(total)
		table.clear(outAt)
		table.clear(lastHitAt)
		fightElapsed = 0
		safeRadius = brawlArena.rimRadius
		for _, w in wallParts do
			w.part.CFrame = CFrame.new(
				origin.X + w.dir.X * (safeRadius + 0.5),
				w.y,
				origin.Z + w.dir.Z * (safeRadius + 0.5)
			) * w.part.CFrame.Rotation
		end
		-- The wreckage from last round is swept away on purpose: a clean floor for the new round.
		if arena then
			for _, d in arena.model:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("Scrap") == true then
					d:Destroy()
				end
			end
		end
		spawnCars() -- every car is fully fixed again
		phase = "ready"
		if arena then
			arena.model:SetAttribute("Round", roundNo)
		end
		begin()
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
			Telemetry.firstInput(player)
			Steer.set(steerStates[i], value, os.clock(), throttle)
		end,
		action = function(player: Player, name: any)
			if destroyed or phase ~= "fight" then
				return
			end
			-- Race: RESET puts a stuck car back at its last gate (the client shows the button
			-- after 3 s without progress; the server checks the time and a cooldown itself).
			if name == "reset" and raceOn then
				local i = indexOf(player)
				local car = if i then cars[i] else nil
				if i == nil or gone[i] or car == nil or car.dead or not raceStarted then
					return
				end
				local now = os.clock()
				local prog = raceProg[i]
				local noProgress = if prog then now - prog.since else 0
				if
					Race.canManualReset(
						noProgress,
						now - (raceResetAt[i] or -math.huge),
						RaceTrackConfig.resetButtonSeconds,
						RaceTrackConfig.resetCooldown
					)
				then
					respawnRacer(car)
					raceProg[i] = Race.progressNew(now)
					raceResetAt[i] = now
				end
				return
			end
			-- Tag: an eliminated player asks for the next round right away (server note; the
			-- round ends as soon as every human is out).
			if name == "rematch" and tagOn then
				local i = indexOf(player)
				if i and not gone[i] and cars[i] and cars[i].dead then
					rematchAsked[i] = true
				end
				return
			end
			if not MovesRules.isMove(name, MovesConfig.Names) then
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
				lessonEvent(i, name)
				if name == "boost" then
					-- Data for the boost meter: it refills until this server time.
					cars[i].model:SetAttribute(
						"BoostReadyAt",
						workspace:GetServerTimeNow() + seconds
					)
					cars[i].model:SetAttribute("BoostSeconds", seconds)
				end
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
			if Modes.leaverRule(mode) == "eliminate" and phase ~= "matchEnd" then
				eliminate(car, "LEFT THE GAME")
			else
				-- Soccer, tag, race: a bot takes over the car (the server drives it again).
				clientDriven[i] = nil
				car.model:SetAttribute("DriverUserId", nil)
				car.model:SetAttribute("KickoffMark", nil)
				car.model:SetAttribute("RaceCanReset", nil)
				pcall(function()
					car.body:SetNetworkOwner(nil)
				end)
				-- Tag: no human left to play = end soon.
				if tagOn and allOutAt == nil and Modes.allHumansOut(last, humanFlags()) then
					allOutAt = os.clock() + tagCfg.allOutEndSeconds
				end
			end
		end,
		destroy = function()
			destroyed = true
			clearOutFlags()
			for _, part in participants do
				pcall(function()
					for _, name in GroupResults.attributeNames do
						part.player:SetAttribute(name, nil)
					end
				end)
			end
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
			if brawlOn then
				Atmosphere.day()
			end
		end,
	}

	arena = if onField
		then SoccerArena.build(origin, soccerOn)
		elseif raceOn then RaceArena.build(origin)
		else Arena.build(origin, if brawlOn then brawlArena else nil)
	if brawlOn then
		Atmosphere.night()
	end
	if arena then
		arena.model:SetAttribute("GameMode", mode) -- Specials reads it: ability meaning per mode
		arena.model:SetAttribute("Round", roundNo)
		if brawlOn and brawlArena.square ~= true then
			-- The walls the shrink pushes in (a square arena has fixed walls) (low lip round the floor edge).
			for _, w in arena.model:GetChildren() do
				if w:IsA("BasePart") and w.Name == "Wall" then
					local d = Vector3.new(w.Position.X - origin.X, 0, w.Position.Z - origin.Z)
					if d.Magnitude > 1 then
						table.insert(wallParts, { part = w, dir = d.Unit, y = w.Position.Y })
					end
				end
			end
		end
	end
	spawnCars()
	begin()
	return handle
end

return GroupMatch
