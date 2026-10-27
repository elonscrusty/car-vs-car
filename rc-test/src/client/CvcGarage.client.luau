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
local CvcLayout = require(Shared:WaitForChild("CvcLayout"))
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
CvcLayout.place(panel, "garage", "Panel")
panel.BackgroundColor3 = KartStyle.BLUE
panel.Visible = false
panel.Parent = pop
CvcUi.corner(panel, 0.05)
CvcUi.rim(panel, KartStyle.PANEL_RIM)
local ribbon = CvcUi.ribbon(panel, "MY GARAGE")

local close = button(panel, "X", KartStyle.RED)
close.Name = "Close"
CvcLayout.place(close, "garage", "Close")
close.ZIndex = 3
CvcUi.corner(close, 0.5)

-- two tabs under the ribbon
local tabStations = button(panel, "STATIONS", KartStyle.YELLOW)
CvcLayout.place(tabStations, "garage", "TabStations")
local tabCars = button(panel, "MY CARS", KartStyle.SKY)
CvcLayout.place(tabCars, "garage", "TabCars")
local note = label(panel, "", WHITE)
CvcLayout.place(note, "garage", "Note")
note.TextXAlignment = Enum.TextXAlignment.Right

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
CvcLayout.place(body, "garage", "Body")
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 6
body.Parent = panel

local more = button(panel, "MORE STATIONS", KartStyle.GREEN)
more.Name = "More"
CvcLayout.place(more, "garage", "More")

local view = "stations" -- or "cars"
local forStation: number? = nil -- picking a car for this station (in the cars view)

