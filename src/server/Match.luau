--!strict
-- One match: one or two players (the other car is a bot). The server owns everything: cars,
-- launches, damage, winner. Flow: everyone aims at the same time (drag to launch) -> all launch
-- together -> bot cars drive themselves (Autopilot); human cars drive forward on their own and
-- the player steers (Steer remote). Cars ram until one car is out of HP (or time is up).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local Build = require(ReplicatedStorage.Shared.Build)
local BowlConfig = require(ReplicatedStorage.Shared.BowlConfig)
local BowlRules = require(ReplicatedStorage.Shared.BowlRules)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Fight = require(ReplicatedStorage.Shared.Fight)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Steer = require(ReplicatedStorage.Shared.Steer)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Autopilot = require(script.Parent.Autopilot)
local BowlHazards = require(script.Parent.BowlHazards)
local Buffs = require(script.Parent.Buffs)
local Pickups = require(script.Parent.Pickups)
local BotLevels = require(ReplicatedStorage.Shared.BotLevels)
local Appearance = require(script.Parent.Appearance)
local CarBuilder = require(script.Parent.CarBuilder)
local Dummy = require(script.Parent.Dummy)
local Fx = require(script.Parent.Fx)
local Impulse = require(script.Parent.Impulse)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local Damage = require(ReplicatedStorage.Shared.Damage)
local Specials = require(script.Parent.Specials)
local Weapon = require(script.Parent.Weapon)
local WeaponsConfig = require(ReplicatedStorage.Shared.WeaponsConfig)
local Moves = require(script.Parent.Moves)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local MovesRules = require(ReplicatedStorage.Shared.Moves)

type Phase = "pick" | "ready" | "aim" | "fight" | "roundEnd" | "matchEnd"

export type Handle = {
	launch: (player: Player, angle: any, power: any) -> (),
	steer: (player: Player, value: any, throttle: any?) -> (), -- steer -1 left .. 1 right, gas -1 back .. 1 forward; fight only
	action: (player: Player, name: any) -> (), -- "boost" | "jump" | "special" | "weapon", only in the fight
	playerLeft: (player: Player) -> (),
	destroy: () -> (),
}

export type Participant = {
	player: Player,
	carId: string,
	onFinished: (won: boolean, stay: boolean?) -> (), -- called once, after the end screen, if the player stayed
	onEndScreen: (() -> ())?, -- called when this player's end screen goes up
	appearance: Appearance.Appearance?, -- paint, sticker and level badge for this player's car
	botLevel: string?, -- bot difficulty when this lone player fights a bot ("easy" | "medium" | "hard")
	weaponId: string?, -- the weapon this player's car wears (nil = none)
	build: Build.BuildData?, -- build-and-watch: the parts this player's car wears
}

local Match = {}

