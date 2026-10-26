--!strict
-- The tycoon on screen (carter's plan, 10-26: race -> coins -> cars -> your cars make coins), in
-- the Kart Party look (KartStyle; KartSkin adds the gloss and the pop-ins):
--   * the income chip by the coins: "+12/MIN", and while a race win's 2X is on, "2X 9:41"
--   * a big "+N COINS!" pop with a burst when you collect your plot's pile
--   * MY GARAGE: your cars, which are parked (and earning), PARK / OUT, and BIGGER GARAGE
--   * the map vote card in the break: tap the map you want next
-- The server (TycoonServer, the race runner) decides everything; this only shows it and asks.
-- Its names are in rc-game/tycoon/PLAN.md: player attributes Income, BoostUntil, PlotLevel,
-- Parked; RemoteEvent Plot ("collect" / "park" / "level" up, "collected" / "boost" down);
-- RemoteEvent ServerRace ("vote" / "votes").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared:WaitForChild("CarCatalog"))
local Garage = require(Shared:WaitForChild("Garage"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local Party = require(script.Parent:WaitForChild("Party"))
local Popup = require(script.Parent:WaitForChild("Popup"))
local StageGate = require(script.Parent:WaitForChild("StageGate"))

local player = Players.LocalPlayer
local INK, WHITE = KartStyle.INK, KartStyle.WHITE

-- a shared module another thread adds (Tycoon: slots / levelCost; Maps: names): nil until it is in
local function optional(name: string): any
	local m = Shared:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
	end
	return nil
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

local function rim(parent: Instance, thick: number)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = INK
	s.Thickness = thick
	s.Parent = parent
end

local function label(parent: Instance, text: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = KartStyle.FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = KartStyle.FONT
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.Text = text
	b.Parent = parent
	corner(b, 0.3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.16, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	return b
end

local function rarityOf(car: CarCatalog.Car): (string, Color3, number)
	-- (CarCatalog.RARITY comes with the rarity field: until then every car is common)
	local r = (car :: any).rarity
	local tiers = (CarCatalog :: any).RARITY
	local tier = if type(r) == "string" and type(tiers) == "table" then tiers[r] else nil
	if type(tier) ~= "table" then
		return "COMMON", Color3.fromRGB(176, 184, 196), 2
	end
	local c = tier.color
	local color = if typeof(c) == "Color3"
		then c
		elseif type(c) == "table" then Color3.fromRGB(c[1], c[2], c[3])
		else Color3.fromRGB(176, 184, 196)
	return string.upper(tostring(tier.label or r)), color, tonumber(tier.perMin) or 2
end

local function plotEvent(): RemoteEvent?
	local e = ReplicatedStorage:FindFirstChild("Plot")
	return if e and e:IsA("RemoteEvent") then e else nil
end

-- ===== the income chip =====

local hud = Instance.new("ScreenGui")
hud.Name = "Tycoon"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")

local income = Instance.new("TextLabel")
income.Name = "Income"
HudLayout.place(income, "Income")
income.BackgroundColor3 = KartStyle.GREEN
income.Font = KartStyle.FONT
income.TextScaled = true
income.TextColor3 = WHITE
income.Visible = false -- until the server says how much
income.Parent = hud
corner(income, 0.3)
rim(income, KartStyle.BUTTON_RIM)
local incomePad = Instance.new("UIPadding")
incomePad.PaddingTop = UDim.new(0.16, 0)
incomePad.PaddingBottom = UDim.new(0.12, 0)
incomePad.PaddingLeft = UDim.new(0.08, 0)
incomePad.PaddingRight = UDim.new(0.08, 0)
incomePad.Parent = income
local incomeScale = Instance.new("UIScale")
incomeScale.Parent = income
StageGate.hold(income, "coins")

local lastIncome = -1
local function bump()
	incomeScale.Scale = 1.3
	TweenService:Create(incomeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 })
		:Play()
end

-- the first time a new player sees the chip: a yellow note beside it says what it is
local tipShown = false
local function incomeTip()
	local stage = player:GetAttribute("Stage")
	if type(stage) ~= "number" or stage >= 3 then
		return -- the save isn't in yet (asks again next frame), or they know by now
	end
	tipShown = true
	local tip = label(hud, "YOUR CARS MAKE COINS!", INK)
	tip.Name = "IncomeTip"
	local at = HudLayout.find("Income", "walk")
	tip.Position = UDim2.new(if at then at.x + at.w + 0.012 else 0.25, 0, 0, 64)
	tip.Size = UDim2.fromOffset(230, 36)
	tip.BackgroundColor3 = KartStyle.YELLOW
	tip.BackgroundTransparency = 0
	corner(tip, 0.3)
	rim(tip, KartStyle.BUTTON_RIM)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = tip
	-- a little point toward the chip
	local nub = Instance.new("Frame")
	nub.Name = "Kart_Nub"
	nub.AnchorPoint = Vector2.new(0.5, 0.5)
	nub.Position = UDim2.new(0, -3, 0.5, 0)
	nub.Size = UDim2.fromOffset(12, 12)
	nub.Rotation = 45
	nub.BackgroundColor3 = KartStyle.YELLOW
	nub.BorderSizePixel = 0
	nub.ZIndex = tip.ZIndex - 1
	nub.Parent = tip
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = tip
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local function gone()
		if tip.Parent then
			TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
			task.delay(0.25, function()
				tip:Destroy()
			end)
		end
	end
	-- the 10 s start once the join title card (Title.client) is gone: under it the kid can't read
	-- this (Studio: the note was up for only 2-3 s after loading)
	task.spawn(function()
		local pgui = player:WaitForChild("PlayerGui")
		local waited = 0
		while pgui:FindFirstChild("TitleCard") and waited < 12 do
			waited += task.wait(0.25)
		end
		task.wait(10)
		gone()
	end)
	player:GetAttributeChangedSignal("Driving"):Connect(gone)
end

-- each tenth of a second: the 2X clock ticks, and with a 2X on the chip flips between the two
RunService.Heartbeat:Connect(function()
	local perMin = player:GetAttribute("Income")
	if type(perMin) ~= "number" then
		income.Visible = false
		return
	end
	income.Visible = player:GetAttribute("Driving") ~= true
	if income.Visible and not tipShown and StageGate.shows("coins") then
		incomeTip()
	end
	local n = math.floor(perMin + 0.5)
	if n ~= lastIncome then
		if lastIncome >= 0 and n > lastIncome then
			bump() -- a new car parked, a bigger garage, a 2X
		end
		lastIncome = n
	end
	local untilAt = player:GetAttribute("BoostUntil")
	local left = if type(untilAt) == "number" then untilAt - workspace:GetServerTimeNow() else 0
	if left > 0 and os.clock() % 4 < 2 then
		income.BackgroundColor3 = KartStyle.YELLOW
		income.TextColor3 = INK
		income.Text = string.format("2X %d:%02d", left // 60, math.floor(left % 60))
	else
		income.BackgroundColor3 = KartStyle.GREEN
		income.TextColor3 = WHITE
		income.Text = `+{n}/MIN`
	end
end)

-- ===== collect: "+N COINS!" =====

local top = Instance.new("ScreenGui")
top.Name = "TycoonTop"
top.ResetOnSpawn = false
top.IgnoreGuiInset = true
top.DisplayOrder = HudLayout.POPUP + 1 -- over a popup: it's quick
top.Parent = player:WaitForChild("PlayerGui")
local topFall = Instance.new("Frame") -- confetti under the big words, not over them
topFall.Name = "Kart_Fall"
topFall.BackgroundTransparency = 1
topFall.Size = UDim2.fromScale(1, 1)
topFall.ZIndex = 0
topFall.Active = false
topFall.Parent = top

local function bigWords(text: string, color: Color3)
	local w = label(top, text, color)
	w.Name = "Kart_Words" -- (styled here: KartSkin leaves Kart_ pieces alone)
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Position = UDim2.fromScale(0.5, 0.42)
	w.Size = UDim2.fromScale(0.5, 0.14)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 4
	s.Parent = w
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = w
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.1, function()
		TweenService:Create(w, TweenInfo.new(0.5), {
			Position = UDim2.fromScale(0.5, 0.3),
			TextTransparency = 1,
		}):Play()
		TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.delay(0.5, function()
			w:Destroy()
		end)
	end)
end

-- ===== welcome back: what your parked cars made while you were away =====

local awayGui = Instance.new("ScreenGui")
awayGui.Name = "WelcomeBack"
awayGui.ResetOnSpawn = false
awayGui.IgnoreGuiInset = true
awayGui.DisplayOrder = HudLayout.POPUP
awayGui.Parent = player:WaitForChild("PlayerGui")

local away = Instance.new("Frame")
away.Name = "Panel"
away.AnchorPoint = Vector2.new(0.5, 0.5)
away.Position = UDim2.fromScale(0.5, 0.5)
away.Size = UDim2.fromScale(0.46, 0.46)
away.BackgroundColor3 = KartStyle.BLUE
away.Visible = false
away.ZIndex = 1
away.Parent = awayGui
corner(away, 0.08)
rim(away, KartStyle.PANEL_RIM)
local awaySize = Instance.new("UISizeConstraint")
awaySize.MaxSize = Vector2.new(520, 330)
awaySize.Parent = away

local awayTitle = label(away, "WELCOME BACK!", INK)
awayTitle.Name = "Ribbon"
awayTitle.AnchorPoint = Vector2.new(0.5, 0.5)
awayTitle.Position = UDim2.fromScale(0.5, 0)
awayTitle.Size = UDim2.fromScale(0.7, 0.2)
awayTitle.BackgroundColor3 = KartStyle.YELLOW
awayTitle.BackgroundTransparency = 0
awayTitle.ZIndex = 3
corner(awayTitle, 0.3)
rim(awayTitle, KartStyle.BUTTON_RIM)
local awayTitlePad = Instance.new("UIPadding")
awayTitlePad.PaddingTop = UDim.new(0.14, 0)
awayTitlePad.PaddingBottom = UDim.new(0.1, 0)
awayTitlePad.Parent = awayTitle

local awayLine = label(away, "YOUR CARS MADE", WHITE)
awayLine.Position = UDim2.fromScale(0.06, 0.16)
awayLine.Size = UDim2.fromScale(0.88, 0.13)
local awayCoins = label(away, "+0 COINS", KartStyle.YELLOW)
awayCoins.Name = "Coins"
awayCoins.Position = UDim2.fromScale(0.06, 0.3)
awayCoins.Size = UDim2.fromScale(0.88, 0.26)
local awayCoinsRim = Instance.new("UIStroke")
awayCoinsRim.Color = INK
awayCoinsRim.Thickness = 3
awayCoinsRim.Parent = awayCoins
local awayTime = label(away, "WHILE YOU WERE AWAY", WHITE)
awayTime.Position = UDim2.fromScale(0.06, 0.57)
awayTime.Size = UDim2.fromScale(0.88, 0.11)

local awayGet = button(away, "COLLECT!", KartStyle.GREEN)
awayGet.Name = "Collect"
awayGet.AnchorPoint = Vector2.new(0.5, 1)
awayGet.Position = UDim2.fromScale(0.5, 0.94)
awayGet.Size = UDim2.fromScale(0.56, 0.2)
awayGet:SetAttribute("KartPulse", true) -- the one thing to press (KartSkin)
local stopRays: (() -> ())? = nil

local function shutAway()
	away.Visible = false
	if stopRays then
		stopRays()
		stopRays = nil
	end
end
awayGet.Activated:Connect(function()
	shutAway()
	local e = plotEvent()
	if e then
		e:FireServer("collect") -- the pile at your garage: "+N COINS!" pops as it lands
	end
end)
Popup.add("away", awayGui, shutAway)
-- the confetti falls between the dim cover (ZIndex 0) and the card (1)
local awayFall = Instance.new("Frame")
awayFall.Name = "Kart_Fall"
awayFall.BackgroundTransparency = 1
awayFall.Size = UDim2.fromScale(1, 1)
awayFall.ZIndex = 0
awayFall.Active = false
awayFall.Parent = awayGui
away:GetPropertyChangedSignal("Visible"):Connect(function()
	Popup.shown("away", away.Visible)
end)

-- 7260 -> "2 HOURS", 300 -> "5 MIN": how long you were gone, in a word or two
local function awayWords(seconds: number): string
	if seconds >= 2 * 3600 then
		return `{math.floor(seconds / 3600)} HOURS`
	elseif seconds >= 3600 then
		return "1 HOUR"
	end
	return `{math.max(1, math.floor(seconds / 60))} MIN`
end

local function showAway(coins: number, seconds: number?)
	awayCoins.Text = `+{math.floor(coins)} COINS`
	awayTime.Text = if seconds and seconds >= 60
		then `IN THE {awayWords(seconds)} YOU WERE AWAY`
		else "WHILE YOU WERE AWAY"
	away.Visible = true
	if not stopRays then
		stopRays = Party.rays(awayCoins, KartStyle.YELLOW)
	end
	Party.confetti(awayFall, 40) -- behind the card: the words stay clear (Studio shot 08)
end

-- collected coins fly up into the coins number, so you see where they went
local function coinChip(): GuiObject?
	local stars = player.PlayerGui:FindFirstChild("StarsHud")
	local c = stars and stars:FindFirstChild("CoinCount", true)
	return if c and c:IsA("GuiObject") and c.AbsoluteSize.X > 0 then c else nil
end

local function flyCoins(n: number)
	local chip = coinChip()
	if not chip then
		return
	end
	local to = chip.AbsolutePosition
		+ Vector2.new(chip.AbsoluteSize.Y * 0.5, chip.AbsoluteSize.Y * 0.5)
	local from = top.AbsoluteSize * Vector2.new(0.5, 0.42)
	local count = math.clamp(math.floor(n / 5), 6, 14)
	for i = 1, count do
		task.delay((i - 1) * 0.05 + 0.15, function()
			local c = Instance.new("Frame")
			c.Name = "Kart_Coin"
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Size = UDim2.fromOffset(22, 22)
			c.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
			c.ZIndex = 40
			local spread = Vector2.new(math.random(-70, 70), math.random(-40, 40))
			c.Position = UDim2.fromOffset(from.X + spread.X, from.Y + spread.Y)
			c.Parent = top
			corner(c, 0.5)
			local r = Instance.new("UIStroke")
			r.Color = Color3.fromRGB(176, 112, 10)
			r.Thickness = 2
			r.Parent = c
			local t = 0.55 + math.random() * 0.15
			TweenService:Create(
				c,
				TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(14, 14) }
			):Play()
			task.delay(t, function()
				c:Destroy()
				-- the coins number gives a little hop as each one lands
				local scale = chip:FindFirstChildOfClass("UIScale")
				if scale then
					scale.Scale = 1.15
					TweenService
						:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 })
						:Play()
				end
			end)
		end)
	end
