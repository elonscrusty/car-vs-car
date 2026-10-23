--!strict
-- The spawn lobby's car shops (Garage.build with a shop kind, marked with a ShopKind attribute):
-- the three cars on show turn slowly on their stands, and the counter opens the shop screen.
-- The screen is looks only for now: a card per car (the car itself, its name, its price in
-- coins) with a BUY button that stays grey until coins exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garage"))

local player = Players.LocalPlayer

local SPIN = 0.35 -- radians a second
local TITLES = { drift = "DRIFT CARS", race = "RACE CARS", rock = "ROCK CARS" }

-- ===== Spinning cars =====

type Spinner = { car: Model, center: Vector3, offset: CFrame }
local spinners: { Spinner } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- ===== Shop screen =====

local gui = Instance.new("ScreenGui")
gui.Name = "CarShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.86, 0.7)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
panel.Parent = gui
local panelRatio = Instance.new("UIAspectRatioConstraint")
panelRatio.AspectRatio = 1.9
panelRatio.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0.05, 0)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 4
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromScale(0.05, 0.03)
title.Size = UDim2.fromScale(0.7, 0.13)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = panel

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(0.97, 0.03)
close.Size = UDim2.fromScale(0.07, 0.13)
close.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
close.Font = Enum.Font.GothamBlack
close.TextScaled = true
close.TextColor3 = Color3.new(1, 1, 1)
close.Text = "X"
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0.3, 0)
closeCorner.Parent = close

local cards = Instance.new("Frame")
cards.Name = "Cards"
cards.BackgroundTransparency = 1
cards.Position = UDim2.fromScale(0.04, 0.2)
cards.Size = UDim2.fromScale(0.92, 0.75)
cards.Parent = panel
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0.03, 0)
list.Parent = cards

local function label(parent: Instance, text: string, y: number, h: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0.06, y)
	l.Size = UDim2.fromScale(0.88, h)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function card(shopModel: Model, kind: string, i: number)
	local info = Garage.SHOPS[kind]
	local c = Instance.new("Frame")
	c.Name = "Card" .. i
	c.Size = UDim2.fromScale(0.3, 1)
	c.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
	c.LayoutOrder = i
	c.Parent = cards
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = c

	-- the car itself, a copy of the one on the stand
	local view = Instance.new("ViewportFrame")
	view.Position = UDim2.fromScale(0.06, 0.04)
	view.Size = UDim2.fromScale(0.88, 0.52)
	view.BackgroundColor3 = rgb(info.color)
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.Parent = c
	local viewCorner = Instance.new("UICorner")
	viewCorner.CornerRadius = UDim.new(0.1, 0)
	viewCorner.Parent = view
	local src = shopModel:FindFirstChild("Car" .. i)
	if src and src:IsA("Model") then
		local copy = src:Clone()
		copy.Parent = view
		local cf, size = copy:GetBoundingBox()
		local cam = Instance.new("Camera")
		local dist = size.Magnitude * 1.1
		local eye = cf.Position + Vector3.new(dist * 0.6, dist * 0.45, dist * 0.6)
		cam.CFrame = CFrame.lookAt(eye, cf.Position)
		cam.FieldOfView = 40
		cam.Parent = view
		view.CurrentCamera = cam
	end

	label(c, info.names[i], 0.58, 0.13, Color3.new(1, 1, 1))
	label(c, info.prices[i] .. " coins", 0.71, 0.1, Color3.fromRGB(255, 213, 79))

	-- no coins yet: the button is there, grey, and does nothing
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Position = UDim2.fromScale(0.12, 0.84)
	buy.Size = UDim2.fromScale(0.76, 0.12)
	buy.BackgroundColor3 = Color3.fromRGB(110, 110, 118)
	buy.AutoButtonColor = false
	buy.Active = false
	buy.Font = Enum.Font.GothamBlack
	buy.TextScaled = true
	buy.TextColor3 = Color3.fromRGB(200, 200, 205)
	buy.Text = "BUY"
	buy.Parent = c
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0.3, 0)
	buyCorner.Parent = buy
end

local function openShop(shopModel: Model, kind: string)
	for _, old in cards:GetChildren() do
		if old:IsA("Frame") then
			old:Destroy()
		end
	end
	title.Text = TITLES[kind] or "CARS"
	panelStroke.Color = rgb(Garage.SHOPS[kind].color)
	for i = 1, #Garage.SHOPS[kind].names do
		card(shopModel, kind, i)
	end
	gui.Enabled = true
end

close.Activated:Connect(function()
	gui.Enabled = false
end)

-- ===== Hook up each shop as it appears =====

local seen: { [Model]: boolean } = {}

local function addShop(shopModel: Model)
	local kind = shopModel:GetAttribute("ShopKind")
	if seen[shopModel] or type(kind) ~= "string" or Garage.SHOPS[kind] == nil then
		return
	end
	seen[shopModel] = true
	for i = 1, #Garage.SHOPS[kind].names do
		local car = shopModel:FindFirstChild("Car" .. i)
		local stand = shopModel:FindFirstChild("Stand" .. i)
		local ring = stand and stand:FindFirstChild("Ring")
		if car and car:IsA("Model") then
			local center = if ring and ring:IsA("BasePart")
				then ring.Position
				else car:GetPivot().Position
			local pivot = car:GetPivot()
			table.insert(spinners, {
				car = car,
				center = center,
				offset = CFrame.new(center):Inverse() * pivot,
			})
		end
	end
	local counter = shopModel:FindFirstChild("Counter")
	local desk = counter and counter:FindFirstChild("Desk")
	if desk and desk:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Shop"
		prompt.ObjectText = TITLES[kind] or ""
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = desk
		prompt.Triggered:Connect(function()
			openShop(shopModel, kind)
		end)
	end
end

local function check(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("ShopKind") ~= nil then
		-- the cars and stands arrive just after the model; give them a moment
		task.delay(1, addShop, inst :: Model)
	end
end

for _, d in workspace:GetDescendants() do
	check(d)
end
workspace.DescendantAdded:Connect(check)

local angle = 0
RunService.RenderStepped:Connect(function(dt)
	angle += dt * SPIN
	local turn = CFrame.Angles(0, angle, 0)
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if s.car.Parent == nil then
			table.remove(spinners, i)
		else
			s.car:PivotTo(CFrame.new(s.center) * turn * s.offset)
		end
	end
end)
