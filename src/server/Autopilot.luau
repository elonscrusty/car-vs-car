--!strict
-- Drives one car every frame: asks the AI where to go, steers, pushes, flips if upside down.
-- All forces are applied here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)
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

function Autopilot.step(
	car: CarBuilder.Car,
	enemy: CarBuilder.Car,
	dt: number,
	rayParams: RaycastParams
)
	local body = car.body
	local stats = car.stats
	local cf = body.CFrame

	-- 1. Upside down for too long? Flip back.
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
		return
	end

	-- 2. Only drive when wheels are on the ground (no mid-air steering).
	local reach = stats.size[2] / 2 + GameConfig.Drive.groundRayExtra
	local grounded = workspace:Raycast(cf.Position, Vector3.new(0, -reach, 0), rayParams) ~= nil
	if not grounded then
		return
	end

	-- 3. Ask the AI what to do.
	local pos, epos = cf.Position, enemy.body.Position
	local cmd = Ai.decide(
		stats.ai,
		{ x = pos.X, z = pos.Z },
		{ x = epos.X, z = epos.Z },
		car.ai,
		dt,
		GameConfig.Ai
	)

	-- 4. Steer: spin around Y toward the target point.
	local fwd = flat(cf.LookVector)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	local angle = Ai.signedAngle(fwd.X, fwd.Z, cmd.tx - pos.X, cmd.tz - pos.Z)
	local spin = Ai.steer(angle, GameConfig.Drive.turnGain, stats.turnRate)
	local av = body.AssemblyAngularVelocity
	body.AssemblyAngularVelocity = Vector3.new(av.X, spin, av.Z)

	-- 5. Push forward/back, up to max speed. Impulse = mass x speed change.
	local mass = body.AssemblyMass
	local vel = body.AssemblyLinearVelocity
	local forwardSpeed = vel:Dot(fwd)
	local throttle = Ai.driveScale(angle, cmd.throttle)
	if
		(throttle > 0 and forwardSpeed < stats.maxSpeed)
		or (throttle < 0 and forwardSpeed > -stats.maxSpeed * 0.6)
	then
		body:ApplyImpulse(fwd * throttle * stats.accel * mass * dt)
	end

	-- 6. Grip: cancel part of the sideways slide so it drives like a car, not soap.
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local sideSpeed = vel:Dot(right)
	body:ApplyImpulse(-right * sideSpeed * math.min(1, GameConfig.Drive.grip * dt) * mass)
end

return Autopilot
