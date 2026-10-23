--!strict
-- The RC car's driving: four ray-cast springs, tyres that can slide, a rear-biased engine and a
-- drift button. The player's own device owns the body, so these pushes answer instantly.
-- All the numbers live in Shared/Tuning and the maths in Shared/CarMath.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type Input = { steer: number, throttle: number, brake: number, drift: boolean }

export type Telemetry = {
	speed: number,
	vLong: number,
	slip: number,
	grounded: number, -- how many wheels touch
	drifting: boolean,
	wheels: { WheelInfo },
}

-- What each wheel is doing, for smoke and skid marks.
export type WheelInfo = {
	rear: boolean,
	touching: boolean,
	contact: Vector3, -- where the tyre meets the ground
	normal: Vector3,
	slide: number, -- sideways sliding speed of the tyre (studs/s)
}

-- A look-only skin for the wheels: mesh wheels drawn on the springs in place of the grey ones.
-- `spots` are where each wheel sits under the body (only X and Z are used), in the same order
-- as the wheels: front left, front right, rear left, rear right. `turns` is how each mesh is
-- turned inside the car. Nothing here touches the driving.
export type WheelLook = { wheels: { BasePart }, spots: { Vector3 }, turns: { CFrame } }

export type Car = {
	model: Model,
	body: BasePart,
	telemetry: Telemetry,
	step: (dt: number, input: Input) -> (),
	render: (dt: number) -> (),
	setLook: (look: WheelLook?) -> (),
	teleport: (cf: CFrame) -> (),
	destroy: () -> (),
}

type Wheel = {
	attach: Vector3, -- local spot the spring hangs from
	front: boolean,
	drive: number, -- share of the engine
	susp: number, -- current spring length
	shown: number, -- smoothed length for drawing
	spin: number,
	part: Part,
	bar: Part,
	info: WheelInfo,
}

local RCCar = {}

local function makeWheel(folder: Folder, attach: Vector3, front: boolean): Wheel
	local d = Tuning.wheelRadius * 2
	local part = Instance.new("Part")
	part.Name = "Wheel"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(Tuning.wheelWidth, d, d)
	part.Color = Color3.fromRGB(30, 30, 33)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = folder
	-- a light bar across the wheel so you can see it spin
	local bar = Instance.new("Part")
	bar.Name = "WheelBar"
	bar.Size = Vector3.new(Tuning.wheelWidth + 0.1, 0.3, d * 0.7)
	bar.Color = Color3.fromRGB(215, 215, 220)
	bar.Material = Enum.Material.SmoothPlastic
	bar.Anchored = true
	bar.CanCollide = false
	bar.CanQuery = false
	bar.CanTouch = false
	bar.Parent = folder
	return {
		attach = attach,
		front = front,
		drive = 0,
		susp = Tuning.maxSusp,
		shown = Tuning.maxSusp,
		spin = 0,
		part = part,
		bar = bar,
		info = {
			rear = not front,
			touching = false,
			contact = Vector3.zero,
			normal = Vector3.yAxis,
			slide = 0,
		},
	}
end

