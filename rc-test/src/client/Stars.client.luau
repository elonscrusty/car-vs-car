--!strict
-- Carter's stars loop, phase 1, on screen: the star count (top left, under the timer) and a pop
-- when a run ends with a medal or a plot record. The server decides everything (Stars.server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Profile = require(ReplicatedStorage.Shared.Profile)

local remote = ReplicatedStorage:WaitForChild("StarsEvent") :: RemoteEvent
local player = Players.LocalPlayer

local NAMES = { "BRONZE", "SILVER", "GOLD" }
local COLORS = {
	Color3.fromRGB(214, 140, 80),
	Color3.fromRGB(215, 222, 232),
	Color3.fromRGB(255, 205, 60),
}

local gui = Instance.new("ScreenGui")
gui.Name = "Stars"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local chip = Instance.new("TextLabel")
chip.Name = "StarCount"
chip.AnchorPoint = Vector2.new(0, 0)
chip.Position = UDim2.new(0.02, 0, 0.14, 70) -- under the timer
chip.Size = UDim2.fromScale(0.13, 0.06)
chip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
chip.BackgroundTransparency = 0.3
chip.TextColor3 = Color3.fromRGB(255, 213, 79)
chip.Font = Enum.Font.GothamBlack
chip.TextScaled = true
chip.Text = "⭐ 0"
chip.Parent = gui
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0.3, 0)
chipCorner.Parent = chip
local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