end

local function onPlot(what: unknown, a: unknown, b: unknown)
	if what == "away" and type(a) == "number" and a >= 1 then
		showAway(a, if type(b) == "number" then b else nil)
	elseif what == "collected" and type(a) == "number" and a > 0 then
		bigWords(`+{math.floor(a)} COINS!`, KartStyle.YELLOW)
		Party.burst(top, UDim2.fromScale(0.5, 0.42), 20)
		flyCoins(a)
	elseif what == "boost" then
		bigWords("2X COINS!", KartStyle.YELLOW)
		Party.confetti(topFall, 30)
	end
end

task.spawn(function()
	local e = ReplicatedStorage:WaitForChild("Plot", 60)
	if e and e:IsA("RemoteEvent") then
		e.OnClientEvent:Connect(onPlot)
	end
end)

-- ===== MY GARAGE =====

local pop = Instance.new("ScreenGui")
pop.Name = "Garage"
pop.ResetOnSpawn = false
pop.IgnoreGuiInset = true
pop.DisplayOrder = HudLayout.POPUP
pop.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.53)
panel.Size = UDim2.fromScale(0.62, 0.74)
panel.BackgroundColor3 = KartStyle.BLUE
panel.Visible = false
panel.Parent = pop
corner(panel, 0.06)
rim(panel, KartStyle.PANEL_RIM)

