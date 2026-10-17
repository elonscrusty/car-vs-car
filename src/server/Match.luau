--!strict
-- One solo match: player vs bot. The server owns everything: cars, launches, damage, winner.
-- Flow: aim (drag to launch) -> launch -> cars drive themselves (Autopilot) and ram until one car
-- is out of HP (or time is up). Lobby matches (opts) skip the pick phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Fight = require(ReplicatedStorage.Shared.Fight)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
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
	local round = 0
	local playerCarId = "Heavy"
	local aimToken = 0 -- bumps each aim phase so old timeouts do nothing
	local lastHitAt = -math.huge
	local frozen = false -- hit stop: cars are held still for a moment
	local suddenDeath = false -- time ran out with equal HP: the next hit wins
	local fightElapsed = 0
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

	local function setAnchored(car: CarBuilder.Car, anchored: boolean)
		for _, part in car.model:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = anchored
			end
		end
	end

	-- The match is over: `loser` is out.
	local function endMatch(loser: CarBuilder.Car, koText: string?)
		if phase == "roundEnd" or phase == "matchEnd" then
			return
		end
		phase = "roundEnd"
		send({ kind = "ko", text = koText or "K.O.!", pos = loser.body.Position })
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
		send({ kind = "roundEnd", round = round, youLost = loser.idx == 1, focus = focus })

		task.delay(cfg.Match.roundEndDelay, function()
			if destroyed then
				return
			end
			phase = "matchEnd"
			local youWon = loser.idx == 2
			send({ kind = "matchEnd", youWon = youWon })
			if opts then
				task.delay(LobbyConfig.Rewards.endScreenSeconds, function()
					if not destroyed then
						opts.onFinished(youWon)
					end
				end)
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
		if suddenDeath then
			dmg = defender.hp
		end
		lastHitAt = os.clock()

		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)

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
			defender.body:ApplyImpulse(
				Vector3.yAxis * defender.body.AssemblyMass * attacker.stats.hitLift
			)
		end
		if dead then
			endMatch(defender)
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

	-- Both cars start on their own side of the bowl and stay where they stop for the whole match.
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

	-- Turn the car toward the aim and push it once. After this it only coasts.
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

	local function startFight(angle: number, power: number)
		phase = "fight"
		lastHitAt = -math.huge
		frozen = false
		fightElapsed = 0
		launchCar(cars[1], angle, power)
		-- Bot: aims at you with a little error.
		local mine, bot = cars[1].body.Position, cars[2].body.Position
		local noise = rng:NextNumber(-12, 12)
		launchCar(cars[2], Duel.botAim(bot.X, bot.Z, mine.X, mine.Z, noise), rng:NextNumber(0.6, 1))
		send({ kind = "fight", round = round })
	end

	function beginAim()
		if destroyed or arena == nil then
			return
		end
		phase = "aim"
		round += 1
		aimToken += 1
		local token = aimToken
		local a = arena :: Arena.Arena
		send({
			kind = "aim",
			round = round,
			yourCar = cars[1].id,
			enemyCar = cars[2].id,
			center = a.center,
			carPos = cars[1].body.Position,
			enemyPos = cars[2].body.Position,
			baseDir = Vector3.zAxis,
			seconds = cfg.Match.aimTimeout,
		})
		-- Too slow? The server gives you a small random push.
		task.delay(cfg.Match.aimTimeout, function()
			if not destroyed and phase == "aim" and token == aimToken then
				startFight(rng:NextNumber(-180, 180), 0.35)
			end
		end)
	end

	local function startMatch()
		if arena == nil then
			arena = Arena.build(origin)
		end
		round, suddenDeath = 0, false
		spawnCars()
		beginAim()
	end

	-- Every frame during a fight: cars drive themselves, remember velocity for the impact math,
	-- catch ring-outs, and watch the match clock.
	local fightConn = RunService.Heartbeat:Connect(function(dt)
		if phase ~= "fight" or frozen then
			return
		end
		for _, car in cars do
			if not car.dead then
				Autopilot.step(car, cars[3 - car.idx], dt, rayParams, origin)
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
			send({ kind = "ko", text = "SUDDEN DEATH!", pos = cars[1].body.Position })
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
			startMatch()
		end,
		launch = function(angle: any, power: any)
			if destroyed or phase ~= "aim" then
				return
			end
			local a, p = Logic.sanitizeLaunch(angle, power, 180)
			if a == nil or p == nil then
				return
			end
			startFight(a, p)
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
		startMatch()
	end
	return handle
end

return Match
