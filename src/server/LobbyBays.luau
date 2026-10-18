--!strict
-- Player garage bays on the lobby floor: one stall per player with their equipped car doing donuts
-- (look only: anchored, no collisions, tire smoke, skid ring). Assigned on join, freed on leave.

local RunService = game:GetService("RunService")

local Appearance = require(script.Parent.Appearance)
local Build = require(game:GetService("ReplicatedStorage").Shared.Build)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyLayout = require(game:GetService("ReplicatedStorage").Shared.LobbyLayout)

local LobbyBays = {}

export type Handle = {
	-- Show (or refresh) this player's bay: their equipped car on the lift, the other cars they own
	-- parked in a row (newest in front) and the name sign. `sign` is the text ("NAME  LV 3").
	-- `owned` lists the car ids this player owns, oldest first.
	set: (
		player: Player,
		carId: string,
		look: Appearance.Appearance?,
		build: Build.BuildData?,
		sign: string,
		owned: { string }
	) -> (),
	clear: (player: Player) -> (),
	destroy: () -> (),
}

local SCALE = 0.9 -- the lift car (the real car is bigger)
local PARK_SCALE = 0.36 -- the parked collection
local PARK_MAX = 4
local PARK_SLOTS = { 0, 1, -1, 2 } -- row positions: the newest in the middle
local PARK_STEP = 3.8 -- studs between parked cars (along the wall)
local SPIN = 0.45 -- radians per second: a slow turn on the lift
local STEP = 1 / 20 -- seconds between updates (cheap for the network)
local LIFT_LOW, LIFT_HIGH = 2.4, 3.8 -- platform height above the floor (it slowly rises and sinks)
local ROBOT_DIST = 7.2 -- how far from the lift the mechanic robots stand

local METAL = Color3.fromRGB(110, 114, 126)
local YELLOW = Color3.fromRGB(255, 205, 40)

type Robot = {
	base: CFrame, -- floor position, turned toward the lift
	head: Part,
	eye: Part,
	arm: Part,
	wrench: Part,
	shoulder: CFrame,
	phase: number,
}

type Bay = {
	center: Vector3, -- the lift (floor level)
	face: number,
	signLabel: TextLabel,
	prompt: ProximityPrompt,
	player: Player?,
	car: Model?,
	extras: { Instance }, -- the parked cars
	angle: number,
	half: number, -- half the car's height (scaled)
	platform: Part,
	column: Part,
	robots: { Robot },
}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- A small mechanic robot that stands at `pos` and swings a wrench (with sparks) at the car.
local function makeRobot(
	folder: Folder,
	pos: Vector3,
	lookAt: Vector3,
	color: Color3,
	phase: number
): Robot
	local base = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	local bodyCF = base * CFrame.new(0, 2.1, 0)
	block(folder, "RobotFoot", Vector3.new(1.9, 0.8, 1.7), Color3.fromRGB(40, 42, 50)).CFrame = base
		* CFrame.new(0, 0.4, 0)
	block(folder, "RobotBody", Vector3.new(2, 2.6, 1.6), color).CFrame = bodyCF
	block(folder, "RobotChest", Vector3.new(1.3, 0.5, 0.2), YELLOW).CFrame = bodyCF
		* CFrame.new(0, 0.3, -0.85)
	local head = block(
		folder,
		"RobotHead",
		Vector3.new(1.5, 1.5, 1.5),
		Color3.fromRGB(205, 208, 218),
		Enum.PartType.Ball
	)
	head.CFrame = bodyCF * CFrame.new(0, 2.1, 0)
	local eye = block(
		folder,
		"RobotEye",
		Vector3.new(1.1, 0.35, 0.2),
		Color3.fromRGB(60, 240, 255),
		nil,
		Enum.Material.Neon
	)
	eye.CFrame = head.CFrame * CFrame.new(0, 0.1, -0.7)
	local shoulder = bodyCF * CFrame.new(1.3, 0.8, 0)
	local arm = block(folder, "RobotArm", Vector3.new(0.5, 0.5, 3), Color3.fromRGB(205, 208, 218))
	local wrench = block(
		folder,
		"RobotWrench",
		Vector3.new(0.5, 1.4, 0.5),
		Color3.fromRGB(230, 60, 50),
		nil,
		Enum.Material.Metal
	)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 16
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -25, 0)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 120, 30))
	sparks.Parent = wrench
	return {
		base = base,
		head = head,
		eye = eye,
		arm = arm,
		wrench = wrench,
		shoulder = shoulder,
		phase = phase,
	}
