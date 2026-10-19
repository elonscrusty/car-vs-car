--!strict
-- Camera: fixed high view of the whole arena, shakes on big hits, and a push-in on the crash dummy at a KO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local FeelRules = require(ReplicatedStorage.Shared.FeelRules)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CameraDirector = {}

export type Director = {
	overview: (center: Vector3, side: Vector3?) -> (), -- side: flat direction from the middle to your car
	focus: (target: BasePart?) -> (), -- KO: follow the dummy and zoom in
	shake: (strength: number) -> (), -- 0..1
	punchFov: (amount: number) -> (), -- brief zoom-in punch
	soccer: (on: boolean) -> (), -- car soccer: high behind your car, keeps the ball in frame
	snap: (pos: Vector3) -> (), -- goal: look at this point for ~1 s, then ease back
	boost: () -> (), -- boost: brief FOV widen
	release: () -> (), -- back to the normal Roblox camera (lobby)
}

function CameraDirector.new(): Director
	local feel = GameConfig.Feel
	local rng = Random.new()
	local base = CFrame.identity
	local active = false
	local target: BasePart? = nil
	local goalFov = feel.normalFov
	local myCar: BasePart? = nil -- your own car, found once the fight starts (nil in the lobby)
	local nextFind = 0
	local soccerOn = false
	local ballPart: BasePart? = nil
	local nextBallFind = 0
	local fov = feel.normalFov
	local shakeLeft, shakeSize = 0, 0
	local snapPos: Vector3? = nil
	local snapStart = -1000
	local boostStart = -1000
	local walls: { BasePart } = {} -- walls of your soccer arena, faded while they block the view
	local wallFade: { [BasePart]: number } = {}
	local nextWallCheck = 0
	-- Whole-arena view (set when your car is found): floor middle and half sizes, the fixed look direction
	local arenaMid = Vector3.zero
	local arenaHx, arenaHz = 60, 60
	local viewYaw = 0
	local fitAspect, fitDist = 0, 0
	local wallTarget: { [BasePart]: number } = {}

	local function calm(): boolean
		return SoundService:GetAttribute(feel.calmAttribute) == true
	end

	local function cam(): Camera
		return workspace.CurrentCamera :: Camera
	end

	-- Floor footprint of the arena (all parts named Floor, in world space) and the fixed view
	-- direction: along a world axis so the longer side runs left-right on screen, facing the way
	-- your car starts.
	local function measureArena(arena: Instance, car: BasePart?)
		local minX, maxX, minZ, maxZ, topY =
			math.huge, -math.huge, math.huge, -math.huge, -math.huge
		for _, p in arena:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Floor" then
				local h = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							minX, maxX = math.min(minX, w.X), math.max(maxX, w.X)
							minZ, maxZ = math.min(minZ, w.Z), math.max(maxZ, w.Z)
							topY = math.max(topY, w.Y)
						end
					end
				end
			end
		end
		if minX > maxX then
			local c = if car then car.Position else Vector3.zero
			minX, maxX, minZ, maxZ, topY = c.X - 60, c.X + 60, c.Z - 60, c.Z + 60, c.Y
		end
		arenaMid = Vector3.new((minX + maxX) / 2, topY, (minZ + maxZ) / 2)
		arenaHx, arenaHz = (maxX - minX) / 2, (maxZ - minZ) / 2
		local look = if car then car.CFrame.LookVector else Vector3.zAxis
		if arenaHx >= arenaHz then
			viewYaw = if look.Z >= 0 then 0 else math.pi -- long side left-right: look along +Z / -Z
		else
			viewYaw = if look.X >= 0 then math.pi / 2 else -math.pi / 2
		end
		fitAspect = 0 -- re-fit the distance
	end

	-- Your car is the model in an Arena that carries your user id (the server sets it at the fight).
	-- Also notes what kind of arena it is and which soccer team you are on.
	local function findMyCar(): BasePart?
		local uid = Players.LocalPlayer.UserId
		for _, arena in workspace:GetChildren() do
			if arena.Name == "Arena" then
				for _, m in arena:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("DriverUserId") == uid then
						measureArena(arena, m.PrimaryPart)
						return m.PrimaryPart
					end
				end
			end
		end
		return nil
	end

	local function resetWalls()
		for w in wallFade do
			if w.Parent ~= nil then
				w.LocalTransparencyModifier = 0
			end
		end
		table.clear(wallFade)
		table.clear(wallTarget)
		table.clear(walls)
	end

	-- Soccer walls between the camera and your car or the ball fade out (audit #15).
	local function updateWalls(camPos: Vector3, car: BasePart, ball: BasePart?, dt: number)
		local now = os.clock()
		if now >= nextWallCheck then
			nextWallCheck = now + 0.1
			local arena = car:FindFirstAncestor("Arena")
			if arena and (#walls == 0 or walls[1].Parent == nil) then
				table.clear(walls)
				table.clear(wallFade)
				table.clear(wallTarget)
				for _, p in arena:GetChildren() do
					if p:IsA("BasePart") and (p.Name == "Wall" or p.Name == "WallTrim") then
						table.insert(walls, p)
					end
				end
			end
			local pad = feel.wallFadePad
			for _, w in walls do
				local half = w.Size / 2
				local a = w.CFrame:PointToObjectSpace(camPos)
				local blocks = false
				local ends = { car.Position }
				if ball ~= nil then
					table.insert(ends, ball.Position)
				end
				for _, e in ends do
					local b = w.CFrame:PointToObjectSpace(e)
					if
						FeelRules.segmentHitsBox(
							{ a.X, a.Y, a.Z },
							{ b.X, b.Y, b.Z },
							half.X + pad,
							half.Y + pad,
							half.Z + pad
						)
					then
						blocks = true
						break
					end
				end
				wallTarget[w] = if blocks then feel.wallFadeTransparency else 0
			end
		end
		for _, w in walls do
			if w.Parent ~= nil then
				local cur = wallFade[w] or 0
				local nxt = FeelRules.approach(cur, wallTarget[w] or 0, dt, feel.wallFadeRate)
				if nxt ~= cur then
					wallFade[w] = nxt
					w.LocalTransparencyModifier = nxt
				end
			end
		end
	end

	-- The soccer ball is the part named "Ball" in the Arena that holds your car.
	local function findBall(car: BasePart): BasePart?
		local arena = car:FindFirstAncestor("Arena")
		local b = if arena then arena:FindFirstChild("Ball") else nil
		return if b and b:IsA("BasePart") then b else nil
	end

	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		local t = target
		if t ~= nil and t.Parent ~= nil then
			local pos = t.Position
			local goal = CFrame.lookAt(pos + Vector3.new(0, feel.koCamUp, feel.koCamBack), pos)
			base = base:Lerp(goal, math.min(1, dt * 7))
		else
			-- Gentle follow: lean toward your car, and widen the view a little at speed.
			local car = myCar
			if (car == nil or car.Parent == nil) and os.clock() >= nextFind then
				nextFind = os.clock() + 0.3
				myCar = findMyCar()
				car = myCar
			end
			if car ~= nil and car.Parent ~= nil then
				-- Whole-arena camera: one fixed high spot that sees the entire floor, whatever
				-- the car does. Only the soccer walls in the way fade out.
				local c = cam()
				local aspect = c.ViewportSize.X / math.max(1, c.ViewportSize.Y)
				if math.abs(aspect - fitAspect) > 0.02 then
					fitAspect = aspect
					fitDist = FeelRules.arenaFitDistance(
						arenaHx,
						arenaHz,
						viewYaw,
						feel.arenaPitch,
						feel.normalFov,
						aspect,
						feel.arenaMargin
					)
				end
				local pitch = math.rad(feel.arenaPitch)
				local dir = Vector3.new(math.sin(viewYaw), 0, math.cos(viewYaw))
				local camPos = arenaMid
					+ (-dir * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)) * fitDist
				local goal = CFrame.lookAt(camPos, arenaMid)
				base = base:Lerp(goal, 1 - math.exp(-feel.arenaEase * dt))
				goalFov = feel.normalFov
				if soccerOn then
					local ball = ballPart
					if (ball == nil or ball.Parent == nil) and os.clock() >= nextBallFind then
						nextBallFind = os.clock() + 0.3
						ballPart = findBall(car)
						ball = ballPart
					end
					updateWalls(base.Position, car, ball, dt)
				end
			end
		end
		-- Extra FOV while boosting, and the goal camera snap to the ball.
		local now = os.clock()
		local calmOn = calm()
		local fovGoal = goalFov
			+ FeelRules.boostFov(
				now - boostStart,
				feel.boostFxSeconds,
				feel.boostFovAdd * FeelRules.shakeScale(calmOn)
			)
		local frameBase = base
		local sp = snapPos
		if sp ~= nil then
			local w =
				FeelRules.snapWeight(now - snapStart, feel.goalSnapSeconds, feel.goalSnapBlendOut)
			if w <= 0 then
				snapPos = nil
			else
				if calmOn then
					w *= 0.5
				end
				frameBase = base:Lerp(CFrame.lookAt(base.Position, sp), w)
				fovGoal += (feel.goalSnapFov - goalFov) * w
			end
		end
		fov += (fovGoal - fov) * math.min(1, dt * 4)
		local c = cam()
		c.FieldOfView = fov
		local offset = Vector3.zero
		if shakeLeft > 0 then
			shakeLeft = math.max(0, shakeLeft - dt)
			local k = shakeSize * (shakeLeft / feel.shakeTime)
			offset = Vector3.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
		end
		c.CFrame = frameBase * CFrame.new(offset)
	end)

	local function overview(center: Vector3, side: Vector3?)
		target = nil
		active = true
		goalFov, fov = feel.normalFov, feel.normalFov
		-- Camera sits behind YOUR car so it is the near one, bottom of the screen.
		local flat = if side then Vector3.new(side.X, 0, side.Z) else Vector3.zero
		local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		myCar = nil
		base = CFrame.lookAt(center + dir * 60 + Vector3.new(0, 72, 0), center)
		local c = cam()
		c.CameraType = Enum.CameraType.Scriptable
	end

	local function focus(part: BasePart?)
		target = part
		if part ~= nil then
			goalFov = feel.koFov
		end
	end

	local function shake(strength: number)
		local size = feel.shakeMax * math.clamp(strength, 0, 1) * FeelRules.shakeScale(calm())
		if size >= shakeSize * (shakeLeft / feel.shakeTime) then
			shakeSize, shakeLeft = size, feel.shakeTime
		end
	end

	local function punchFov(amount: number)
		if active then
			fov = math.max(10, fov - amount * FeelRules.shakeScale(calm())) -- eases back to goalFov on its own
		end
	end

	local function soccer(on: boolean)
		soccerOn = on
		ballPart = nil
		resetWalls()
	end

	local function snap(pos: Vector3)
		snapPos = pos
		snapStart = os.clock()
	end

	local function boost()
		boostStart = os.clock()
	end

	local function release()
		resetWalls()
		snapPos = nil
		boostStart = -1000
		soccerOn = false
		ballPart = nil
		active = false
		target = nil
		myCar = nil
		shakeLeft = 0
		goalFov, fov = feel.normalFov, feel.normalFov
		local c = cam()
		c.FieldOfView = feel.normalFov
		c.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			c.CameraSubject = humanoid
		end
	end

	return {
		overview = overview,
		focus = focus,
		shake = shake,
		punchFov = punchFov,
		soccer = soccer,
		snap = snap,
		boost = boost,
		release = release,
	}
end

return CameraDirector
