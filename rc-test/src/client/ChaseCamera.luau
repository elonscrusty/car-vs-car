--!strict
-- Camera that sits behind the car, swings toward where the car is really going (so drifts show
-- their side), and widens the view with speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type Cam = {
	update: (dt: number) -> (),
	snap: () -> (),
}

local ChaseCamera = {}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then
		return Vector3.zAxis
	end
	return f.Unit
end

function ChaseCamera.new(body: BasePart, ignore: { Instance }): Cam
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local heading = flat(body.CFrame.LookVector)
	local pos = body.Position - heading * Tuning.camDistance + Vector3.new(0, Tuning.camHeight, 0)
	local lookAt = body.Position

	local cam = {} :: Cam

	function cam.snap()
		heading = flat(body.CFrame.LookVector)
		pos = body.Position - heading * Tuning.camDistance + Vector3.new(0, Tuning.camHeight, 0)
		lookAt = body.Position
	end

	function cam.update(dt: number)
		dt = math.min(dt, 0.1)
		local cf = body.CFrame
		local vel = body.AssemblyLinearVelocity
		local speed = vel.Magnitude
		local want = flat(cf.LookVector)
		-- lean toward the real direction of travel when moving forward
		if speed > 8 and vel:Dot(cf.LookVector) > 0 then
			local w = 0.55 * CarMath.clamp((speed - 8) / 20, 0, 1)
			want = flat(want * (1 - w) + flat(vel) * w)
		end
		local a = 1 - math.exp(-5 * dt)
		heading = flat(heading:Lerp(want, a))

		local focus = cf.Position + Vector3.new(0, 1.5, 0)
		local dist = Tuning.camDistance + speed * 0.05
		local desired = focus - heading * dist + Vector3.new(0, Tuning.camHeight, 0)
		-- keep the view out of walls and hills
		local toCam = desired - focus
		local hit = workspace:Raycast(focus, toCam, params)
		if hit then
			desired = hit.Position + hit.Normal * 0.6
		end

		local ax = 1 - math.exp(-9 * dt)
		local ay = 1 - math.exp(-6 * dt)
		pos = Vector3.new(
			pos.X + (desired.X - pos.X) * ax,
			pos.Y + (desired.Y - pos.Y) * ay,
			pos.Z + (desired.Z - pos.Z) * ax
		)
		if hit then
			pos = desired
		end
		lookAt = lookAt:Lerp(focus + heading * 5, 1 - math.exp(-12 * dt))
		camera.CFrame = CFrame.lookAt(pos, lookAt)
		camera.FieldOfView = CarMath.fov(speed)
	end

	return cam
end

return ChaseCamera
