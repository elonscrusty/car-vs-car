--!strict
-- How a car a PLAYER drives moves: top speed, wall bounce, knocked slide, grip, drift, turning.
-- Shared on purpose: the server runs it for server-driven cars, and the player's own device runs
-- it for their own car (the device owns that car's physics, so it answers the stick at once).
-- The server still decides hits, HP and weapons. `Mover` is the part of a battle car this needs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleFeel = require(ReplicatedStorage.Shared.BattleFeel)

export type Out = { turn: number, drive: number, state: string }
export type Mover = {
	body: BasePart,
	model: Model,
	L: number,
	fighter: BattleConfig.Fighter,
	stagger: number, -- > 0 while knocked: the car slides and cannot steer
	slide: Vector3, -- flat velocity a wall bounce keeps pushing while knocked
	lastForward: Vector3,
	momentum: boolean,
	turnNow: number?, -- the steering after smoothing (-1..1): the wheel takes a moment to swing
}

local BattleDrive = {}

-- One RaycastParams per car model (excluding the model itself), made once and reused every step.
local paramCache: { [Model]: RaycastParams } = setmetatable({}, { __mode = "k" }) :: any
local function paramsFor(model: Model): RaycastParams
	local p = paramCache[model]
	if p == nil then
		p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { model }
		paramCache[model] = p
	end
	return p
end

-- Body facing, flat on the floor.
function BattleDrive.forward(car: Mover): Vector3
	local lv = car.body.CFrame.LookVector
	local p = Vector3.new(lv.X, 0, lv.Z)
	local f = if p.Magnitude < 1e-4 then Vector3.new(0, 0, -1) else p.Unit
	car.lastForward = f
	return f
end

-- A wall part the map tags "Bouncy" (the duel arena walls, cover blocks and tires) throws a car back
-- that runs into it, instead of letting the drive code push it to a dead stop. The car loses a bit
-- of speed, slides back for a moment and cannot steer meanwhile (the knocked state). No damage.
-- Every car has the same top speed (spec: only weight and turning differ).
function BattleDrive.topSpeed(_car: Mover): number
	return BattleConfig.Human.topSpeed
end

function BattleDrive.wallBounce(car: Mover, v: Vector3, dt: number): boolean
	local body = car.body
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	if speed < 0.3 * BattleDrive.topSpeed(car) then
		return false
	end
	local params = paramsFor(car.model)
	-- a box the size of the car (a little thinner, and clear of the floor) sweeps ahead, so a
	-- corner, a block's edge or a tire the middle line would miss still throws the car back
	local sweep = math.max(speed * dt * 3, 3) + 1
	local size = Vector3.new(body.Size.X * 0.9, math.max(body.Size.Y * 0.5, 1), body.Size.Z * 0.9)
	local hit = workspace:Blockcast(
		CFrame.new(body.Position) * body.CFrame.Rotation,
		size,
		flat.Unit * sweep,
		params
	)
	if hit == nil then
		-- already touching: the sweep starts inside the wall, so fall back to a ray from the middle
		hit = workspace:Raycast(body.Position, flat.Unit * (body.Size.Z / 2 + sweep), params)
	end
	if hit == nil or not CollectionService:HasTag(hit.Instance, "Bouncy") then
		return false
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	if n.Magnitude < 1e-3 then
		return false
	end
	n = n.Unit
	local props = (hit.Instance :: BasePart).CustomPhysicalProperties
	local keep = (if props then props.Elasticity else 0.5) * 0.85
	local r = (flat - 2 * flat:Dot(n) * n) * keep
	body.AssemblyLinearVelocity = Vector3.new(r.X, v.Y, r.Z)
	car.stagger = math.max(car.stagger, 0.6)
	car.slide = Vector3.new(r.X, 0, r.Z)
	return true
end

-- A car the player drives: quicker getaway, tight turns from a standstill, a drift when steering
-- hard at speed, and no forced speed while airborne (so a ramp launches it properly).
function BattleDrive.humanStep(car: Mover, out: Out, dt: number, f: Vector3, v: Vector3)
	local mv = BattleConfig.Move
	local H = BattleConfig.Human
	local body = car.body
	local cruise = BattleDrive.topSpeed(car)
	local steerNow = out.turn
	if out.state ~= "charge" and out.state ~= "skid" then
		steerNow = BattleFeel.smoothTurn(car.turnNow or 0, out.turn, dt)
	end
	car.turnNow = steerNow
	local yawRate = steerNow * math.rad(car.fighter.turnDeg)

	local params = paramsFor(car.model)
	local onGround = workspace:Raycast(
		body.Position,
		Vector3.new(0, -(body.Size.Y * 0.5 + H.groundRayL * car.L), 0),
		params
	) ~= nil
	car.model:SetAttribute("Airborne", not onGround)
	if not onGround then
		-- in the air: keep the speed and spin the ramp gave it, steer a little
		local w = body.AssemblyAngularVelocity
		body.AssemblyAngularVelocity = Vector3.new(w.X, yawRate * H.airYawScale, w.Z)
		return
	end

	local fwd = v.X * f.X + v.Z * f.Z
	local lat = Vector3.new(v.X - f.X * fwd, 0, v.Z - f.Z * fwd)
	local want = out.drive * cruise
	if want < 0 then
		want *= mv.reverseScale
	end
	if out.state == "charge" then
		fwd += math.clamp(want - fwd, -mv.accel * 4 * cruise * dt, mv.accel * 4 * cruise * dt) -- a charge gets up to speed fast
	elseif out.state == "skid" then
		local step = mv.skidBrake * cruise * dt -- a missed charge rolls on
		fwd += math.clamp(want - fwd, -step, step)
	else
		fwd = BattleFeel.nextSpeed(fwd, want, dt, cruise)
	end
	local skidding = out.state == "skid"

	local speedFrac = math.abs(fwd) / cruise
	local drifting = not skidding
		and out.state ~= "charge"
		and math.abs(out.turn) >= H.driftSteer
		and speedFrac >= H.driftSpeed
	car.model:SetAttribute("Drifting", drifting)
	local sideGrip = if skidding then mv.skidSide elseif drifting then H.driftSide else 8
	lat *= math.max(0, 1 - sideGrip * dt)
	local maxSlide = H.slideMaxFrac * cruise
	if lat.Magnitude > maxSlide then
		lat = lat.Unit * maxSlide
	end
	body.AssemblyLinearVelocity = Vector3.new(f.X * fwd + lat.X, v.Y, f.Z * fwd + lat.Z)

	local turnScale = BattleFeel.turnScale(speedFrac)
	if out.state == "charge" then
		turnScale = H.chargeSteerScale
	elseif drifting then
		turnScale *= H.driftYawBoost
	end
	body.AssemblyAngularVelocity = Vector3.new(0, yawRate * turnScale, 0)
end

-- A knocked car slides and spins on the shove with no steering. True while it is knocked.
function BattleDrive.knockedStep(car: Mover, v: Vector3, dt: number): boolean
	if car.stagger <= 0 then
		return false
	end
	local mv = BattleConfig.Move
	car.stagger = math.max(0, car.stagger - dt)
	local keep = math.max(0, 1 - mv.knockFriction * dt)
	local body = car.body
	if car.slide.Magnitude > 0 then
		-- a wall bounce: hold the slide ourselves so the floor does not stop it in a blink
		car.slide *= keep
		body.AssemblyLinearVelocity = Vector3.new(car.slide.X, v.Y, car.slide.Z)
		if car.stagger <= 0 then
			car.slide = Vector3.zero
		end
		return true
	end
	body.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
	return true
end

-- One step of a player-driven car: wall bounce, knocked slide, else the human feel.
function BattleDrive.drive(car: Mover, out: Out, dt: number)
	local f = BattleDrive.forward(car)
	local v = car.body.AssemblyLinearVelocity
	if car.stagger <= 0 and BattleDrive.wallBounce(car, v, dt) then
		return
	end
	if BattleDrive.knockedStep(car, v, dt) then
		return
	end
	BattleDrive.humanStep(car, out, dt, f, v)
end

return BattleDrive
