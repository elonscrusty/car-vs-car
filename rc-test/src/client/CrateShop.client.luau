--!strict
-- Car VS Car's crate shop in the spawn lobby (carter's yes 10-26,
-- rc-game/cvc/pics/crate-shop-top-down.png). Only with Features.CVC on. The building and its three
-- crates come from Garage.build("crates"); this spins and bobs each crate on its turntable, puts a
-- price plate in front of it (its name, coins, and the odds of each kind of car as coloured chips),
-- and a prompt on it that opens the crate screen for that crate (CvcCrate listens on the
-- BindableEvent ReplicatedStorage.CvcCrateShop: Fire(kind)).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
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

-- A dark plate low in front of the crate, leaned back (like the car shops' price plates): the
-- crate's name on a pill in its colour, the price, and a chip per kind of car with its odds.
local function plate(ring: BasePart, out: Vector3, kind: Crates.Kind): TextLabel
	local color = rgb(Garage.CRATE_COLORS[kind.id] or Garage.CRATE_COLORS.basic)
	local at = ring.Position + out * 3.3 + Vector3.new(0, 0.95, 0)
	local p = Instance.new("Part")
	p.Name = kind.id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(4.6, 2, 0.15)
	p.Color = INK
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.lookAt(at, at + out) * CFrame.Angles(math.rad(25), 0, 0)
	p.Parent = plates
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
	text(g, kind.label, 0.08, 0.06, 0.84, 0.3, color, Color3.new(1, 1, 1))
	local price = text(g, `{kind.price} coins`, 0.04, 0.38, 0.92, 0.3, nil, GOLD)
	-- the odds: one chip per kind of car that this crate can give, in that kind's colour
	local odds = Crates.odds(kind.id)
	local shown = {}
	for _, r in CarCatalog.RARITY_ORDER do
		if (odds[r] or 0) > 0 then
			table.insert(shown, r)
		end
	end
	local w = 0.92 / math.max(#shown, 1)
	for i, r in shown do
		local tier = CarCatalog.RARITY[r]
		local n = odds[r]
		local s = if n == math.floor(n) then `{n}%` else string.format("%.1f%%", n)
		text(
			g,
			s,
			0.04 + (i - 1) * w + 0.01,
			0.72,
			w - 0.02,
			0.22,
			-- common on a mid slate, like the car shops' plates (light grey under white words blurred)
			if r == "common" then Color3.fromRGB(100, 110, 140) else rgb(tier.color),
			Color3.new(1, 1, 1)
		)
	end
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

local GLOW: { [string]: string } = { basic = "rare", big = "epic", mega = "legend" }

type Spin = { model: Model, base: CFrame, phase: number }
local spins: { Spin } = {}
local seen: { [Model]: boolean } = {}

local function addShop(shop: Model)
	if seen[shop] or shop:GetAttribute("ShopKind") ~= "crates" then
		return
	end
	seen[shop] = true
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
			-- a glow like a car of the best kind it can give: big = epic, mega = legend (pulses)
			CarGlow.apply(crate, GLOW[id])
			table.insert(spins, { model = crate, base = crate:GetPivot(), phase = i * 1.3 })
			local box = crate:FindFirstChild("Box")
			if box and box:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "LOOK"
				prompt.ObjectText = kind.label
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
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, s in spins do
		if s.model.Parent then
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
