--!strict
-- Camera that sits behind the car, swings toward where the car is really going (so drifts show
-- their side), and widens the view with speed. Also: the show cam (circles the car), the driver
-- view (watch from the person's eyes like real RC, zooming in when the car is far away), the
-- top-down view (straight above, for drifting) and the free view (drag to look from any side).
-- In a Smash match the chase view eases into the match camera (shared/ArenaCam: higher, further
-- back, tilted down, a little look-ahead); Main switches it with setArena while InMatch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ArenaCam = require(ReplicatedStorage.Shared.ArenaCam)
local CarMath = require(ReplicatedStorage.Shared.CarMath)
local SeeKart = require(ReplicatedStorage.Shared.SeeKart)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

export type Cam = {
	update: (dt: number) -> (),
	snap: () -> (),
	toggleOrbit: () -> boolean,
	setView: (view: View) -> (),
	setUp: (dir: Vector3) -> (),
	kick: (degrees: number) -> (),
	setArena: (on: boolean, now: boolean?) -> (),
	arenaDistance: () -> number,
	isArena: () -> boolean,
	comeBack: () -> (),
	flyIn: () -> (),
}

export type View = "driver" | "chase" | "top" | "free"

local ChaseCamera = {}

-- Free view input, shared by every camera made (hooked up once): a mouse drag (either button) or
-- a finger dragged on open screen turns the view, the mouse wheel or a pinch zooms.
-- Roblox's own camera scripts mark the right button, wheel and touches as "used", so that flag
-- is not trusted here; instead a press that lands on one of our buttons or the stick is skipped.
local turnX, turnY, zoomBy = 0, 0, 1
do
	local player = Players.LocalPlayer
	local function onButton(pos: Vector3): boolean
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return false
		end
		for _, g in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			if g.Active and g.Visible then
				return true
			end
		end
		return false
	end
	local dragging = false
	local lastMouse = Vector3.zero
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.MouseButton1 then
			if not onButton(input.Position) then
				dragging = true
				lastMouse = input.Position
			end
		elseif kind == Enum.UserInputType.Touch then
			if onButton(input.Position) then
				return
			end
			local last = input.Position
			local conn: RBXScriptConnection
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					conn:Disconnect()
					return
				end
				local d = input.Position - last
				last = input.Position
				turnX += d.X * 0.006
				turnY += d.Y * 0.006
			end)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.MouseButton1 then
			dragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
				or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- screen position change, not Delta: Delta is only filled in while the mouse is locked
			local d = input.Position - lastMouse
			lastMouse = input.Position
			if dragging then
				turnX += d.X * 0.008
				turnY += d.Y * 0.008
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			zoomBy *= 1 - input.Position.Z * 0.12
		end
	end)
	local lastPinch = 1
	UserInputService.TouchPinch:Connect(
		function(_: { Vector2 }, scale: number, _: number, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				lastPinch = 1
			end
			zoomBy *= lastPinch / math.max(scale, 0.01)
			lastPinch = scale
		end
	)
end

-- the match camera's numbers (shared/ArenaCam), worked out again only when the screen's size
-- changes: a phone-shaped screen gets the close camera (ArenaCam.fit)
local STUDIO = game:GetService("RunService"):IsStudio()
local arenaFit: ArenaCam.Fit = ArenaCam.fit(844, 390)
local arenaFitFor = Vector2.zero
local arenaFitPhone: boolean? = nil
local ARENA_BACK, ARENA_UP = ArenaCam.offset(arenaFit.distance, arenaFit.pitch)
local STEEP_BACK, STEEP_UP = ArenaCam.offset(arenaFit.distance, ArenaCam.STEEP)
local function refit(view: Vector2)
	if view.X < 1 or view.Y < 1 then
		return
	end
	-- a phone: by size, a touch screen with no keyboard, or Studio's TestPhoneCam switch
	local phone = ArenaCam.isPhone(
		view.X,
		view.Y,
		UserInputService.TouchEnabled,
		UserInputService.KeyboardEnabled,
		ArenaCam.forced(STUDIO, workspace:GetAttribute(ArenaCam.TEST_ATTR))
	)
	if view == arenaFitFor and phone == arenaFitPhone then
		return
	end
	arenaFitFor, arenaFitPhone = view, phone
	arenaFit = ArenaCam.fit(view.X, view.Y, phone)
	ARENA_BACK, ARENA_UP = ArenaCam.offset(arenaFit.distance, arenaFit.pitch)
	STEEP_BACK, STEEP_UP = ArenaCam.offset(arenaFit.distance, ArenaCam.STEEP)
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
	local kick = 0 -- extra field of view for a moment (boost pads), eases back to 0
	-- driver view: how far the eyes are lifted to see over a wall, and walls see-through for now
	local lift = 0
	local faded: { [BasePart]: boolean } = {}
	-- the match camera: on or off, and how far into it (eased over ArenaCam.BLEND)
	local arenaOn = false
	local arenaFrom, arenaW, arenaT = 0, 0, 0
	local whoosh = -1 -- seconds into the come-back whoosh after a respawn (below 0 = not playing)
	local flying = -1 -- seconds into the match start fly-in (below 0 = not playing)
	refit(camera.ViewportSize) -- (this screen's numbers before the first spot: no swoop)
	local arenaOff = -heading * ARENA_BACK + Vector3.new(0, ARENA_UP, 0) -- camera minus focus
	local lean = Vector3.zero -- the look-ahead, eased
	-- the kart you SEE (CarSkin's RCSkin: bigger than the physics box, down to the ground): its
	-- middle in the body's own space, measured per skin; the match camera aims at it
	local seenSkin: Instance? = nil -- the skin measured (kept once two frames agree)
	local seenTry: Vector3? = nil -- last frame's measure of a skin not kept yet
	local seenMid = Vector3.zero
	local seenRel: Vector3? = nil -- its middle minus the followed spot, eased (no spring shake)
	local function measure(skin: Instance): Vector3?
		local lo, hi = nil :: Vector3?, nil :: Vector3?
		for _, d in skin:GetDescendants() do
			if d:IsA("BasePart") then
				-- the part's box in the body's axes (a skin part keeps its imported turn)
				local rel = body.CFrame:ToObjectSpace(d.CFrame)
				local h = d.Size / 2
				local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
				local ext = Vector3.new(
					math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
					math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
					math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
				)
				local c = rel.Position
				lo = if lo then lo:Min(c - ext) else c - ext
				hi = if hi then hi:Max(c + ext) else c + ext
			end
		end
		return if lo and hi then (lo + hi) / 2 else nil
	end
	local function seenMiddle(): Vector3
		local skin = workspace:FindFirstChild("RCSkin")
		if skin == nil then
			seenSkin, seenTry, seenMid = nil, nil, Vector3.zero
		elseif skin ~= seenSkin then
			-- (a new skin is placed over a frame or two: keep its middle once two frames agree
			-- and it sits on the kart; the body until then)
			local m = measure(skin)
			if m and m.Magnitude <= 2 * ArenaCam.KART_LONG then
				if seenTry and (seenTry - m).Magnitude < 0.05 then
					seenSkin, seenTry, seenMid = skin, nil, m
				else
					seenTry = m
				end
			else
				seenTry = nil
			end
		end
		return body.CFrame:PointToWorldSpace(if skin == seenSkin then seenMid else Vector3.zero)
	end
	-- its wall check sees only the arena itself (not other karts, shots or boxes) and looks past
	-- the arena props: SeeKart fades those instead of the camera jumping in at every tree
	local arenaParams = RaycastParams.new()
	arenaParams.FilterType = Enum.RaycastFilterType.Include
	local arenaModel: Instance? = nil

	-- how far out along `out` (camera minus focus) the camera can go before a wall or the floor,
	-- keeping WALL_GAP off the surface; never further than `out`
	local function arenaWant(out: Vector3): Vector3
		local model = if arenaModel and arenaModel.Parent == workspace
			then arenaModel
			else workspace:FindFirstChild("SmashArena")
		if model ~= arenaModel then
			arenaModel = model
			arenaParams.FilterDescendantsInstances = if model
				then { model, workspace.Terrain }
				else { workspace.Terrain }
		end
		local len = out.Magnitude
		if len < 1e-3 then
			return out
		end
		local from = focus
		local left = len
		local dir = out / len
		for _ = 1, 6 do
			local hit = workspace:Raycast(from, dir * left, arenaParams)
			if not hit then
				return out
			end
			local inst = hit.Instance
			-- (a wall pillar stands in the wall: it counts as the wall, so the camera never
			-- steps past it into the wall behind)
			if not SeeKart.PROPS[inst.Name] or inst.Name == "WallPillar" then
				-- the spot just off the surface, back along the ray
				return out * ArenaCam.reach(hit.Distance + (len - left), len)
			end
			-- a prop: go on from just past it
			local step = hit.Distance + 0.01
			from += dir * step
			left -= step
			if left <= 0 then
				return out
			end
		end
		return out
	end

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
	arrow.Font = Enum.Font.Oswald
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
	-- top view: screen-up points this way (the plot's far end; plots face the road)
	local topUp = -Vector3.zAxis

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

	-- the match camera's distance for this screen (Main's lost-camera check)
	function cam.arenaDistance(): number
		return arenaFit.distance
	end

	-- is the match camera on now (Main: a respawn in a match gets the come-back whoosh)
	function cam.isArena(): boolean
		return arenaOn
	end

	-- the come-back whoosh (shared/ArenaCam.comeBack): starts at the next frame
	function cam.comeBack()
		whoosh = 0
	end

	-- the match start fly-in (shared/ArenaCam.flyIn): starts at the next frame
	function cam.flyIn()
		flying = 0
	end

	function cam.snap()
		whoosh, flying = -1, -1
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
		-- (a jump: straight into the match camera if it's on, no blend; the wall check pulls it
		-- in on the first frame if it must)
		refit(camera.ViewportSize)
		arenaOff = -heading * ARENA_BACK + Vector3.new(0, ARENA_UP, 0)
		lean = Vector3.zero
		seenRel = nil
		arenaW = if arenaOn then 1 else 0
		arenaFrom, arenaT = arenaW, ArenaCam.BLEND
	end

	-- the match camera on or off; `now` = no blend (a fresh camera for a respawn)
	function cam.setArena(on: boolean, now: boolean?)
		if now then
			arenaOn = on
			arenaW = if on then 1 else 0
			arenaFrom, arenaT = arenaW, ArenaCam.BLEND
		elseif on ~= arenaOn then
			arenaOn = on
			arenaFrom, arenaT = arenaW, 0
		end
	end

	function cam.setUp(dir: Vector3)
		topUp = flat(dir)
	end

	function cam.setView(v: View)
		view = v
		lift = 0
		clearFaded()
		orbiting = false
		cam.snap()
	end

	function cam.kick(degrees: number)
		kick = math.max(kick, degrees)
	end

	function cam.update(dt: number)
		dt = math.min(dt, 0.1)
		kick *= math.exp(-2.5 * dt)
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
			camera.FieldOfView = zoomFov + kick
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
			pos = lookAt + Vector3.new(0, height, 0) - topUp * (height * 0.12)
			camera.CFrame = CFrame.lookAt(pos, lookAt, topUp)
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

		-- the match camera's share, eased over ArenaCam.BLEND s (in and out)
		arenaT += dt
		arenaW = arenaFrom + ((if arenaOn then 1 else 0) - arenaFrom) * ArenaCam.blend(arenaT)
		local fov = CarMath.fov(flatSpeed)
		if not (arenaOn and arenaW >= 1) then
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
		end

		if arenaW > 1e-3 then
			refit(camera.ViewportSize)
			-- where it wants to be: behind and above (further back at speed: the speed zoom),
			-- or swung up steeper when a wall is close
			local pull = 1 + arenaFit.back * CarMath.clamp(flatSpeed / Tuning.topSpeed, 0, 1)
			local want = arenaWant((-heading * ARENA_BACK + Vector3.new(0, ARENA_UP, 0)) * pull)
			if want.Magnitude < ArenaCam.MIN_REACH * arenaFit.distance * pull then
				local steep =
					arenaWant((-heading * STEEP_BACK + Vector3.new(0, STEEP_UP, 0)) * pull)
				if steep.Magnitude > want.Magnitude then
					want = steep
				end
			end
			-- the length: in at once (never inside a wall), back out slowly; the direction eases
			-- quickly (a swing up over the kart isn't a jump); then the same wall check on the
			-- spot itself
			local wantLen, len = want.Magnitude, arenaOff.Magnitude
			if wantLen <= len + 1e-3 then
				len = wantLen
			else
				len += (wantLen - len) * (1 - math.exp(-2.5 * dt))
			end
			local dir = if len > 1e-3 and wantLen > 1e-3
				then arenaOff.Unit:Lerp(want.Unit, 1 - math.exp(-12 * dt))
				else want
			-- (settled on `want`: it was just checked, no second check)
			arenaOff = if len == wantLen and dir:FuzzyEq(want.Unit, 1e-4)
				then want
				elseif dir.Magnitude > 1e-3 then arenaWant(dir.Unit * len)
				else want
			local offLen = arenaOff.Magnitude
			local vel = body.AssemblyLinearVelocity
			local flatVel = Vector3.new(vel.X, 0, vel.Z)
			local wantLean = if flatVel.Magnitude > 0.5
				then flatVel.Unit * ArenaCam.lead(flatVel.Magnitude) * arenaFit.lean
				else Vector3.zero
			lean += (wantLean - lean) * (1 - math.exp(-ArenaCam.LEAD_EASE * dt))
			-- (the aim fits the camera's real distance and pitch, so a pulled-in or swung-up
			-- camera keeps the kart in the lower third too)
			local aFov = arenaFit.fov
				+ arenaFit.fast * CarMath.clamp(flatSpeed / Tuning.topSpeed, 0, 1)
			local flatOff = Vector3.new(arenaOff.X, 0, arenaOff.Z).Magnitude
			local rel = seenMiddle() - focus
			seenRel = if seenRel then seenRel:Lerp(rel, 1 - math.exp(-8 * dt)) else rel
			local seen = seenRel :: Vector3
			local aim = if offLen > 1e-3
				then ArenaCam.aimAhead(
					offLen,
					math.deg(math.atan2(arenaOff.Y, flatOff)),
					aFov,
					arenaFit.low,
					-seen.Y,
					if flatOff > 1e-3
						then seen:Dot(-Vector3.new(arenaOff.X, 0, arenaOff.Z).Unit)
						else 0
				)
				else 0
			local aLook = focus + heading * aim + lean
			local wideBy = 0 -- the come-back's wider view
			if arenaW >= 1 then
				pos, lookAt = focus + arenaOff, aLook
				if flying >= 0 then
					-- the fly-in: round the arena from high up, tightening down onto the kart; a
					-- moving kart rushes it, so it never gets in the way of driving
					flying += dt * (if flatSpeed > 3 * Tuning.scale then ArenaCam.FLYIN_RUSH else 1)
					local k, turn, out, hgt, wide = ArenaCam.flyIn(flying, flatOff, arenaOff.Y)
					wideBy = wide
					local arena = arenaModel
					local middle = if arena and arena:IsA("Model")
						then arena:GetBoundingBox().Position
						else focus
					local mid = Vector3.new(middle.X, focus.Y, middle.Z):Lerp(focus, k)
					local back = Vector3.new(arenaOff.X, 0, arenaOff.Z)
					if back.Magnitude > 1e-3 then
						local c, s = math.cos(turn), math.sin(turn)
						local u = back.Unit
						local dir = Vector3.new(u.X * c - u.Z * s, 0, u.X * s + u.Z * c)
						pos = mid + dir * out + Vector3.new(0, hgt, 0)
						if k >= ArenaCam.FLYIN_WALLS then
							pos = focus + arenaWant(pos - focus)
						end
						lookAt = Vector3.new(middle.X, focus.Y, middle.Z):Lerp(aLook, k)
					end
					if flying >= ArenaCam.FLYIN_SECONDS then
						flying = -1
					end
				elseif whoosh >= 0 then
					-- the come-back: round the kart, wide and high, spiralling in to the chase spot
					-- (the wall check still holds it off the walls)
					whoosh += dt
					local turn, out, hgt, wide = ArenaCam.comeBack(whoosh, flatOff, arenaOff.Y)
					wideBy = wide
					local back = Vector3.new(arenaOff.X, 0, arenaOff.Z)
					if back.Magnitude > 1e-3 then
						local c, s = math.cos(turn), math.sin(turn)
						local u = back.Unit
						local dir = Vector3.new(u.X * c - u.Z * s, 0, u.X * s + u.Z * c)
						pos = focus + arenaWant(dir * out + Vector3.new(0, hgt, 0))
					end
					if whoosh >= ArenaCam.COMEBACK_SECONDS then
						whoosh = -1
					end
				end
			else
				pos = pos:Lerp(focus + arenaOff, arenaW)
				lookAt = lookAt:Lerp(aLook, arenaW)
				-- (the blend's in-between spots can cross a hill: the same wall check on the
				-- spot itself)
				pos = focus + arenaWant(pos - focus)
			end
			fov += (aFov - fov) * arenaW + wideBy
		end
		camera.CFrame = CFrame.lookAt(pos, lookAt)
		camera.FieldOfView = fov + kick
	end

	return cam
end

return ChaseCamera