local title = label(panel, "MY GARAGE", INK)
title.Name = "Ribbon"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0)
title.Size = UDim2.fromScale(0.5, 0.14)
title.BackgroundColor3 = KartStyle.YELLOW
title.BackgroundTransparency = 0
title.ZIndex = 3
corner(title, 0.3)
rim(title, KartStyle.BUTTON_RIM)
local titlePad = Instance.new("UIPadding")
titlePad.PaddingTop = UDim.new(0.14, 0)
titlePad.PaddingBottom = UDim.new(0.1, 0)
titlePad.Parent = title

local close = button(panel, "X", KartStyle.RED)
close.Name = "Close"
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.fromScale(1, 0)
close.Size = UDim2.fromScale(0.12, 0.12)
close.SizeConstraint = Enum.SizeConstraint.RelativeYY
close.ZIndex = 3
corner(close, 0.5)

local slotsLine = label(panel, "", WHITE)
slotsLine.Position = UDim2.fromScale(0.05, 0.1)
slotsLine.Size = UDim2.fromScale(0.9, 0.08)

local list = Instance.new("ScrollingFrame")
list.Name = "Cars"
list.Position = UDim2.fromScale(0.04, 0.2)
list.Size = UDim2.fromScale(0.92, 0.58)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.Parent = panel

