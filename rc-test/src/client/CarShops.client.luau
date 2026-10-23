--!strict
-- The spawn lobby's car shops (Garage.build with a shop kind, marked with a ShopKind attribute)
-- and the gumball machine (tagged "Gumball"). The cars on show turn slowly on their stands; the
-- counter opens the shop screen: a card per car (the car itself, its name, its price in coins)
-- with BUY (when you have the coins), PICK (yours: drive it in that mode) or DRIVING. The
-- gumball machine opens its own screen: every rare car with its odds, and SPIN.
-- The server (CarShop.server, RemoteFunction CarShop) does every buy, pick and spin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Garage = require(Shared:WaitForChild("Garage"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))

local player = Players.LocalPlayer
local shopRemote = ReplicatedStorage:WaitForChild("CarShop") :: RemoteFunction

local SPIN = 0.35 -- radians a second
local TITLES = { drift = "DRIFT CARS", race = "RACE CARS", rock = "ROCK CARS" }
local MODE_WORDS = { drift = "drift", race = "race", rock = "rock" }
local GOLD = Color3.fromRGB(255, 213, 79)
local GREY = Color3.fromRGB(110, 110, 118)

type State = {
	coins: number,
	owned: { string },
	equipped: { [string]: string },
	ok: boolean,
	why: string?,
	car: string?,
	new: boolean?,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ask(action: string, id: string?): State?
	local ok, result = pcall(function()
		return shopRemote:InvokeServer(action, id)
	end)
	if ok and type(result) == "table" and type(result.coins) == "number" then
		return result :: State
	end
	return nil
end

-- ===== Spinning cars =====

type Spinner = { car: Model, center: Vector3, offset: CFrame }
local spinners: { Spinner } = {}

-- ===== Screen pieces =====

local gui = Instance.new("ScreenGui")
gui.Name = "CarShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = HudLayout.POPUP
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.78)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
panel.Parent = gui
local panelRatio = Instance.new("UIAspectRatioConstraint")
panelRatio.AspectRatio = 1.9
panelRatio.Parent = panel
corner(panel, 0.05)
local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 4
panelStroke.Parent = panel

local function text(
	parent: Instance,
	t: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	left: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	l.Text = t
	l.Parent = parent
	return l
end

local title = text(panel, "", 0.05, 0.03, 0.6, 0.12, Color3.new(1, 1, 1), true)
local coinsLabel = text(panel, "", 0.62, 0.05, 0.25, 0.08, GOLD)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

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
corner(close, 0.3)

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromScale(0.04, 0.19)
body.Size = UDim2.fromScale(0.92, 0.77)
body.Parent = panel

local function clear()
	for _, old in body:GetChildren() do
		old:Destroy()
	end
end

local function button(parent: Instance, t: string, color: Color3, live: boolean): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = if live then color else GREY
	b.AutoButtonColor = live
	b.Active = live
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = if live then Color3.new(1, 1, 1) else Color3.fromRGB(200, 200, 205)
	b.Text = t
	b.Parent = parent
	corner(b, 0.3)
	-- keep the words off the rounded edges
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.08, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.Parent = b
	return b
end

-- A toy car in a little window, seen from the front.
local function preview(parent: Instance, car: CarCatalog.Car, bg: Color3): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.BackgroundColor3 = bg
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.Parent = parent
	corner(view, 0.1)
	local pieces = {}
	Garage.toyCar(Garage.adder(pieces), "Car", { x = 0, y = 0, z = 0 }, 0, car.color, 1, car.style)
	local model = Instance.new("Model")
	Garage.makeParts(pieces, model, CFrame.identity)
	model.Parent = view
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	local d = size.Magnitude * 1.15
	-- nose is -Z: look at it from the front left, a bit above
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-d * 0.55, d * 0.4, -d * 0.7), cf.Position)
	cam.FieldOfView = 40
	cam.Parent = view
	view.CurrentCamera = cam
	return view
end

-- ===== Shop screen =====

local current: { kind: string, gumball: boolean }? = nil
local render: () -> () = function() end

