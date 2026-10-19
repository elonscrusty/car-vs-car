--!strict
-- Drives one car every frame, flips it if upside down, pushes it forward.
-- Bots: step() asks the AI where to go and steers. Humans: stepManual() keeps the gas on and
-- steers from the player's input.
-- All forces are applied here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local BotLevels = require(ReplicatedStorage.Shared.BotLevels)
local CarDrive = require(ReplicatedStorage.Shared.CarDrive)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)

-- Per-frame move effects for a human car (boost, drift). All 1 = normal driving.
export type Mods = CarDrive.Mods

local Autopilot = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Shared first part: flip recovery, then the grounded check. Returns the floor hit, or nil when
-- the car must not be driven this frame (flipped back, or in the air: no mid-air steering).
local function groundHit(car: CarBuilder.Car, dt: number, rayParams: RaycastParams): RaycastResult?
	local hit, timer =
		CarDrive.groundHit(car.model, car.body, car.stats, car.flipTimer, dt, rayParams)
	car.flipTimer = timer
	return hit
end

local function push(
	car: CarBuilder.Car,
	fwd: Vector3,
	throttle: number,
	hit: RaycastResult,
	dt: number,
	mods: Mods?
)
	CarDrive.push(car.body, car.stats, fwd, throttle, hit, dt, mods, Buffs.speedMult(car))
end

local setSpin = CarDrive.setSpin

-- Bot car: the AI picks the target, the car turns toward it.
function Autopilot.step(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	dt: number,
	rayParams: RaycastParams,
	center: Vector3,
	level: BotLevels.Level?,
	mods: Mods? -- boost and such (build-and-watch: the player's power buttons)
)
	local lv = level or BotLevels.get(nil)
	local body = car.body
	local stats = car.stats
	local cf = body.CFrame
	local hit = groundHit(car, dt, rayParams)
	if hit == nil then
		return
	end

	-- Ask the AI what to do. It needs to know how the car is moving (rim guard, lead aiming).
	local vel = flat(body.AssemblyLinearVelocity)
	local flatSpeed = vel.Magnitude
	local fwd = flat(cf.LookVector)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	local mem = car.ai
	local evel = flat(enemy.body.AssemblyLinearVelocity)
	mem.vx, mem.vz, mem.fx, mem.fz = vel.X, vel.Z, fwd.X, fwd.Z
	mem.evx, mem.evz, mem.lead = evel.X, evel.Z, lv.lead
	mem.runUp, mem.accel, mem.turnRate = lv.runUpMult, stats.accel, stats.turnRate
	Ai.noteSpeed(
		mem,
		flatSpeed,
		dt,
		BotLevels.stuckLimit(lv, GameConfig.Ai.stuckSeconds),
		GameConfig.Ai.retreatTime
	)
	local pos, epos = cf.Position, enemy.body.Position
	local cmd = Ai.decide(
		stats.ai,
		{ x = pos.X, z = pos.Z },
		{ x = epos.X, z = epos.Z },
		mem,
		dt,
		GameConfig.Ai,
		{ x = center.X, z = center.Z }
	)

	-- Steer: spin around Y toward the target point.
	local angle = Ai.signedAngle(fwd.X, fwd.Z, cmd.tx - pos.X, cmd.tz - pos.Z)
	angle += math.rad(BotLevels.wanderOffsetDeg(lv, os.clock(), car.idx))
	setSpin(body, Ai.steer(angle, GameConfig.Drive.turnGain * lv.turnGainMult, stats.turnRate))
	local throttle = Ai.driveScale(angle, cmd.throttle)
	local forwardSpeed = body.AssemblyLinearVelocity:Dot(fwd)
	if throttle > 0 and lv.speedMult < 1 and forwardSpeed > stats.maxSpeed * lv.speedMult then
		throttle = 0 -- slower bot: coast above its lower top speed
	end
	push(car, fwd, throttle, hit, dt, mods)
	if
		lv.speedMult > 1
		and throttle > 0
		and forwardSpeed >= stats.maxSpeed
		and forwardSpeed < stats.maxSpeed * lv.speedMult
	then
		-- Faster bot: push on past the normal top speed.
		body:ApplyImpulse(fwd * stats.accel * body.AssemblyMass * dt)
	end
end

-- Human car: `steerInput` (-1 left .. 1 right) turns it, `throttle` (-1 back .. 1 forward) is
-- the gas. Both are already smoothed.
function Autopilot.stepManual(
	car: CarBuilder.Car,
	steerInput: number,
	throttle: number,
	dt: number,
	rayParams: RaycastParams,
	mods: Mods?
)
	car.flipTimer = CarDrive.manual(
		car.model,
		car.body,
		car.stats,
		car.flipTimer,
		steerInput,
		throttle,
		dt,
		rayParams,
		mods,
		Buffs.speedMult(car)
	)
end

return Autopilot