-- coins, beside the stars
local coinChip = chip:Clone()
coinChip.Name = "CoinCount"
coinChip.Position = UDim2.new(0.16, 0, 0.14, 70)
coinChip.TextColor3 = Color3.fromRGB(255, 236, 150)
coinChip.Text = "0"
coinChip.Parent = gui
-- a drawn coin (the coin emoji is missing from Roblox's font): gold disc, darker rim, a lighter
-- inner ring. The number sits to its right.
local coinPad = Instance.new("UIPadding")
coinPad.PaddingLeft = UDim.new(0.42, 0)
coinPad.PaddingRight = UDim.new(0.08, 0)
coinPad.Parent = coinChip
local coin = Instance.new("Frame")
coin.Name = "Coin"
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.new(-0.42 / 0.5, 6, 0.5, 0) -- back over the left padding
coin.Size = UDim2.fromScale(0.7, 0.7)
coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
coin.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
coin.Parent = coinChip
local coinRound = Instance.new("UICorner")
coinRound.CornerRadius = UDim.new(0.5, 0)
coinRound.Parent = coin
local coinRim = Instance.new("UIStroke")
coinRim.Color = Color3.fromRGB(176, 112, 10)
coinRim.Thickness = 2
coinRim.Parent = coin
local coinInner = Instance.new("Frame")
coinInner.AnchorPoint = Vector2.new(0.5, 0.5)
coinInner.Position = UDim2.fromScale(0.5, 0.5)
coinInner.Size = UDim2.fromScale(0.55, 0.55)
coinInner.BackgroundTransparency = 1
coinInner.Parent = coin
local innerRound = Instance.new("UICorner")
innerRound.CornerRadius = UDim.new(0.5, 0)
innerRound.Parent = coinInner
local innerRing = Instance.new("UIStroke")
innerRing.Color = Color3.fromRGB(255, 232, 140)
innerRing.Thickness = 1.5
innerRing.Parent = coinInner

-- gold bolts found, only while on a rock plot
local boltChip = chip:Clone()
boltChip.Name = "BoltCount"
boltChip.Position = UDim2.new(0.30, 0, 0.14, 70)
boltChip.TextColor3 = Color3.fromRGB(255, 200, 70)
boltChip.Text = "BOLTS 0/5"
boltChip.Visible = false
boltChip.Parent = gui

-- found bolts are hidden on this screen (the server says which)
local foundBolts: { [number]: boolean } = {}
local function hideFound()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, d in plots:GetDescendants() do
		local id = d:GetAttribute("BoltId")
		if type(id) == "number" and foundBolts[id] then
			for _, p in { d, table.unpack(d:GetDescendants()) } do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 1
				elseif p:IsA("Light") or p:IsA("ParticleEmitter") then
					(p :: any).Enabled = false
				end
			end
		end
	end
end

-- rivals: a button under the coins opens your score against each player you raced
local rivalsBtn = Instance.new("TextButton")
rivalsBtn.Name = "Rivals"
rivalsBtn.Position = UDim2.new(0.16, 0, 0.2, 76) -- under the coins
rivalsBtn.Size = UDim2.fromScale(0.13, 0.05)
rivalsBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
rivalsBtn.BackgroundTransparency = 0.3
rivalsBtn.TextColor3 = Color3.new(1, 1, 1)
rivalsBtn.Font = Enum.Font.GothamBlack
rivalsBtn.TextScaled = true
rivalsBtn.Text = "RIVALS"
rivalsBtn.Parent = gui
local rivalsBtnCorner = Instance.new("UICorner")
rivalsBtnCorner.CornerRadius = UDim.new(0.3, 0)
rivalsBtnCorner.Parent = rivalsBtn

local panel = Instance.new("Frame")
panel.Name = "RivalsPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.42, 0.62)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0.06, 0)
panelCorner.Parent = panel
local function panelLabel(name: string, y: number, h: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromScale(0.05, y)
	l.Size = UDim2.fromScale(0.9, h)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = panel
	return l
end
local title = panelLabel("Title", 0.03, 0.1)
title.Font = Enum.Font.GothamBlack
title.Text = "RIVALS"
local streakLine = panelLabel("Streak", 0.14, 0.07)
streakLine.TextColor3 = Color3.fromRGB(255, 150, 40)
local rows: { TextLabel } = {}
for i = 1, 8 do
	rows[i] = panelLabel("Row" .. i, 0.23 + (i - 1) * 0.085, 0.075)
end
local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(0.97, 0.03)
close.Size = UDim2.fromScale(0.14, 0.1)
close.SizeConstraint = Enum.SizeConstraint.RelativeYY
close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBlack
close.TextScaled = true
close.Text = "X"
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0.5, 0)
closeCorner.Parent = close
rivalsBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
close.Activated:Connect(function()
	panel.Visible = false
end)

local function showRivals(list: { any }, streak: number, points: number)
	streakLine.Text = `win streak {streak}   wins {points}`
	for i, row in rows do
		local r = list[i]
		if type(r) == "table" and type(r.name) == "string" then
			local w = if type(r.wins) == "number" then r.wins else 0
			local l = if type(r.losses) == "number" then r.losses else 0
			row.Text = `{r.name}    you {w} - {l} them`
			row.TextColor3 = if w > l
				then Color3.fromRGB(120, 230, 120)
				elseif w < l then Color3.fromRGB(255, 120, 110)
				else Color3.new(1, 1, 1)
		elseif i == 1 then
			row.Text = "beat a friend's time to start!"
			row.TextColor3 = Color3.fromRGB(200, 200, 205)
		else
			row.Text = ""
		end
	end
end
showRivals({}, 0, 0)

-- short messages: likes, visit gifts
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.fromScale(0.5, 0.76)
toast.Size = UDim2.fromScale(0.5, 0.06)
toast.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0.4, 0)
toastCorner.Parent = toast
local toasts = 0
local function showToast(text: string)
	toasts += 1
	local mine = toasts
	toast.Text = text
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.3
	task.delay(2.5, function()
		if toasts == mine then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end
	end)
end

-- shown when this server can't save (Studio without API access, DataStore down)
local noSave = Instance.new("TextLabel")
noSave.Name = "NotSaving"
noSave.AnchorPoint = Vector2.new(0, 0)
noSave.Position = UDim2.new(0, 0, 1, 2)
noSave.Size = UDim2.fromScale(1, 0.5)
noSave.BackgroundTransparency = 1
noSave.TextColor3 = Color3.fromRGB(255, 110, 100)
noSave.TextStrokeTransparency = 0.4
noSave.Font = Enum.Font.GothamBold
noSave.TextScaled = true
noSave.Text = "NOT SAVING"
noSave.Visible = false
noSave.Parent = chip

