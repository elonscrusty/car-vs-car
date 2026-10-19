--!strict
-- Player garage bays on the lobby floor: one garage per player (built into the side wall) with their
-- equipped car on a four-post lift and the rest of their cars parked. Look only: anchored, no
-- collisions. Assigned on join, freed on leave.

local RunService = game:GetService("RunService")

local Appearance = require(script.Parent.Appearance)
local Build = require(game:GetService("ReplicatedStorage").Shared.Build)
local CarConfig = require(game:GetService("ReplicatedStorage").Shared.CarConfig)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyDecor = require(script.Parent.LobbyDecor)
local GarageLikes = require(game:GetService("ReplicatedStorage").Shared.GarageLikes)
local LobbyLayout = require(game:GetService("ReplicatedStorage").Shared.LobbyLayout)

local LobbyBays = {}

export type Handle = {
	-- Show (or refresh) this player's garage: their equipped car up on the lift, the other cars they
	-- own parked in a row by the back wall (newest in the middle) and the name sign. `sign` is the
	-- text ("NAME  LV 3"). `owned` lists the car ids this player owns, oldest first.
	set: (
		player: Player,
		carId: string,
		look: Appearance.Appearance?,
		build: Build.BuildData?,
		sign: string,
		owned: { string },
		likes: number
	) -> (),
	-- Update only the like count on this player's name sign (cheap: no car rebuild).
	setLikes: (player: Player, likes: number) -> (),
	-- Called when someone triggers the heart at a garage door: (liker, the garage owner).
	onLike: (callback: (liker: Player, owner: Player) -> ()) -> (),
	clear: (player: Player) -> (),
	destroy: () -> (),
}

local PARK_SCALE = 0.5 -- the parked collection
local PARK_SLOTS = { 0, 1, -1, 2 } -- row positions: the newest in the middle
local PARK_STEP = 5.6 -- studs between parked cars (along the wall)
local PARK_MAX = 4
local STEP = 1 / 20 -- seconds between updates (cheap for the network)
local LIFT_LOW, LIFT_HIGH = 2.2, 5 -- height of the runways above the floor (they slowly rise and sink)
local LIFT_SHIFT = 3 -- the lift stands this far toward the hall from the middle of the bay
local PARK_BACK = 5.5 -- parked cars stand this far from the back wall
local POST_X, POST_Z = 9.5, 8 -- lift posts, from the lift centre
local REAL_LIFT_TOP = 1.45 -- height of the runways of the Blender lift

local DEMO_COLORS = {
	Color3.fromRGB(235, 60, 60),
	Color3.fromRGB(60, 150, 255),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(70, 200, 110),
}
local METAL = Color3.fromRGB(110, 114, 126)
local YELLOW = Color3.fromRGB(255, 205, 40)

