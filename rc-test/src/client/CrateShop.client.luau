--!strict
-- Car VS Car's crate shop in the spawn lobby (carter's yes 10-26,
-- rc-game/cvc/pics/crate-shop-top-down.png). Only with Features.CVC on. The building and its three
-- crates come from Garage.build("crates"); this spins and bobs each crate on its turntable, hangs a
-- price plate at the shop front in line with it (its name and price; the odds are on the crate
-- screen), and a prompt on it that opens the crate screen for that crate (CvcCrate listens on the
-- BindableEvent ReplicatedStorage.CvcCrateShop: Fire(kind)).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CarGlow = require(Shared:WaitForChild("CarGlow"))
local Crates = require(Shared:WaitForChild("Crates"))
local Garage = require(Shared:WaitForChild("Garage"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))

local INK, GOLD = KartStyle.INK, KartStyle.YELLOW

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- the hook into the crate screen (whichever side starts first makes it)
local function shopEvent(): BindableEvent
	local e = ReplicatedStorage:FindFirstChild("CvcCrateShop")
	if e and e:IsA("BindableEvent") then
		return e
	end
	local made = Instance.new("BindableEvent")
	made.Name = "CvcCrateShop"
	made.Parent = ReplicatedStorage
	return made
end

local plates = Instance.new("Folder")
plates.Name = "CratePlates"
plates.Parent = workspace

local function text(
	parent: Instance,
	t: string,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: Color3?,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.BackgroundColor3 = fill or Color3.new()
	l.BackgroundTransparency = if fill then 0 else 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = t
	l.Parent = parent
	local rim = Instance.new("UIStroke")
	rim.Thickness = KartStyle.TEXT_RIM
	rim.Color = INK
	rim.Parent = l
	if fill then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = l
	end
	return l
end

-- A dark plate hung at the shop's front in line with the crate: the crate's name on a pill in
-- its colour and its price.
local function plate(ring: BasePart, out: Vector3, kind: Crates.Kind): TextLabel
	local color = rgb(Garage.CRATE_COLORS[kind.id] or Garage.CRATE_COLORS.basic)
	-- hung at the shop's open front, just under the awning's lip and in front of it (Studio pr847:
	-- up inside over the crate, the awning hid it from the plaza), and above a kid's head (auditor
	-- L7: down at the turntable's front edge your own avatar hid the middle price). The ring is at
	-- the shop's z 1.5 and the shop's front at about z 9 (Garage.shopMeshes): 7.8 out = z 9.3.
	local at = ring.Position + out * 7.8 + Vector3.new(0, 4.6, 0)
	local p = Instance.new("Part")
	p.Name = kind.id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	-- as wide as the stands allow (5.6 apart), so the words read from the plaza (final pass 15b),
	-- and tall enough for a big price (phone playtest u14: "300 coins" was a blur)
	p.Size = Vector3.new(5.3, 2.4, 0.15)
	p.Color = INK
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.lookAt(at, at + out) * CFrame.Angles(math.rad(10), 0, 0) -- face up a little, to the camera
	p.Parent = plates
	-- two short rods up into the awning
	for _, side in { -1, 1 } do
		local rod = Instance.new("Part")
		rod.Name = "Rod"
		rod.Anchored = true
		rod.CanCollide = false
		rod.CanQuery = false
		rod.CanTouch = false
		rod.CastShadow = false
		rod.Size = Vector3.new(0.15, 1.4, 0.15)
		rod.Color = INK
		rod.Material = Enum.Material.SmoothPlastic
		rod.CFrame = CFrame.new(
			(p.CFrame * CFrame.new(side * 2.2, 1.1, 0)).Position + Vector3.new(0, 0.6, 0)
		)
		rod.Parent = plates
	end
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0
	g.Parent = p
	local edge = Instance.new("Frame")
	edge.Position = UDim2.fromOffset(6, 6)
	edge.Size = UDim2.new(1, -12, 1, -12)
	edge.BackgroundTransparency = 1
	edge.Parent = g
	local edgeRim = Instance.new("UIStroke")
	edgeRim.Thickness = 6
	edgeRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edgeRim.Color = color
	edgeRim.Parent = edge
	-- one word and a number (the playtest counted ~45 words on the shop): SMALL / BIG / MEGA on a
	-- pill in the crate's colour, then a coin and the price. The odds are on the crate card that
	-- opens before you buy (CvcCrate), so the plates don't repeat them.
	local name = string.split(kind.label, " ")[1]
	text(g, name, 0.2, 0.06, 0.6, 0.28, color, Color3.new(1, 1, 1))
	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromScale(0.2, 0.66)
	coin.Size = UDim2.fromScale(0.24, 0.45)
	coin.BackgroundColor3 = GOLD
	coin.Parent = g
	local coinRound = Instance.new("UICorner")
	coinRound.CornerRadius = UDim.new(0.5, 0)
	coinRound.Parent = coin
	local coinRim = Instance.new("UIStroke")
	coinRim.Thickness = 5
	coinRim.Color = Color3.fromRGB(190, 120, 20)
	coinRim.Parent = coin
	local price = text(g, `{kind.price}`, 0.36, 0.4, 0.58, 0.52, nil, GOLD)
	price.TextXAlignment = Enum.TextXAlignment.Left
	return price
end

-- The price on each plate turns green when you have the coins for that crate (gold till then).
local LocalPlayer = game:GetService("Players").LocalPlayer
local prices: { { label: TextLabel, cost: number } } = {}
local function paint()
	local coins = LocalPlayer:GetAttribute("Coins")
	local have = if type(coins) == "number" then coins else 0
	for _, p in prices do
		p.label.TextColor3 = if have >= p.cost then KartStyle.GREEN else GOLD
	end
end
LocalPlayer:GetAttributeChangedSignal("Coins"):Connect(paint)

-- A soft light in each crate's own colour. (CarGlow's car lights are made for open stands: three
-- in the small booth washed it out white, Studio final pass 15.) The mega one still pulses.
local GLOW: { [string]: number } = { basic = 0.5, big = 0.65, mega = 0.8 }
local function glow(crate: Model, id: string, color: Color3)
	local part = crate:FindFirstChild("Box")
	if not (part and part:IsA("BasePart")) then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "CrateGlow"
	light.Color = color
	light.Brightness = GLOW[id] or 0.5
	light.Range = 5
	light.Shadows = false
	light:SetAttribute("Base", light.Brightness)
	light.Parent = part
	if id == "mega" then
		CollectionService:AddTag(light, CarGlow.PULSE_TAG)
	end
