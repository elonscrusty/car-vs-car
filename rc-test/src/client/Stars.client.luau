--!strict
-- Carter's stars loop, phase 1, on screen: the star count (top left, under the timer) and a pop
-- when a run ends with a medal or a plot record. The server decides everything (Stars.server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
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
gui.DisplayOrder = HudLayout.HUD
gui.Parent = player:WaitForChild("PlayerGui")

-- the lobby HUD (stars, coins, rivals, jobs, weekend banner): hidden while driving
local hud = Instance.new("ScreenGui")
hud.Name = "StarsHud"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = gui.Parent
-- fewer buttons for a brand new player: RIVALS, JOBS and the NEXT bar wait until the first
-- drive in any car (Lobby sets DroveOnce) or once you have a star; until then it is just stars,
-- coins and the way to DRIVE
local later = Instance.new("Frame")
later.Name = "AfterFirstDrive"
later.BackgroundTransparency = 1
later.Size = UDim2.fromScale(1, 1)
later.Parent = hud
local function showLater()
	local stars = player:GetAttribute("Stars")
	later.Visible = player:GetAttribute("DroveOnce") == true
		or (type(stars) == "number" and stars > 0)
end
player:GetAttributeChangedSignal("DroveOnce"):Connect(showLater)
player:GetAttributeChangedSignal("Stars"):Connect(showLater)
showLater()

-- pop-up cards (daily gift, rivals, toasts) sit on top of every other button
local top = Instance.new("ScreenGui")
top.Name = "StarsTop"
top.ResetOnSpawn = false
top.IgnoreGuiInset = true
top.DisplayOrder = HudLayout.POPUP
top.Parent = gui.Parent

local chip = Instance.new("TextLabel")
chip.Name = "StarCount"
HudLayout.place(chip, "StarCount")
chip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
chip.BackgroundTransparency = 0.3
chip.TextColor3 = Color3.fromRGB(255, 213, 79)
chip.Font = Enum.Font.GothamBlack
chip.TextScaled = true
chip.Text = "⭐ 0"
chip.Parent = hud
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0.3, 0)
chipCorner.Parent = chip
local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

-- coins, beside the stars
local coinChip = chip:Clone()
coinChip.Name = "CoinCount"
HudLayout.place(coinChip, "CoinCount")
coinChip.TextColor3 = Color3.fromRGB(255, 236, 150)
coinChip.Text = "0"
coinChip.Parent = hud
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
HudLayout.place(boltChip, "BoltCount", "drive")
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
HudLayout.place(rivalsBtn, "Rivals")
rivalsBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
rivalsBtn.BackgroundTransparency = 0.3
rivalsBtn.TextColor3 = Color3.new(1, 1, 1)
rivalsBtn.Font = Enum.Font.GothamBlack
rivalsBtn.TextScaled = true
rivalsBtn.Text = "RIVALS"
rivalsBtn.Parent = later
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
panel.Parent = top
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
	-- a new player has no rivals yet: no button to wonder about until they do
	rivalsBtn.Visible = #list > 0 or points > 0
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

-- daily jobs: a small JOBS 1/3 chip under the chips; tap it to open the list (new players see
-- one short chip, not a wall of words)
local jobs = Instance.new("Frame")
jobs.Name = "DailyJobs"
HudLayout.place(jobs, "DailyJobs")
jobs.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
jobs.BackgroundTransparency = 0.3
jobs.Visible = false -- until the server sends them
jobs.Parent = later
local jobsCorner = Instance.new("UICorner")
jobsCorner.CornerRadius = UDim.new(0.08, 0)
jobsCorner.Parent = jobs
local jobsPad = Instance.new("UIPadding")
jobsPad.PaddingLeft = UDim.new(0.04, 0)
jobsPad.PaddingRight = UDim.new(0.04, 0)
jobsPad.PaddingTop = UDim.new(0.04, 0)
jobsPad.PaddingBottom = UDim.new(0.04, 0)
jobsPad.Parent = jobs
local jobsTitle = Instance.new("TextButton")
jobsTitle.Name = "Title"
jobsTitle.Size = UDim2.fromScale(1, 0.22)
jobsTitle.BackgroundTransparency = 1
jobsTitle.TextColor3 = Color3.fromRGB(255, 213, 79)
jobsTitle.Font = Enum.Font.GothamBlack
jobsTitle.TextScaled = true
jobsTitle.TextXAlignment = Enum.TextXAlignment.Left
jobsTitle.Text = "DAILY JOBS"
jobsTitle.Parent = jobs
local jobRows: { TextLabel } = {}
for i = 1, 3 do
	local row = Instance.new("TextLabel")
	row.Name = "Job" .. i
	row.Position = UDim2.fromScale(0, 0.26 * i)
	row.Size = UDim2.fromScale(1, 0.22)
	row.BackgroundTransparency = 1
	row.TextColor3 = Color3.new(1, 1, 1)
	row.Font = Enum.Font.GothamBold
	row.TextScaled = true
	row.RichText = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = jobs
	jobRows[i] = row
