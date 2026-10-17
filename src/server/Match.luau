--!strict
-- One match: one or two players (the other car is a bot). The server owns everything: cars,
-- launches, damage, winner. Flow: everyone aims at the same time (drag to launch) -> all launch
-- together -> bot cars drive themselves (Autopilot); human cars drive forward on their own and
-- the player steers (Steer remote). Cars ram until one car is out of HP (or time is up).

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
local Steer = require(ReplicatedStorage.Shared.Steer)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Autopilot = require(script.Parent.Autopilot)
local Appearance = require(script.Parent.Appearance)
local CarBuilder = require(script.Parent.CarBuilder)
local Dummy = require(script.Parent.Dummy)
local Fx = require(script.Parent.Fx)

type Phase = "pick" | "aim" | "fight" | "roundEnd" | "matchEnd"

export type Handle = {
	launch: (player: Player, angle: any, power: any) -> (),
	steer: (player: Player, value: any) -> (), -- -1 left .. 1 right, only used in the fight
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
}

local Match = {}

-- participants: 1 or 2 players, in car order (car 1, car 2). A missing second player is a bot.
function Match.new(participants: { Participant }, slot: number, remotes: Remotes.RemoteSet): Handle
	local cfg = GameConfig
	local origin = Vector3.new(slot * cfg.Arena.slotSpacing, cfg.Arena.baseY, 0)
	local rng = Random.new()
	local gone: { [number]: boolean } = {} -- car index -> that player left

	local phase: Phase = "aim"
	local destroyed = false
	local arena: Arena.Arena? = nil
	local cars: { CarBuilder.Car } = {}
	local touchConns: { RBXScriptConnection } = {}
	local round = 0
	local submissions: { [number]: { angle: number, power: number } } = {}
	local lastHitAt = -math.huge
	local frozen = false -- hit stop: cars are held still for a moment
	local suddenDeath = false -- time ran out with equal HP: the next hit wins
	local fightElapsed = 0
	local steerStates: { [number]: Steer.State } = { Steer.newState(), Steer.newState() }
	local steerSmooth: { [number]: number } = { 0, 0 } -- eased input per car
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
		a.ai.hit = true
		b.ai.hit = true

		-- Feel: tell the client (shake, sparks, number), smoke when low, freeze for a blink.
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
			cars[idx] = CarBuilder.build(
				id,
				idx,
				cf,
				a.model,
				nameOf(idx),
				part == nil,
				if part then part.appearance else nil
			)
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

	local function startFight()
		phase = "fight"
		lastHitAt = -math.huge
		frozen = false
		fightElapsed = 0
		for i = 1, 2 do
			Steer.reset(steerStates[i])
			steerSmooth[i] = 0
		end
		for i, car in cars do
			local sub = submissions[i]
			if sub then
				launchCar(car, sub.angle, sub.power)
			else
				-- Bot: aims at the other car with a little error.
				local me, other = car.body.Position, cars[3 - i].body.Position
				local noise = rng:NextNumber(-12, 12)
				launchCar(
					car,
					Duel.botAim(me.X, me.Z, other.X, other.Z, noise),
					rng:NextNumber(0.6, 1)
				)
			end
		end
		sendAll(function()
			return { kind = "fight", round = round }
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

	local fightConn = RunService.Heartbeat:Connect(function(dt)
		if phase ~= "fight" or frozen then
			return
		end
		for _, car in cars do
			if not car.dead then
				local human = participants[car.idx]
				if human and not gone[car.idx] then
					local raw =
						Steer.current(steerStates[car.idx], os.clock(), cfg.Steer.staleSeconds)
					local eased = Steer.smooth(steerSmooth[car.idx], raw, dt, cfg.Steer.smoothRate)
					steerSmooth[car.idx] = eased
					Autopilot.stepManual(car, eased, dt, rayParams)
				else
					Autopilot.step(car, cars[3 - car.idx], dt, rayParams, origin)
				end
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
		steer = function(player: Player, value: any)
			if destroyed or phase ~= "fight" then
				return
			end
			local i = indexOf(player)
			if i == nil or gone[i] then
				return
			end
			Steer.set(steerStates[i], value, os.clock())
		end,
		playerLeft = function(player: Player)
			local i = indexOf(player)
			if i == nil or gone[i] then
				return
			end
			gone[i] = true
			-- The player who stays wins.
			if phase == "aim" or phase == "fight" then
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
