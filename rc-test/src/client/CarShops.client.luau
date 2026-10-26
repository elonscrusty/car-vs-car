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
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundLevels = require(Shared:WaitForChild("SoundLevels"))
local Garage = require(Shared:WaitForChild("Garage"))
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local CarGlow = require(Shared:WaitForChild("CarGlow"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Party = require(script.Parent:WaitForChild("Party"))
local Popup = require(script.Parent:WaitForChild("Popup"))

local player = Players.LocalPlayer
local shopRemote = ReplicatedStorage:WaitForChild("CarShop") :: RemoteFunction

local SPIN = 0.35 -- radians a second
local TITLES = { drift = "DRIFT CARS", race = "RACE CARS" }
local GOLD = KartStyle.YELLOW
local GREY = Color3.fromRGB(110, 110, 118)
-- Kart Party cards: white cards with ink words and rims on the blue panel
local CARD = Color3.fromRGB(244, 247, 255)
local PRICE = Color3.fromRGB(214, 128, 0) -- coin orange: reads on a white card
local HINT = Color3.fromRGB(207, 227, 255)

type State = {
	coins: number,
	owned: { string },
	equipped: { [string]: string },
	stars: number?,
	ok: boolean,
	why: string?,
	car: string?,
	new: boolean?,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A new car parks on your plot and starts making coins (the server adds it if a spot is free).
local function park(id: string)
	local plot = ReplicatedStorage:FindFirstChild("Plot")
	if plot and plot:IsA("RemoteEvent") then
		plot:FireServer("park", id, true)
	end
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
panelStroke.Thickness = KartStyle.PANEL_RIM
panelStroke.Color = KartStyle.INK
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
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	l.Text = t
	l.Parent = parent
	return l
end

-- the shop's name on a yellow ribbon, in the shop's own colour rim
local title = text(panel, "", 0.04, 0.035, 0.3, 0.11, KartStyle.INK)
title.BackgroundColor3 = GOLD
title.BackgroundTransparency = 0
corner(title, 0.3)
local titleRim = Instance.new("UIStroke")
titleRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
titleRim.Color = KartStyle.INK
titleRim.Thickness = KartStyle.BUTTON_RIM
titleRim.Parent = title
local titlePad = Instance.new("UIPadding")
titlePad.PaddingTop = UDim.new(0.14, 0)
titlePad.PaddingBottom = UDim.new(0.1, 0)
titlePad.PaddingLeft = UDim.new(0.05, 0)
titlePad.PaddingRight = UDim.new(0.05, 0)
titlePad.Parent = title
local coinsLabel = text(panel, "", 0.62, 0.05, 0.25, 0.08, GOLD)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(0.97, 0.03)
close.Size = UDim2.fromScale(0.07, 0.13)
close.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
close.Font = Enum.Font.LuckiestGuy
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
	b.Font = Enum.Font.LuckiestGuy
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
	return if coins >= price then "BUY" else `{price - coins} MORE`
end

-- ===== NEW CAR! =====
-- A new car is a big moment: the whole screen goes dark, the car turns slowly in the middle,
-- NEW CAR! pops in, and you are already driving it. Tap DRIVE IT! to go.

local revealSpin: RBXScriptConnection? = nil

-- Can this car go for a drive from the shop? (Tycoon plan: plots are garages, only the free
-- drift plot drives; a race car races on the maps with JOIN RACE.)
local function drivesNow(car: CarCatalog.Car): boolean
	return car.mode == "drift"
end

-- A kind's pill colour: its own, but common's light grey is a slate here (it vanished on the
-- white cards, Studio check 10-26). Words on a pill are always white.
local COMMON_PILL = Color3.fromRGB(110, 116, 135)
local function pillColor(tier: CarCatalog.Rarity): Color3
	return if tier.id == "common" then COMMON_PILL else rgb(tier.color)
end

local function reveal(car: CarCatalog.Car, onDone: () -> ())
	local back = Instance.new("TextButton") -- swallows taps behind it
	back.Name = "NewCar"
	back.AutoButtonColor = false
	back.Text = ""
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.25
	back.ZIndex = 10
	back.Parent = gui
	panel.Visible = false -- nothing behind NEW CAR! to clash with it
	-- a rising two-note ping (the built-in sound the race start already uses)
	for i, pitch in { 1, 1.5 } do
		task.delay((i - 1) * 0.14, function()
			local ping = Instance.new("Sound")
			ping.SoundId = "rbxasset://sounds/electronicpingshort.wav"
			ping.PlaybackSpeed = pitch
			ping.Volume = SoundLevels.NEW_CAR
			ping.Parent = gui
			ping:Play()
			ping.Ended:Once(function()
				ping:Destroy()
			end)
		end)
	end
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(0.6, 0.9)
	box.BackgroundTransparency = 1
	box.ZIndex = 10
	box.Parent = back
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1.25
	ratio.Parent = box
	local view = preview(box, car, rgb(car.color):Lerp(Color3.new(0, 0, 0), 0.6))
	view.ZIndex = 10
	view.Position = UDim2.fromScale(0.1, 0.16)
	view.Size = UDim2.fromScale(0.8, 0.52)
	local words = {
		text(box, "NEW CAR!", 0, 0, 1, 0.15, GOLD),
		text(box, car.name, 0, 0.7, 1, 0.1, Color3.new(1, 1, 1)),
		text(
			box,
			`In your garage! +{CarCatalog.rarity(car.id).perMin} coins/min`,
			0,
			0.8,
			1,
			0.06,
			Color3.fromRGB(180, 230, 190)
		),
	}
	-- its kind on a pill over the car, in the kind's colour
	local tier = CarCatalog.rarity(car.id)
	local kindTag = text(box, tier.label, 0.36, 0.15, 0.28, 0.065, Color3.new(1, 1, 1))
	kindTag.BackgroundColor3 = pillColor(tier)
	kindTag.BackgroundTransparency = 0
	corner(kindTag, 0.5)
	table.insert(words, kindTag)
	for _, w in words do
		w.ZIndex = 11
	end
	local go = button(
		box,
		if not drivesNow(car) then "OK!" elseif car.mode == "drift" then "DRIFT IT!" else "DRIVE IT!",
		Color3.fromRGB(60, 180, 80),
		true
	)
	go.ZIndex = 11
	go.Position = UDim2.fromScale(0.3, 0.88)
	go.Size = UDim2.fromScale(0.4, 0.12)
	-- NEW CAR! pops in from small
	local pop = words[1]
	pop.Size = UDim2.fromScale(0.2, 0.03)
	pop.Position = UDim2.fromScale(0.4, 0.06)
	TweenService:Create(
		pop,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 0.15), Position = UDim2.fromScale(0, 0) }
	):Play()
	-- a party: gold rays turn behind the car, confetti falls
	-- rays in the kind's colour (gold for common and legend)
	local stopRays = Party.rays(view, if tier.id == "common" then GOLD else rgb(tier.color))
	Party.confetti(back, 60)
	-- the car turns on its spot
	local cam = view.CurrentCamera
	local model = view:FindFirstChildOfClass("Model")
	if cam and model then
		local cf = model:GetBoundingBox()
		local center = cf.Position
		local offset = cam.CFrame.Position - center
		local angle = 0
		if revealSpin then
			revealSpin:Disconnect()
		end
		revealSpin = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.8
			cam.CFrame = CFrame.lookAt(
				center + CFrame.Angles(0, angle, 0):VectorToWorldSpace(offset),
				center
			)
		end)
	end
	go.Activated:Connect(function()
		if revealSpin then
			revealSpin:Disconnect()
			revealSpin = nil
		end
		stopRays()
		back:Destroy()
		panel.Visible = true
		onDone()
	end)