local level = button(panel, "BIGGER GARAGE", KartStyle.GREEN)
level.Name = "Level"
level.AnchorPoint = Vector2.new(0.5, 1)
level.Position = UDim2.fromScale(0.5, 0.96)
level.Size = UDim2.fromScale(0.6, 0.13)

local shopRemote = ReplicatedStorage:WaitForChild("CarShop") :: RemoteFunction

local function owned(): { string }
	local ok, s = pcall(function()
		return shopRemote:InvokeServer("state")
	end)
	if ok and type(s) == "table" and type(s.owned) == "table" then
		return s.owned
	end
	return {}
end

local function parked(): { [string]: boolean }
	local out = {}
	local s = player:GetAttribute("Parked")
	if type(s) == "string" then
		for id in string.gmatch(s, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

local function plotLevel(): number
	local l = player:GetAttribute("PlotLevel")
	return if type(l) == "number" then l else 0
end

local render: () -> ()
local ROW = 60 -- pixels per car row

local function row(i: number, car: CarCatalog.Car, isParked: boolean, room: boolean)
	local word, color, perMin = rarityOf(car)
	local r = Instance.new("Frame")
	r.Name = car.id
	r.Position = UDim2.new(0, 0, 0, (i - 1) * ROW)
	r.Size = UDim2.new(1, -10, 0, ROW - 6)
	r.BackgroundColor3 = Color3.fromRGB(244, 247, 255)
	r.Parent = list
	corner(r, 0.3)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = if word == "COMMON" then INK else color
	edge.Thickness = if word == "COMMON" then 2 else 3
	edge.Parent = r
	-- the car itself in a little window (the shop's toy car), its name, its rarity word, what it makes
	local pic = Instance.new("ViewportFrame")
	pic.Name = "Car"
	pic:SetAttribute("NoKart", true) -- a picture: no gloss over it
	pic.AnchorPoint = Vector2.new(0, 0.5)
	pic.Position = UDim2.new(0, 6, 0.5, 0)
	pic.Size = UDim2.fromOffset(ROW - 14, ROW - 14)
	pic.BackgroundColor3 = color:Lerp(INK, 0.4) -- darker than the row: a white car still shows
	pic.Ambient = Color3.fromRGB(200, 200, 200)
	pic.LightColor = WHITE
	pic.Parent = r
	corner(pic, 0.25)
	local pieces = {}
	Garage.toyCar(Garage.adder(pieces), "Car", { x = 0, y = 0, z = 0 }, 0, car.color, 1, car.style)
	local model = Instance.new("Model")
	Garage.makeParts(pieces, model, CFrame.identity)
	model.Parent = pic
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	local d = size.Magnitude * 0.78 -- close in: the car fills its window
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-d * 0.55, d * 0.4, -d * 0.7), cf.Position)
	cam.FieldOfView = 40
	cam.Parent = pic
	pic.CurrentCamera = cam
	local TEXT_X = ROW
	local name = label(r, string.upper(car.name), INK)
	name.Position = UDim2.new(0, TEXT_X, 0.08, 0)
	name.Size = UDim2.new(0.5, -TEXT_X, 0.46, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local tag = label(r, `{word}  +{perMin}/MIN`, color:Lerp(INK, 0.55))
	-- (big enough to read on a phone: Studio shot 02)
	tag.Position = UDim2.new(0, TEXT_X, 0.54, 0)
	tag.Size = UDim2.new(0.5, -TEXT_X, 0.4, 0)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	local b = button(
		r,
		if isParked then "OUT" else "PARK",
		if isParked then KartStyle.RED else KartStyle.GREEN
	)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -8, 0.5, 0)
	b.Size = UDim2.new(0.26, 0, 0.72, 0)
	if not isParked and not room then
		b.Text = "FULL"
		b.BackgroundColor3 = Color3.fromRGB(110, 110, 118)
		b.AutoButtonColor = false
		b.Active = false
		return
	end
	b.Activated:Connect(function()
		local e = plotEvent()
		if e then
			e:FireServer("park", car.id, not isParked)
		end
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local Tycoon = optional("Tycoon")
	local lvl = plotLevel()
	local slots = if Tycoon and Tycoon.slots then Tycoon.slots(lvl) else 3
	local inside = parked()
	local count = 0
	for _ in inside do
		count += 1
	end
	slotsLine.Text = `PARKED {count} / {slots}  -  PARKED CARS MAKE COINS`
	local ids = owned()
	-- parked first, then the rest
	table.sort(ids, function(a, b)
		local pa, pb = inside[a] == true, inside[b] == true
		if pa ~= pb then
			return pa
		end
		return a < b
	end)
	local n = 0
	for _, id in ids do
		local car = CarCatalog.get(id)
		if car then
			n += 1
			row(n, car, inside[id] == true, count < slots)
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, n * ROW)
	local cost = if Tycoon and Tycoon.levelCost then Tycoon.levelCost(lvl) else nil
	level.Visible = type(cost) == "number"
	if type(cost) == "number" then
		level.Text = `BIGGER GARAGE  {cost}`
	end
