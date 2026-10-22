--!strict
-- Camera that sits behind the car, swings toward where the car is really going (so drifts show
-- their side), and widens the view with speed. Also: the show cam (circles the car), the driver
-- view (watch from the person's eyes like real RC, zooming in when the car is far away), the
-- top-down view (straight above, for drifting) and the free view (drag to look from any side).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type Cam = {
	update: (dt: number) -> (),
	snap: () -> (),
	toggleOrbit: () -> boolean,
	setView: (view: View) -> (),
}

export type View = "driver" | "chase" | "top" | "free"

local ChaseCamera = {}

-- Free view input, shared by every camera made (hooked up once): right mouse drag or a finger
-- dragged on open screen turns the view, the mouse wheel or a pinch zooms.
local turnX, turnY, zoomBy = 0, 0, 1
do
	local dragging = false
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local last = input.Position
			local conn: RBXScriptConnection
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					conn:Disconnect()
					return
				end
				local d = input.Position - last
				last = input.Position
				turnX += d.X * 0.012
				turnY += d.Y * 0.012
			end)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			turnX += input.Delta.X * 0.008
			turnY += input.Delta.Y * 0.008
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoomBy *= 1 - input.Position.Z * 0.12
		end
	end)
	local lastPinch = 1
	UserInputService.TouchPinch:Connect(
		function(
			_: { Vector2 },
			scale: number,
			_: number,
			state: Enum.UserInputState,
			processed: boolean
		)
			if processed then
				return
			end
			if state == Enum.UserInputState.Begin then
				lastPinch = 1
			end
			zoomBy *= lastPinch / math.max(scale, 0.01)
			lastPinch = scale
		end
	)
