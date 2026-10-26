--!strict
-- Car VS Car crates (carter 10-26, rc-game/cvc-plan.md), in the Kart Party look. Only with
-- Features.CVC on. A CRATE button under the coins while you have one to open; it shows the crate
-- and its odds (always before you open it), then OPEN!: the crate shakes, pops, and your new car
-- comes out with rays, confetti and its rarity. The server rolls the car (TrainingServer
-- ("open") -> ("crate", carId, rarity)); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Crates = require(Shared:WaitForChild("Crates"))
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

-- the crate you get from your first race (the server opens only that one for now)
local KIND = "free"

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
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.54)
panel.Size = UDim2.fromScale(0.6, 0.76)
panel.BackgroundColor3 = KartStyle.BLUE
panel.Visible = false
panel.Parent = pop
CvcUi.corner(panel, 0.05)
CvcUi.rim(panel, KartStyle.PANEL_RIM)
local panelMax = Instance.new("UISizeConstraint")
panelMax.MaxSize = Vector2.new(620, 520)
panelMax.Parent = panel
local kind = Crates.get(KIND)
local ribbon = CvcUi.ribbon(panel, if kind then kind.label else "CRATE")

local close = button(panel, "X", KartStyle.RED)
close.Name = "Close"
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.fromScale(1, 0)
close.Size = UDim2.fromScale(0.11, 0.11)
close.SizeConstraint = Enum.SizeConstraint.RelativeYY
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
oddsBox.Position = UDim2.fromScale(0.5, 0.14)
oddsBox.Size = UDim2.fromScale(0.46, 0.58)
oddsBox.BackgroundTransparency = 1
oddsBox.Parent = panel
local oddsTitle = label(oddsBox, "WHAT'S INSIDE", WHITE)
oddsTitle.Size = UDim2.fromScale(1, 0.16)
do
	local odds = Crates.odds(KIND)
	local rows = 0
	for _, r in CarCatalog.RARITY_ORDER do
		local pct = odds[r] or 0
		local info = CarCatalog.RARITY[r]
		if info then
			local y = 0.2 + rows * 0.2
			rows += 1
			local c = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
			local chip = label(oddsBox, info.label, INK)
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
			local num =
				label(oddsBox, `{pct}%`, if pct > 0 then WHITE else Color3.fromRGB(160, 175, 210))
			num.Position = UDim2.fromScale(0.66, y)
			num.Size = UDim2.fromScale(0.34, 0.17)
			num.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end

local openBtn = button(panel, "OPEN!", KartStyle.GREEN)
openBtn.Name = "Open"
openBtn.AnchorPoint = Vector2.new(0.5, 1)
openBtn.Position = UDim2.fromScale(0.5, 0.95)
openBtn.Size = UDim2.fromScale(0.46, 0.13)
openBtn:SetAttribute("KartPulse", true)
local left = label(panel, "", WHITE)
left.AnchorPoint = Vector2.new(0.5, 1)
left.Position = UDim2.fromScale(0.5, 0.8)
left.Size = UDim2.fromScale(0.6, 0.06)

-- the new car comes out here (over the crate's place)
local reveal = Instance.new("Frame")
reveal.Name = "Reveal"
reveal.AnchorPoint = Vector2.new(0.5, 0.5)
reveal.Position = UDim2.fromScale(0.5, 0.45)
reveal.Size = UDim2.fromScale(0.5, 0.62)
reveal.BackgroundTransparency = 1
reveal.ZIndex = 2
reveal.Visible = false
reveal.Parent = panel

local opening = false
local shake: Tween? = nil

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
	ribbon.Text = if kind then kind.label else "CRATE"
	openBtn.Text = "OPEN!"
	openBtn.BackgroundColor3 = KartStyle.GREEN
	left.Text = if CvcState.crates > 1 then `{CvcState.crates} CRATES TO OPEN` else ""
end

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
		shake:Cancel()
		shake = nil
	end
	box.Rotation = 0
end

openBtn.Activated:Connect(function()
	if opening then
		return
	end
	if reveal.Visible then
		-- the car is out: another crate, or done
		if CvcState.crates > 0 then
			showChoose()
		else
			setOpen(false)
		end
		return
	end
	if CvcState.crates <= 0 then
		setOpen(false)
		return
	end
	opening = true
	CvcState.ask("open")
	openBtn.Text = "..."
	box.Rotation = -8
	shake = TweenService:Create(
		box,
		TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 8 }
	)
	if shake then
		shake:Play()
	end
	task.delay(6, function()
		-- the server said no (or is slow): back to the crate
		if opening then
			opening = false
			stopShake()
			showChoose()
		end
	end)
end)

local function gotCar(id: string, rarity: string)
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
	Party.rays(reveal, color)
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = reveal
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	ribbon.Text = `NEW {info.label} CAR!`
	openBtn.Text = if CvcState.crates > 0 then "OPEN ANOTHER!" else "YAY!"
	local n = table.find(CarCatalog.RARITY_ORDER, info.id) or 1
	Sfx.crate(n)
	CvcUi.bigWords(top, `{CvcState.name(id)}!`, color, 0.16)
	Party.confetti(fall, 30 + n * 20)
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
	setOpen(not panel.Visible)
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
