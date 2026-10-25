--!strict
-- One solo match: player vs bot. The server owns everything: cars, forces, damage, hearts, rounds.
-- Phases: pick -> aim -> fight -> roundEnd -> (aim again | matchEnd). Lobby matches (opts) skip pick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local Fight = require(ReplicatedStorage.Shared.Fight)
local Logic = require(ReplicatedStorage.Shared.Logic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Autopilot = require(script.Parent.Autopilot)
local CarBuilder = require(script.Parent.CarBuilder)
local Dummy = require(script.Parent.Dummy)
local Fx = require(script.Parent.Fx)

type Phase = "pick" | "aim" | "fight" | "roundEnd" | "matchEnd"

export type Handle = {
	selectCar: (carId: any) -> (),
	launch: (angle: any, power: any) -> (),
	boost: () -> (),
	special: () -> (),
	destroy: () -> (),
}

export type Opts = {
	carId: string,
	onFinished: (won: boolean) -> (),
}

local Match = {}

-- With opts (lobby flow): skips the pick phase, uses opts.carId, has no play-again, and calls
-- opts.onFinished(won) once the end screen has been shown for Rewards.endScreenSeconds.
function Match.new(player: Player, slot: number, remotes: Remotes.RemoteSet, opts: Opts?): Handle
	local cfg = GameConfig
	local origin = Vector3.new(slot * cfg.Arena.slotSpacing, cfg.Arena.baseY, 0)
	local rng = Random.new()

	local phase: Phase = "pick"
	local destroyed = false
	local arena: Arena.Arena? = nil
	local cars: { CarBuilder.Car } = {}
	local touchConns: { RBXScriptConnection } = {}
	local hearts = { cfg.Match.hearts, cfg.Match.hearts }
	local round = 0
	local playerCarId = "Heavy"
	local aimToken = 0 -- bumps each aim phase so old timeouts do nothing
	local lastHitAt = -math.huge
	local frozen = false -- hit stop: cars are held still for a moment
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local beginAim: () -> () -- defined further down (rounds call each other)

	local function send(update: Types.UiUpdate)
		if not destroyed then
			remotes.UiUpdate:FireClient(player, update)
		end
	end

	local function clearCars()
		for _, c in touchConns do
			c:Disconnect()
		end
		table.clear(touchConns)
		for _, car in cars do
			car.model:Destroy()
		end
		table.clear(cars)
	end

	local function endRound(loser: CarBuilder.Car, koText: string?)
		if phase ~= "fight" then
			return
		end
		phase = "roundEnd"
		send({ kind = "ko", text = koText or "K.O.!", pos = loser.body.Position })
		loser.dead = true
		loser.flame.Enabled = false
		loser.hp = 0
		loser.bar.set(0, loser.stats.hp)
		loser.bar.hide()
		loser.body.Color = Color3.fromRGB(45, 45, 50)

		local currentArena = arena
		local focus: BasePart? = nil
		if currentArena then
			focus = Dummy.launch(loser.body.Position, currentArena.model)
		end

		local newHearts, over = Logic.loseHeart(hearts[loser.idx])
		hearts[loser.idx] = newHearts
		send({
			kind = "roundEnd",
			round = round,
			youLost = loser.idx == 1,
			youHearts = hearts[1],
			enemyHearts = hearts[2],
			focus = focus,
		})

		task.delay(cfg.Match.roundEndDelay, function()
			if destroyed then
				return
			end
			if over then
				phase = "matchEnd"
				local youWon = hearts[2] <= 0
				send({ kind = "matchEnd", youWon = youWon })
				if opts then
					task.delay(LobbyConfig.Rewards.endScreenSeconds, function()
						if not destroyed then
							opts.onFinished(youWon)
						end
					end)
				end
			else
				beginAim()
			end
		end)
	end

	-- Hit stop: hold both cars still for a blink, then let them go with the same speeds.
	local function hitStop(duration: number)
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
					pcall(function()
						car.body:SetNetworkOwner(nil)
					end)
					car.body.AssemblyLinearVelocity = lin[i]
					car.body.AssemblyAngularVelocity = ang[i]
				end
			end
		end)
	end

	local function startBoost(car: CarBuilder.Car): boolean
		if car.dead or not Logic.canBoost(car.boostLeft, car.boostCd) then
			return false
		end
		car.boostLeft = cfg.Boost.duration
		car.boostCd = cfg.Boost.cooldown
		car.flame.Enabled = true
		if car.idx == 1 then
			send({ kind = "boost", cooldown = cfg.Boost.cooldown })
		end
		return true
	end

	-- Damage that does not come from a crash (special moves).
	local function specialDamage(defender: CarBuilder.Car, dmg: number, pos: Vector3)
		if defender.dead or dmg <= 0 then
			return
		end
		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)
		send({ kind = "hit", pos = pos, strength = 0.8, damage = dmg, youHit = defender.idx == 1 })
		if not defender.smoking and newHp / defender.stats.hp < cfg.Feel.smokeBelow then
			defender.smoking = true
			Fx.smoke(defender.body)
		end
		if dead then
			endRound(defender)
		end
	end

	-- One special move per car. Returns true if it fired.
	local function useSpecial(car: CarBuilder.Car): boolean
		if car.dead or phase ~= "fight" or frozen or not Fight.canSpecial(car.specialCd) then
			return false
		end
		local sp = cfg.Special
		car.specialCd = sp.cooldown
		local enemy = cars[3 - car.idx]
		local toEnemy = if enemy then enemy.body.Position - car.body.Position else Vector3.zero
		local dist = toEnemy.Magnitude
		local alive = enemy ~= nil and not enemy.dead
		if car.id == "Heavy" then
			-- Ground slam: shockwave that shoves and hurts, weaker with distance.
			local f = Fight.falloff(dist, sp.Heavy.radius)
			local flat = Vector3.new(toEnemy.X, 0, toEnemy.Z)
			if alive and f > 0 and flat.Magnitude > 0.01 and enemy then
				enemy.body:ApplyImpulse(
					(flat.Unit * sp.Heavy.knock * f + Vector3.yAxis * sp.Heavy.up * f)
						* enemy.body.AssemblyMass
				)
				specialDamage(enemy, sp.Heavy.damage * f, enemy.body.Position)
			else
				send({
					kind = "hit",
					pos = car.body.Position,
					strength = 0.6,
					damage = 0,
					youHit = false,
				})
			end
		elseif car.id == "Light" then
			-- Dash: instant burst straight ahead, plus a short boost for the flame.
			car.body:ApplyImpulse(
				car.body.CFrame.LookVector * car.body.AssemblyMass * sp.Light.dash
			)
			car.boostLeft = math.max(car.boostLeft, 0.3)
			car.flame.Enabled = true
		elseif car.id == "Ramp" then
			-- Flip kick: if the enemy is right in front, launch it.
			if alive and enemy and dist > 0.01 then
				local dot = car.body.CFrame.LookVector:Dot(toEnemy.Unit)
				if Fight.inCone(dist, dot, sp.Ramp.range, sp.Ramp.minDot) then
					enemy.body:ApplyImpulse(Vector3.yAxis * enemy.body.AssemblyMass * sp.Ramp.lift)
					specialDamage(enemy, sp.Ramp.damage, enemy.body.Position)
				end
			end
		elseif car.id == "Spike" then
			car.spikeLeft = sp.Spike.duration
		end
		if car.idx == 1 then
			send({ kind = "special", cooldown = sp.cooldown })
		end
		return true
	end

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
		-- Spike with spikes out hits harder.
		if attacker.spikeLeft > 0 then
			dmg *= cfg.Special.Spike.damageMult
		end
		-- Counter: the defender tapped boost just before this hit.
		local now = os.clock()
		local countered = Fight.isCountered(defender.counter, now, cfg.Counter.window)
		if countered then
			Fight.consume(defender.counter)
			dmg = Fight.counterDamage(dmg, cfg.Counter.damageMult)
		end
		lastHitAt = now

		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)
		a.ai.hit = true
		b.ai.hit = true

		-- Feel: tell the client (shake, sparks, number), smoke when low, freeze for a blink.
		local strength = Logic.hitStrength(rel, cfg.Feel.bigHitSpeed)
		send({
			kind = "hit",
			pos = (a.body.Position + b.body.Position) / 2,
			strength = strength,
			damage = dmg,
			youHit = defender.idx == 1,
		})
		if not defender.smoking and newHp / defender.stats.hp < cfg.Feel.smokeBelow then
			defender.smoking = true
			Fx.smoke(defender.body)
		end
		local stopT = Logic.hitStopTime(
			strength,
			cfg.Feel.hitStopMin,
			cfg.Feel.hitStopMax,
			cfg.Feel.hitStopFrom
		)
		hitStop(stopT)
		if countered then
			local mid = (a.body.Position + b.body.Position) / 2
			send({ kind = "counter", pos = mid })
			local away = attacker.body.Position - defender.body.Position
			if away.Magnitude > 0.001 then
				-- After the freeze, so the shove is not eaten by hit stop.
				task.delay(stopT + 0.03, function()
					if not destroyed and not attacker.dead and attacker.model.Parent ~= nil then
						attacker.body:ApplyImpulse(
							away.Unit * attacker.body.AssemblyMass * cfg.Counter.knock
						)
					end
				end)
			end
		end

		-- Ramp: kick the enemy upward to flip it.
		if attacker.stats.hitLift > 0 then
			defender.body:ApplyImpulse(
				Vector3.yAxis * defender.body.AssemblyMass * attacker.stats.hitLift
			)
		end
		if dead then
			endRound(defender)
		end
	end

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
		local botId = CarConfig.Order[rng:NextInteger(1, #CarConfig.Order)]
		for idx, id in { playerCarId, botId } do
			local stats = CarConfig.Cars[id]
			local cf = Arena.carCFrame(a, idx, stats.size[2] / 2)
			cars[idx] = CarBuilder.build(id, idx, cf, a.model)
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

	local function launchCar(car: CarBuilder.Car, base: Vector3, angle: number, power: number)
		for _, part in car.model:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		pcall(function()
			car.body:SetNetworkOwner(nil) -- server owns the car physics
		end)
		local speed = Logic.launchSpeed(power, cfg.Launch.minSpeed, cfg.Launch.maxSpeed)
		local dir = Aim.direction(base, angle)
		car.body:ApplyImpulse(dir * car.body.AssemblyMass * speed)
	end

	local function startFight(angle: number, power: number)
		local a = arena :: Arena.Arena
		phase = "fight"
		lastHitAt = -math.huge
		frozen = false
		launchCar(cars[1], Arena.inwardDirection(a, 1), angle, power)
		-- Bot: random aim and power
		local botAngle = rng:NextNumber(-cfg.Match.aimMaxDeg, cfg.Match.aimMaxDeg)
		launchCar(cars[2], Arena.inwardDirection(a, 2), botAngle, rng:NextNumber(0.5, 1))
		send({ kind = "fight", round = round })
	end

	function beginAim()
		if destroyed or arena == nil then
			return
		end
		phase = "aim"
		round += 1
		spawnCars()
		aimToken += 1
		local token = aimToken
		local a = arena :: Arena.Arena
		send({
			kind = "aim",
			round = round,
			yourCar = cars[1].id,
			enemyCar = cars[2].id,
			youHearts = hearts[1],
			enemyHearts = hearts[2],
			center = a.center,
			carPos = cars[1].body.Position,
			baseDir = Arena.inwardDirection(a, 1),
		})
		-- Too slow? The server launches for you.
		task.delay(cfg.Match.aimTimeout, function()
			if not destroyed and phase == "aim" and token == aimToken then
				startFight(0, 0.6)
			end
		end)
	end

	-- Every frame during a fight: both cars auto-pilot, then remember velocity for impact math.
	local fightConn = RunService.Heartbeat:Connect(function(dt)
		if phase ~= "fight" or frozen then
			return
		end
		for _, car in cars do
			car.boostLeft, car.boostCd = Logic.tickBoost(car.boostLeft, car.boostCd, dt)
			car.specialCd = math.max(0, car.specialCd - dt)
			car.spikeLeft = math.max(0, car.spikeLeft - dt)
			if car.boostLeft <= 0 then
				car.flame.Enabled = false
			end
		end
		-- Bot boosts now and then when the player is a good run away and in front.
		local bot, you = cars[2], cars[1]
		if not bot.dead and not you.dead and Logic.canBoost(bot.boostLeft, bot.boostCd) then
			local toYou = you.body.Position - bot.body.Position
			local dist = toYou.Magnitude
			if
				dist >= cfg.Boost.botMinDist
				and dist <= cfg.Boost.botMaxDist
				and bot.body.CFrame.LookVector:Dot(toYou.Unit) > 0.9
				and rng:NextNumber() < 0.05
			then
				startBoost(bot)
			end
		end
		-- Bot special: Heavy/Ramp when close, Light/Spike when there is room to run.
		if
			not bot.dead
			and not you.dead
			and Fight.canSpecial(bot.specialCd)
			and rng:NextNumber() < 0.03
		then
			local dist = (you.body.Position - bot.body.Position).Magnitude
			local close = bot.id == "Heavy" or bot.id == "Ramp"
			if (close and dist < 20) or (not close and dist > 22) then
				useSpecial(bot)
			end
		end
		for i, car in cars do
			if not car.dead then
				Autopilot.step(car, cars[3 - i], dt, rayParams, origin)
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
					car.hp = 0
					endRound(car, "RING OUT!")
				end
			end
		end
	end)

	local handle: Handle = {
		selectCar = function(carId: any)
			if opts or destroyed or (phase ~= "pick" and phase ~= "matchEnd") then
				return
			end
			if CarConfig.get(carId) == nil then
				return
			end
			playerCarId = carId :: string
			hearts = { cfg.Match.hearts, cfg.Match.hearts }
			round = 0
			if arena == nil then
				arena = Arena.build(origin)
			end
			beginAim()
		end,
		launch = function(angle: any, power: any)
			if destroyed or phase ~= "aim" then
				return
			end
			local a, p = Logic.sanitizeLaunch(angle, power, cfg.Match.aimMaxDeg)
			if a == nil or p == nil then
				return
			end
			startFight(a, p)
		end,
		boost = function()
			if destroyed or phase ~= "fight" then
				return
			end
			local mine = cars[1]
			if mine then
				-- Every tap is also a counter try (locked for a few seconds after each tap).
				Fight.tap(mine.counter, os.clock(), cfg.Counter.cooldown)
				startBoost(mine)
			end
		end,
		special = function()
			if destroyed or phase ~= "fight" then
				return
			end
			local mine = cars[1]
			if mine then
				useSpecial(mine)
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
	if opts and CarConfig.get(opts.carId) ~= nil then
		playerCarId = opts.carId
		arena = Arena.build(origin)
		beginAim()
	end
	return handle
end

return Match