type Bay = {
	center: Vector3, -- the lift (floor level)
	face: number,
	signLabel: TextLabel,
	signText: string, -- name part of the sign; the like count is added under it
	prompt: ProximityPrompt,
	likePrompt: ProximityPrompt,
	player: Player?,
	car: Model?,
	extras: { Instance }, -- the parked cars
	runwayZ: number, -- how far each runway is from the middle
	bottom: number, -- the car's lowest point below its pivot (a negative number)
	runways: { Part },
	ramps: { Part },
	phase: number,
	real: boolean, -- stands on the Blender lift (static); otherwise the plain animated one
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

function LobbyBays.new(folder: Folder, origin: Vector3): Handle
	local bays: { Bay } = {}

	for i, spot in LobbyLayout.bays do
		local center =
			Vector3.new(origin.X + spot.x + spot.face * LIFT_SHIFT, origin.Y, origin.Z + spot.z)

		-- Floor mark under the lift: a dark pad with a yellow frame.
		local ring = block(folder, "BayRing", Vector3.new(24, 0.06, 18), Color3.fromRGB(22, 22, 26))
		ring.CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0))
		local edge = block(folder, "BayEdge", Vector3.new(25, 0.05, 19), YELLOW)
		edge.CFrame = CFrame.new(center + Vector3.new(0, 0.07, 0))
		edge.Transparency = 0.2

		-- The real (Blender) four-post lift when it is imported; otherwise a plain stand-in: four
		-- tall posts with yellow caps and two runways under the wheels that slowly rise and sink.
		local realLift = LobbyDecor.clone("FourPostLift", folder, 20)
		if realLift then
			realLift:PivotTo(CFrame.new(center) * CFrame.Angles(0, -spot.face * math.pi / 2, 0))
		end
		local runways: { Part } = {}
		local ramps: { Part } = {}
		if realLift == nil then
			for _, px in { -1, 1 } do
				for _, pz in { -1, 1 } do
					local post = block(
						folder,
						"LiftPost",
						Vector3.new(1.6, 11, 1.6),
						METAL,
						nil,
						Enum.Material.Metal
					)
					post.CFrame = CFrame.new(center + Vector3.new(px * POST_X, 5.5, pz * POST_Z))
					local cap = block(folder, "LiftPostCap", Vector3.new(2.2, 0.8, 2.2), YELLOW)
					cap.CFrame = CFrame.new(center + Vector3.new(px * POST_X, 11.2, pz * POST_Z))
				end
			end
			for _ = 1, 2 do
				local runway = block(
					folder,
					"LiftRunway",
					Vector3.new(2 * POST_X + 1, 0.9, 3),
					Color3.fromRGB(70, 74, 86),
					nil,
					Enum.Material.Metal
				)
				table.insert(runways, runway)
				local stripe =
					block(folder, "LiftRunwayStripe", Vector3.new(2 * POST_X + 1, 0.2, 0.4), YELLOW)
				stripe.Parent = runway
				stripe.Name = "Stripe"
				table.insert(runways, stripe)
				for _ = 1, 2 do
					local ramp = block(
						folder,
						"LiftRamp",
						Vector3.new(4, 0.7, 3),
						Color3.fromRGB(235, 190, 40),
						nil,
						Enum.Material.Metal
					)
					table.insert(ramps, ramp)
				end
			end
		end

		-- Name sign on the back wall, facing the hall.
		local sign = Instance.new("Part")
		sign.Name = "BaySign"
		sign.Size = Vector3.new(14, 3.6, 0.5)
		local signPos = Vector3.new(
			origin.X + spot.x - spot.face * (LobbyLayout.bay.w / 2 - 1),
			origin.Y + 7.2,
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

		-- The heart at the door: walk up and press it to like this garage (the server decides).
		local spotX = spot.x + spot.face * (LobbyLayout.bay.w / 2 - 3)
		local heart = block(
			folder,
			"BayLikeSpot",
			Vector3.new(2.4, 2.4, 0.4),
			Color3.fromRGB(224, 51, 79),
			Enum.PartType.Ball
		)
		heart.CFrame = CFrame.new(
			origin.X + spotX,
			origin.Y + 3.2,
			origin.Z + spot.z + LobbyLayout.bay.gap / 2 + 1.5
		)
		local heartGui = Instance.new("BillboardGui")
		heartGui.Size = UDim2.fromOffset(60, 60)
		heartGui.StudsOffset = Vector3.new(0, 2.4, 0)
		heartGui.AlwaysOnTop = false
		heartGui.MaxDistance = 60
		heartGui.Parent = heart
		local heartLbl = Instance.new("TextLabel")
		heartLbl.Size = UDim2.fromScale(1, 1)
		heartLbl.BackgroundTransparency = 1
		heartLbl.Font = Enum.Font.FredokaOne
		heartLbl.TextScaled = true
		heartLbl.Text = "♥"
		heartLbl.TextColor3 = Color3.fromRGB(255, 77, 109)
		heartLbl.TextStrokeTransparency = 0.3
		heartLbl.Parent = heartGui
		local likePrompt = Instance.new("ProximityPrompt")
		likePrompt.Name = "LikePrompt"
		likePrompt.ActionText = "Like"
		likePrompt.ObjectText = "Garage"
		likePrompt.KeyboardKeyCode = Enum.KeyCode.F
		likePrompt.RequiresLineOfSight = false
		likePrompt.MaxActivationDistance = 12
		likePrompt.HoldDuration = 0
		likePrompt.Enabled = false
		likePrompt.Parent = heart

		-- "Customize" prompt: only the owner's client opens the garage from it.
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BayPrompt"
		prompt.ActionText = "Customize"
		prompt.ObjectText = "Your garage"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 22
		prompt.HoldDuration = 0
		prompt.Enabled = false
		prompt.Parent = ring

		bays[i] = {
			center = center,
			face = spot.face,
			signLabel = lbl,
			signText = "OPEN",
			prompt = prompt,
			likePrompt = likePrompt,
			player = nil,
			car = nil,
			extras = {},
			runwayZ = 3.4,
			bottom = -1,
			runways = runways,
			ramps = ramps,
			phase = i * 1.3,
			real = realLift ~= nil,
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

	local fillDemo: (b: Bay, i: number) -> ()

	local function drop(b: Bay)
		clearCars(b)
		fillDemo(b, table.find(bays, b) or 1)
		b.player = nil
		b.prompt.Enabled = false
		b.prompt:SetAttribute("OwnerUserId", nil)
		b.likePrompt.Enabled = false
		b.likePrompt:SetAttribute("OwnerUserId", nil)
		b.signText = "OPEN"
		b.signLabel.Text = "OPEN"
		b.signLabel.TextColor3 = Color3.fromRGB(110, 120, 140)
	end

	-- Builds a show car (look only: anchored, no collisions, no bar), scaled so its length is
	-- `length` studs. Returns the model and how far its lowest point is below its pivot.
	local function showCar(
		carId: string,
		cf: CFrame,
		length: number,
		look: Appearance.Appearance?,
		build: Build.BuildData?
	): (Model, number, Vector3)
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
		local _, size0 = model:GetBoundingBox()
		model:ScaleTo(length / math.max(size0.X, size0.Z, 0.1))
		local bbCf, bbSize = model:GetBoundingBox()
		local bottom = (bbCf.Position.Y - bbSize.Y / 2) - model:GetPivot().Position.Y
		return model, bottom, bbSize
	end

	-- The lift car faces the hall; its length follows the car's own length (a bit of variety).
	local function liftCar(
		b: Bay,
		carId: string,
		look: Appearance.Appearance?,
		build: Build.BuildData?
	)
		local cfg = CarConfig.get(carId)
		local carLen = if cfg then math.max(cfg.size[1], cfg.size[3]) else 8
		local model, bottom, bbSize =
			showCar(carId, CFrame.new(b.center), 12 + 0.4 * carLen, look, build)
		model:PivotTo(CFrame.new(b.center) * CFrame.Angles(0, -b.face * math.pi / 2, 0))
		b.car = model
		b.bottom = bottom
		b.runwayZ = math.clamp(math.min(bbSize.X, bbSize.Z) * 0.3, 2.2, 4.4)
		if b.real then
			model:PivotTo(
				CFrame.new(b.center.X, b.center.Y + REAL_LIFT_TOP - bottom, b.center.Z)
					* model:GetPivot().Rotation
			)
		end
	end

	-- An empty bay shows a colored sample car so the wall never looks bare.
	fillDemo = function(b, i)
		local order = CarConfig.Order
		if #order == 0 then
			return
		end
		liftCar(
			b,
			order[(i - 1) % #order + 1],
			{ paintColor = DEMO_COLORS[(i - 1) % #DEMO_COLORS + 1] },
			nil
		)
	end

	for i, b in bays do
		fillDemo(b, i)
	end

	local handle = {} :: Handle
	handle.set = function(player, carId, look, build, sign, owned, likes)
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
		b.likePrompt.Enabled = true
		b.likePrompt:SetAttribute("OwnerUserId", player.UserId)
		b.signText = sign
		b.signLabel.Text = `{sign}\n{GarageLikes.label(likes)}`
		b.signLabel.TextColor3 = Color3.fromRGB(255, 205, 40)
		clearCars(b)

		liftCar(b, carId, look, build)

		-- The rest of the collection, parked in a row by the back wall. Newest (last owned) first,
		-- in the middle, then outward.
		local others: { string } = {}
		for k = #owned, 1, -1 do
			if owned[k] ~= carId then
				table.insert(others, owned[k])
			end
		end
		local base = Vector3.new(
			b.center.X - b.face * (LIFT_SHIFT + LobbyLayout.bay.w / 2 - PARK_BACK),
			origin.Y,
			b.center.Z
		)
		local yaw = CFrame.Angles(0, -b.face * math.pi / 2, 0)
		for k = 1, math.min(#others, PARK_MAX) do
			local c2 = CarConfig.get(others[k])
			local len2 = if c2 then math.max(c2.size[1], c2.size[3]) else 8
			local pos = base + Vector3.new(0, 0, PARK_SLOTS[k] * PARK_STEP)
			local parked, pbottom =
				showCar(others[k], CFrame.new(pos), (12 + 0.4 * len2) * PARK_SCALE, nil, nil)
			parked:PivotTo(CFrame.new(pos + Vector3.new(0, 0.2 - pbottom, 0)) * yaw)
			table.insert(b.extras, parked)
		end
	end
	handle.setLikes = function(player, likes)
		local b = bayOf(player)
		if b then
			b.signLabel.Text = `{b.signText}\n{GarageLikes.label(likes)}`
		end
	end
	local likeConns: { RBXScriptConnection } = {}
	handle.onLike = function(callback)
		for _, b in bays do
			table.insert(
				likeConns,
				b.likePrompt.Triggered:Connect(function(liker: Player)
					local owner = b.player
					if owner then
						callback(liker, owner)
					end
				end)
			)
		end
	end
	handle.clear = function(player)
		local b = bayOf(player)
		if b then
			drop(b)
		end
	end

	-- One loop for all bays: the lift slowly rises and sinks with the car on it.
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		local t = os.clock()
		for _, b in bays do
			if b.real then
				continue
			end
			local y = LIFT_LOW + (LIFT_HIGH - LIFT_LOW) * (math.sin(t * 0.35 + b.phase) * 0.5 + 0.5)
			local c = b.center
			-- runways[1], [2] = left runway and its stripe; [3], [4] = right ones.
			for k, rz in { -1, 1 } do
				local runway = b.runways[(k - 1) * 2 + 1]
				local stripe = b.runways[(k - 1) * 2 + 2]
				local z = rz * b.runwayZ
				runway.CFrame = CFrame.new(c.X, c.Y + y, c.Z + z)
				stripe.CFrame = CFrame.new(c.X, c.Y + y + 0.5, c.Z + z)
				for e, rx in { -1, 1 } do
					local ramp = b.ramps[(k - 1) * 2 + e]
					ramp.CFrame = CFrame.new(c.X + rx * (POST_X + 2.4), c.Y + y - 0.55, c.Z + z)
						* CFrame.Angles(0, 0, -rx * math.rad(16))
				end
			end
			local model = b.car
			if model and model.Parent then
				local pivot = model:GetPivot()
				model:PivotTo(CFrame.new(c.X, c.Y + y + 0.45 - b.bottom, c.Z) * pivot.Rotation)
			end
		end
	end)

	handle.destroy = function()
		conn:Disconnect()
		for _, c in likeConns do
			c:Disconnect()
		end
		for _, b in bays do
			clearCars(b)
		end
	end
	return handle
end

return LobbyBays