end

type Spin = { model: Model, base: CFrame, phase: number }
local spins: { Spin } = {}
local seen: { [Model]: boolean } = {}

local function addShop(shop: Model)
	if seen[shop] or shop:GetAttribute("ShopKind") ~= "crates" then
		return
	end
	seen[shop] = true
	-- the sign post's board (Garage.crateYard): CRATES on two opposite sides only, big enough to
	-- read from across the plaza (on all 4, two sides showed at once: "CRATES CRATES", L7)
	local sign = shop:FindFirstChild("CrateSign")
	local board = sign and sign:FindFirstChild("Board")
	if board and board:IsA("BasePart") then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 40
			g.LightInfluence = 0
			g.Parent = board
			text(g, "CRATES", 0.05, 0.1, 0.9, 0.8, nil, Color3.new(1, 1, 1))
		end
	end
	local floor = shop.PrimaryPart
	local out = if floor then floor.CFrame.ZVector else Vector3.new(0, 0, 1)
	for i, id in Crates.SHOP do
		local kind = Crates.get(id)
		local crate = shop:FindFirstChild("Crate" .. i)
		local stand = shop:FindFirstChild("Stand" .. i)
		local ring = stand and stand:FindFirstChild("Ring")
		if kind and crate and crate:IsA("Model") then
			local color = rgb(Garage.CRATE_COLORS[id] or Garage.CRATE_COLORS.basic)
			if ring and ring:IsA("BasePart") then
				ring.Color = color
				table.insert(prices, { label = plate(ring, out, kind), cost = kind.price })
				paint()
			end
			glow(crate, id, color)
			table.insert(spins, { model = crate, base = crate:GetPivot(), phase = i * 1.3 })
			local box = crate:FindFirstChild("Box")
			if box and box:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "LOOK"
				prompt.ObjectText = "" -- (the plate names it)
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = box
				prompt.Triggered:Connect(function()
					shopEvent():Fire(id)
				end)
			end
		end
	end
end

-- each crate turns slowly and bobs a little on its turntable, so it reads as "open me"
-- (only near ones: in a race across the map nobody can see them turn, phone speed)
local SPIN_NEAR = 150
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for _, s in spins do
		if s.model.Parent and (s.base.Position - eye).Magnitude < SPIN_NEAR then
			local bob = math.sin(t * 2 + s.phase) * 0.3 + 0.3
			s.model:PivotTo(s.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 0.6 + s.phase, 0))
		end
	end
end)

local function check(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("ShopKind") == "crates" then
		-- the crates and stands arrive just after the model; give them a moment
		task.delay(1, addShop, inst :: Model)
	end
end
for _, d in workspace:GetDescendants() do
	check(d)
end
workspace.DescendantAdded:Connect(check)