-- participants: 1 or 2 players, in car order (car 1, car 2). A missing second player is a bot.
function Match.new(participants: { Participant }, slot: number, remotes: Remotes.RemoteSet): Handle
	local cfg = GameConfig
	local origin = Vector3.new(slot * cfg.Arena.slotSpacing, cfg.Arena.baseY, 0)
	local rng = Random.new()
	local auto = cfg.Mode.autoFight -- build-and-watch: the cars fight on their own
	local autoLevel = BotLevels.get("hard") -- sharp turns, fast, goes straight for the other car
	local gone: { [number]: boolean } = {} -- car index -> that player left

	local phase: Phase = "aim"
	local destroyed = false
	local arena: Arena.Arena? = nil
	local cars: { CarBuilder.Car } = {}
	local touchConns: { RBXScriptConnection } = {}
	local pickups: Pickups.Handle? = nil
	local hazards: BowlHazards.Handle? = nil
	local round = 0
	local submissions: { [number]: { angle: number, power: number } } = {}
	local lastHitAt = -math.huge
	local frozen = false -- hit stop: cars are held still for a moment
	local suddenDeath = false -- time ran out with equal HP: the next hit wins
	local fightElapsed = 0
	local steerStates: { [number]: Steer.State } = { Steer.newState(), Steer.newState() }
	local steerSmooth: { [number]: number } = { 0, 0 } -- eased input per car
	local throttleSmooth: { [number]: number } = { 0, 0 } -- eased gas per car
	-- car index -> true when that player's own device drives (and owns the physics of) the car
	local clientDriven: { [number]: boolean } = {}
	local moveStates: { [number]: Moves.State } = { Moves.new(), Moves.new() } -- reset each fight
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function nameOf(i: number): string
		local p = participants[i]
		return if p then p.player.DisplayName else "BOT"
	end

	-- Sends to one player (by car index). Skips bots and players who left.
	local function sendTo(i: number, update: Types.UiUpdate)
		local p = participants[i]
		if p and not gone[i] and not destroyed then
			remotes.UiUpdate:FireClient(p.player, update)
		end
	end

	-- Same message for everyone, or built per player (their own point of view).
	local function sendAll(make: (i: number) -> Types.UiUpdate)
		for i = 1, 2 do
			sendTo(i, make(i))
		end
	end

	local function clearCars()
		table.clear(clientDriven)
		if hazards then
			hazards.destroy()
			hazards = nil
		end
		if pickups then
			pickups.destroy()
			pickups = nil
		end
		for _, c in touchConns do
			c:Disconnect()
		end
		table.clear(touchConns)
		for _, car in cars do
			Buffs.clear(car)
			Weapon.clear(car)
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

	local hitStop: (duration: number) -> () -- defined below

	-- The match is over: `loser` is out.
	local function endMatch(loser: CarBuilder.Car, koText: string?)
		if phase == "roundEnd" or phase == "matchEnd" then
			return
		end
		phase = "roundEnd"
		if hazards then
			hazards.destroy()
			hazards = nil
		end
		if auto and not frozen then
			hitStop(cfg.Mode.koFreezeSeconds) -- a short freeze frame on the knockout
		end
		if pickups then
			pickups.destroy()
			pickups = nil
		end
		local koPos = loser.body.Position
		sendAll(function()
			return { kind = "ko", text = koText or "K.O.!", pos = koPos }
		end)
		loser.dead = true
		loser.hp = 0
		loser.bar.set(0, loser.stats.hp)
		loser.bar.hide()
		loser.body.Color = Color3.fromRGB(45, 45, 50)

		local currentArena = arena
		local focus: BasePart? = nil
		if currentArena then
			focus = Dummy.launch(loser.body.Position, currentArena.model)
		end
		sendAll(function(i)
			return { kind = "roundEnd", round = round, youLost = loser.idx == i, focus = focus }
		end)

		task.delay(cfg.Match.roundEndDelay, function()
			if destroyed then
				return
			end
			phase = "matchEnd"
			for i, part in participants do
				local youWon = loser.idx ~= i
				sendTo(i, { kind = "matchEnd", youWon = youWon })
				if part.onEndScreen then
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

	-- Hit stop: hold both cars still for a blink, then let them go with the same speeds.
	function hitStop(duration: number)
		if duration <= 0 or frozen then
			return
		end
		frozen = true
		local held = { cars[1], cars[2] }
		local lin, ang = {}, {}
		for i, car in held do
			lin[i], ang[i] = car.body.AssemblyLinearVelocity, car.body.AssemblyAngularVelocity
			car.body.Anchored = true
		end
		task.delay(duration, function()
			frozen = false
			for i, car in held do
				if car.model.Parent ~= nil then
					car.body.Anchored = false
					local part = participants[i]
					pcall(function()
						car.body:SetNetworkOwner(
							if clientDriven[i] and part then part.player else nil
						)
					end)
					car.body.AssemblyLinearVelocity = lin[i]
					car.body.AssemblyAngularVelocity = ang[i]
				end
			end
		end)
	end

	local comboStates = { Damage.newCombo(), Damage.newCombo() }

	-- A hit between two cars. Uses velocities from the end of the last frame (before the crash).
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
		-- Weak spot (back/side), combo chain and buffs.
		local toAttacker = attacker.body.Position - defender.body.Position
		local look = defender.body.CFrame.LookVector
		local zone = Damage.zone(
			Damage.cosFlat(look.X, look.Z, toAttacker.X, toAttacker.Z),
			CombatConfig.Zones
		)
		local comboCount =
			Damage.comboHit(comboStates[attacker.idx], os.clock(), CombatConfig.Combo.window)
		local specialMult = if type((Specials :: any).damageMult) == "function"
			then (Specials :: any).damageMult(attacker)
			else 1
		dmg = Damage.final(
			dmg,
			Damage.zoneMult(zone, CombatConfig.Zones),
			Damage.comboMult(comboCount, CombatConfig.Combo.mults),
			Buffs.damageMult(attacker),
			specialMult * Weapon.damageMult(attacker)
		)
		dmg = Buffs.absorb(defender, dmg)
		if suddenDeath then
			dmg = defender.hp
		end
		lastHitAt = os.clock()

		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)
		a.ai.hit = true
		b.ai.hit = true

		-- Feel: tell the client (shake, sparks, number), smoke when low, freeze for a blink.
		local strength = Logic.hitStrength(rel, cfg.Feel.bigHitSpeed)
		local popSpeed, spinSpeed = BowlRules.smashPop(strength, BowlConfig.Smash)
		local hitPos = (a.body.Position + b.body.Position) / 2
		sendAll(function(i)
			return {
				kind = "hit",
				pos = hitPos,
				strength = strength,
				damage = dmg,
				youHit = defender.idx == i,
				tag = if popSpeed > 0 then BowlConfig.Smash.text else Damage.tag(zone, comboCount),
			}
		end)
		if popSpeed > 0 then
			-- SMASH: the car that got hit flies up and spins.
			Impulse.linear(defender.body, Vector3.yAxis * defender.body.AssemblyMass * popSpeed)
			defender.body.AssemblyAngularVelocity += Vector3.yAxis * spinSpeed
		end
		if not defender.smoking and newHp / defender.stats.hp < cfg.Feel.smokeBelow then
			defender.smoking = true
			Fx.smoke(defender.body)
		end
		hitStop(
			Logic.hitStopTime(
				strength,
				cfg.Feel.hitStopMin,
				cfg.Feel.hitStopMax,
				cfg.Feel.hitStopFrom
			)
		)

		-- Ramp: kick the enemy upward to flip it.
		if attacker.stats.hitLift > 0 then
			Impulse.linear(
				defender.body,
				Vector3.yAxis * defender.body.AssemblyMass * attacker.stats.hitLift
			)
		end
		if dead then
			endMatch(defender)
		end
	end

	-- Damage from a weapon (not a car crash): shield and buffs count, then HP, hit message, K.O.
	local function dealWeaponDamage(
		attacker: CarBuilder.Car,
		defender: CarBuilder.Car,
		amount: number,
		pos: Vector3,
		tag: string
	)
		if attacker.dead or defender.dead or phase ~= "fight" then
			return
		end
		local dmg = Buffs.absorb(defender, amount * Buffs.damageMult(attacker))
		if suddenDeath then
			dmg = defender.hp
		end
		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)
		attacker.ai.hit = true
		defender.ai.hit = true
		local strength = math.clamp(dmg / 25, 0.15, 0.8)
		sendAll(function(i)
			return {
				kind = "hit",
				pos = pos,
				strength = strength,
				damage = dmg,
				youHit = defender.idx == i,
				tag = tag,
			}
		end)
		if not defender.smoking and newHp / defender.stats.hp < cfg.Feel.smokeBelow then
			defender.smoking = true
			Fx.smoke(defender.body)
		end
		if dead then
			endMatch(defender)
		end
	end

	local weaponCtx: Weapon.Context = {
		deal = dealWeaponDamage,
		origin = origin,
		rimRadius = cfg.Arena.rimRadius,
	}

	local function onTouched(car: CarBuilder.Car, other: BasePart)
		if phase ~= "fight" then
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
		if not Logic.canHit(os.clock(), lastHitAt, cfg.Damage.hitCooldown) then
			return
		end
		resolveHit(car, enemy)
	end

	local function spawnCars()
		local a = arena :: Arena.Arena
		clearCars()
		for idx = 1, 2 do
			local part = participants[idx]
			local id = if part
				then part.carId
				else CarConfig.Order[rng:NextInteger(1, #CarConfig.Order)]
			local stats = CarConfig.Cars[id]
			local cf = Arena.carCFrame(a, idx, stats.size[2] / 2)
			local build: Build.BuildData? = nil
			if cfg.Mode.useBuild then
				if part then
					build = part.build
				else
					local first = participants[1]
					local level = if first and first.build
						then Build.averageLevel(first.build)
						else 1
					build = Build.botBuild(function()
						return rng:NextNumber()
					end, level)
				end
			end
			cars[idx] = CarBuilder.build(
				id,
				idx,
				cf,
				a.model,
				nameOf(idx),
				part == nil,
				if part then part.appearance else nil,
				build
			)
			local weaponId = if part
				then part.weaponId
				else WeaponsConfig.Order[rng:NextInteger(1, #WeaponsConfig.Order)]
			Weapon.attach(cars[idx], weaponId, a.model)
		end
		rayParams.FilterDescendantsInstances = { cars[1].model, cars[2].model }
		for _, car in cars do
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
	end

	-- Turn the car toward the aim and push it once. After this it drives on (Autopilot for bots).
	local function launchCar(car: CarBuilder.Car, angle: number, power: number)
		local dir = Aim.direction(Vector3.zAxis, angle)
		local up = car.body.CFrame.UpVector
		local fwd = (dir - up * dir:Dot(up))
		if fwd.Magnitude > 0.01 then
			fwd = fwd.Unit
			car.model:PivotTo(CFrame.fromMatrix(car.body.Position, fwd:Cross(up), up))
		end
		setAnchored(car, false)
		pcall(function()
			car.body:SetNetworkOwner(nil) -- server owns the car physics
		end)
		local speed = Logic.launchSpeed(power, cfg.Launch.minSpeed, cfg.Launch.maxSpeed)
		car.body:ApplyImpulse(dir * car.body.AssemblyMass * speed)
	end

	-- Bot difficulty (lone player vs bot); medium when unset or unknown.
	local botLevel = BotLevels.get(if participants[1] then participants[1].botLevel else nil)

	local function parkCharacter(player: Player)
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if char and root and root:IsA("BasePart") then
			root.Anchored = true
			char:PivotTo(CFrame.new(origin + Vector3.new(0, -12, 0)))
		end
	end

	local function startFight()
		phase = "fight"
		lastHitAt = -math.huge
		frozen = false
		fightElapsed = 0
		for i = 1, 2 do
			Steer.reset(steerStates[i])
			steerSmooth[i] = 0
			throttleSmooth[i] = 0
			moveStates[i] = Moves.new()
		end
		for i, car in cars do
			local sub = submissions[i]
			if sub then
				launchCar(car, sub.angle, sub.power)
			else
				-- Bot: aims at the other car with a little error.
				local me, other = car.body.Position, cars[3 - i].body.Position
				local noise = rng:NextNumber(-botLevel.noiseDeg, botLevel.noiseDeg)
				launchCar(
					car,
					Duel.botAim(me.X, me.Z, other.X, other.Z, noise),
					BotLevels.launchPower(botLevel, rng:NextNumber())
				)
			end
		end
		-- Each human gets the physics of their own car a moment after the launch push, so their
		-- device can drive it with no lag. Test players (not real Players) stay server-driven.
		-- A device only simulates parts near its character, and arenas are far from the lobby, so
		-- the character is parked (anchored) under the arena floor for the fight. The lobby brings
		-- it back (LoadCharacter) when the player leaves the match.
		task.delay(0.15, function()
			if destroyed or phase ~= "fight" or auto then
				return
			end
			for i, car in cars do
				local part = participants[i]
				if part and not gone[i] and typeof(part.player) == "Instance" then
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
		if arena then
			pickups = Pickups.start(arena, cars, rng, function(car, update)
				sendTo(car.idx, update)
			end)
			hazards = BowlHazards.new(arena, cars)
		end
		sendAll(function(i)
			local wid = Weapon.idOf(cars[i])
			return {
				kind = "fight",
				auto = auto,
				round = round,
				weapon = wid,
				weaponPassive = if wid then Weapon.isPassive(wid) else nil,
			}
		end)
	end

	-- Every human who has not launched yet gets a small random push, then the fight starts.
	local function launchAllNow()
		for i, part in participants do
			if part and not gone[i] and submissions[i] == nil then
				submissions[i] = { angle = rng:NextNumber(-180, 180), power = 0.35 }
			end
		end
		startFight()
	end

	local function allSubmitted(): boolean
		for i = 1, #participants do
			if not gone[i] and submissions[i] == nil then
				return false
			end
		end
		return true
	end

	local function beginAim()
		if destroyed or arena == nil then
			return
		end
		if auto then
			-- Build-and-watch: no aiming. A short "ready" countdown, then the cars go.
			phase = "ready"
			round += 1
			local a = arena :: Arena.Arena
			local wait = cfg.Mode.readySeconds
			sendAll(function(i)
				return {
					kind = "ready",
					round = round,
					yourCar = cars[i].id,
					enemyCar = cars[3 - i].id,
					enemyName = nameOf(3 - i),
					center = a.center,
					carPos = cars[i].body.Position,
					seconds = wait,
				}
			end)
			task.delay(wait, function()
				if not destroyed and phase == "ready" then
					startFight()
				end
			end)
			return
		end
		phase = "aim"
		round += 1
		local a = arena :: Arena.Arena
		sendAll(function(i)
			return {
				kind = "aim",
				round = round,
				yourCar = cars[i].id,
				enemyCar = cars[3 - i].id,
				enemyName = nameOf(3 - i),
				center = a.center,
				carPos = cars[i].body.Position,
				enemyPos = cars[3 - i].body.Position,
				baseDir = Vector3.zAxis,
				seconds = cfg.Match.aimTimeout,
			}
		end)
		task.delay(cfg.Match.aimTimeout, function()
			if not destroyed and phase == "aim" then
				launchAllNow()
			end
		end)
	end

	-- Every frame during a fight: cars drive themselves, remember velocity for the impact math,
	-- catch ring-outs, and watch the match clock.
	local function indexOf(player: Player): number?
		for i, part in participants do
			if part.player == player then
				return i
			end
		end
		return nil
	end

	-- A driver's device owns its car, so a hacked client could drive it far too fast. Slow the car
	-- down when it passes any speed the game can legitimately give it.
	local function limitSpeed(car: CarBuilder.Car)
		local cap = math.max(
			cfg.Launch.maxSpeed,
			car.stats.maxSpeed * (1 + MovesConfig.Boost.speedBonus) * Buffs.speedMult(car)
		) * cfg.Drive.speedCapSlack
		local v = car.body.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > cap then
			local keep = flat.Unit * cap
			car.body.AssemblyLinearVelocity = Vector3.new(keep.X, v.Y, keep.Z)
		end
	end

	-- The safe ring burns a car outside it (HP only, no hit effects).
	local function hazardDamage(car: CarBuilder.Car, amount: number)
		if phase ~= "fight" or car.dead then
			return
		end
		local newHp, dead = Logic.applyDamage(car.hp, amount)
		car.hp = newHp
		car.bar.set(newHp, car.stats.hp)
		if dead then
			endMatch(car, "BURNED OUT!")
		end
	end

	local fightConn = RunService.Heartbeat:Connect(function(dt)
		if phase ~= "fight" or frozen then
			return
		end
		for _, car in cars do
			if not car.dead then
				Buffs.tick(car, dt)
				local human = participants[car.idx]
				if auto then
					-- Build-and-watch: every car hunts the other one and uses its own boost and
					-- special, so fights are fast and full of hits.
					local now = os.clock()
					local enemy = cars[3 - car.idx]
					local state = moveStates[car.idx]
					local dist = (enemy.body.Position - car.body.Position).Magnitude
					if dist > 18 then
						Moves.press(state, "boost", car, enemy, rayParams, now)
					elseif dist < 12 then
						Moves.press(state, "special", car, enemy, rayParams, now)
					end
					local mods = Moves.mods(state, car, 0, dt, now)
					Autopilot.step(car, enemy, dt, rayParams, origin, autoLevel, mods)
				elseif human and not gone[car.idx] and clientDriven[car.idx] then
					-- The driver's device moves this car; the server only keeps it honest.
					car.model:SetAttribute("SpeedMult", Buffs.speedMult(car))
					limitSpeed(car)
				elseif human and not gone[car.idx] then
					local raw =
						Steer.current(steerStates[car.idx], os.clock(), cfg.Steer.staleSeconds)
					local eased = Steer.smooth(steerSmooth[car.idx], raw, dt, cfg.Steer.smoothRate)
					steerSmooth[car.idx] = eased
					local rawGas = Steer.currentThrottle(
						steerStates[car.idx],
						os.clock(),
						cfg.Steer.staleSeconds
					)
					local gas =
						Steer.smooth(throttleSmooth[car.idx], rawGas, dt, cfg.Steer.smoothRate)
					throttleSmooth[car.idx] = gas
					local mods = Moves.mods(moveStates[car.idx], car, eased, dt, os.clock())
					Autopilot.stepManual(car, eased, gas, dt, rayParams, mods)
				else
					Autopilot.step(car, cars[3 - car.idx], dt, rayParams, origin, botLevel)
				end
			end
		end
		local now = os.clock()
		if hazards then
			hazards.step(dt, now, fightElapsed, hazardDamage)
			if phase ~= "fight" then
				return
			end
		end
		for _, car in cars do
			Weapon.tick(
				car,
				cars[3 - car.idx],
				dt,
				now,
				auto or participants[car.idx] == nil,
				weaponCtx
			)
			if phase ~= "fight" then
				return
			end
		end
		for _, car in cars do
			car.prevVel = car.body.AssemblyLinearVelocity
			-- Pushed past the rim, or fell out of the bowl = ring-out = 0 HP.
			if not car.dead then
				local dx, dz = car.body.Position.X - origin.X, car.body.Position.Z - origin.Z
				local out = Fight.isRingOut(
					math.sqrt(dx * dx + dz * dz),
					cfg.Arena.rimRadius,
					cfg.RingOut.margin
				)
				if out or car.body.Position.Y < origin.Y - cfg.Match.outOfBoundsDrop then
					endMatch(car, "RING OUT!")
					return
				end
			end
		end
		-- Match clock: time up = higher HP wins; equal HP = the next hit wins.
		fightElapsed += dt
		if fightElapsed >= cfg.Match.maxMatchSeconds and not suddenDeath then
			local w = Duel.timeoutWinner(cars[1].hp, cars[2].hp)
			if w ~= 0 then
				endMatch(cars[3 - w], "TIME UP!")
				return
			end
			suddenDeath = true
			local pos = cars[1].body.Position
			sendAll(function()
				return { kind = "ko", text = "SUDDEN DEATH!", pos = pos }
			end)
		end
	end)

	local handle: Handle = {
		launch = function(player: Player, angle: any, power: any)
			if destroyed or phase ~= "aim" then
				return
			end
			local i = indexOf(player)
			if i == nil or gone[i] or submissions[i] ~= nil then
				return
			end
			local a, p = Logic.sanitizeLaunch(angle, power, 180)
			if a == nil or p == nil then
				return
			end
			submissions[i] = { angle = a, power = p }
			if allSubmitted() then
				startFight()
			end
		end,
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
			if
				destroyed
				or phase ~= "fight"
				or frozen
				or not MovesRules.isMove(name, MovesConfig.Names)
			then
				return
			end
			local i = indexOf(player)
			if i == nil or gone[i] then
				return
			end
			local seconds = if name == "weapon"
				then Weapon.press(cars[i], cars[3 - i], os.clock())
				else Moves.press(
					moveStates[i],
					name,
					cars[i],
					cars[3 - i],
					rayParams,
					os.clock()
				)
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
			-- The player who stays wins.
			if phase == "ready" or phase == "aim" or phase == "fight" then
				endMatch(cars[i], "OPPONENT LEFT")
			end
		end,
		destroy = function()
			destroyed = true
			fightConn:Disconnect()
			clearCars()
			if arena then
				arena.model:Destroy()
			end
		end,
	}
	arena = Arena.build(origin)
	spawnCars()
	beginAim()
	return handle
end

return Match
