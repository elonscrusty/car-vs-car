--!strict
-- How a car drives: flip recovery, the ground check, gas / reverse, the slope assist, side grip
-- and turning. Used on the SERVER for bot cars and on the PLAYER'S OWN DEVICE for their car
-- (the driver owns their car's physics so it answers instantly). Forces only work on the machine
-- that owns the car, so call these only there.

local CarConfig = require(script.Parent.CarConfig)
local CarTraits = require(script.Parent.CarTraits)
local GameConfig = require(script.Parent.GameConfig)
local Logic = require(script.Parent.Logic)
local Steer = require(script.Parent.Steer)

-- Per-frame move effects for a human car (boost, drift). All 1 = normal driving.
export type Mods = { speedScale: number, accelScale: number, gripScale: number, turnScale: number }

-- Remembers the last floor hit so a one-frame miss (bump, seam, ramp lip) does not drop the grip.
export type GroundMemory = { hit: RaycastResult?, age: number }

local CarDrive = {}

function CarDrive.newGroundMemory(): GroundMemory
	return { hit = nil, age = math.huge }
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Puts a flipped car back on its wheels, same spot (a bit higher), same heading.
function CarDrive.flipUpright(model: Model, body: BasePart)
	local cf = body.CFrame
	local look = flat(cf.LookVector)
	if look.Magnitude < 0.1 then
		look = flat(cf.UpVector)
	end
	if look.Magnitude < 0.1 then
		look = Vector3.zAxis
	end
	local pos = cf.Position + Vector3.new(0, 4, 0)
	model:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
end

-- Flip recovery, then the grounded check. Returns (floor hit or nil, new flip timer). The hit is
-- nil when the car must not be driven this frame (flipped back, or in the air: no mid-air steering).
function CarDrive.groundHit(
	model: Model,
	body: BasePart,
	stats: CarConfig.CarStats,
	flipTimer: number,
	dt: number,
	rayParams: RaycastParams
): (RaycastResult?, number)
	local cf = body.CFrame
	local flipCfg = GameConfig.Flip
	local timer, doFlip = Logic.updateFlipTimer(
		flipTimer,
		cf.UpVector.Y,
		dt,
		flipCfg.upsideDownUpY,
		flipCfg.afterSeconds
	)
	if doFlip then
		CarDrive.flipUpright(model, body)
		return nil, timer
	end

	local reach = stats.size[2] / 2 + GameConfig.Drive.groundRayExtra
	local hit = workspace:Raycast(cf.Position, Vector3.new(0, -reach, 0), rayParams)
	if hit == nil or not (hit.Instance.Name == "Floor" or hit.Instance.Name == "Slope") then
		return nil, timer
	end
	return hit, timer
end

-- Push forward/back up to max speed (with slope assist), then grip. `speedMult` is the power-up
-- top-speed multiplier.
function CarDrive.push(
	body: BasePart,
	stats: CarConfig.CarStats,
	fwd: Vector3,
	throttle: number,
	hit: RaycastResult,
	dt: number,
	mods: Mods?,
	speedMult: number,
	steerAbs: number? -- how hard the driver is steering (0..1); drives the car's drift trait
)
	local mass = body.AssemblyMass
	local vel = body.AssemblyLinearVelocity
	local forwardSpeed = vel:Dot(fwd)
	local maxSpeed = stats.maxSpeed * speedMult * (if mods then mods.speedScale else 1)
	-- Handling traits (CarTraitsConfig): acceleration curve and grip depend on how close to top
	-- speed the car is.
	local traits = CarTraits.of(stats)
	local frac = CarTraits.speedFrac(forwardSpeed, maxSpeed)
	if
		(throttle > 0 and forwardSpeed < maxSpeed)
		or (throttle < 0 and forwardSpeed > -maxSpeed * 0.6)
	then
		-- Impulse = mass x speed change.
		local accelScale = (if mods then mods.accelScale else 1)
			* CarTraits.accelFactor(traits, frac)
		body:ApplyImpulse(fwd * throttle * stats.accel * accelScale * mass * dt)
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

	-- No gas: roll to a stop instead of gliding (player cars only; bots keep their old coast).
	if mods and math.abs(throttle) < 0.05 then
		local k = math.min(1, GameConfig.Drive.coastDrag * dt)
		body:ApplyImpulse(-fwd * forwardSpeed * k * mass)
	end

	-- Grip: cancel part of the sideways slide so it drives like a car, not soap.
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local sideSpeed = vel:Dot(right)
	local gripScale = (if mods then mods.gripScale else 1)
		* CarTraits.gripFactor(traits, steerAbs or 0, frac)
	body:ApplyImpulse(
		-right
			* sideSpeed
			* math.min(
				1,
				(if mods then GameConfig.Drive.humanGrip else GameConfig.Drive.grip)
					* gripScale
					* dt
			)
			* mass
	)
end

function CarDrive.setSpin(body: BasePart, spin: number)
	local av = body.AssemblyAngularVelocity
	body.AssemblyAngularVelocity = Vector3.new(av.X, spin, av.Z)
end

-- Human driving, one frame: `steerInput` (-1 left .. 1 right) turns the car, `throttle`
-- (-1 back .. 1 forward) is the gas. Both are already smoothed. Returns the new flip timer.
function CarDrive.manual(
	model: Model,
	body: BasePart,
	stats: CarConfig.CarStats,
	flipTimer: number,
	steerInput: number,
	throttle: number,
	dt: number,
	rayParams: RaycastParams,
	mods: Mods?,
	speedMult: number,
	memory: GroundMemory?
): number
	local hit, timer = CarDrive.groundHit(model, body, stats, flipTimer, dt, rayParams)
	if memory ~= nil then
		if hit ~= nil then
			memory.hit, memory.age = hit, 0
		else
			memory.age += dt
			if memory.hit ~= nil and memory.age <= GameConfig.Drive.groundCoyote then
				hit = memory.hit
			end
		end
	end
	if hit == nil then
		return timer
	end
	local fwd = flat(body.CFrame.LookVector)
	if fwd.Magnitude < 0.1 then
		return timer
	end
	fwd = fwd.Unit
	local drive = GameConfig.Drive
	local traits = CarTraits.of(stats)
	local speedFrac = CarTraits.speedFrac(body.AssemblyLinearVelocity:Dot(fwd), stats.maxSpeed)
	-- Turn rate fades toward the car's highTurn trait as it nears top speed (heavy cars push wide).
	local turnScale = (if mods then mods.turnScale else 1) * CarTraits.turnFactor(traits, speedFrac)
	if mods then
		local flatSpeed = flat(body.AssemblyLinearVelocity).Magnitude
		turnScale *= drive.turnMinShare + (1 - drive.turnMinShare) * math.clamp(
			flatSpeed / drive.turnFullSpeed,
			0,
			1
		)
	end
	local turnRate =
		math.clamp(stats.turnRate * drive.manualTurn, drive.manualTurnMin, drive.manualTurnMax)
	CarDrive.setSpin(body, Steer.spin(steerInput, turnRate, turnScale))
	CarDrive.push(body, stats, fwd, throttle, hit, dt, mods, speedMult, math.abs(steerInput))
	return timer
end

return CarDrive
