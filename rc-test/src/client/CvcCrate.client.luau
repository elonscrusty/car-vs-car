--!strict
-- Car VS Car crates (carter 10-26, rc-game/cvc-plan.md), in the Kart Party look. Only with
-- Features.CVC on. A CRATE button under the coins while you have one to open; it shows the crate
-- and its odds (always before you open it), then OPEN!: the crate shakes, pops, and your new car
-- comes out with rays, confetti and its rarity. The server rolls the car (TrainingServer
-- ("open") -> ("crate", carId, rarity)); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
-- (Features.NEW_UI: the new screens do this instead, CvcScreens.client)
if not Features.CVC or Features.NEW_UI then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Crates = require(Shared:WaitForChild("Crates"))
local CvcLayout = require(Shared:WaitForChild("CvcLayout"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Party = require(script.Parent:WaitForChild("Party"))
local Popup = require(script.Parent:WaitForChild("Popup"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local INK, WHITE = KartStyle.INK, KartStyle.WHITE
local label, button = CvcUi.label, CvcUi.button
local WOOD = Color3.fromRGB(196, 128, 64)

-- the crate on the screen: "free" (from your first race: OPEN!) or a shop crate (BUY, coins).
-- The crate shop (the spawn lobby thread's CRATES building) fires CvcCrateShop(kind) to show one.
local KIND = "free"
-- each crate's colour (the free one and CRATE are wood)
local BOX_COLORS = {
	big = Color3.fromRGB(61, 155, 255),
	mega = Color3.fromRGB(170, 80, 255),
}
local GREY = Color3.fromRGB(110, 110, 120)

local function coins(): number
	local c = player:GetAttribute("Coins")
	return if type(c) == "number" then c else 0
end

CvcState.start()

local pop = Instance.new("ScreenGui")
pop.Name = "CvcCrate"
pop.ResetOnSpawn = false
pop.IgnoreGuiInset = true
pop.DisplayOrder = HudLayout.POPUP
pop.Parent = player:WaitForChild("PlayerGui")
local top, fall = CvcUi.topGui("CvcCrateTop", HudLayout.POPUP + 1, player:WaitForChild("PlayerGui"))

local panel = Instance.new("Frame")
panel.Name = "Panel"
CvcLayout.place(panel, "crate", "Panel")
panel.BackgroundColor3 = KartStyle.BLUE
panel.Visible = false
panel.Parent = pop
CvcUi.corner(panel, 0.05)
CvcUi.rim(panel, KartStyle.PANEL_RIM)
local ribbon = CvcUi.ribbon(panel, "CRATE")
local revealId = 0 -- the last car out (its ribbon comes back once its big name is gone)

local close = button(panel, "X", KartStyle.RED)
close.Name = "Close"
CvcLayout.place(close, "crate", "Close")
close.ZIndex = 3
CvcUi.corner(close, 0.5)

-- the crate: a wooden box with a yellow band and a big "?"
local box = Instance.new("Frame")
box.Name = "Crate"
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.27, 0.42)
box.Size = UDim2.fromScale(0.3, 0.3)
box.SizeConstraint = Enum.SizeConstraint.RelativeXX
box.BackgroundColor3 = WOOD
box.ZIndex = 2
box.Parent = panel
CvcUi.corner(box, 0.12)
CvcUi.rim(box, KartStyle.PANEL_RIM)
local band = Instance.new("Frame")
band.Name = "Band"
band.AnchorPoint = Vector2.new(0.5, 0)
band.Position = UDim2.fromScale(0.5, 0)
band.Size = UDim2.fromScale(0.22, 1)
band.BackgroundColor3 = KartStyle.YELLOW
band.BorderSizePixel = 0
band.ZIndex = 2
band.Parent = box
local mark = label(box, "?", WHITE)
mark.Size = UDim2.fromScale(1, 1)
mark.ZIndex = 3
local markRim = Instance.new("UIStroke")
markRim.Color = INK
markRim.Thickness = 3
markRim.Parent = mark
local boxScale = Instance.new("UIScale")
boxScale.Parent = box

-- the odds, one row per kind of car: always shown before you open
local oddsBox = Instance.new("Frame")
oddsBox.Name = "Odds"
CvcLayout.place(oddsBox, "crate", "Odds")
oddsBox.BackgroundTransparency = 1
oddsBox.Parent = panel
local oddsTitle = label(oddsBox, "WHAT'S INSIDE", WHITE)
oddsTitle.Size = UDim2.fromScale(1, 0.16)
local function buildOdds()
	for _, c in oddsBox:GetChildren() do
		if c.Name == "Row" then
			c:Destroy()
		end
	end
	local odds = Crates.odds(KIND)
	local rows = 0
	for _, r in CarCatalog.RARITY_ORDER do
		local pct = odds[r] or 0
		local info = CarCatalog.RARITY[r]
		-- (a kind that can't come out is left off: LEGEND 0% read oddly on the free crate,
		-- Studio final-27)
		if info and pct > 0 then
			local y = 0.2 + rows * 0.2
			rows += 1
			local c = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
			local chip = label(oddsBox, info.label, INK)
			chip.Name = "Row"
			chip.Position = UDim2.fromScale(0, y)
			chip.Size = UDim2.fromScale(0.62, 0.17)
			chip.BackgroundColor3 = c
			chip.BackgroundTransparency = 0
			CvcUi.corner(chip, 0.3)
			CvcUi.rim(chip, KartStyle.BUTTON_RIM)
			local chipPad = Instance.new("UIPadding")
			chipPad.PaddingTop = UDim.new(0.16, 0)
			chipPad.PaddingBottom = UDim.new(0.12, 0)
			chipPad.Parent = chip
			local num = label(oddsBox, `{pct}%`, WHITE)
			num.Position = UDim2.fromScale(0.66, y)
			num.Size = UDim2.fromScale(0.34, 0.17)
			num.TextXAlignment = Enum.TextXAlignment.Right
			num.Name = "Row"
		end
	end
end

local openBtn = button(panel, "OPEN!", KartStyle.GREEN)
openBtn.Name = "Open"
CvcLayout.place(openBtn, "crate", "Open")
openBtn:SetAttribute("KartPulse", true)
local left = label(panel, "", WHITE)
left.AnchorPoint = Vector2.new(0.5, 1)
left.Position = UDim2.fromScale(0.5, 0.8)
left.Size = UDim2.fromScale(0.7, 0.08)
-- (under the crate and its odds: the lower half was an empty blue area, Studio polish-12)
local NEW_CAR_WORDS = "A NEW CAR FOR YOUR GARAGE!"

-- the new car comes out here (over the crate's place)
local reveal = Instance.new("Frame")
reveal.Name = "Reveal"
CvcLayout.place(reveal, "crate", "Reveal")
reveal.BackgroundTransparency = 1
reveal.ZIndex = 2
reveal.Visible = false
reveal.Parent = panel

local opening = false
local shake: RBXScriptConnection? = nil
local shakeAt = 0 -- when the shaking started (os.clock)
local got = false -- the server's car is in (it comes out once the build-up is done)
-- the shake builds up for this long before the crate pops, however fast the server is
local BUILD = 1.2

local function showChoose()
	-- the crate and its odds, before opening
	reveal.Visible = false
	for _, c in reveal:GetChildren() do
		c:Destroy()
	end
	for _, c in panel:GetChildren() do
		if c.Name == "Kart_Rays" then
			c:Destroy()
		end
	end
	box.Visible = true
	box.Rotation = 0
	boxScale.Scale = 1
	oddsBox.Visible = true
	local kind = Crates.get(KIND)
	revealId += 1 -- (a name still up from the last crate: the ribbon is back now)
	ribbon.Visible = true
	-- its name and price ("CRATE" alone said neither, Studio polish-5)
	local cost = Crates.price(KIND)
	ribbon.Text = if kind and cost
		then `{kind.label}  {cost} COINS`
		elseif kind then kind.label
		else "CRATE"
	box.BackgroundColor3 = BOX_COLORS[KIND] or WOOD
	local price = Crates.price(KIND)
	if price then
		local short = price - coins()
		openBtn.Text = if short > 0 then `NEED {short} MORE COINS` else `BUY & OPEN!`
		openBtn.BackgroundColor3 = if short > 0 then GREY else KartStyle.GREEN
		openBtn:SetAttribute("KartPulse", if short > 0 then nil else true)
		left.Text = if short > 0 then "WIN RACES AND TRAIN FOR COINS" else NEW_CAR_WORDS
	else
		openBtn.Text = "OPEN!"
		openBtn.BackgroundColor3 = KartStyle.GREEN
		openBtn:SetAttribute("KartPulse", true)
		left.Text = if CvcState.crates > 1
			then `{CvcState.crates} CRATES TO OPEN`
			else NEW_CAR_WORDS
	end
end

-- which crate the screen shows (and its odds)
local function setKind(k: string)
	if k ~= KIND then
		KIND = k
		buildOdds()
	end
end
buildOdds()

local function setOpen(on: boolean)
	if not on and opening then
		return -- (wait for the car)
	end
	panel.Visible = on
	if on then
		showChoose()
	end
end

local function stopShake()
	if shake then
		shake:Disconnect()
		shake = nil
	end
	box.Rotation = 0
	boxScale.Scale = 1
end

openBtn.Activated:Connect(function()
	if opening then
		return
	end
	local price = Crates.price(KIND)
	if reveal.Visible then
		-- the car is out: another crate, or done
		if price or CvcState.crates > 0 then
			showChoose()
		else
			setOpen(false)
		end
		return
	end
	if price then
		if coins() < price then
			return -- (grey: not enough coins yet)
		end
		opening = true
		Sfx.buy()
		CvcState.ask("buy", KIND)
	elseif CvcState.crates <= 0 then
		setOpen(false)
		return
	else
		opening = true
		CvcState.ask("open")
	end
	openBtn.Text = "..."
	got = false
	shakeAt = os.clock()
	-- (bigger crates rattle more)
	Sfx.shake(if KIND == "mega" then 3 elseif KIND == "big" then 2 else 1)
	-- the shake builds up: wider, faster, and the crate swells
	shake = RunService.RenderStepped:Connect(function()
		local t = os.clock() - shakeAt
		local f = math.min(t / BUILD, 1)
		box.Rotation = math.sin(t * (18 + 30 * f)) * (4 + 10 * f)
		boxScale.Scale = 1 + 0.15 * f
	end)
	task.delay(6, function()
		-- the server said no (or is slow): back to the crate
		if opening and not got then
			opening = false
			stopShake()
			showChoose()
		end
	end)
end)

local function comeOut(id: string, rarity: string)
	opening = false
	stopShake()
	panel.Visible = true
	box.Visible = false
	oddsBox.Visible = false
	left.Text = ""
	reveal.Visible = true
	for _, c in reveal:GetChildren() do
		c:Destroy()
	end
	local info = CarCatalog.RARITY[rarity] or CarCatalog.RARITY.common
	local color = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
	local card = CvcUi.card(reveal, CvcState.fresh(id))
	card.frame.Size = UDim2.fromScale(1, 1)
	card.frame.ZIndex = 2
	-- (this screen sorts by ZIndex across the whole gui: the card's insides go above its white face,
	-- or the picture, name and bars draw under it and the card shows blank)
	for _, d in card.frame:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += card.frame.ZIndex
		end
	end
	local n = table.find(CarCatalog.RARITY_ORDER, info.id) or 1
	local legend = info.id == "legend"
	Party.rays(reveal, color)
	if legend then
		-- LEGEND: a second ring of rays, a flash and a huge pop
		Party.rays(reveal, KartStyle.WHITE)
		local f = Instance.new("Frame")
		f.Name = "Kart_Flash"
		f:SetAttribute("NoKart", true)
		f.Active = false
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0.2
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = fall
		TweenService:Create(f, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function()
			f:Destroy()
		end)
	end
	-- the crate bursts where it stood
	-- (screen offsets: AbsolutePosition starts under Roblox's top bar, Kart_Fall at the top left)
	local at = box.AbsolutePosition - fall.AbsolutePosition + box.AbsoluteSize / 2
	Party.burst(top, UDim2.fromOffset(at.X, at.Y), 12 + n * 6)
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = reveal
	TweenService:Create(s, TweenInfo.new(if legend then 0.7 else 0.45, Enum.EasingStyle.Back), {
		Scale = 1,
	}):Play()
	-- the car's big name first, where the ribbon is (it sat on NEW COMMON CAR!, Studio final-16b),
	-- then the ribbon comes back with it
	revealId += 1
	local mine = revealId
	ribbon.Visible = false
	task.delay(if legend then 3 else 1.8, function()
		if mine == revealId then
			ribbon.Text = `NEW {info.label} CAR!`
			ribbon.Visible = true
		end
	end)
	openBtn.Text = if Crates.price(KIND)
		then "BUY ANOTHER!"
		elseif CvcState.crates > 0 then "OPEN ANOTHER!"
		else "YAY!"
	openBtn.BackgroundColor3 = KartStyle.GREEN
	Sfx.crate(n)
	CvcUi.bigWords(top, if legend then "LEGEND!!" else `{CvcState.name(id)}!`, color, 0.12)
	if legend then
		task.delay(1.2, function()
			CvcUi.bigWords(top, `{CvcState.name(id)}!`, color, 0.12)
		end)
	end
	Party.confetti(fall, if legend then 160 else 30 + n * 20)
end

-- the server's car: out it comes once the shake has built up
local function gotCar(id: string, rarity: string)
	got = true
	local wait = if opening then math.max(0, BUILD - (os.clock() - shakeAt)) else 0
	task.delay(wait, function()
		comeOut(id, rarity)
	end)
end

CvcState.event:Connect(function(what: unknown, id: unknown, rarity: unknown)
	if what == "crate" and type(id) == "string" then
		gotCar(id, if type(rarity) == "string" then rarity else "common")
	end
end)

close.Activated:Connect(function()
	setOpen(false)
end)
Popup.add("cvcCrate", pop, function()
	setOpen(false)
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	Popup.shown("cvcCrate", panel.Visible)
end)

-- the CRATE button, under the coins, while there's one to open
local hud = Instance.new("ScreenGui")
hud.Name = "CvcCrateButton"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")
local openCrates = button(hud, "CRATE!", WOOD)
openCrates.Name = "CrateButton"
HudLayout.place(openCrates, "Crate")
openCrates.Visible = false
openCrates:SetAttribute("KartPulse", true)
CvcUi.rim(openCrates, KartStyle.BUTTON_RIM)
openCrates.Activated:Connect(function()
	if not opening then
		setKind("free")
	end
	setOpen(not panel.Visible)
end)

-- the crate shop: its prompts fire CvcCrateShop(kind) (whichever side starts first makes it)
local shopEvent = ReplicatedStorage:FindFirstChild("CvcCrateShop")
if not shopEvent then
	shopEvent = Instance.new("BindableEvent")
	shopEvent.Name = "CvcCrateShop"
	shopEvent.Parent = ReplicatedStorage
end
if shopEvent and shopEvent:IsA("BindableEvent") then
	shopEvent.Event:Connect(function(k: unknown)
		if opening or not (type(k) == "string" and Crates.get(k)) then
			return
		end
		setKind(k)
		setOpen(true)
	end)
end
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if panel.Visible and not opening and not reveal.Visible then
		showChoose()
	end
end)
local had = 0
local function showButton()
	local n = CvcState.crates
	openCrates.Visible = CvcState.loaded and n > 0 and player:GetAttribute("Driving") ~= true
	openCrates.Text = if n > 1 then `CRATES {n}` else "CRATE!"
	if CvcState.loaded and n > had then
		-- a new crate (your first race): show it off
		local sc = openCrates:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		sc.Scale = 1.6
		sc.Parent = openCrates
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	had = n
	if panel.Visible and not opening and not reveal.Visible then
		showChoose()
	end
end
player:GetAttributeChangedSignal("Driving"):Connect(showButton)
CvcState.changed:Connect(showButton)
showButton()
