--!strict
-- Car VS Car: MY GARAGE (carter 10-26, rc-game/cvc-plan.md), in the Kart Party look. Only with
-- Features.CVC on.
--   * STATIONS: each station on your plot (TREADMILL / RAMP / SPEED TRACK), its level, the car on
--     it with its bars, MAKE IT BETTER (coins) and CHANGE CAR; MORE STATIONS (the plot level)
--   * MY CARS: every car you own with its bars; RACE WITH IT, and (when changing a station's car)
--     TRAIN HERE
-- The server (TrainingServer, RemoteEvent Garage) decides; this shows CvcState and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Training = require(Shared:WaitForChild("Training"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Popup = require(script.Parent:WaitForChild("Popup"))

local player = Players.LocalPlayer
local INK, WHITE = KartStyle.INK, KartStyle.WHITE
local label, button = CvcUi.label, CvcUi.button
local GREY = Color3.fromRGB(110, 110, 120)

-- the coins a station level and a plot level cost: shared numbers once the lead / Economy move
-- them out of TrainingServer; until then a copy of its stand-ins (keep in step)
-- what each station trains most, for its card
local MAIN_WORD = { treadmill = "SPEED", ramp = "BOOST", track = "TURNING" }

local function coins(): number
	local c = player:GetAttribute("Coins")
	return if type(c) == "number" then c else 0
end

local pop = Instance.new("ScreenGui")
pop.Name = "CvcGarage"
pop.ResetOnSpawn = false
pop.IgnoreGuiInset = true
pop.DisplayOrder = HudLayout.POPUP
pop.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.54)
panel.Size = UDim2.fromScale(0.82, 0.78)
panel.BackgroundColor3 = KartStyle.BLUE
panel.Visible = false
panel.Parent = pop
CvcUi.corner(panel, 0.05)
CvcUi.rim(panel, KartStyle.PANEL_RIM)
local panelMax = Instance.new("UISizeConstraint")
panelMax.MaxSize = Vector2.new(960, 540)
panelMax.Parent = panel
local ribbon = CvcUi.ribbon(panel, "MY GARAGE")

local close = button(panel, "X", KartStyle.RED)
close.Name = "Close"
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.fromScale(1, 0)
close.Size = UDim2.fromScale(0.11, 0.11)
close.SizeConstraint = Enum.SizeConstraint.RelativeYY
close.ZIndex = 3
CvcUi.corner(close, 0.5)

-- two tabs under the ribbon
local tabStations = button(panel, "STATIONS", KartStyle.YELLOW)
tabStations.Position = UDim2.fromScale(0.04, 0.09)
tabStations.Size = UDim2.fromScale(0.25, 0.09)
local tabCars = button(panel, "MY CARS", KartStyle.SKY)
tabCars.Position = UDim2.fromScale(0.31, 0.09)
tabCars.Size = UDim2.fromScale(0.25, 0.09)
local note = label(panel, "", WHITE)
note.Position = UDim2.fromScale(0.58, 0.09)
note.Size = UDim2.fromScale(0.38, 0.09)
note.TextXAlignment = Enum.TextXAlignment.Right

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.fromScale(0.03, 0.21)
body.Size = UDim2.fromScale(0.94, 0.62)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 6
body.Parent = panel

local more = button(panel, "MORE STATIONS", KartStyle.GREEN)
more.Name = "More"
more.AnchorPoint = Vector2.new(0.5, 1)
more.Position = UDim2.fromScale(0.5, 0.97)
more.Size = UDim2.fromScale(0.5, 0.11)

local view = "stations" -- or "cars"
local forStation: number? = nil -- picking a car for this station (in the cars view)

local render: () -> ()

local function clear()
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- one station: a card across, side by side with the others (scroll for more)
local CARD_W = 210
local function stationCard(i: number, st: CvcState.Station)
	local card = Instance.new("Frame")
	card.Name = "Station" .. i
	card.Position = UDim2.new(0, (i - 1) * (CARD_W + 12), 0, 0)
	card.Size = UDim2.new(0, CARD_W, 1, -8)
	card.BackgroundColor3 = Color3.fromRGB(244, 247, 255)
	card.Parent = body
	CvcUi.corner(card, 0.06)
	CvcUi.rim(card, KartStyle.BUTTON_RIM)
	local kind = label(card, Training.NAMES[st.kind] or string.upper(st.kind), INK)
	kind.Position = UDim2.fromScale(0.05, 0.02)
	kind.Size = UDim2.fromScale(0.9, 0.1)
	local lv = label(
		card,
		`LEVEL {st.level}  -  MOST {MAIN_WORD[st.kind] or ""}`,
		Color3.fromRGB(70, 80, 110)
	)
	lv.Position = UDim2.fromScale(0.05, 0.12)
	lv.Size = UDim2.fromScale(0.9, 0.07)
	local car = st.uid ~= "" and CvcState.find(st.uid) or nil
	if car then
		local pic = CvcUi.carPic(card, car.id)
		pic.Position = UDim2.fromScale(0.2, 0.2)
		pic.Size = UDim2.fromScale(0.6, 0.27)
		local name = label(card, CvcState.name(car.id), INK)
		name.Position = UDim2.fromScale(0.05, 0.47)
		name.Size = UDim2.fromScale(0.9, 0.07)
		local bars = CvcUi.bars(card)
		bars.frame.Position = UDim2.fromScale(0.06, 0.55)
		bars.frame.Size = UDim2.fromScale(0.88, 0.2)
		bars.set(car)
		if Training.full(car, CvcState.stats(car.id)) then
			name.Text = `{CvcState.name(car.id)}  MAX!`
		end
	else
		local empty = label(card, "EMPTY\nPUT A CAR HERE!", Color3.fromRGB(110, 120, 150))
		empty.Position = UDim2.fromScale(0.05, 0.25)
		empty.Size = UDim2.fromScale(0.9, 0.4)
	end
	local change = button(card, if car then "CHANGE CAR" else "PUT A CAR", KartStyle.SKY)
	change.Position = UDim2.fromScale(0.06, 0.77)
	change.Size = UDim2.fromScale(0.42, 0.1)
	change.Activated:Connect(function()
		view, forStation = "cars", i
		render()
	end)
	local cost = Training.upgradeCost(st.level)
	local up = button(card, "", KartStyle.GREEN)
	up.Position = UDim2.fromScale(0.52, 0.77)
	up.Size = UDim2.fromScale(0.42, 0.1)
	if st.level >= Training.MAX_STATION_LEVEL or not cost then
		up.Text = "TOP LEVEL!"
		up.BackgroundColor3 = KartStyle.YELLOW
		up.TextColor3 = INK
		up.AutoButtonColor = false
	else
		local short = cost - coins()
		up.Text = if short > 0 then `{short} MORE` else `BETTER {cost}`
		up.BackgroundColor3 = if short > 0 then GREY else KartStyle.GREEN
		up.Activated:Connect(function()
			if coins() >= cost then
				CvcState.ask("upgrade", i)
			end
		end)
	end
	local faster = label(card, "MAKE IT TRAIN FASTER", Color3.fromRGB(70, 80, 110))
	faster.Position = UDim2.fromScale(0.05, 0.89)
	faster.Size = UDim2.fromScale(0.9, 0.07)
	faster.Visible = up.Text ~= "TOP LEVEL!"
end

-- one car you own: a row
local ROW = 74
local function carRow(n: number, car: CvcState.Car)
	local r = Instance.new("Frame")
	r.Name = car.uid
	r.Position = UDim2.new(0, 0, 0, (n - 1) * ROW)
	r.Size = UDim2.new(1, -10, 0, ROW - 6)
	r.BackgroundColor3 = Color3.fromRGB(244, 247, 255)
	r.Parent = body
	CvcUi.corner(r, 0.2)
	local rarity = CarCatalog.rarity(car.id)
	local edge = CvcUi.rim(r, if rarity.id == "common" then 2 else 3)
	if rarity.id ~= "common" then
		edge.Color = CvcUi.rarityColor(car.id)
	end
	local pic = CvcUi.carPic(r, car.id)
	pic.AnchorPoint = Vector2.new(0, 0.5)
	pic.Position = UDim2.new(0, 6, 0.5, 0)
	pic.Size = UDim2.fromOffset(ROW - 16, ROW - 16)
	local name = label(r, CvcState.name(car.id), INK)
	name.Position = UDim2.new(0, ROW, 0.08, 0)
	name.Size = UDim2.new(0.26, -ROW, 0.46, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local on = CvcState.stationOf(car.uid)
	local st = on and CvcState.stations[on]
	local where = if car.uid == CvcState.racer
		then "RACING CAR"
		elseif st then `ON THE {Training.NAMES[st.kind] or ""}`
		else rarity.label
	local tag = label(r, where, CvcUi.rarityColor(car.id):Lerp(INK, 0.5))
	tag.Position = UDim2.new(0, ROW, 0.56, 0)
	tag.Size = UDim2.new(0.26, -ROW, 0.34, 0)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	local bars = CvcUi.bars(r)
	bars.frame.Position = UDim2.fromScale(0.27, 0.08)
	bars.frame.Size = UDim2.fromScale(0.38, 0.84)
	bars.set(car)
	-- the buttons on the right
	if forStation then
		local i = forStation
		local here = on == i
		local b = button(
			r,
			if here then "TAKE OFF" else "TRAIN HERE",
			if here then KartStyle.RED else KartStyle.GREEN
		)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -8, 0.5, 0)
		b.Size = UDim2.new(0.3, 0, 0.66, 0)
		b.Activated:Connect(function()
			CvcState.ask("station", i, if here then "" else car.uid)
			view, forStation = "stations", nil
			render()
		end)
	else
		local isRacer = car.uid == CvcState.racer
		local b = button(
			r,
			if isRacer then "RACING!" else "RACE WITH IT",
			if isRacer then KartStyle.YELLOW else KartStyle.RED
		)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -8, 0.5, 0)
		b.Size = UDim2.new(0.3, 0, 0.66, 0)
		if isRacer then
			b.TextColor3 = INK
			b.AutoButtonColor = false
		else
			b.Activated:Connect(function()
				CvcState.ask("racer", car.uid)
			end)
		end
	end
end

render = function()
	if not panel.Visible then
		return
	end
	clear()
	tabStations.BackgroundColor3 = if view == "stations" then KartStyle.YELLOW else KartStyle.SKY
	tabStations.TextColor3 = if view == "stations" then INK else WHITE
	tabCars.BackgroundColor3 = if view == "cars" then KartStyle.YELLOW else KartStyle.SKY
	tabCars.TextColor3 = if view == "cars" then INK else WHITE
	if view == "stations" then
		ribbon.Text = "MY GARAGE"
		note.Text = "CARS TRAIN WHILE YOU PLAY"
		for i, st in CvcState.stations do
			stationCard(i, st)
		end
		body.ScrollingDirection = Enum.ScrollingDirection.X
		body.CanvasSize = UDim2.fromOffset(#CvcState.stations * (CARD_W + 12), 0)
		local cost = Training.plotCost(CvcState.plotLevel)
		more.Visible = cost ~= nil and CvcState.plotLevel < Training.MAX_PLOT_LEVEL
		if cost then
			local short = cost - coins()
			more.Text = if short > 0 then `MORE STATIONS: {short} MORE` else `MORE STATIONS  {cost}`
			more.BackgroundColor3 = if short > 0 then GREY else KartStyle.GREEN
		end
	else
		local st = forStation and CvcState.stations[forStation]
		ribbon.Text = if st then `PICK A CAR FOR THE {Training.NAMES[st.kind] or ""}` else "MY CARS"
		note.Text = `{#CvcState.garage} CARS`
		for n, car in CvcState.garage do
			carRow(n, car)
		end
		body.ScrollingDirection = Enum.ScrollingDirection.Y
		body.CanvasSize = UDim2.fromOffset(0, #CvcState.garage * ROW)
		more.Visible = false
	end
end

more.Activated:Connect(function()
	local cost = Training.plotCost(CvcState.plotLevel)
	if cost and coins() >= cost then
		CvcState.ask("level")
	end
end)
tabStations.Activated:Connect(function()
	view, forStation = "stations", nil
	render()
end)
tabCars.Activated:Connect(function()
	view, forStation = "cars", nil
	render()
end)

local function setOpen(on: boolean)
	panel.Visible = on
	if on then
		view, forStation = "stations", nil
	end
	render()
end
close.Activated:Connect(function()
	setOpen(false)
end)
Popup.add("cvcGarage", pop, function()
	setOpen(false)
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	Popup.shown("cvcGarage", panel.Visible)
end)
-- training moves the bars every couple of seconds: redraw then (not on every tick of a closed panel)
CvcState.changed:Connect(render)
player:GetAttributeChangedSignal("Coins"):Connect(render)

-- the MY GARAGE button, under the league badge
local open = button(Instance.new("ScreenGui"), "MY GARAGE", KartStyle.RED)
local hud = open.Parent :: ScreenGui
hud.Name = "CvcGarageButton"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")
open.Name = "GarageButton"
HudLayout.place(open, "Garage")
open.Visible = false
open.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
local function showOpen()
	open.Visible = CvcState.loaded
		and player:GetAttribute("Picked") == true
		and player:GetAttribute("Driving") ~= true
end
player:GetAttributeChangedSignal("Picked"):Connect(showOpen)
player:GetAttributeChangedSignal("Driving"):Connect(showOpen)
CvcState.changed:Connect(showOpen)
showOpen()