end
local folded = true
local resetAt = 0 -- os.time() when new jobs come
local jobsDone, jobsAll = 0, 0
local waitText = ""
local function showTitle()
	if folded then
		jobsTitle.Text = `JOBS {jobsDone}/{jobsAll}  ▼`
	else
		jobsTitle.Text = if waitText ~= ""
			then `DAILY JOBS  <font color="#AAB2BD">new in {waitText}</font>`
			else "DAILY JOBS"
	end
end
local function showFold()
	for _, row in jobRows do
		row.Visible = not folded
	end
	HudLayout.place(jobs, "DailyJobs")
	if folded then
		jobs.Size = UDim2.fromOffset(130, 34)
	end
	jobsTitle.Size = UDim2.fromScale(1, if folded then 1 else 0.22)
	showTitle()
end
jobsTitle.Activated:Connect(function()
	folded = not folded
	showFold()
end)
local function showJobs(lines: { any })
	jobsDone, jobsAll = 0, 0
	for i, row in jobRows do
		local l = lines[i]
		if type(l) == "table" and type(l.text) == "string" then
			jobsAll += 1
			jobsDone += if l.done then 1 else 0
			if l.done then
				row.Text = `<font color="#7CE08A">✓ {l.text}</font>`
			else
				row.Text = `{l.text}  <font color="#FFD54F">{l.have}/{l.goal}  +{l.coins}</font>`
			end
		else
			row.Text = ""
		end
	end
	jobs.Visible = true
	showFold()
end
-- how long until new jobs, in the title
task.spawn(function()
	while true do
		local left = resetAt - os.time()
		if resetAt > 0 and left > 0 then
			local h, m = math.floor(left / 3600), math.floor(left % 3600 / 60)
			local wait = if h > 0 then `{h}h` else `{math.max(m, 1)}m`
			waitText = wait
			showTitle()
		end
		task.wait(20)
	end
end)
jobsTitle.RichText = true

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
toast.Parent = top
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
noSave.AnchorPoint = Vector2.new(0, 1)
noSave.Position = UDim2.new(0, 0, 0, -2) -- above the chip: RIVALS sits under it
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
pop.Parent = top
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
HudLayout.place(banner, "WeekendBanner") -- under the NEXT RACE chip
banner.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
banner.TextColor3 = Color3.fromRGB(70, 35, 0)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Text = "2X COINS WEEKEND!"
banner.Visible = false
banner.Parent = hud
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
-- a few seconds when it starts (or you join), then out of the way: fewer things on screen
local bannerShows = 0
local function showBanner()
	bannerShows += 1
	local mine = bannerShows
	banner.Visible = workspace:GetAttribute("CoinBoost") == 2
	task.delay(6, function()
		if mine == bannerShows then
			banner.Visible = false
		end
	end)
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
card.Parent = top
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
	-- a brand new player sees the way to their plot first: the gift waits until they have driven
	-- once (PlotGuide sets HasDriven) and are back on foot, so it never covers the road; and no
	-- race, race card or prize card is up (three cards stacked in the middle, tour3-03)
	local me = Players.LocalPlayer
	local pg = me:WaitForChild("PlayerGui")
	local function calm(): boolean
		local race = pg:FindFirstChild("ServerRace")
		local prizeCard = pg:FindFirstChild("RacePrize", true)
		return me:GetAttribute("HasDriven") == true
			and me:GetAttribute("Driving") ~= true
			and me:GetAttribute("Building") ~= true -- (it hid behind the build screen, tour 2)
			and not (race and race:GetAttribute("Busy") == true)
			and not (prizeCard and (prizeCard :: GuiObject).Visible)
	end
	local waited, still = 0, 0
	while still < 3 and waited < 600 do
		local dt = task.wait(1)
		waited += dt
		still = if calm() then still + dt else 0
	end
	if cards ~= mine then
		return
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

