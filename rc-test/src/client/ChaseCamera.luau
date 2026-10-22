--!strict
-- Camera that sits behind the car, swings toward where the car is really going (so drifts show
-- their side), and widens the view with speed. Also: the show cam (circles the car) and the driver
-- view (watch from the person's eyes like real RC, zooming in when the car is far away).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type Cam = {
	update: (dt: number) -> (),
	snap: () -> (),
	toggleOrbit: () -> boolean,
	setDriver: (on: boolean) -> (),
}

local ChaseCamera = {}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then
		return Vector3.zAxis
	end
	return f.Unit
end

function ChaseCamera.new(body: BasePart, ignore: { Instance }, eye: () -> Vector3): Cam
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local heading = flat(body.CFrame.LookVector)
	local pos = body.Position - heading * Tuning.camDistance + Vector3.new(0, Tuning.camHeight, 0)
	local lookAt = body.Position
	-- the chase cam follows the car's position exactly and only eases its offset, so it never
	-- falls behind at speed
	local offset = pos - body.Position
	local focusY = body.Position.Y + 1.5 * Tuning.scale
	local zoomFov = Tuning.driverFovMax
	-- driver view: how far the eyes are lifted to see over a wall, and walls see-through for now
	local lift = 0
	local faded: { [BasePart]: boolean } = {}

	local function clearFaded()
		for part in faded do
			part.LocalTransparencyModifier = 0
		end
		table.clear(faded)
	end

	local function blocker(from: Vector3, target: Vector3): BasePart?
		local d = target - from
		local hit = workspace:Raycast(from, d - d.Unit * 0.5 * Tuning.scale, params)
		if hit and hit.Instance:IsA("BasePart") then
			return hit.Instance :: BasePart
		end
		return nil
	end

	local driver = false
	local orbiting = false
	local orbitAngle = 0

	local cam = {} :: Cam

	-- Show-off view: circles slowly and low around the car to watch the springs work.
	function cam.toggleOrbit(): boolean
		orbiting = not orbiting
		clearFaded()
		local back = -flat(body.CFrame.LookVector)
		orbitAngle = math.atan2(back.Z, back.X) + 0.8
		if orbiting then
			driver = false
		end
		cam.snap()
		return orbiting
	end

	function cam.snap()
		heading = flat(body.CFrame.LookVector)
		pos = body.Position - heading * Tuning.camDistance + Vector3.new(0, Tuning.camHeight, 0)
		lookAt = body.Position
		focusY = body.Position.Y + 1.5 * Tuning.scale
		offset = pos - (body.Position + Vector3.new(0, 1.5 * Tuning.scale, 0))
	end

	function cam.setDriver(on: boolean)
		driver = on
		lift = 0
		clearFaded()
		if on then
			orbiting = false
		end
		cam.snap()
	end

	function cam.update(dt: number)
		dt = math.min(dt, 0.1)
		-- a person spawning resets the camera; keep it ours
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if driver then
			local base = eye()
			local target = body.Position
			-- a wall between the eyes and the car: look from a bit higher, the lowest height that
			-- sees the car; if even the highest is blocked, make the wall see-through
			local maxLift = Tuning.driverLiftMax
			local wantLift = maxLift
			for i = 0, 6 do
				local h = maxLift * i / 6
				if not blocker(base + Vector3.new(0, h, 0), target) then
					wantLift = h
					break
				end
			end
			lift += (wantLift - lift) * (1 - math.exp(-4 * dt))
			local from = base + Vector3.new(0, lift, 0)
			clearFaded()
			for _ = 1, 3 do
				local part = blocker(from, target)
				if not part or faded[part] then
					break
				end
				part.LocalTransparencyModifier = 0.75
				faded[part] = true
				params:AddToFilter(part)
			end
			if next(faded) then
				params.FilterDescendantsInstances = ignore
			end
			local dist = (target - from).Magnitude
			-- auto zoom: narrow the view as the car gets far away so it stays easy to see
			local want = math.deg(2 * math.atan(Tuning.driverWidth / 2 / math.max(dist, 0.01)))
			want = CarMath.clamp(want, Tuning.driverFovMin, Tuning.driverFovMax)
			zoomFov += (want - zoomFov) * (1 - math.exp(-3 * dt))
			lookAt = lookAt:Lerp(target, 1 - math.exp(-20 * dt))
			camera.CFrame = CFrame.lookAt(from, lookAt)
			camera.FieldOfView = zoomFov
			return
		end
		if orbiting then
			orbitAngle += Tuning.orbitSpeed * dt
			local center = body.Position + Vector3.new(0, 0.5 * Tuning.scale, 0)
			local want = center
				+ Vector3.new(math.cos(orbitAngle), 0, math.sin(orbitAngle)) * Tuning.orbitDistance
				+ Vector3.new(0, Tuning.orbitHeight, 0)
			local hit = workspace:Raycast(center, want - center, params)
			if hit then
				want = hit.Position + hit.Normal * 0.6 * Tuning.scale
				-- too close to the car: look down from above instead
				if (want - center).Magnitude < 6 * Tuning.scale then
					want = center + Vector3.new(0, Tuning.orbitDistance * 0.8, 0)
				end
			end
			pos = pos:Lerp(want, 1 - math.exp(-4 * dt))
			lookAt = lookAt:Lerp(center, 1 - math.exp(-8 * dt))
			camera.CFrame = CFrame.lookAt(pos, lookAt)
			camera.FieldOfView = 60
			return
		end
		local cf = body.CFrame
		local vel = body.AssemblyLinearVelocity
		local speed = vel.Magnitude
		local want = flat(cf.LookVector)
		-- lean toward the real direction of travel when moving forward
		if speed > 8 * Tuning.scale and vel:Dot(cf.LookVector) > 0 then
			local w = 0.55 * CarMath.clamp((speed - 8 * Tuning.scale) / (20 * Tuning.scale), 0, 1)
			want = flat(want * (1 - w) + flat(vel) * w)
		end
		local a = 1 - math.exp(-5 * dt)
		heading = flat(heading:Lerp(want, a))

		-- follow the car exactly sideways, but ease the height so bumps and springs don't shake
		-- the view
		local raw = cf.Position + Vector3.new(0, 1.5 * Tuning.scale, 0)
		focusY += (raw.Y - focusY) * (1 - math.exp(-6 * dt))
		local focus = Vector3.new(raw.X, focusY, raw.Z)
		local dist = Tuning.camDistance + speed * 0.05
		local desired = focus - heading * dist + Vector3.new(0, Tuning.camHeight, 0)
		-- keep the view out of walls and hills
		local toCam = desired - focus
		local hit = workspace:Raycast(focus, toCam, params)
		if hit then
			desired = hit.Position + hit.Normal * 0.6 * Tuning.scale
		end

		if hit then
			-- pulled in by a wall: jump there (no flip-flopping between two spots)
			offset = desired - focus
		else
			offset = offset:Lerp(desired - focus, 1 - math.exp(-8 * dt))
		end
		pos = focus + offset
		-- never dip into the floor
		local down = workspace:Raycast(
			pos + Vector3.new(0, Tuning.camHeight, 0),
			Vector3.new(0, -Tuning.camHeight * 3, 0),
			params
		)
		if down then
			local minY = down.Position.Y + Tuning.camHeight * 0.4
			if pos.Y < minY then
				pos = Vector3.new(pos.X, minY, pos.Z)
				offset = pos - focus
			end
		end
		lookAt = focus + heading * 5 * Tuning.scale
		camera.CFrame = CFrame.lookAt(pos, lookAt)
		camera.FieldOfView = CarMath.fov(speed)
	end

	return cam
end

return ChaseCamera