end

local current: { kind: string, gumball: boolean }? = nil

-- DRIVE IT!: shut the shop and put me on a track in my new car (my own plot when it is that
-- kind, else an open one; the server picks).
local function driveNow(car: CarCatalog.Car)
	gui.Enabled = false
	current = nil
	task.spawn(ask, "drive", car.id)
end

-- ===== Shop screen =====

local render: () -> () = function() end

local function showShop(kind: string, s: State)
	clear()
	title.Text = TITLES[kind] or "CARS"
	titleRim.Color = KartStyle.INK
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
	-- four cards show at once; < > (or a swipe) shows the next four
	local PER = 4
	local shown = math.max(#cars, PER)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.fromScale(0.06, 0)
	scroller.Size = UDim2.fromScale(0.88, 0.9)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 8
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.CanvasSize = UDim2.fromScale(shown / PER, 0)
	scroller.Parent = body
	local function arrow(t: string, x: number, step: number): TextButton
		local b = button(body, t, Color3.fromRGB(70, 70, 84), true)
		b.Position = UDim2.fromScale(x, 0.32)
		b.Size = UDim2.fromScale(0.05, 0.22)
		b.Activated:Connect(function()
			local page = scroller.AbsoluteSize.X
			local most = math.max(scroller.AbsoluteCanvasSize.X - page, 0)
			local to = math.clamp(scroller.CanvasPosition.X + step * page, 0, most)
			TweenService:Create(scroller, TweenInfo.new(0.25), {
				CanvasPosition = Vector2.new(to, 0),
			}):Play()
		end)
		return b
	end
	if #cars > PER then
		local left = arrow("<", 0, -1)
		local right = arrow(">", 0.95, 1)
		-- show an arrow only when there is more that way
		local function update()
			local most = scroller.AbsoluteCanvasSize.X - scroller.AbsoluteSize.X
			left.Visible = scroller.CanvasPosition.X > 2
			right.Visible = scroller.CanvasPosition.X < most - 2
		end
		scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(update)
		scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		task.defer(update)
	end
	text(
		body,
		if #cars > PER
			then "Win races for coins. Parked cars make coins too. Tap > for more."
			else "Win races for coins. Parked cars make coins too.",
		0,
		0.92,
		1,
		0.08,
		HINT
	)
	for i, car in cars do
		local c = Instance.new("Frame")
		c.Position = UDim2.new((i - 1) / shown, 4, 0, 4)
		c.Size = UDim2.new(1 / shown, -8, 1, -18)
		c.BackgroundColor3 = CARD
		c.Parent = scroller
		corner(c, 0.08)
		local cardRim = Instance.new("UIStroke")
		cardRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cardRim.Color = if s.equipped[kind] == car.id then GOLD else KartStyle.INK
		cardRim.Thickness = if s.equipped[kind] == car.id then 4 else KartStyle.BUTTON_RIM
		cardRim.Parent = c
		-- the car's kind: a word tag on the top edge, and (rare and up) a rim that glows in its
		-- colour, faster the rarer it is
		local tier = CarCatalog.RARITY[car.rarity] or CarCatalog.RARITY.common
		local kindColor = rgb(tier.color)
		local tag = text(c, tier.label, 0.22, 0.02, 0.56, 0.08, Color3.new(1, 1, 1))
		tag.BackgroundColor3 = pillColor(tier)
		tag.BackgroundTransparency = 0
		tag.ZIndex = 3
		corner(tag, 0.5)
		if car.rarity ~= "common" and s.equipped[kind] ~= car.id then
			local speed = if car.rarity == "legend"
				then 0.45
				elseif car.rarity == "epic" then 0.65
				else 0.9
			cardRim.Color = kindColor
			cardRim.Thickness = 4
			TweenService:Create(
				cardRim,
				TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 7, Transparency = 0.3 }
			):Play()
		end
		-- the cards drop in one after another
		local drop = Instance.new("UIScale")
		drop.Scale = 0.3
		drop.Parent = c
		task.delay(0.05 + (i - 1) * 0.06, function()
			TweenService:Create(
				drop,
				TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)
		local view = preview(c, car, rgb(Garage.SHOPS[kind].color))
		view.Position = UDim2.fromScale(0.06, 0.04)
		view.Size = UDim2.fromScale(0.88, 0.5)
		text(c, car.name, 0.06, 0.56, 0.88, 0.1, KartStyle.INK)
		-- what it makes parked on your plot (tycoon plan)
		text(c, `+{tier.perMin} coins/min`, 0.06, 0.66, 0.88, 0.08, KartStyle.GREEN)
		local price = if owned[car.id] and car.price > 0
			then "OWNED"
			elseif car.rare then "GUMBALL"
			elseif car.price == 0 then "FREE"
			else car.price .. " coins"
		text(
			c,
			price,
			0.06,
			0.745,
			0.88,
			0.085,
			if car.rare then Color3.fromRGB(230, 70, 150) else PRICE
		)

		local b: TextButton
		if s.equipped[kind] == car.id then
			b = button(
				c,
				if drivesNow(car) then "DRIVING" else "PICKED",
				Color3.fromRGB(60, 180, 80),
				false
			)
			b.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
			b.TextColor3 = Color3.new(1, 1, 1)
		elseif owned[car.id] and not drivesNow(car) then
			-- yours: the car you race with on the maps
			b = button(c, "PICK", Color3.fromRGB(40, 120, 230), true)
			b.Activated:Connect(function()
				local now = ask("equip", car.id)
				if now then
					showShop(kind, now)
				end
			end)
		elseif owned[car.id] then
			-- yours: put it on and go drive it
			b = button(c, "DRIVE", Color3.fromRGB(40, 120, 230), true)
			b.Activated:Connect(function()
				local now = ask("equip", car.id)
				if now and now.ok then
					gui.Enabled = false
					current = nil
					-- the server takes one call per 0.3 s
					task.delay(0.35, ask, "drive", car.id)
				elseif now then
					showShop(kind, now)
				end
			end)
		else
			b = button(c, needWords(car.price, s.coins), KartStyle.GREEN, s.coins >= car.price)
			if s.coins >= car.price then
				b:SetAttribute("KartPulse", true)
				local buyButton = b
				b.Activated:Connect(function()
					-- a burst of bits out of BUY, at once (the server answers after)
					local at = buyButton.AbsolutePosition + buyButton.AbsoluteSize / 2
					Party.burst(gui, UDim2.fromOffset(at.X, at.Y))
					local now = ask("buy", car.id)
					if now then
						showShop(kind, now)
						if now.ok then
							park(car.id)
							-- the server put it on already: show it off, then go drive
							reveal(car, function()
								if drivesNow(car) then
									driveNow(car)
								end
							end)
						end
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
	titleRim.Color = Color3.fromRGB(255, 120, 190)
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
		-- name | kind | odds, each in its own box (long names ran into the kind word)
		text(row, g.car.name, 0.12, 0.12, 0.38, 0.76, Color3.new(1, 1, 1), true)
		local kind = CarCatalog.RARITY[g.car.rarity] or CarCatalog.RARITY.common
		-- its kind, and what it makes parked in your garage
		text(row, kind.label, 0.52, 0.08, 0.16, 0.46, rgb(kind.color))
		text(row, `+{kind.perMin}/min`, 0.52, 0.54, 0.16, 0.38, KartStyle.GREEN)
		text(row, g.chance .. "%", 0.7, 0.12, 0.16, 0.76, GOLD)
		if owned[g.car.id] then
			text(row, "HAVE", 0.9, 0.2, 0.09, 0.6, Color3.fromRGB(90, 220, 110))
		end
	end
	-- the chance of each kind, under the list
	local odds = CarCatalog.tierOdds()
	local x = 0
	for _, r in CarCatalog.RARITY_ORDER do
		local n = odds[r]
		if n then
			local kind = CarCatalog.RARITY[r]
			text(body, `{kind.label} {n}%`, x, 0.82, 0.2, 0.07, rgb(kind.color))
			x += 0.21
		end
	end
	text(
		body,
		`A car you have already gives {CarCatalog.DUPLICATE_REFUND} coins back.`,
		0,
		0.9,
		0.62,
		0.08,
		Color3.fromRGB(180, 180, 190)
	)
	local can = s.coins >= CarCatalog.GUMBALL_PRICE
	local spin =
		button(body, `SPIN  {CarCatalog.GUMBALL_PRICE} COINS`, Color3.fromRGB(255, 120, 190), can)
	spin.Position = UDim2.fromScale(0.66, 0.62)
	spin.Size = UDim2.fromScale(0.34, 0.2)
	-- before a spin: what a spin gives, plainly (no emoji: they draw as boxes)
	local out = text(
		body,
		result or "One spin = one car from the list. The % is your chance.",
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
			local now = ask("spin")
			if now then
				local car = if now.car then CarCatalog.get(now.car) else nil
				local msg = if car == nil
					then "Not enough coins"
					elseif now.new then `NEW {CarCatalog.rarity(car.id).label}! {car.name}`
					else `{car.name}: had it, +{CarCatalog.DUPLICATE_REFUND} coins`
				showGumball(now, msg)
				if car and now.new then
					park(car.id)
					reveal(car, function()
						if drivesNow(car) then
							driveNow(car)
						end
					end)
				end
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
-- tap outside shuts it too, and it never stacks on another popup
-- (not while NEW CAR! is up: the panel hides for it, and DRIVE IT! is the way on)
Popup.add("cars", gui, function()
	gui.Enabled = false
	current = nil
end)
local function carsShown()
	Popup.shown("cars", gui.Enabled and panel.Visible)
end
gui:GetPropertyChangedSignal("Enabled"):Connect(carsShown)
panel:GetPropertyChangedSignal("Visible"):Connect(carsShown)

-- each prompt's JoinStage name (shop / gumball): a brand new player isn't asked to shop yet
local JoinStage = require(Shared:WaitForChild("JoinStage"))
local gated: { [ProximityPrompt]: string } = {}
local function gate()
	local stage = Players.LocalPlayer:GetAttribute("Stage")
	for p, name in gated do
		if p.Parent == nil then
			gated[p] = nil
		else
			p.Enabled = JoinStage.shows(stage, name)
		end
	end
end
Players.LocalPlayer:GetAttributeChangedSignal("Stage"):Connect(gate)

local function prompt(
	parent: BasePart,
	action: string,
	object: string,
	stageName: string,
	onUse: () -> ()
)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onUse)
	gated[p] = stageName
	gate()
end

-- ===== Hook up each shop as it appears =====

local seen: { [Model]: boolean } = {}

-- A small slanted dark price plate on the floor in front of each car on show in a shop: its
-- kind (in the kind's colour) and its price, so a kid can see what's what before opening the screen.
-- (Studio 10-26: tags floating over the cars were hidden by the cars, the shutter or the front
-- posts from one spot or another; a plate low in front of the car has nothing in its way.)
local plates = Instance.new("Folder")
plates.Name = "ShopPlates"
plates.Parent = workspace
local function carTag(ring: BasePart, out: Vector3, car: CarCatalog.Car)
	local tier = CarCatalog.rarity(car.id)
	-- out past the turntable's edge, so a spinning car's nose never pokes through it
	local at = ring.Position + out * 3.3 + Vector3.new(0, 0.95, 0)
	local p = Instance.new("Part")
	p.Name = car.id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	-- as big as fits: 1 stud between plates; Studio 10-26 found 3.8x1.6 too small at 20 studs
	p.Size = Vector3.new(4.6, 2, 0.15)
	p.Color = KartStyle.INK
	p.Material = Enum.Material.SmoothPlastic
	-- facing out of the shop, leaned back so it reads from standing height
	p.CFrame = CFrame.lookAt(at, at + out) * CFrame.Angles(math.rad(25), 0, 0)
	p.Parent = plates
	local b = Instance.new("SurfaceGui")
	b.Face = Enum.NormalId.Front
	b.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	b.PixelsPerStud = 60
	b.LightInfluence = 0
	b.Parent = p
	-- a rim in the kind's own colour, bright on the dark plate (Studio 10-26: dark plates read from
	-- 20 studs, white ones melted into the white plaza and the gold price was faint on them)
	local edge = Instance.new("Frame")
	-- inset by the rim's width: a border stroke draws outside its frame
	edge.Position = UDim2.fromOffset(6, 6)
	edge.Size = UDim2.new(1, -12, 1, -12)
	edge.BackgroundTransparency = 1
	edge.Parent = b
	local edgeRim = Instance.new("UIStroke")
	edgeRim.Thickness = 6
	edgeRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edgeRim.Color = rgb(tier.color)
	edgeRim.Parent = edge
	local function line(t: string, y: number, h: number, fill: Color3?, color: Color3)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(if fill then 0.08 else 0.04, y)
		l.Size = UDim2.fromScale(if fill then 0.84 else 0.92, h)
		l.BackgroundColor3 = fill or Color3.new()
		l.BackgroundTransparency = if fill then 0 else 1
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = t
		l.Parent = b
		local rim = Instance.new("UIStroke")
		rim.Thickness = KartStyle.TEXT_RIM
		rim.Color = KartStyle.INK
		rim.Parent = l
		if fill then
			corner(l, 0.5)
		end
	end
	-- common's pill a lighter slate here, so it shows on the dark plate
	local pill = if tier.id == "common" then Color3.fromRGB(150, 158, 180) else pillColor(tier)
	line(tier.label, 0.08, 0.4, pill, Color3.new(1, 1, 1))
	line(if car.price == 0 then "FREE" else `{car.price} coins`, 0.51, 0.44, nil, GOLD)
end

local function addShop(shopModel: Model)
	local kind = shopModel:GetAttribute("ShopKind")
	if seen[shopModel] or type(kind) ~= "string" or Garage.SHOPS[kind] == nil then
		return
	end
	seen[shopModel] = true
	local shown = Garage.SHOPS[kind]
	for i, at in shown.display do
		local car = shopModel:FindFirstChild("Car" .. i)
		local stand = shopModel:FindFirstChild("Stand" .. i)
		local ring = stand and stand:FindFirstChild("Ring")
		if car and car:IsA("Model") then
			local info = CarCatalog.get(shown.ids[at])
			CarGlow.applyCar(car, shown.ids[at])
			if info then
				-- the shop's floor faces like the shop: its +Z points out of the open front
				local floor = shopModel.PrimaryPart
				if ring and ring:IsA("BasePart") and floor then
					carTag(ring, floor.CFrame.ZVector, info)
				end
				-- the turntable's ring in the kind's colour (rare and up)
				if ring and ring:IsA("BasePart") and info.rarity ~= "common" then
					local c = CarCatalog.RARITY[info.rarity].color
					ring.Color = Color3.fromRGB(c[1], c[2], c[3])
				end
			end
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
		prompt(desk, "Shop", TITLES[kind] or "", "shop", function()
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
		prompt(inst, "Spin", "Gumball", "gumball", function()
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
local NEAR = 150 -- farther than this the turn can't be seen: those cars wait (phone speed)
RunService.RenderStepped:Connect(function(dt)
	angle += dt * SPIN
	local turn = CFrame.Angles(0, angle, 0)
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if s.car.Parent == nil then
			table.remove(spinners, i)
		elseif (s.center - eye).Magnitude < NEAR then
			s.car:PivotTo(CFrame.new(s.center) * turn * s.offset)
		end
	end
end)