end

function LobbyBays.new(folder: Folder, origin: Vector3): Handle
	local bays: { Bay } = {}

	for i, spot in LobbyLayout.bays do
		local center = Vector3.new(origin.X + spot.x + spot.face * 3, origin.Y, origin.Z + spot.z)

		-- Floor mark under the lift.
		local ring = block(
			folder,
			"BayRing",
			Vector3.new(0.06, 14, 14),
			Color3.fromRGB(22, 22, 26),
			Enum.PartType.Cylinder
		)
		ring.CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		local edge =
			block(folder, "BayEdge", Vector3.new(0.05, 15, 15), YELLOW, Enum.PartType.Cylinder)
		edge.CFrame = ring.CFrame - Vector3.new(0, 0.03, 0)
		edge.Transparency = 0.2

		-- The lift: a pillar and a round platform that slowly rises and sinks.
		local column = block(
			folder,
			"LiftColumn",
			Vector3.new(LIFT_LOW, 2, 2),
			METAL,
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		local platform = block(
			folder,
			"LiftPlatform",
			Vector3.new(0.6, 10, 10),
			Color3.fromRGB(70, 74, 86),
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		local rim =
			block(folder, "LiftRim", Vector3.new(0.5, 10.6, 10.6), YELLOW, Enum.PartType.Cylinder)
		rim.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)

		local robots: { Robot } = {}
		for k, side in { -1, 1 } do
			local rp = center + Vector3.new(0, 0, side * ROBOT_DIST)
			local color = if k == 1
				then Color3.fromRGB(255, 140, 40)
				else Color3.fromRGB(70, 140, 240)
			table.insert(robots, makeRobot(folder, rp, center, color, k * 1.7 + i))
		end

		-- Name sign on the back wall, facing the hall.
		local sign = Instance.new("Part")
		sign.Name = "BaySign"
		sign.Size = Vector3.new(12, 2.4, 0.5)
		local signPos = Vector3.new(
			origin.X + spot.x - spot.face * (LobbyLayout.bay.w / 2 - 1),
			origin.Y + 5.8,
			origin.Z + spot.z
		)
		sign.CFrame = CFrame.lookAt(signPos, signPos + Vector3.xAxis * spot.face)
		sign.Color = Color3.fromRGB(14, 12, 24)
		sign.Material = Enum.Material.SmoothPlastic
		sign.Anchored = true
		sign.CanCollide = false
		sign.CanQuery = false
		sign.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = sign
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.Text = "OPEN"
		lbl.TextColor3 = Color3.fromRGB(110, 120, 140)
		lbl.Parent = gui

		-- "Customize" prompt: only the owner's client opens the garage from it.
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BayPrompt"
		prompt.ActionText = "Customize"
		prompt.ObjectText = "Your garage"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 14
		prompt.HoldDuration = 0
		prompt.Enabled = false
		prompt.Parent = ring

		bays[i] = {
			center = center,
			face = spot.face,
			signLabel = lbl,
			prompt = prompt,
			player = nil,
			car = nil,
			extras = {},
			angle = (i * 1.3) % 6.28,
			half = 1,
			platform = platform,
			column = column,
			robots = robots,
		}
	end

	local function bayOf(player: Player): Bay?
		for _, b in bays do
			if b.player == player then
				return b
			end
		end
		return nil
	end

	local function clearCars(b: Bay)
		if b.car then
			b.car:Destroy()
			b.car = nil
		end
		for _, e in b.extras do
			e:Destroy()
		end
		table.clear(b.extras)
	end

	local function drop(b: Bay)
		clearCars(b)
		b.player = nil
		b.prompt.Enabled = false
		b.prompt:SetAttribute("OwnerUserId", nil)
		b.signLabel.Text = "OPEN"
		b.signLabel.TextColor3 = Color3.fromRGB(110, 120, 140)
	end

	-- Builds a show car (look only: anchored, no collisions, no bar) at the given scale.
	local function showCar(
		carId: string,
		cf: CFrame,
		scale: number,
		look: Appearance.Appearance?,
		build: Build.BuildData?
	): (Model, number)
		local car = CarBuilder.build(carId, 1, cf, folder, "", true, look, build)
		car.bar.hide()
		local model = car.model
		model.Name = "BayCar"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		model:ScaleTo(scale)
		return model, car.body.Size.Y * scale / 2
	end

	local handle = {} :: Handle
	handle.set = function(player, carId, look, build, sign, owned)
		local b = bayOf(player)
		if b == nil then
			for _, free in bays do
				if free.player == nil then
					b = free
					break
				end
			end
		end
		if b == nil then
			return -- all bays taken: the player simply has no plot
		end
		b.player = player
		b.prompt.Enabled = true
		b.prompt:SetAttribute("OwnerUserId", player.UserId)
		b.signLabel.Text = sign
		b.signLabel.TextColor3 = Color3.fromRGB(255, 205, 40)
		clearCars(b)

		local model, half = showCar(carId, CFrame.new(b.center), SCALE, look, build)
		b.car = model
		b.half = half

		-- The rest of the collection, parked in a row by the back wall. Newest (last owned) first,
		-- in the middle, then outward.
		local others: { string } = {}
		for k = #owned, 1, -1 do
			if owned[k] ~= carId then
				table.insert(others, owned[k])
			end
		end
		local base = b.center + Vector3.new(-b.face * 9.5, 0, 0)
		local yaw = CFrame.Angles(0, -b.face * math.pi / 2, 0)
		for k = 1, math.min(#others, PARK_MAX) do
			local pos = base + Vector3.new(0, 0, PARK_SLOTS[k] * PARK_STEP)
			local parked, ph = showCar(others[k], CFrame.new(pos), PARK_SCALE, nil, nil)
			parked:PivotTo(CFrame.new(pos + Vector3.new(0, ph + 0.15, 0)) * yaw)
			table.insert(b.extras, parked)
		end
	end
	handle.clear = function(player)
		local b = bayOf(player)
		if b then
			drop(b)
		end
	end

	-- One loop for all bays: the lift rises and sinks, the car turns slowly, the robots work.
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < STEP then
			return
		end
		local step = acc
		acc = 0
		local t = os.clock()
		for _, b in bays do
			local y = LIFT_LOW + (LIFT_HIGH - LIFT_LOW) * (math.sin(t * 0.6 + b.angle) * 0.5 + 0.5)
			local c = b.center
			b.platform.CFrame = CFrame.new(c.X, c.Y + y, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
			b.column.Size = Vector3.new(y, 2, 2)
			b.column.CFrame = CFrame.new(c.X, c.Y + y / 2, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
			local model = b.car
			if model and model.Parent then
				b.angle += SPIN * step
				model:PivotTo(
					CFrame.new(c.X, c.Y + y + 0.4 + b.half, c.Z) * CFrame.Angles(0, b.angle, 0)
				)
			end
			for _, r in b.robots do
				local swing = math.sin(t * 4 + r.phase) * 0.6
				local armCF = r.shoulder * CFrame.Angles(swing - 0.3, 0, 0)
				r.arm.CFrame = armCF * CFrame.new(0, 0, -1.5)
				r.wrench.CFrame = armCF * CFrame.new(0, 0, -3.1) * CFrame.Angles(0, 0, t * 9)
				r.head.CFrame = r.base * CFrame.new(0, 4.2 + math.sin(t * 3 + r.phase) * 0.12, 0)
				r.eye.CFrame = r.head.CFrame * CFrame.new(0, 0.1, -0.7)
			end
		end
	end)

	handle.destroy = function()
		conn:Disconnect()
		for _, b in bays do
			clearCars(b)
		end
	end
	return handle
end

return LobbyBays