end

level.Activated:Connect(function()
	local e = plotEvent()
	if e then
		e:FireServer("level")
	end
end)

local function setOpen(on: boolean)
	panel.Visible = on
	render()
end
close.Activated:Connect(function()
	setOpen(false)
end)
Popup.add("garage", pop, function()
	setOpen(false)
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	Popup.shown("garage", panel.Visible)
end)
for _, a in { "Parked", "PlotLevel" } do
	player:GetAttributeChangedSignal(a):Connect(render)
end

-- a bigger garage is a big moment: words, confetti, and what you got
-- (nil until the save is in: the first number is the saved level, not a level up)
local shownLevel: number? = player:GetAttribute("PlotLevel") :: any
player:GetAttributeChangedSignal("PlotLevel"):Connect(function()
	local l = plotLevel()
	if shownLevel and l > shownLevel then
		bigWords("BIGGER GARAGE!", KartStyle.YELLOW)
		Party.confetti(topFall, 50)
		task.delay(1.3, function()
			bigWords("+1 PARKING SPOT!", KartStyle.GREEN)
		end)
	end
	shownLevel = l
end)

-- the GARAGE button, under the income chip
local garageBtn = button(hud, "GARAGE", KartStyle.RED)
garageBtn.Name = "GarageButton"
HudLayout.place(garageBtn, "Garage")
garageBtn.Visible = false
StageGate.hold(garageBtn, "garage") -- from the start: your first car is parked and earning
garageBtn.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
local function showGarageBtn()
	garageBtn.Visible = player:GetAttribute("Parked") ~= nil
		and player:GetAttribute("Driving") ~= true