end

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
	-- the chase cam moves with the car's speed and only gently pulls onto the car, so tiny
	-- tyre and spring shakes never reach the view, but it never falls behind either
	local focus = body.Position + Vector3.new(0, 1.5 * Tuning.scale, 0)
	local flatSpeed = 0 -- smoothed ground speed (spring bounce up and down is not speed)
	local reach = 1 -- share of the full distance the camera is out (walls pull it in)
	local floorLift = 0 -- extra height to stay above the ground under the camera
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

	-- Track the car smoothly (both views use this): ground speed, heading and the focus point.
	local function follow(dt: number)
		local cf = body.CFrame
		local vel = body.AssemblyLinearVelocity
		local flatVel = Vector3.new(vel.X, 0, vel.Z)
		flatSpeed += (flatVel.Magnitude - flatSpeed) * (1 - math.exp(-3 * dt))
		local want = flat(cf.LookVector)
		-- lean toward the real direction of travel when moving forward
		-- (only while really moving now: pinned on a wall, the tiny speed points anywhere)
		if
			flatSpeed > 8 * Tuning.scale
			and flatVel.Magnitude > 8 * Tuning.scale
			and flatVel:Dot(cf.LookVector) > 0
		then
			local w = 0.55
				* CarMath.clamp((flatSpeed - 8 * Tuning.scale) / (20 * Tuning.scale), 0, 1)
			want = flat(want * (1 - w) + flat(flatVel) * w)
		end
		-- tumbling or on its side: the nose points anywhere, so hold the heading still
		if cf.UpVector.Y > 0.7 then
			heading = flat(heading:Lerp(want, 1 - math.exp(-5 * dt)))
		end

		-- carry the focus along at the car's speed, then pull it onto the car: no lag, no shake
		local raw = cf.Position + Vector3.new(0, 1.5 * Tuning.scale, 0)
		focus += flatVel * dt
		local kSide = 1 - math.exp(-10 * dt)
		local kUp = 1 - math.exp(-6 * dt)
		focus = Vector3.new(
			focus.X + (raw.X - focus.X) * kSide,
			focus.Y + (raw.Y - focus.Y) * kUp,
			focus.Z + (raw.Z - focus.Z) * kSide
		)
		if (raw - focus).Magnitude > 6 * Tuning.scale then
			focus = raw -- jumped (reset or teleport): catch up at once
		end
	end

	-- driver view: a small arrow over the car when something stands between the eyes and it
	local marker = Instance.new("BillboardGui")
	marker.Name = "CarMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(26, 26)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2.5 * Tuning.scale, 0)
	marker.Enabled = false
	marker.Adornee = body
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Text = "▼"
	arrow.TextColor3 = Color3.fromRGB(255, 220, 40)
	arrow.TextStrokeTransparency = 0
	arrow.Parent = marker
	marker.Parent = body

	local view: View = "chase"
	local orbiting = false
	local orbitAngle = 0
	-- free view: angle around the car, angle up, and how far out
	local freeYaw, freePitch, freeZoom = 0, 0.5, 1
	local freeReach = 1

	local cam = {} :: Cam

	-- Show-off view: circles slowly and low around the car to watch the springs work.
	function cam.toggleOrbit(): boolean
		orbiting = not orbiting
		clearFaded()
		local back = -flat(body.CFrame.LookVector)
		orbitAngle = math.atan2(back.Z, back.X) + 0.8
		cam.snap()
		return orbiting
	end

	function cam.snap()
		heading = flat(body.CFrame.LookVector)
		pos = body.Position - heading * Tuning.camDistance + Vector3.new(0, Tuning.camHeight, 0)
		lookAt = body.Position
		focus = body.Position + Vector3.new(0, 1.5 * Tuning.scale, 0)
		flatSpeed = 0
		reach = 1
		floorLift = 0
		-- the free view starts behind the car
		local back = -heading
		freeYaw = math.atan2(back.Z, back.X)
		freePitch, freeZoom, freeReach = 0.5, 1, 1
		turnX, turnY, zoomBy = 0, 0, 1
	end

	function cam.setView(v: View)
		view = v
		lift = 0
		clearFaded()
		orbiting = false
		cam.snap()
	end

	function cam.update(dt: number)
		dt = math.min(dt, 0.1)
		marker.Enabled = false
		-- a person spawning resets the camera; keep it ours
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if view == "driver" and not orbiting then
			follow(dt)
			local base = eye()
			local target = focus
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
			marker.Enabled = next(faded) ~= nil
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
		if view == "top" then
			-- straight above the car, a little ahead of where it is going, track's far end up
			follow(dt)
			local vel = body.AssemblyLinearVelocity
			local lead = Vector3.new(vel.X, 0, vel.Z) * 0.35
			if lead.Magnitude > Tuning.topHeight * 0.3 then
				lead = lead.Unit * Tuning.topHeight * 0.3
			end
			lookAt = lookAt:Lerp(focus + lead, 1 - math.exp(-4 * dt))
			local height = Tuning.topHeight
				* (1 + 0.25 * CarMath.clamp(flatSpeed / Tuning.topSpeed, 0, 1))
			pos = lookAt + Vector3.new(0, height, height * 0.12)
			camera.CFrame = CFrame.lookAt(pos, lookAt, -Vector3.zAxis)
			camera.FieldOfView = 50
			return
		end
		if view == "free" then
			follow(dt)
			freeYaw += turnX
			freePitch = CarMath.clamp(freePitch + turnY, 0.08, 1.45)
			freeZoom = CarMath.clamp(freeZoom * zoomBy, 0.35, 3)
			turnX, turnY, zoomBy = 0, 0, 1
			local dist = Tuning.freeDistance * freeZoom
			local out = Vector3.new(
				math.cos(freeYaw) * math.cos(freePitch),
				math.sin(freePitch),
				math.sin(freeYaw) * math.cos(freePitch)
			) * dist
			-- a rock or wall in the way: slide in (fast in, slow out)
			local limit = 1
			local hit = workspace:Raycast(focus, out, params)
			if hit then
				limit = CarMath.clamp((hit.Distance - 0.6 * Tuning.scale) / dist, 0.1, 1)
			end
			local rate = if limit < freeReach then 20 else 2.5
			freeReach += (limit - freeReach) * (1 - math.exp(-rate * dt))
			pos = focus + out * freeReach
			camera.CFrame = CFrame.lookAt(pos, focus)
			camera.FieldOfView = 65
			return
		end
		follow(dt)

		local dist = Tuning.camDistance
			* (1 + 0.2 * CarMath.clamp(flatSpeed / Tuning.topSpeed, 0, 1))
		local back = -heading * dist + Vector3.new(0, Tuning.camHeight, 0)
		-- a wall behind: slide in smoothly (fast in, slow out) instead of jumping every frame
		local limit = 1
		local hit = workspace:Raycast(focus, back, params)
		if hit then
			limit = CarMath.clamp((hit.Distance - 0.6 * Tuning.scale) / back.Magnitude, 0.15, 1)
		end
		local rate = if limit < reach then 20 else 2.5
		reach += (limit - reach) * (1 - math.exp(-rate * dt))
		pos = focus + back * reach

		-- never dip into the floor (eased, so bumps under the camera don't jolt it)
		local need = 0
		local down = workspace:Raycast(
			pos + Vector3.new(0, Tuning.camHeight, 0),
			Vector3.new(0, -Tuning.camHeight * 3, 0),
			params
		)
		if down then
			need = math.max(0, down.Position.Y + Tuning.camHeight * 0.4 - pos.Y)
		end
		local liftRate = if need > floorLift then 15 else 3
		floorLift += (need - floorLift) * (1 - math.exp(-liftRate * dt))
		pos += Vector3.new(0, floorLift, 0)

		lookAt = focus + heading * 5 * Tuning.scale
		camera.CFrame = CFrame.lookAt(pos, lookAt)
		camera.FieldOfView = CarMath.fov(flatSpeed)
	end

	return cam
end

return ChaseCamera