function RCCar.new(model: Model, ignore: { Instance }): Car
	local body = model.PrimaryPart :: BasePart
	local folder = Instance.new("Folder")
	folder.Name = "RCWheels"
	folder.Parent = workspace

	local wheels: { Wheel } = {}
	for _, fz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			local attach = Vector3.new(sx * Tuning.wheelX, Tuning.attachY, fz * Tuning.wheelZ)
			table.insert(wheels, makeWheel(folder, attach, fz < 0))
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { model, folder }
	for _, inst in ignore do
		table.insert(skip, inst)
	end
	rayParams.FilterDescendantsInstances = skip

	local steer = 0 -- right is positive
	local handbrake = 0
	local flippedFor = 0
	local holdLook: Vector3? = nil -- crawler: the heading to keep while the stick is centred
	local stuckFor = 0
	local boostLeft = 0 -- seconds of boost-pad push left
	local unstickTime = 0 -- seconds left of the helper's turn
	local unstickDir = 0
	local infos: { WheelInfo } = {}
	for i, w in wheels do
		infos[i] = w.info
	end
	local telemetry: Telemetry =
		{ speed = 0, vLong = 0, slip = 0, grounded = 0, drifting = false, wheels = infos }

	local car = {} :: Car
	car.model = model
	car.body = body
	car.telemetry = telemetry

	function car.step(dt: number, input: Input)
		if dt <= 0 or dt > 0.1 then
			return
		end
		local S = Tuning.scale
		-- the car's own gravity shrinks with its size, so a small car moves like the big one
		local gravity = workspace.Gravity * S
		local cf = body.CFrame
		local up = cf.UpVector
		local mass = body.AssemblyMass
		local wm = mass / 4
		local k = wm * Tuning.springOmega * Tuning.springOmega
		local c = 2 * Tuning.springZeta * wm * Tuning.springOmega
		local vel = body.AssemblyLinearVelocity

		local vLongBody = vel:Dot(cf.LookVector)
		local vLatBody = vel:Dot(cf.RightVector)
		local slip = CarMath.slipAngle(vLatBody, vLongBody)

		-- steering, with a little automatic counter-steer when the tail slides
		local stick = input.steer
		-- crawler: like a gyro in a real RC crawler, steer the nose back to the held heading
		-- after a bump knocks it off (the tyres grip too well to just twist the car back)
		local held = holdLook
		if Tuning.yawHold > 0 and held and math.abs(input.steer) < 0.05 then
			local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			if look.Magnitude > 0.1 then
				local err = math.asin(CarMath.clamp(held:Cross(look.Unit).Y, -1, 1))
				local dir = if vLongBody < -0.2 * Tuning.scale then -1 else 1
				stick = CarMath.clamp(err * 4 * dir, -1, 1)
			end
		end
		local target = CarMath.steerTarget(stick, vLongBody, slip)
		local rate = if math.abs(target) > math.abs(steer)
			then Tuning.steerRate
			else Tuning.steerReturn
		steer = CarMath.approach(steer, target, rate * dt)

		handbrake = CarMath.approach(
			handbrake,
			if input.drift then 1 else 0,
			(if input.drift then 5 else 3) * dt
		)

		-- what the pedals mean this frame
		local throttle = CarMath.clamp(input.throttle, 0, 1)
		local brake = CarMath.clamp(input.brake, 0, 1)
		local driveForward = throttle > 0
		local reversing = false
		local braking = false
		if not driveForward and brake > 0 then
			if vLongBody > 3 then
				braking = true
			else
				reversing = true
			end
		end

		local front = CarMath.frontShare(vLongBody)
		for _, w in wheels do
			w.drive = if w.front then front / 2 else (1 - front) / 2
		end

		boostLeft = math.max(0, boostLeft - dt)
		local grounded = 0
		for _, w in wheels do
			local attachWorld = cf * w.attach
			local rayLen = Tuning.wheelRadius + Tuning.maxSusp
			local hit = workspace:Raycast(attachWorld, -up * rayLen, rayParams)
			if hit and hit.Normal:Dot(up) > 0.25 then
				grounded += 1
				local n = hit.Normal
				local dist = hit.Distance
				w.susp = CarMath.clamp(dist - Tuning.wheelRadius, 0, Tuning.maxSusp)
				local compression = Tuning.maxSusp - w.susp

				local vPoint = body:GetVelocityAtPosition(attachWorld)
				local spring = CarMath.springForce(compression, -vPoint:Dot(n), k, c)
				if dist < Tuning.wheelRadius then
					spring += k * Tuning.bumpStop * (Tuning.wheelRadius - dist)
				end

				if hit.Instance:GetAttribute("Boost") == true then
					boostLeft = CarMath.BOOST_TIME
				end
				local gripAttr = hit.Instance:GetAttribute("Grip")
				local surfaceGrip = if type(gripAttr) == "number" then gripAttr else 1
				local mu = Tuning.baseMu * surfaceGrip

				-- the wheel's own forward / sideways directions, flat on the ground
				local ang = if w.front then -steer else 0
				local dir = CFrame.fromAxisAngle(up, ang) * cf.LookVector
				dir = dir - n * dir:Dot(n)
				if dir.Magnitude < 0.01 then
					dir = cf.LookVector
				end
				local fwd = dir.Unit
				local right = fwd:Cross(n)
				local vLong = vPoint:Dot(fwd)
				local vLat = vPoint:Dot(right)

				-- forward / back push
				local fx = 0
				local rear = not w.front
				if driveForward then
					fx = mass * CarMath.engineAccel(vLong, true) * w.drive * throttle
				elseif reversing then
					fx = -mass * CarMath.engineAccel(vLong, false) * w.drive * brake
				elseif braking then
					local want = vLong * wm / dt
					fx = -math.sign(vLong)
						* math.min(Tuning.brakeAccel * wm * brake, math.abs(want))
				elseif math.abs(vLong) < Tuning.holdSpeed then
					-- park on hills: cancel the roll and the pull of gravity
					fx = -vLong * wm * 0.3 / dt + CarMath.holdForce(wm, gravity, fwd.Y)
				else
					fx = -vLong * wm * Tuning.coastDrag
				end
				if boostLeft <= 0 then
					fx += CarMath.governor(vLong, wm, dt)
				end
				-- rough ground like grass slows the car all the time (no attribute = none)
				local dragAttr = hit.Instance:GetAttribute("Drag")
				if type(dragAttr) == "number" then
					fx -= vLong * wm * dragAttr
				end
				if rear and handbrake > 0 then
					fx -= vLong * wm * Tuning.handbrakeBleed * handbrake
				end

				-- sideways grip, weaker at the back while the drift button is down
				local latScale = if rear then 1 - (1 - Tuning.handbrakeRearGrip) * handbrake else 1
				if rear and Tuning.powerSlide > 0 then
					-- gas while already sideways keeps the back loose
					local sideways = CarMath.clamp((math.abs(slip) - 0.15) / 0.3, 0, 1)
					latScale *= 1 - Tuning.powerSlide * throttle * sideways
				end
				w.info.touching = true
				w.info.contact = hit.Position
				w.info.normal = n
				w.info.slide = math.abs(vLat)
				local fy = CarMath.lateralForce(vLat, vLong, mu * spring * latScale, wm, dt)
				fx, fy = CarMath.tractionCircle(fx, fy, mu * spring, mu * spring * latScale)

				local force = n * spring + fwd * fx + right * fy
				body:ApplyImpulseAtPosition(force * dt, attachWorld)
			else
				w.susp = Tuning.maxSusp
				w.info.touching = false
				w.info.slide = 0
			end
		end

		-- a little push down at speed keeps the car stuck to the road
		local speed = vel.Magnitude
		local t = CarMath.clamp(speed / Tuning.topSpeed, 0, 1)
		if grounded > 0 then
			body:ApplyImpulse(-up * mass * gravity * Tuning.downforce * t * t * dt)
			-- boost pad: push straight ahead for a moment, even past top speed
			if boostLeft > 0 then
				local ahead = cf.LookVector
				body:ApplyImpulse(ahead * mass * CarMath.boostAccel(vLongBody) * dt)
			end
			local thrust = CarMath.driftThrust(speed, slip, throttle)
			if thrust > 0 and vLongBody > 0 then
				local flatVel = Vector3.new(vel.X, 0, vel.Z)
				if flatVel.Magnitude > 1 then
					body:ApplyImpulse(flatVel.Unit * mass * thrust * dt)
				end
			end
			-- cap the spin so a drift stays a slide, not a spin-out
			local ang = body.AssemblyAngularVelocity
			local yaw = ang:Dot(up)
			local capped = CarMath.clamp(
				CarMath.driftYaw(yaw, slip, vLongBody, dt),
				-Tuning.maxYaw,
				Tuning.maxYaw
			)
			if capped ~= yaw then
				body.AssemblyAngularVelocity = ang - up * (yaw - capped)
			end
			-- crawler: keep the heading the car had when the stick was let go, so slopes and
			-- bumps don't slowly turn it off its line (springs back like a soft spring)
			if Tuning.yawHold > 0 and math.abs(input.steer) < 0.05 then
				local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
				if look.Magnitude > 0.1 then
					look = look.Unit
					local yawRate = body.AssemblyAngularVelocity.Y
					local c = Tuning.yawHold
					-- pick the heading once the wheels are straight: where the car is pointing
					-- plus the little bit it will still swing, so the end of a tap isn't pulled
					-- back and a slope can't slowly turn it either
					if holdLook == nil and math.abs(steer) < 0.02 then
						local ahead = CarMath.clamp(yawRate / c, -0.15, 0.15)
						holdLook = CFrame.Angles(0, ahead, 0):VectorToWorldSpace(look)
					end
					local err = 0
					if holdLook then
						err = math.asin(CarMath.clamp(holdLook:Cross(look).Y, -1, 1))
					end
					local accel = -(c * c / 4) * err - c * yawRate
					local inertiaYaw = mass * (Tuning.bodyX ^ 2 + Tuning.bodyZ ^ 2) / 12
					body:ApplyAngularImpulse(Vector3.yAxis * accel * inertiaYaw * dt)
				end
			else
				holdLook = nil
			end
		else
			-- in the air: settle the spin so jumps land flat-ish
			body.AssemblyAngularVelocity *= math.max(0, 1 - 1.5 * dt)
		end

		-- parked (no keys, barely moving, all four wheels down): settle on the springs instead of
		-- shimmering, which shows most on the small car
		if
			grounded == 4
			and input.throttle == 0
			and input.brake == 0
			and math.abs(input.steer) < 0.05
			and speed < Tuning.holdSpeed
		then
			-- as a push, not by setting the speed: setting it would throw away this step's
			-- spring and lift pushes and make the car hop
			body:ApplyImpulse(-vel * mass * math.min(1, 10 * dt))
		end

		-- nose stuck against a wall with the gas on and the stick turned: help it turn away,
		-- like bumping off the wall (only the gas would otherwise just keep pushing into it)
		local noseHit =
			workspace:Raycast(cf.Position, cf.LookVector * (Tuning.bodyZ / 2 + 0.6 * S), rayParams)
		if
			throttle > 0
			and math.abs(input.steer) > 0.2
			and noseHit
			and math.abs(noseHit.Normal.Y) < 0.6
			and math.abs(vLongBody) < 3 * S
		then
			stuckFor += dt
		else
			stuckFor = 0
		end
		if stuckFor > 0.25 and unstickTime <= 0 then
			-- start one short, fixed turn the way the stick points (about 55 degrees)
			unstickTime = 0.6
			unstickDir = -math.sign(input.steer)
			stuckFor = 0
		end
		if unstickTime > 0 then
			unstickTime -= dt
			-- set the spin directly: the tyres and the yaw limit would otherwise hold the car
			-- straight; also ease off the wall while it is still there
			local spin = body.AssemblyAngularVelocity
			local rate = if unstickTime > 0 then unstickDir * 1.6 else 0
			body.AssemblyAngularVelocity = spin - up * spin:Dot(up) + up * rate
			if noseHit then
				body:ApplyImpulse(noseHit.Normal * mass * 12 * S * dt)
			end
		end

		-- crawler: lean on its side past a little and it eases back upright, so a tall, soft car
		-- doesn't topple off a slope (like a heavy battery low in a real crawler)
		-- crawler: sticky tyres, so a side slope can't slide the car sideways off its line
		if Tuning.sideHold > 0 and grounded >= 2 then
			local right = cf.RightVector
			local vSide = body.AssemblyLinearVelocity:Dot(right)
			body:ApplyImpulse(-right * vSide * math.min(1, Tuning.sideHold * dt) * mass)
		end

		if Tuning.uprightAssist > 0 then
			local look = cf.LookVector
			local tipped = up:Cross(Vector3.yAxis):Dot(look) -- sin of the side lean, signed
			local over = math.sign(tipped) * math.max(0, math.abs(tipped) - 0.25)
			local rollRate = body.AssemblyAngularVelocity:Dot(look)
			local inertia = mass * (Tuning.bodyX ^ 2 + Tuning.bodyY ^ 2) / 12
			local accel = Tuning.uprightAssist * over
				- 4 * rollRate * math.min(1, math.abs(tipped) * 4)
			body:ApplyAngularImpulse(look * accel * inertia * dt)
		end

		-- upside down for a while = flip back over
		if S < 1 then
			body:ApplyImpulse(Vector3.yAxis * mass * (workspace.Gravity - gravity) * dt)
		end

		if up.Y < 0.15 and speed < 12 * S then
			flippedFor += dt
			if flippedFor > 1.2 then
				flippedFor = 0
				local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
				if look.Magnitude < 0.1 then
					look = Vector3.zAxis
				end
				car.teleport(
					CFrame.lookAt(cf.Position + Vector3.new(0, 3 * S, 0), cf.Position + look)
				)
			end
		else
			flippedFor = 0
		end

		telemetry.speed = speed
		telemetry.vLong = vLongBody
		telemetry.slip = slip
		telemetry.grounded = grounded
		telemetry.drifting = grounded > 0 and speed > 15 * S and math.abs(slip) > 0.25
	end

	local look: WheelLook? = nil

	-- Swaps the grey wheels for mesh ones (or back, with nil). Only changes what is drawn.
	function car.setLook(newLook: WheelLook?)
		look = newLook
		local hide = if newLook then 1 else 0
		for _, w in wheels do
			w.part.Transparency = hide
			w.bar.Transparency = hide
		end
	end

	-- Draws the wheels on the springs. Call every frame.
	function car.render(dt: number)
		local cf = body.CFrame
		local up = cf.UpVector
		local rot = cf.Rotation
		local vLong = telemetry.vLong
		for i, w in wheels do
			w.shown += (w.susp - w.shown) * math.min(1, 25 * dt)
			w.spin -= vLong / Tuning.wheelRadius * dt
			local spot = w.attach
			if look then
				local s = look.spots[i]
				spot = Vector3.new(s.X, w.attach.Y, s.Z)
			end
			local center = cf * spot - up * w.shown
			local yaw = if w.front then -steer else 0
			local wcf = CFrame.new(center)
				* rot
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(w.spin, 0, 0)
			w.part.CFrame = wcf
			w.bar.CFrame = wcf
			if look then
				look.wheels[i].CFrame = wcf * look.turns[i]
			end
		end
	end

	-- Puts the car somewhere, standing still.
	function car.teleport(cf: CFrame)
		model:PivotTo(cf)
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
		steer = 0
		handbrake = 0
		flippedFor = 0
		holdLook = nil
		for _, w in wheels do
			w.shown = Tuning.maxSusp
			w.susp = Tuning.maxSusp
		end
	end

	function car.destroy()
		folder:Destroy()
	end

	return car
end

return RCCar