end
player:GetAttributeChangedSignal("Parked"):Connect(showGarageBtn)
player:GetAttributeChangedSignal("Driving"):Connect(showGarageBtn)
showGarageBtn()

-- ===== the map vote =====

local vote = Instance.new("Frame")
vote.Name = "MapVote"
vote.AnchorPoint = Vector2.new(0.5, 0)
-- small, up top in the middle: off the spawn view a new kid looks at (Studio kid-02), clear of
-- the coins row (left) and NEXT RACE (right); its ribbon stays under Roblox's top bar
vote.Position = UDim2.new(0.5, 0, 0, 74)
vote.Size = UDim2.fromScale(0.34, 0.24)
local voteMax = Instance.new("UISizeConstraint")
voteMax.MaxSize = Vector2.new(380, 150)
voteMax.Parent = vote
vote.BackgroundColor3 = KartStyle.BLUE
vote.Visible = false
vote.Parent = hud
corner(vote, 0.12)
rim(vote, KartStyle.PANEL_RIM)
StageGate.hold(vote, "race")
local voteTitle = label(vote, "PICK A MAP AND RACE!", INK)
voteTitle.AnchorPoint = Vector2.new(0.5, 0.5)
voteTitle.Position = UDim2.fromScale(0.5, 0)
voteTitle.Size = UDim2.fromScale(0.8, 0.22)
voteTitle.BackgroundColor3 = KartStyle.YELLOW
voteTitle.BackgroundTransparency = 0
voteTitle.ZIndex = 3
corner(voteTitle, 0.3)
rim(voteTitle, KartStyle.BUTTON_RIM)
local voteTitlePad = Instance.new("UIPadding")
voteTitlePad.PaddingTop = UDim.new(0.14, 0)
voteTitlePad.PaddingBottom = UDim.new(0.1, 0)
voteTitlePad.Parent = voteTitle
-- the time left, as a bar that runs down along the bottom
local timeBar = Instance.new("Frame")
timeBar.AnchorPoint = Vector2.new(0, 1)
timeBar.Position = UDim2.new(0, 10, 1, -8)
timeBar.Size = UDim2.new(1, -20, 0.06, 0)
timeBar.BackgroundColor3 = KartStyle.YELLOW
timeBar.Parent = vote
corner(timeBar, 0.5)