local render: () -> ()
-- what each card and row does to show the coins and bars now, without being built again
-- (the panel was rebuilt on every coin and every training tick: a BETTER tap between a
-- rebuild's old button and its new one was lost, Studio final-14)
local updates: { () -> () } = {}

local function clear()
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(updates)
end

-- dark words on a yellow button: no light outline round them (it smeared, Studio final-14)
local function inkText(b: TextButton, on: boolean)
	b.TextColor3 = if on then INK else WHITE
	b.TextStrokeTransparency = if on then 1 else 0.2
end

-- one station: a card across, side by side with the others (scroll for more)
local CARD_W = 210
local function stationCard(i: number, st: CvcState.Station)
	local card = Instance.new("Frame")
	card.Name = "Station" .. i
	CvcLayout.place(card, "garage", "Card")
	card.Position += UDim2.fromOffset((i - 1) * (CARD_W + 12), 0)
	card.BackgroundColor3 = Color3.fromRGB(244, 247, 255)
	card.Parent = body
	CvcUi.corner(card, 0.06)
	CvcUi.rim(card, KartStyle.BUTTON_RIM)
	-- the top part: what it is, its level, the car on it and its bars (the buttons go under)
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	CvcLayout.place(top, "garage", "CardTop")
	top.Parent = card
	local kind = label(top, Training.NAMES[st.kind] or string.upper(st.kind), INK)
	kind.Position = UDim2.fromScale(0.05, 0.03)
	kind.Size = UDim2.fromScale(0.9, 0.14)
	local lv = label(top, "", Color3.fromRGB(70, 80, 110))
	lv.Position = UDim2.fromScale(0.05, 0.17)
	lv.Size = UDim2.fromScale(0.9, 0.09)
	local car = st.uid ~= "" and CvcState.find(st.uid) or nil
	local name: TextLabel? = nil
	local bars: CvcUi.Bars? = nil
	if car then
		local pic = CvcUi.carPic(top, car.id)
		pic.Position = UDim2.fromScale(0.22, 0.28)
		pic.Size = UDim2.fromScale(0.56, 0.3)
		name = label(top, CvcState.name(car.id), INK)
		local n = name :: TextLabel
		n.Position = UDim2.fromScale(0.05, 0.59)
		n.Size = UDim2.fromScale(0.9, 0.1)
		bars = CvcUi.bars(top)
		local b = bars :: CvcUi.Bars
		b.frame.Position = UDim2.fromScale(0.06, 0.7)
		b.frame.Size = UDim2.fromScale(0.88, 0.29)
	else
		local empty = label(top, "EMPTY\nPUT A CAR HERE!", Color3.fromRGB(110, 120, 150))
		empty.Position = UDim2.fromScale(0.05, 0.32)
		empty.Size = UDim2.fromScale(0.9, 0.5)
	end
	local change = button(card, if car then "CHANGE CAR" else "PUT A CAR", KartStyle.SKY)
	CvcLayout.place(change, "garage", "Change")
	change.Activated:Connect(function()
		view, forStation = "cars", i
		render()
	end)
	local up = button(card, "", KartStyle.GREEN)
	CvcLayout.place(up, "garage", "Up")
	-- (the tap reads the station as it is now: its level may have gone up since this was built)
	up.Activated:Connect(function()
		local now = CvcState.stations[i]
		local cost = now and Training.upgradeCost(now.level)
		if now and cost and now.level < Training.MAX_STATION_LEVEL and coins() >= cost then
			CvcState.ask("upgrade", i)
		end
	end)
	local function update()
		local now = CvcState.stations[i] or st
		lv.Text = `LEVEL {now.level}  -  MOST {MAIN_WORD[now.kind] or ""}`
		local c = car and CvcState.find(car.uid)
		if c and name and bars then
			bars.set(c)
			name.Text = if Training.full(c, CvcState.stats(c.id))
				then `{CvcState.name(c.id)}  MAX!`
				else CvcState.name(c.id)
		end
		local cost = Training.upgradeCost(now.level)
		if now.level >= Training.MAX_STATION_LEVEL or not cost then
			up.Text = "TOP LEVEL!"
			up.BackgroundColor3 = KartStyle.YELLOW
			inkText(up, true)
			up.AutoButtonColor = false
		else
			local short = cost - coins()
			-- what it does and what it costs (grey: not enough coins yet); "81 MORE" said neither,
			-- Studio polish-5
			up.Text = `BETTER!\n{cost} COINS`
			up.BackgroundColor3 = if short > 0 then GREY else KartStyle.GREEN
			inkText(up, false)
			up.AutoButtonColor = true
		end
	end
	update()
	table.insert(updates, update)
end

-- one car you own: a row
local ROW = 74
local function carRow(n: number, car: CvcState.Car)
	local r = Instance.new("Frame")
	r.Name = car.uid
	CvcLayout.place(r, "garage", "Row")
	r.Position += UDim2.fromOffset(0, (n - 1) * ROW)
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
	table.insert(updates, function()
		local c = CvcState.find(car.uid)
		if c then
			bars.set(c)
		end
	end)
	-- the buttons on the right
	if forStation then
		local i = forStation
		local here = on == i
		local b = button(
			r,
			if here then "TAKE OFF" else "TRAIN HERE",
			if here then KartStyle.RED else KartStyle.GREEN
		)
		CvcLayout.place(b, "garage", "RowButton")
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
		CvcLayout.place(b, "garage", "RowButton")
		if isRacer then
			inkText(b, true)
			b.AutoButtonColor = false
		else
			b.Activated:Connect(function()
				CvcState.ask("racer", car.uid)
			end)
		end
	end
end

-- what the panel is built from: when only coins and bars move, it updates in place
local function shape(): string
	local bits = { view, tostring(forStation), CvcState.racer or "" }
	for _, st in CvcState.stations do
		table.insert(bits, `{st.kind}:{st.uid}`)
	end
	if view == "cars" then
		for _, car in CvcState.garage do
			table.insert(bits, car.uid)
		end
	end
	return table.concat(bits, "|")
end
local built: string? = nil

render = function()
	if not panel.Visible then
		built = nil
		return
	end
	tabStations.BackgroundColor3 = if view == "stations" then KartStyle.YELLOW else KartStyle.SKY
	inkText(tabStations, view == "stations")
	tabCars.BackgroundColor3 = if view == "cars" then KartStyle.YELLOW else KartStyle.SKY
	inkText(tabCars, view == "cars")
	local now = shape()
	if now == built then
		for _, update in updates do
			update()
		end
	else
		built = now
		clear()
		if view == "stations" then
			for i, st in CvcState.stations do
				stationCard(i, st)
			end
		else
			for n, car in CvcState.garage do
				carRow(n, car)
			end
		end
	end
	if view == "stations" then
		ribbon.Text = "MY GARAGE"
		note.Text = "CARS TRAIN WHILE YOU PLAY"
		body.ScrollingDirection = Enum.ScrollingDirection.X
		body.CanvasSize = UDim2.fromOffset(#CvcState.stations * (CARD_W + 12), 0)
		local cost = Training.plotCost(CvcState.plotLevel)
		more.Visible = cost ~= nil and CvcState.plotLevel < Training.MAX_PLOT_LEVEL
		if cost then
			local short = cost - coins()
			more.Text = if short > 0
				then `NEW STATION: {cost} COINS ({short} TO GO)`
				else `NEW STATION: {cost} COINS`
			more.BackgroundColor3 = if short > 0 then GREY else KartStyle.GREEN
		end
	else
		local st = forStation and CvcState.stations[forStation]
		ribbon.Text = if st then `PICK A CAR FOR THE {Training.NAMES[st.kind] or ""}` else "MY CARS"
		note.Text = `{#CvcState.garage} CARS`
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