local pop = Instance.new("TextLabel")
pop.Name = "MedalPop"
pop.AnchorPoint = Vector2.new(0.5, 0.5)
pop.Position = UDim2.fromScale(0.5, 0.62) -- under the drift score pop
pop.Size = UDim2.fromScale(0.56, 0.16)
pop.BackgroundTransparency = 1
pop.Font = Enum.Font.GothamBlack
pop.TextScaled = true
pop.RichText = true
pop.TextColor3 = Color3.new(1, 1, 1)
pop.TextStrokeColor3 = Color3.new(0, 0, 0)
pop.TextTransparency = 1
pop.TextStrokeTransparency = 1
pop.Parent = gui
local popScale = Instance.new("UIScale")
popScale.Parent = pop

local shown = 0 -- pops in a row: an old pop's fade must not hide a newer one
local function showPop(text: string, color: Color3)
	shown += 1
	local mine = shown
	pop.Text = text
	pop.TextColor3 = color
	pop.TextTransparency = 0
	pop.TextStrokeTransparency = 0.3
	popScale.Scale = 0.6
	TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.8, function()
		if shown ~= mine then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(pop, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- ===== weekend banner and the daily gift =====

-- "2X COINS" over the top of the screen while workspace.CoinBoost is 2 (Saturday and Sunday)
local banner = Instance.new("TextLabel")
banner.Name = "WeekendBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 122) -- under the friends button
banner.Size = UDim2.fromScale(0.34, 0.055)
banner.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
banner.TextColor3 = Color3.fromRGB(70, 35, 0)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Text = "2X COINS WEEKEND!"
banner.Visible = false
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0.4, 0)
bannerCorner.Parent = banner
local bannerRim = Instance.new("UIStroke")
bannerRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bannerRim.Color = Color3.fromRGB(176, 112, 10)
bannerRim.Thickness = 2
bannerRim.Parent = banner
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
TweenService:Create(
	bannerScale,
	TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Scale = 1.06 }
):Play()
local function showBanner()
	banner.Visible = workspace:GetAttribute("CoinBoost") == 2
end
workspace:GetAttributeChangedSignal("CoinBoost"):Connect(showBanner)
showBanner()

-- the daily gift card: "DAY 3!" and a strip of the 7 days, today's lit up. Tap to close.
local DAILY = Profile.DAILY
local card = Instance.new("TextButton")
card.Name = "DailyGift"
card.AutoButtonColor = false
card.Text = ""
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.45)
card.Size = UDim2.fromScale(0.62, 0.36)
card.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
card.BackgroundTransparency = 0.08
card.Visible = false
card.Parent = gui
local cardRatio = Instance.new("UIAspectRatioConstraint")
cardRatio.AspectRatio = 2.3
cardRatio.Parent = card
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0.08, 0)
cardCorner.Parent = card
local cardRim = Instance.new("UIStroke")
cardRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cardRim.Color = Color3.fromRGB(255, 196, 40)
cardRim.Thickness = 3
cardRim.Parent = card
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local function label(parent: Instance, pos: UDim2, size: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Parent = parent
	return l
end
local dayTitle =
	label(card, UDim2.fromScale(0.5, 0.17), UDim2.fromScale(0.9, 0.2), Color3.new(1, 1, 1))
local gift = label(
	card,
	UDim2.fromScale(0.5, 0.42),
	UDim2.fromScale(0.6, 0.24),
	Color3.fromRGB(255, 220, 90)
)
local days: { Frame } = {}
for i, amount in DAILY do
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.08 + (i - 1) * 0.14, 0.76)
	box.Size = UDim2.fromScale(0.12, 0.3)
	box.BackgroundColor3 = Color3.fromRGB(60, 64, 80)
	box.Parent = card
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.2, 0)
	round.Parent = box
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Color3.fromRGB(255, 230, 120)
	rim.Thickness = 0
	rim.Parent = box
	label(
		box,
		UDim2.fromScale(0.5, 0.28),
		UDim2.fromScale(0.9, 0.36),
		Color3.fromRGB(200, 205, 220)
	).Text = if i
			== #DAILY
		then `{i}+`
		else tostring(i)
	label(box, UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.9, 0.4), Color3.fromRGB(255, 220, 90)).Text =
		tostring(amount)
	table.insert(days, box)
