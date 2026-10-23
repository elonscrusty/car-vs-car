--!strict
-- The spawn lobby's car shops (Garage.build with a shop kind, marked with a ShopKind attribute)
-- and the gumball machine (tagged "Gumball"). The cars on show turn slowly on their stands; the
-- counter opens the shop screen: a card per car (the car itself, its name, its price in coins)
-- with BUY (when you have the coins), PICK (yours: drive it in that mode) or DRIVING. The
-- gumball machine opens its own screen: every rare car with its odds, and SPIN. Every screen has
-- a TILES tab: track tiles for your plot (coin tiles to buy, legendary tiles from the tile spin
-- with the odds shown, or for coins).
-- The server (CarShop.server, RemoteFunction CarShop) does every buy, pick and spin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Garage = require(Shared:WaitForChild("Garage"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local TileShop = require(Shared:WaitForChild("TileShop"))
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
	tiles: { string }?,
	stars: number?,
	ok: boolean,
	why: string?,
	car: string?,
	tile: string?,
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

local title = text(panel, "", 0.05, 0.03, 0.31, 0.12, Color3.new(1, 1, 1), true)
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

-- A list of rows on the left of the screen: five show at once, more scroll (swipe on a phone).
local function rowList(rows: number): (number) -> Frame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.fromScale(0.62, 0.78)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 8
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.CanvasSize = UDim2.fromScale(0, math.max(rows / 5, 1))
	scroller.Parent = body
	local slots = math.max(rows, 5)
	return function(i: number): Frame
		local row = Instance.new("Frame")
		row.Position = UDim2.fromScale(0, (i - 1) / slots)
		row.Size = UDim2.new(1, -12, 1 / slots, -6)
		row.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
		row.Parent = scroller
		corner(row, 0.25)
		return row
	end
end

-- What a grey BUY says: how many more coins you need.
local function needWords(price: number, coins: number): string
	return if coins >= price then "BUY" else `{price - coins} more`
end

-- ===== Shop screen =====

local current: { kind: string, gumball: boolean, tiles: boolean }? = nil
local render: () -> () = function() end

-- CARS / TILES tabs at the top of every screen
local function tab(t: string, x: number, tiles: boolean): TextButton
	local b = button(panel, t, GOLD, true)
	b.Position = UDim2.fromScale(x, 0.04)
	b.Size = UDim2.fromScale(0.12, 0.1)
	b.Activated:Connect(function()
		local c = current
		if c and c.tiles ~= tiles then
			c.tiles = tiles
			render()
		end
	end)
	return b
end
local carsTab = tab("CARS", 0.37, false)
local tilesTab = tab("TILES", 0.5, true)
local function showTab(tiles: boolean)
	carsTab.BackgroundColor3 = if tiles then GREY else GOLD
	tilesTab.BackgroundColor3 = if tiles then GOLD else GREY
end

local function showShop(kind: string, s: State)
	clear()
	title.Text = TITLES[kind] or "CARS"
	panelStroke.Color = rgb(Garage.SHOPS[kind].color)
	coinsLabel.Text = s.coins .. " coins"
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
	-- three cards show at once; more scroll sideways (swipe on a phone)
	local shown = math.max(#cars, 3)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.fromScale(1, 0.9)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 8
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.CanvasSize = UDim2.fromScale(shown / 3, 0)
	scroller.Parent = body
	text(
		body,
		if #cars > 3
			then "Win races and beat records for coins. Swipe for more cars."
			else "Win races and beat records for coins.",
		0,
		0.92,
		1,
		0.08,
		Color3.fromRGB(180, 180, 190)
	)
	for i, car in cars do
		local c = Instance.new("Frame")
		c.Position = UDim2.new((i - 1) / shown, 4, 0, 0)
		c.Size = UDim2.new(1 / shown, -8, 1, -14)
		c.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
		c.Parent = scroller
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
			b = button(
				c,
				needWords(car.price, s.coins),
				Color3.fromRGB(240, 170, 20),
				s.coins >= car.price
			)
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
	local newRow = rowList(#CarCatalog.GUMBALL)
	for i, g in CarCatalog.GUMBALL do
		local row = newRow(i)
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

-- ===== Tiles screen =====

local TIER_WORDS = { coins = "track piece", legendary = "LEGENDARY" }
local LEGEND = Color3.fromRGB(60, 220, 255)

local function showTiles(s: State, result: string?)
	clear()
	title.Text = "TRACK TILES"
	panelStroke.Color = LEGEND
	coinsLabel.Text = s.coins .. " coins"
	local owned: { [string]: boolean } = {}
	for _, id in s.tiles or {} do
		owned[id] = true
	end
	local chance: { [string]: number } = {}
	for _, g in TileShop.SPIN do
		chance[g.id] = g.chance
	end
	local list: { TileShop.Tile } = {}
	for _, t in TileShop.TILES do
		if t.tier ~= "free" then
			table.insert(list, t)
		end
	end
	-- cheapest first, so the next tile to save for is near the top
	table.sort(list, function(a, b)
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.name < b.name
	end)
	local newRow = rowList(#list)
	for i, t in list do
		local row = newRow(i)
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromScale(0.02, 0.15)
		dot.Size = UDim2.fromScale(0.06, 0.7)
		dot.BackgroundColor3 = rgb(t.color)
		dot.Parent = row
		corner(dot, 0.5)
		local legendary = t.tier == "legendary"
		text(row, t.name, 0.1, 0.08, 0.3, 0.5, Color3.new(1, 1, 1), true)
		local at = TileShop.unlockAt(t.id)
		text(
			row,
			if at > 0 then `opens at {at} stars` else TIER_WORDS[t.tier] or "",
			0.1,
			0.58,
			0.3,
			0.34,
			if legendary then LEGEND else Color3.fromRGB(180, 180, 190),
			true
		)
		if chance[t.id] then
			text(row, chance[t.id] .. "%", 0.41, 0.15, 0.13, 0.7, LEGEND)
		end
		text(row, t.price .. " coins", 0.55, 0.2, 0.22, 0.6, GOLD)
		local b: TextButton
		if owned[t.id] then
			b = button(row, "HAVE", Color3.fromRGB(60, 180, 80), false)
			b.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
			b.TextColor3 = Color3.new(1, 1, 1)
		elseif (s.stars or 0) < at then
			-- not open yet: win stars on other people's tracks
			b = button(row, `{at} stars`, GOLD, false)
		else
			local can = s.coins >= t.price
			b = button(row, needWords(t.price, s.coins), Color3.fromRGB(240, 170, 20), can)
			if can then
				b.Activated:Connect(function()
					b.Active = false
					local now = ask("buyTile", t.id)
					if now then
						showTiles(
							now,
							if now.ok then `{t.name} is yours! Put it on your track.` else nil
						)
					end
				end)
			end
		end
		b.Position = UDim2.fromScale(0.79, 0.12)
		b.Size = UDim2.fromScale(0.19, 0.76)
	end
	text(
		body,
		`Legendary tiles hit every racer on your track. A spin you have already gives {TileShop.DUPLICATE_REFUND} coins back.`,
		0,
		0.82,
		0.62,
		0.12,
		Color3.fromRGB(180, 180, 190)
	).TextWrapped =
		true
	local can = s.coins >= TileShop.SPIN_PRICE
	local spin = button(body, `SPIN  {TileShop.SPIN_PRICE} coins`, LEGEND, can)
	spin.Position = UDim2.fromScale(0.66, 0.62)
	spin.Size = UDim2.fromScale(0.34, 0.2)
	local out = text(
		body,
		result or "Spin for a legendary tile!",
		0.66,
		0.05,
		0.34,
		0.5,
		Color3.new(1, 1, 1)
	)
	out.TextWrapped = true
	if can then
		spin.Activated:Connect(function()
			spin.Active = false
			local now = ask("spinTile")
			if now then
				local t = if now.tile then TileShop.get(now.tile) else nil
				local msg = if t == nil
					then "Not enough coins"
					elseif now.new then `You got {t.name}! Put it on your track.`
					else `{t.name} again: {TileShop.DUPLICATE_REFUND} coins back`
				showTiles(now, msg)
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
	showTab(c.tiles)
	if c.tiles then
		showTiles(s)
	elseif c.gumball then
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
			current = { kind = kind, gumball = false, tiles = false }
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
			current = { kind = "", gumball = true, tiles = false }
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
