--!strict
-- Drives one car every frame, flips it if upside down, pushes it forward.
-- Bots: step() asks the AI where to go and steers. Humans: stepManual() keeps the gas on and
-- steers from the player's input.
-- All forces are applied here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)
local Steer = require(ReplicatedStorage.Shared.Steer)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)

local Autopilot = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Puts a flipped car back on its wheels, same spot (a bit higher), same heading.
local function flipUpright(car: CarBuilder.Car)
	local cf = car.body.CFrame
	local look = flat(cf.LookVector)
	if look.Magnitude < 0.1 then
		look = flat(cf.UpVector)
	end
	if look.Magnitude < 0.1 then
		look = Vector3.zAxis
	end
	local pos = cf.Position + Vector3.new(0, 4, 0)
	car.model:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
	car.body.AssemblyLinearVelocity = Vector3.zero
	car.body.AssemblyAngularVelocity = Vector3.zero
end

-- Shared first part: flip recovery, then the grounded check. Returns the floor hit, or nil when
-- the car must not be driven this frame (flipped back, or in the air: no mid-air steering).
local function groundHit(car: CarBuilder.Car, dt: number, rayParams: RaycastParams): RaycastResult?
	local cf = car.body.CFrame
	local flipCfg = GameConfig.Flip
	local timer, doFlip = Logic.updateFlipTimer(
		car.flipTimer,
		cf.UpVector.Y,
		dt,
		flipCfg.upsideDownUpY,
		flipCfg.afterSeconds
	)
	car.flipTimer = timer
	if doFlip then
		flipUpright(car)
		return nil
	end

	local reach = car.stats.size[2] / 2 + GameConfig.Drive.groundRayExtra
	local hit = workspace:Raycast(cf.Position, Vector3.new(0, -reach, 0), rayParams)
	if hit == nil or not (hit.Instance.Name == "Floor" or hit.Instance.Name == "Slope") then
		return nil
	end
	return hit
end

-- Shared last part: push forward/back up to max speed (with slope assist), then grip.
local function push(
	car: CarBuilder.Car,
	fwd: Vector3,
	throttle: number,
	hit: RaycastResult,
	dt: number
)
	local body = car.body
	local stats = car.stats
	local mass = body.AssemblyMass
	local vel = body.AssemblyLinearVelocity
	local forwardSpeed = vel:Dot(fwd)
	local maxSpeed = stats.maxSpeed * Buffs.speedMult(car) -- speed power-up
	if
		(throttle > 0 and forwardSpeed < maxSpeed)
		or (throttle < 0 and forwardSpeed > -maxSpeed * 0.6)
	then
		-- Impulse = mass x speed change.
		body:ApplyImpulse(fwd * throttle * stats.accel * mass * dt)
		-- Slope assist: while driving, cancel the part of gravity that pulls back along the slope,
		-- so a heavy car can climb the bowl instead of stalling facing uphill.
		if throttle > 0 then
			local g = Vector3.new(0, -workspace.Gravity, 0)
			local along = (g - hit.Normal * g:Dot(hit.Normal)):Dot(fwd)
			if along < 0 then
				body:ApplyImpulse(fwd * -along * GameConfig.Drive.slopeAssist * mass * dt)
			end
		end
	end

	-- Grip: cancel part of the sideways slide so it drives like a car, not soap.
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local sideSpeed = vel:Dot(right)
	body:ApplyImpulse(-right * sideSpeed * math.min(1, GameConfig.Drive.grip * dt) * mass)
end

local function setSpin(body: BasePart, spin: number)
	local av = body.AssemblyAngularVelocity
	body.AssemblyAngularVelocity = Vector3.new(av.X, spin, av.Z)
end

-- Bot car: the AI picks the target, the car turns toward it.
function Autopilot.step(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	dt: number,
	rayParams: RaycastParams,
	center: Vector3
)
	local body = car.body
	local stats = car.stats
	local cf = body.CFrame
	local hit = groundHit(car, dt, rayParams)
	if hit == nil then
		return
	end

	-- Ask the AI what to do.
	local flatSpeed = flat(body.AssemblyLinearVelocity).Magnitude
	Ai.noteSpeed(car.ai, flatSpeed, dt, GameConfig.Ai.stuckSeconds, GameConfig.Ai.retreatTime)
	local pos, epos = cf.Position, enemy.body.Position
	local cmd = Ai.decide(
		stats.ai,
		{ x = pos.X, z = pos.Z },
		{ x = epos.X, z = epos.Z },
		car.ai,
		dt,
		GameConfig.Ai,
		{ x = center.X, z = center.Z }
	)

	-- Steer: spin around Y toward the target point.
	local fwd = flat(cf.LookVector)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	local angle = Ai.signedAngle(fwd.X, fwd.Z, cmd.tx - pos.X, cmd.tz - pos.Z)
	setSpin(body, Ai.steer(angle, GameConfig.Drive.turnGain, stats.turnRate))
	push(car, fwd, Ai.driveScale(angle, cmd.throttle), hit, dt)
end

-- Human car: gas is always on; `steerInput` (-1 left .. 1 right, already smoothed) turns it.
function Autopilot.stepManual(
	car: CarBuilder.Car,
	steerInput: number,
	dt: number,
	rayParams: RaycastParams
)
	local hit = groundHit(car, dt, rayParams)
	if hit == nil then
		return
	end
	local fwd = flat(car.body.CFrame.LookVector)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	setSpin(car.body, Steer.spin(steerInput, car.stats.turnRate, GameConfig.Drive.manualTurn))
	push(car, fwd, 1, hit, dt)
end

return Autopilot
