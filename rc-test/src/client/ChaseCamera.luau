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
	local zoomFov = Tuning.driverFovMax

	local driver = false
	local orbiting = false
	local orbitAngle = 0

	local cam = {} :: Cam

	-- Show-off view: circles slowly and low around the car to watch the springs work.
	function cam.toggleOrbit(): boolean
		orbiting = not orbiting
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
		offset = pos - (body.Position + Vector3.new(0, 1.5 * Tuning.scale, 0))
	end

	function cam.setDriver(on: boolean)
		driver = on
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
			local from = eye()
			local target = body.Position
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

		local focus = cf.Position + Vector3.new(0, 1.5 * Tuning.scale, 0)
		local dist = Tuning.camDistance + speed * 0.05
		local desired = focus - heading * dist + Vector3.new(0, Tuning.camHeight, 0)
		-- keep the view out of walls and hills
		local toCam = desired - focus
		local hit = workspace:Raycast(focus, toCam, params)
		if hit then
			desired = hit.Position + hit.Normal * 0.6 * Tuning.scale
		end

		offset = offset:Lerp(desired - focus, 1 - math.exp(-8 * dt))
		pos = focus + offset
		if hit then
			pos = desired
		end
		lookAt = focus + heading * 5 * Tuning.scale
		camera.CFrame = CFrame.lookAt(pos, lookAt)
		camera.FieldOfView = CarMath.fov(speed)
	end

	return cam
end

return ChaseCamera