-- ===== coins fly into your total (after a race, a gift, a job) =====
-- More coins than the chip shows: little gold coins fly from the middle of the screen into the
-- chip and it counts up. While you drive (the chip is hidden) they wait until you walk again.
local coinScale = coinChip:FindFirstChildOfClass("UIScale") :: UIScale
local shownCoins: number? = nil
local targetCoins = 0
local flying = false
local heldGoal: any = nil -- a goal that came in while coins fly (its bar fills after they land)
local goalHeld = false

local function drawCoin(parent: Instance, px: number): Frame
	local c = Instance.new("Frame")
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Size = UDim2.fromOffset(px, px)
	c.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
	c.ZIndex = 5
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = c
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(176, 112, 10)
	rim.Thickness = 2
	rim.Parent = c
	c.Parent = parent
	return c
end

local showGoalNow: (any) -> () -- set below, with the goal bar

local function releaseGoal()
	if goalHeld then
		goalHeld = false
		showGoalNow(heldGoal)
	end
end

local function flyCoins()
	if flying or shownCoins == nil or not hud.Enabled then
		return
	end
	local from = shownCoins :: number
	local gain = targetCoins - from
	if gain <= 0 then
		releaseGoal()
		return
	end
	flying = true
	local count = math.clamp(3 + gain // 15, 3, 10)
	local view = workspace.CurrentCamera.ViewportSize
	local chipPos = coinChip.AbsolutePosition + coinChip.AbsoluteSize / 2
	local start = Vector2.new(view.X * 0.5, view.Y * 0.55)
	-- "+N" by the chip
	local plus = Instance.new("TextLabel")
	plus.AnchorPoint = Vector2.new(0, 0.5)
	plus.Position =
		UDim2.fromOffset(coinChip.AbsolutePosition.X + coinChip.AbsoluteSize.X + 6, chipPos.Y)
	plus.Size = UDim2.fromOffset(110, 30)
	plus.BackgroundTransparency = 1
	plus.Font = Enum.Font.GothamBlack
	plus.TextScaled = true
	plus.TextXAlignment = Enum.TextXAlignment.Left
	plus.TextColor3 = Color3.fromRGB(255, 213, 79)
	plus.TextStrokeTransparency = 0.3
	plus.Text = `+{gain}`
	plus.Parent = top
	for i = 1, count do
		task.delay((i - 1) * 0.08, function()
			local c = drawCoin(top, 26)
			local spread = Vector2.new(math.random(-90, 90), math.random(-50, 50))
			c.Position = UDim2.fromOffset(start.X + spread.X, start.Y + spread.Y)
			local t = TweenService:Create(
				c,
				TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(chipPos.X, chipPos.Y),
					Size = UDim2.fromOffset(14, 14),
				}
			)
			t.Completed:Connect(function()
				c:Destroy()
				-- count up a share of the coins with each one that lands
				local now = if i == count then targetCoins else from + math.floor(gain * i / count)
				coinChip.Text = tostring(now)
				shownCoins = now
				coinScale.Scale = 1.25
				TweenService
					:Create(coinScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 })
					:Play()
				if i == count then
					flying = false
					task.delay(0.6, function()
						plus:Destroy()
					end)
					releaseGoal()
					-- more came in while these flew
					flyCoins()
				end
			end)
			t:Play()
		end)
	end
end

local function setCoins(n: number)
	targetCoins = n
	if shownCoins == nil or n < (shownCoins :: number) then
		shownCoins = n -- first count, or coins spent: no show
		if not flying then
			coinChip.Text = tostring(n)
			releaseGoal()
		end
		return
	end
	flyCoins()
end

-- ===== the next unlock (walk HUD) and the race prize card =====

local GOLD = Color3.fromRGB(255, 213, 79)
local GREEN = Color3.fromRGB(110, 225, 120)