local function showShop(kind: string, s: State)
	clear()
	title.Text = TITLES[kind] or "CARS"
	panelStroke.Color = rgb(Garage.SHOPS[kind].color)
	coinsLabel.Text = s.coins .. " coins"
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.02, 0)
	list.Parent = body
	local owned: { [string]: boolean } = {}
	for _, id in s.owned do
		owned[id] = true
	end
	-- the shop's cars, then any rare cars of this mode you won
	local cars: { CarCatalog.Car } = table.clone(CarCatalog.SHOP[kind])
	for _, g in CarCatalog.GUMBALL do
		if g.car.mode == kind and owned[g.car.id] then
			table.insert(cars, g.car)
		end
	end
	local w = math.min(0.31, (1 - 0.02 * (#cars - 1)) / #cars)
	for i, car in cars do
		local c = Instance.new("Frame")
		c.Size = UDim2.fromScale(w, 1)
		c.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
		c.LayoutOrder = i
		c.Parent = body
		corner(c, 0.08)
		local view = preview(c, car, rgb(Garage.SHOPS[kind].color))
		view.Position = UDim2.fromScale(0.06, 0.04)
		view.Size = UDim2.fromScale(0.88, 0.5)
		text(c, car.name, 0.06, 0.57, 0.88, 0.12, Color3.new(1, 1, 1))
		local price = if car.rare
			then "RARE"
			elseif car.price == 0 then "FREE"
			else car.price .. " coins"
		text(
			c,
			price,
			0.06,
			0.7,
			0.88,
			0.1,
			if car.rare then Color3.fromRGB(255, 120, 190) else GOLD
		)

		local b: TextButton
		if s.equipped[kind] == car.id then
			b = button(c, "DRIVING", Color3.fromRGB(60, 180, 80), false)
			b.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
			b.TextColor3 = Color3.new(1, 1, 1)
		elseif owned[car.id] then
			b = button(c, "PICK", Color3.fromRGB(40, 120, 230), true)
			b.Activated:Connect(function()
				local now = ask("equip", car.id)
				if now then
					showShop(kind, now)
				end
			end)
		else
			b = button(c, "BUY", Color3.fromRGB(240, 170, 20), s.coins >= car.price)
			if s.coins >= car.price then
				b.Activated:Connect(function()
					local now = ask("buy", car.id)
					if now then
						if now.ok then
							-- bought: drive it straight away
							now = ask("equip", car.id) or now
						end
						showShop(kind, now :: State)
					end
				end)
			end
		end
		b.Position = UDim2.fromScale(0.1, 0.84)
		b.Size = UDim2.fromScale(0.8, 0.12)
	end
end

-- ===== Gumball screen =====

local function showGumball(s: State, result: string?)
	clear()
	title.Text = "GUMBALL"
	panelStroke.Color = Color3.fromRGB(255, 120, 190)
	coinsLabel.Text = s.coins .. " coins"
	local owned: { [string]: boolean } = {}
	for _, id in s.owned do
		owned[id] = true
	end
	-- the odds, every car, plainly
	local rows = #CarCatalog.GUMBALL
	for i, g in CarCatalog.GUMBALL do
		local y = (i - 1) / rows * 0.78
		local row = Instance.new("Frame")
		row.Position = UDim2.fromScale(0, y)
		row.Size = UDim2.fromScale(0.62, 0.78 / rows - 0.02)
		row.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
		row.Parent = body
		corner(row, 0.25)
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromScale(0.02, 0.15)
		dot.Size = UDim2.fromScale(0.07, 0.7)
		dot.BackgroundColor3 = rgb(g.car.color)
		dot.Parent = row
		corner(dot, 0.5)
		text(row, g.car.name, 0.12, 0.1, 0.45, 0.8, Color3.new(1, 1, 1), true)
		text(
			row,
			MODE_WORDS[g.car.mode] or "",
			0.55,
			0.15,
			0.18,
			0.7,
			Color3.fromRGB(180, 180, 190)
		)
		text(row, g.chance .. "%", 0.74, 0.1, 0.16, 0.8, GOLD)
		if owned[g.car.id] then
			text(row, "HAVE", 0.9, 0.2, 0.09, 0.6, Color3.fromRGB(90, 220, 110))
		end
	end
	text(
		body,
		`A car you have already gives {CarCatalog.DUPLICATE_REFUND} coins back.`,
		0,
		0.82,
		0.62,
		0.08,
		Color3.fromRGB(180, 180, 190)
	)
	local can = s.coins >= CarCatalog.GUMBALL_PRICE
	local spin =
		button(body, `SPIN  {CarCatalog.GUMBALL_PRICE} coins`, Color3.fromRGB(255, 120, 190), can)
	spin.Position = UDim2.fromScale(0.66, 0.62)
	spin.Size = UDim2.fromScale(0.34, 0.2)
	local out = text(body, result or "", 0.66, 0.05, 0.34, 0.5, Color3.new(1, 1, 1))
	out.TextWrapped = true
	if can then
		spin.Activated:Connect(function()
			spin.Active = false
			local now = ask("spin")
			if now then
				local car = if now.car then CarCatalog.get(now.car) else nil
				local msg = if car == nil
					then "Not enough coins"
					elseif
						now.new
					then `You got {car.name}! Pick it in the {MODE_WORDS[car.mode]} shop.`
					else `{car.name} again: {CarCatalog.DUPLICATE_REFUND} coins back`
				showGumball(now, msg)
			end
		end)
	end
end

render = function()
	local c = current
	if c == nil then
		return
	end
	local s = ask("state")
	if s == nil then
		return
	end
	if c.gumball then
		showGumball(s)
	else
		showShop(c.kind, s)
	end
	gui.Enabled = true
end

close.Activated:Connect(function()
	gui.Enabled = false
	current = nil
end)

local function prompt(parent: BasePart, action: string, object: string, onUse: () -> ())
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onUse)
end

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
			table.insert(spinners, {
				car = car,
				center = center,
				offset = CFrame.new(center):Inverse() * car:GetPivot(),
			})
		end
	end
	local counter = shopModel:FindFirstChild("Counter")
	local desk = counter and counter:FindFirstChild("Desk")
	if desk and desk:IsA("BasePart") then
		prompt(desk, "Shop", TITLES[kind] or "", function()
			current = { kind = kind, gumball = false }
			render()
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

local function addGumball(inst: Instance)
	if inst:IsA("BasePart") then
		prompt(inst, "Spin", "Gumball", function()
			current = { kind = "", gumball = true }
			render()
		end)
	end
end
for _, inst in CollectionService:GetTagged("Gumball") do
	addGumball(inst)
end
CollectionService:GetInstanceAddedSignal("Gumball"):Connect(addGumball)

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