local cards: { [string]: { card: TextButton, count: TextLabel, rim: UIStroke } } = {}
local myVote: string? = nil
local voteEnds, voteStarts = 0, 0

local function mapInfo(id: string): (string, string, Color3)
	local Maps = optional("Maps")
	local m = Maps and Maps.get and Maps.get(id)
	if type(m) == "table" then
		local c = m.color
		local color = if typeof(c) == "Color3"
			then c
			elseif type(c) == "table" then Color3.fromRGB(c[1], c[2], c[3])
			else KartStyle.GREEN
		return string.upper(tostring(m.name or id)), tostring(m.icon or ""), color
	end
	return string.upper(id), "", KartStyle.GREEN
end

local function showVotes(votes: { [string]: number }?)
	for id, c in cards do
		local picked = myVote == id
		c.rim.Color = if picked then KartStyle.YELLOW else INK
		c.rim.Thickness = if picked then 5 else KartStyle.BUTTON_RIM
		local n = if votes then votes[id] else nil
		c.count.Text = if type(n) == "number" and n > 0
			then `{n} VOTE{if n == 1 then "" else "S"}`
			else ""
	end
end

local function openVote(ids: { string }, endsAt: number)
	for _, c in cards do
		c.card:Destroy()
	end
	table.clear(cards)
	myVote = nil
	voteEnds, voteStarts = endsAt, workspace:GetServerTimeNow()
	local n = math.max(#ids, 1)
	for i, id in ids do
		local name, icon, color = mapInfo(id)
		local card = button(vote, "", color)
		card.Name = id
		card.Position = UDim2.new((i - 1) / n, 8, 0.2, 0)
		card.Size = UDim2.new(1 / n, -16, 0.62, 0)
		-- (an emoji scaled to the box drew tiny on a phone, shot 01: a set size reads)
		local pic = label(card, icon, WHITE)
		pic.TextScaled = false
		pic.TextSize = 20
		pic.Size = UDim2.fromScale(1, 0.3)
		local words = label(card, name, WHITE)
		words.Position = UDim2.fromScale(0, 0.28)
		words.Size = UDim2.fromScale(1, 0.44)
		local wordsRim = Instance.new("UIStroke")
		wordsRim.Color = INK
		wordsRim.Thickness = 2
		wordsRim.Parent = words
		local count = label(card, "", KartStyle.YELLOW)
		count.Position = UDim2.fromScale(0, 0.74)
		count.Size = UDim2.fromScale(1, 0.26)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = INK
		stroke.Thickness = KartStyle.BUTTON_RIM
		stroke.Parent = card
		cards[id] = { card = card, count = count, rim = stroke }
		card.Activated:Connect(function()
			if myVote == id then
				return
			end
			myVote = id
			showVotes(nil)
			-- voted: the card goes away on its own a moment later (the race call says the rest)
			local this = voteEnds
			task.delay(1.2, function()
				if voteEnds == this then
					vote.Visible = false
				end
			end)
			local at = card.AbsolutePosition + card.AbsoluteSize / 2
			Party.burst(top, UDim2.fromOffset(at.X, at.Y), 12)
			local e = ReplicatedStorage:FindFirstChild("ServerRace")
			if e and e:IsA("RemoteEvent") then
				e:FireServer("vote", id)
			end
		end)
	end
	vote.Visible = #ids > 1
end

RunService.Heartbeat:Connect(function()
	if not vote.Visible then
		return
	end
	local now = workspace:GetServerTimeNow()
	local left = voteEnds - now
	if left <= 0 or player:GetAttribute("Building") == true then
		vote.Visible = false
		return
	end
	local span = math.max(voteEnds - voteStarts, 1)
	timeBar.Size = UDim2.new((left / span), -20 * (left / span), 0.06, 0)
end)

task.spawn(function()
	local e = ReplicatedStorage:WaitForChild("ServerRace", 60)
	if not (e and e:IsA("RemoteEvent")) then
		return
	end
	e.OnClientEvent:Connect(function(what: unknown, a: unknown, b: unknown)
		if what == "vote" and type(a) == "table" and type(b) == "number" then
			local ids = {}
			for _, id in a :: { any } do
				if type(id) == "string" then
					table.insert(ids, id)
				end
			end
			openVote(ids, b)
		elseif what == "votes" and type(a) == "table" then
			showVotes(a :: { [string]: number })
		elseif what == "state" and a == "racing" then
			vote.Visible = false
		end
	end)
end)