-- every tile free (the server's test switch: AllTilesFree, or Studio unless it is set false)
local function tilesFree(): boolean
	local free = workspace:GetAttribute("AllTilesFree")
	return free == true or (free ~= false and RunService:IsStudio())
end

local function goalText(g: any): (string, string, number)
	-- (what it is, how far, fill 0..1)
	local what = if g.kind == "car"
		then `NEXT CAR: {g.name}`
		elseif g.kind == "tile" then `NEXT TILE: {g.name}`
		else `BIGGER TRACK: {g.name}`
	local unit = if g.kind == "grid" then "⭐" else "coins"
	local fill = if g.price > 0 then math.clamp(g.have / g.price, 0, 1) else 1
	if g.ready then
		return what, if g.kind == "car" then "BUY IT IN THE CAR SHOP!" else "BUY IT IN THE SHOP!", 1
	end
	return what, `{g.have} / {g.price} {unit}`, fill
end

local function bar(parent: Instance, y: number, h: number): Frame
	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Position = UDim2.fromScale(0, y)
	back.Size = UDim2.fromScale(1, h)
	back.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	back.Parent = parent
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.Parent = back
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = fill
	return back
end

local function textLine(
	parent: Instance,
	y: number,
	h: number,
	color: Color3,
	font: Enum.Font
): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.Font = font
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local nextBox = Instance.new("Frame")
nextBox.Name = "NextUnlock"
HudLayout.place(nextBox, "NextUnlock")
nextBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
nextBox.BackgroundTransparency = 0.3
nextBox.Visible = false -- until the server sends a goal
nextBox.Parent = later
local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(0.2, 0)
nextCorner.Parent = nextBox
local nextPad = Instance.new("UIPadding")
nextPad.PaddingLeft = UDim.new(0.04, 0)
nextPad.PaddingRight = UDim.new(0.04, 0)
nextPad.PaddingTop = UDim.new(0.1, 0)
nextPad.PaddingBottom = UDim.new(0.1, 0)
nextPad.Parent = nextBox
local nextRim = Instance.new("UIStroke")
nextRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
nextRim.Color = GREEN
nextRim.Thickness = 2
nextRim.Enabled = false
nextRim.Parent = nextBox
local nextWhat = textLine(nextBox, 0, 0.45, GOLD, Enum.Font.GothamBlack)
local nextHow = textLine(nextBox, 0.45, 0.3, Color3.new(1, 1, 1), Enum.Font.GothamBold)
nextHow.Size = UDim2.fromScale(0.6, 0.3)
local nextBar = bar(nextBox, 0.82, 0.18)
nextHow.Position = UDim2.fromScale(0, 0.47)

local function showGoalBar(g: any)
	-- every tile is free (Studio switch): no tile to save up for
	local allFree = tilesFree()
	if
		type(g) ~= "table"
		or type(g.name) ~= "string"
		or type(g.price) ~= "number"
		or (allFree and g.kind == "tile")
	then
		nextBox.Visible = false
		player:SetAttribute("GoalReady", false)
		return
	end
	-- PlotGuide sends the arrows to the shops (GO SHOP!) while this is true
	player:SetAttribute("GoalReady", g.ready == true)
	local what, how, fill = goalText(g)
	nextWhat.Text = what
	nextHow.Text = how
	nextHow.Size = UDim2.fromScale(if g.ready then 1 else 0.6, 0.3)
	nextHow.TextColor3 = if g.ready then GREEN else Color3.new(1, 1, 1)
	nextRim.Enabled = g.ready == true
	local f = nextBar:FindFirstChild("Fill") :: Frame
	f.BackgroundColor3 = if g.ready then GREEN else GOLD
	TweenService:Create(f, TweenInfo.new(0.4), { Size = UDim2.fromScale(fill, 1) }):Play()
	nextBox.Visible = true
end

-- after a server race: your place, the coins, and the goal bar filling up
showGoalNow = showGoalBar
-- while coins are flying in, the bar waits and fills when they land
local function showGoal(g: any)
	if flying or (shownCoins ~= nil and targetCoins > (shownCoins :: number)) then
		heldGoal, goalHeld = g, true
		return
	end
	showGoalBar(g)
end

local prize = Instance.new("Frame")
prize.Name = "RacePrize"
prize.AnchorPoint = Vector2.new(0.5, 0)
prize.Position = UDim2.fromScale(0.5, 0.64)
prize.Size = UDim2.fromScale(0.4, 0.16)
prize.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
prize.BackgroundTransparency = 0.08
prize.Visible = false
prize.Parent = top
local prizeCorner = Instance.new("UICorner")
prizeCorner.CornerRadius = UDim.new(0.12, 0)
prizeCorner.Parent = prize
local prizeRim = Instance.new("UIStroke")
prizeRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
prizeRim.Color = GOLD
prizeRim.Thickness = 3
prizeRim.Parent = prize
local prizePad = Instance.new("UIPadding")
prizePad.PaddingLeft = UDim.new(0.04, 0)
prizePad.PaddingRight = UDim.new(0.04, 0)
prizePad.PaddingTop = UDim.new(0.08, 0)
prizePad.PaddingBottom = UDim.new(0.08, 0)
prizePad.Parent = prize
local prizeScale = Instance.new("UIScale")
prizeScale.Parent = prize
local prizeTitle = textLine(prize, 0, 0.4, GOLD, Enum.Font.GothamBlack)
prizeTitle.TextXAlignment = Enum.TextXAlignment.Center
local prizeGoal = textLine(prize, 0.46, 0.24, Color3.new(1, 1, 1), Enum.Font.GothamBold)
prizeGoal.TextXAlignment = Enum.TextXAlignment.Center
local prizeBar = bar(prize, 0.78, 0.18)
local prizeShows = 0

-- After a server race (its result card shows first): how far your coins got you to the goal.
local lastGoal: any = nil
local function showPrize(before: any)
	local g = lastGoal
	if type(g) ~= "table" or type(g.name) ~= "string" or type(g.price) ~= "number" then
		return
	end
	local gained = if type(before) == "table"
			and before.kind ~= "grid"
			and g.kind ~= "grid"
		then g.have - before.have
		else 0
	-- one coin number only (the result row has it): this card is what the coins are FOR
	if tilesFree() and g.kind == "tile" then
		return
	end
	local what, how, fill = goalText(g)
	prizeTitle.Text = what
	prizeTitle.TextColor3 = GOLD
	prizeRim.Color = if gained > 0 or g.ready then GOLD else Color3.fromRGB(120, 120, 130)
	prizeGoal.Text = how
	prizeGoal.TextColor3 = if g.ready then GREEN else Color3.new(1, 1, 1)
	local f = prizeBar:FindFirstChild("Fill") :: Frame
	f.BackgroundColor3 = if g.ready then GREEN else GOLD
	-- the bar fills from what you had to what you have now
	local from = if gained > 0 and g.price > 0
		then math.clamp((g.have - gained) / g.price, 0, 1)
		else fill
	f.Size = UDim2.fromScale(from, 1)
	task.delay(0.6, function()
		TweenService
			:Create(
				f,
				TweenInfo.new(0.8, Enum.EasingStyle.Quad),
				{ Size = UDim2.fromScale(fill, 1) }
			)
			:Play()
	end)
	prizeShows += 1
	local mine = prizeShows
	-- just under the race result card (it grows with the racers), else its usual spot
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	local race = if pgui then pgui:FindFirstChild("ServerRace") else nil
	local result = if race then race:FindFirstChild("Result") else nil
	local y = 0.64
	local bottom = if result then result:GetAttribute("Bottom") else nil
	if result and result:IsA("GuiObject") and result.Visible and type(bottom) == "number" then
		y = math.max(y, bottom + 0.02)
	end
	prize.Position = UDim2.fromScale(0.5, math.min(y, 0.8))
	prize.Visible = true
	prizeScale.Scale = 0.6
	TweenService:Create(prizeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 })
		:Play()
	task.delay(6, function()
		if mine == prizeShows then
			prize.Visible = false
		end
	end)
