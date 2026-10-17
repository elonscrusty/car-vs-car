--!strict
-- One solo match: player vs bot. The server owns everything: cars, forces, damage, hearts, rounds.
-- Phases: pick -> aim -> fight -> roundEnd -> (aim again | matchEnd) -> pick again on restart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Autopilot = require(script.Parent.Autopilot)
local CarBuilder = require(script.Parent.CarBuilder)
local Dummy = require(script.Parent.Dummy)

type Phase = "pick" | "aim" | "fight" | "roundEnd" | "matchEnd"

export type Handle = {
	selectCar: (carId: any) -> (),
	launch: (angle: any, power: any) -> (),
	destroy: () -> (),
}

local Match = {}

function Match.new(player: Player, slot: number, remotes: Remotes.RemoteSet): Handle
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

	local function endRound(loser: CarBuilder.Car)
		if phase ~= "fight" then
			return
		end
		phase = "roundEnd"
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
				send({ kind = "matchEnd", youWon = hearts[2] <= 0 })
			else
				beginAim()
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
		lastHitAt = os.clock()

		local newHp, dead = Logic.applyDamage(defender.hp, dmg)
		defender.hp = newHp
		defender.bar.set(newHp, defender.stats.hp)
		a.ai.hit = true
		b.ai.hit = true

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
		if phase ~= "fight" then
			return
		end
		for i, car in cars do
			if not car.dead then
				Autopilot.step(car, cars[3 - i], dt, rayParams, origin)
			end
		end
		for _, car in cars do
			car.prevVel = car.body.AssemblyLinearVelocity
			-- Safety: fell out of the bowl = counts as 0 HP.
			if not car.dead and car.body.Position.Y < origin.Y - cfg.Match.outOfBoundsDrop then
				car.hp = 0
				endRound(car)
			end
		end
	end)

	local handle: Handle = {
		selectCar = function(carId: any)
			if destroyed or (phase ~= "pick" and phase ~= "matchEnd") then
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
		destroy = function()
			destroyed = true
			fightConn:Disconnect()
			clearCars()
			if arena then
				arena.model:Destroy()
			end
		end,
	}
	return handle
end

return Match