end

local cards = 0
local function hideCard()
	card.Visible = false
end
card.Activated:Connect(hideCard)
local function showDaily(coins: number, streak: number, boost: number)
	cards += 1
	local mine = cards
	local today = math.min(streak, #DAILY)
	dayTitle.Text = if streak >= 2 then `DAY {streak} IN A ROW!` else "DAILY GIFT!"
	gift.Text = if boost >= 2 then `+{coins} coins  (2X!)` else `+{coins} coins`
	for i, box in days do
		local rim = box:FindFirstChildOfClass("UIStroke") :: UIStroke
		box.BackgroundColor3 = if i < today
			then Color3.fromRGB(70, 150, 80) -- taken
			elseif i == today then Color3.fromRGB(255, 160, 30) -- today
			else Color3.fromRGB(60, 64, 80)
		rim.Thickness = if i == today then 3 else 0
	end
	card.Visible = true
	cardScale.Scale = 0.5
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(5, function()
		if cards == mine then
			hideCard()
		end
	end)
end

local function setStars(n: number, bump: boolean)
	chip.Text = `⭐ {n}`
	if bump then
		chipScale.Scale = 1.4
		TweenService:Create(chipScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end
end

remote.OnClientEvent:Connect(function(kind: unknown, info: unknown, saving: unknown, ...: unknown)
	if kind == "stars" and type(info) == "number" then
		setStars(info, false)
		noSave.Visible = saving == false
		return
	end
	if kind == "coins" and type(info) == "number" then
		coinChip.Text = tostring(info)
		return
	end
	if kind == "bolts" and type(info) == "number" then
		-- ("bolts", found, total, onRock)
		local total = saving
		boltChip.Text = `BOLTS {info}/{if type(total) == "number" then total else 5}`
		boltChip.Visible = select(1, ...) == true
		return
	end
	if kind == "rivals" and type(info) == "table" then
		local streak = if type(saving) == "number" then saving else 0
		local points = select(1, ...)
		showRivals(info :: { any }, streak, if type(points) == "number" then points else 0)
		return
	end
	if kind == "bolt" and type(info) == "number" then
		foundBolts[info] = true
		hideFound()
		return
	end
	if kind == "boltsFound" and type(info) == "table" then
		for _, id in info :: { any } do
			if type(id) == "number" then
				foundBolts[id] = true
			end
		end
		hideFound()
		return
	end
	if kind == "daily" and type(info) == "number" and type(saving) == "number" then
		-- ("daily", coins, days in a row, boost)
		local boost = select(1, ...)
		showDaily(info, saving, if type(boost) == "number" then boost else 1)
		return
	end
	if kind == "toast" and type(info) == "string" then
		showToast(info)
		return
	end
	if kind ~= "run" or type(info) ~= "table" then
		return
	end
	local r = info :: any
	local medal = if type(r.medal) == "number" then r.medal else 0
	local lines: { string } = {}
	if medal > 0 then
		local line = `{NAMES[medal]}  {r.text}`
		if type(r.gained) == "number" and r.gained > 0 then
			line ..= `  +{r.gained} ⭐`
		end
		table.insert(lines, line)
	else
		table.insert(lines, tostring(r.text))
	end
	if r.record then
		table.insert(lines, `<font color="#FFD54F">NEW PLOT RECORD!</font>`)
	elseif medal > 0 and r.own then
		table.insert(lines, `<font size="20">your plot: win stars on friends' plots</font>`)
	end
	showPop(table.concat(lines, "\n"), if medal > 0 then COLORS[medal] else Color3.new(1, 1, 1))
	if type(r.stars) == "number" then
		setStars(r.stars, type(r.gained) == "number" and r.gained > 0)
	end
end)