end
task.spawn(function()
	local raceEvent = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent
	raceEvent.OnClientEvent:Connect(function(kind: unknown)
		if kind == "result" then
			-- the race pay comes in the next second or two: show the goal after it
			local before = lastGoal
			task.delay(2.5, function()
				showPrize(before)
			end)
		end
	end)
end)

remote.OnClientEvent:Connect(function(kind: unknown, info: unknown, saving: unknown, ...: unknown)
	if kind == "stars" and type(info) == "number" then
		setStars(info, false)
		noSave.Visible = saving == false
		return
	end
	if kind == "goal" then
		lastGoal = info
		showGoal(info)
		return
	end
	if kind == "coins" and type(info) == "number" then
		setCoins(info)
		return
	end
	if kind == "bolts" and type(info) == "number" then
		-- ("bolts", found, total, onRock)
		local total = saving
		boltChip.Text = `BOLTS {info}/{if type(total) == "number" then total else 5}`
		boltChip.Visible = false -- no rock plots any more: bolts stay out of sight
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
		task.spawn(showDaily, info, saving, if type(boost) == "number" then boost else 1) -- it may wait
		return
	end
	if kind == "jobs" and type(info) == "table" then
		-- ("jobs", lines, secondsToNewJobs)
		if type(saving) == "number" then
			resetAt = os.time() + saving
		end
		showJobs(info :: { any })
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

-- hide the lobby HUD while this player drives (Lobby.setDriving sets the attribute)
local function showWalkHud()
	hud.Enabled = player:GetAttribute("Driving") ~= true and player:GetAttribute("Building") ~= true
	if hud.Enabled then
		task.delay(0.5, flyCoins) -- coins won while driving fly in now
	end
end
player:GetAttributeChangedSignal("Driving"):Connect(showWalkHud)
player:GetAttributeChangedSignal("Building"):Connect(showWalkHud)
showWalkHud()
