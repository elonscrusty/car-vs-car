--!strict
-- Player bays on the mezzanine: one little plot per player with their equipped car doing donuts
-- (look only: anchored, no collisions, tire smoke, skid ring). Assigned on join, freed on leave.

local RunService = game:GetService("RunService")

local Appearance = require(script.Parent.Appearance)
local Build = require(game:GetService("ReplicatedStorage").Shared.Build)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyLayout = require(game:GetService("ReplicatedStorage").Shared.LobbyLayout)

local LobbyBays = {}

export type Handle = {
	-- Show (or refresh) this player's car in their bay. `sign` is the text above it ("NAME  LV 3").
	set: (
		player: Player,
		carId: string,
		look: Appearance.Appearance?,
		build: Build.BuildData?,
		sign: string
	) -> (),
	clear: (player: Player) -> (),
	destroy: () -> (),
}

local BAYS = 8
local SPACING = 12
local RADIUS = 2.6
local SCALE = 0.4
local SPIN = 1.7 -- radians per second around the ring
local STEP = 1 / 20 -- seconds between car updates (cheap for the network)

type Bay = {
	center: Vector3,
	signLabel: TextLabel,
	player: Player?,
	car: Model?,
	angle: number,
}

function LobbyBays.new(folder: Folder, origin: Vector3): Handle
	local mz = LobbyLayout.mezzanine
	local deckTop = origin.Y + mz.height
	local bays: { Bay } = {}

	for i = 1, BAYS do
		local x = (i - (BAYS + 1) / 2) * SPACING
		local center = Vector3.new(origin.X + mz.x + x, deckTop, origin.Z + mz.z)
		-- Skid ring and a lighter pad in the middle.
		local ring = Instance.new("Part")
		ring.Name = "BayRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.06, RADIUS * 2 + 3.6, RADIUS * 2 + 3.6)
		ring.CFrame = CFrame.new(center + Vector3.new(0, 0.04, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		ring.Color = Color3.fromRGB(22, 22, 26)
		ring.Material = Enum.Material.SmoothPlastic
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Parent = folder
		local inner = ring:Clone()
		inner.Name = "BayCenter"
		inner.Size = Vector3.new(0.08, RADIUS * 2 - 3, RADIUS * 2 - 3)
		inner.Color = Color3.fromRGB(70, 74, 86)
		inner.Parent = folder
		local edge = ring:Clone()
		edge.Name = "BayEdge"
		edge.Size = Vector3.new(0.05, RADIUS * 2 + 4.6, RADIUS * 2 + 4.6)
		edge.CFrame = ring.CFrame * CFrame.new(0, 0, 0)
		edge.Color = Color3.fromRGB(255, 205, 40)
		edge.Transparency = 0.2
		edge.Position = center + Vector3.new(0, 0.02, 0)
		edge.Parent = folder

		local sign = Instance.new("Part")
		sign.Name = "BaySign"
		sign.Size = Vector3.new(9, 2, 0.4)
		local signPos = center + Vector3.new(0, 7.5, 4.4)
		sign.CFrame = CFrame.lookAt(signPos, signPos + Vector3.zAxis)
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
		lbl.Text = "OPEN BAY"
		lbl.TextColor3 = Color3.fromRGB(110, 120, 140)
		lbl.Parent = gui

		bays[i] =
			{ center = center, signLabel = lbl, player = nil, car = nil, angle = (i * 1.3) % 6.28 }
	end

	local function bayOf(player: Player): Bay?
		for _, b in bays do
			if b.player == player then
				return b
			end
		end
		return nil
	end

	local function drop(b: Bay)
		if b.car then
			b.car:Destroy()
			b.car = nil
		end
		b.player = nil
		b.signLabel.Text = "OPEN BAY"
		b.signLabel.TextColor3 = Color3.fromRGB(110, 120, 140)
	end

	local handle = {} :: Handle
	handle.set = function(player, carId, look, build, sign)
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
		b.signLabel.Text = sign
		b.signLabel.TextColor3 = Color3.fromRGB(255, 205, 40)
		if b.car then
			b.car:Destroy()
		end
		local car = CarBuilder.build(carId, 1, CFrame.new(b.center), folder, "", true, look, build)
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
		model:ScaleTo(SCALE)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Rate = 14
		smoke.Lifetime = NumberRange.new(0.6, 1.1)
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.6),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
		smoke.Parent = car.body
		b.car = model
	end
	handle.clear = function(player)
		local b = bayOf(player)
		if b then
			drop(b)
		end
	end

	-- One loop for all bays: drive each car around its ring, sliding a bit sideways like a drift.
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < STEP then
			return
		end
		local step = acc
		acc = 0
		for _, b in bays do
			local model = b.car
			if model and model.Parent then
				b.angle += SPIN * step
				local a = b.angle
				local pos = b.center + Vector3.new(math.cos(a) * RADIUS, 0.3, math.sin(a) * RADIUS)
				-- Tangent (counter-clockwise) turned a little toward the outside = drift angle.
				local heading = math.pi - a + 0.45
				model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, heading, 0))
			end
		end
	end)

	handle.destroy = function()
		conn:Disconnect()
		for _, b in bays do
			if b.car then
				b.car:Destroy()
			end
		end
	end
	return handle
end

return LobbyBays
