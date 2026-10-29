--!strict
-- Carter's stars loop, phase 1, on screen: the star count (top left, under the timer) and a pop
-- when a run ends with a medal or a plot record. The server decides everything (Stars.server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Crates = require(ReplicatedStorage.Shared.Crates)
local CvcLayout = require(ReplicatedStorage.Shared.CvcLayout)
local Features = require(ReplicatedStorage.Shared.Features)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local KartStyle = require(ReplicatedStorage.Shared.KartStyle)
local Popup = require(script.Parent:WaitForChild("Popup"))
local Ui = script.Parent:WaitForChild("Ui")
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))
local Windows = require(Ui:WaitForChild("Screens"):WaitForChild("Windows"))
local Screen = require(Ui:WaitForChild("Screen"))
local StageGate = require(script.Parent:WaitForChild("StageGate"))
local Profile = require(ReplicatedStorage.Shared.Profile)

local remote = ReplicatedStorage:WaitForChild("StarsEvent") :: RemoteEvent
local player = Players.LocalPlayer

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
-- the screen's top left in AbsolutePosition terms (those start under Roblox's top bar)
local topOrigin = Instance.new("Frame")
topOrigin.Name = "Kart_Origin"
topOrigin.BackgroundTransparency = 1
topOrigin.Size = UDim2.fromOffset(0, 0)
topOrigin.Parent = top

local chip = Instance.new("TextLabel")
chip.Name = "StarCount"
HudLayout.place(chip, "StarCount")
chip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
chip.BackgroundTransparency = 0.3
chip.TextColor3 = Color3.fromRGB(255, 213, 79)
chip.Font = Enum.Font.LuckiestGuy
chip.TextScaled = true
chip.Text = "⭐ 0"
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0.3, 0)
chipCorner.Parent = chip
local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

-- shown when this server can't save (Studio without API access, DataStore down)
local NO_SAVE_X = 180 -- px: past Roblox's three top left buttons
local noSave = Instance.new("TextLabel")
noSave.Name = "NotSaving"
-- up in Roblox's top bar, right of its menu buttons (over the coins chip they hid the NOT,
-- Studio polish-7)
noSave.Position = UDim2.fromOffset(NO_SAVE_X, 18)
noSave.Size = UDim2.fromOffset(260, 24)
noSave.TextXAlignment = Enum.TextXAlignment.Left
noSave.BackgroundTransparency = 1
noSave.TextColor3 = Color3.fromRGB(255, 110, 100)
noSave.TextStrokeTransparency = 0.4
noSave.Font = Enum.Font.LuckiestGuy
noSave.TextScaled = true
noSave.Text = "NOT SAVING"
noSave.Visible = false

-- coins, beside the stars
local coinChip = chip:Clone()
coinChip.Name = "CoinCount"
HudLayout.place(coinChip, "CoinCount")
coinChip.TextColor3 = Color3.fromRGB(255, 236, 150)
coinChip.Text = "0"
coinChip.Parent = hud
noSave.Parent = if Features.CVC and Features.NEW_UI then top else hud
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
jobsTitle.Font = Enum.Font.LuckiestGuy
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
	row.Font = Enum.Font.LuckiestGuy
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
			then `DAILY JOBS  <font color="#AAB2BD">new in {waitText}</font>  ▲`
			else "DAILY JOBS  ▲"
	end
end
local function showFold()
	for _, row in jobRows do
		row.Visible = not folded
	end
	HudLayout.place(jobs, "DailyJobs")
	if folded then
		jobs.Size = UDim2.fromOffset(CvcLayout.JOBS_CHIP[1], CvcLayout.JOBS_CHIP[2])
	end
	jobsTitle.Size = UDim2.fromScale(1, if folded then 1 else 0.22)
	jobs:SetAttribute("Open", not folded) -- (CvcHowTo: the how-to tip waits while it's open)
	showTitle()
end
local unfoldId = 0
jobsTitle.Activated:Connect(function()
	folded = not folded
	showFold()
	-- the open list folds itself again after a while: it covers the view on a phone
	unfoldId += 1
	local me = unfoldId
	if not folded then
		task.delay(10, function()
			if me == unfoldId and not folded then
				folded = true
				showFold()
			end
		end)
	end
end)
local hasJobs = false -- the server has sent today's jobs
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
	hasJobs = true
	jobs.Visible = player:GetAttribute("TipHidesJobs") ~= true
	showFold()
end
-- Car VS Car: a how-to tip that can't keep clear of this chip (it sits right under CRATE! and MY
-- GARAGE: the arrow covered JOBS 2/3, Studio final-31) has it step away while it shows
player:GetAttributeChangedSignal("TipHidesJobs"):Connect(function()
	jobs.Visible = hasJobs and player:GetAttribute("TipHidesJobs") ~= true
end)
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
toast.Font = Enum.Font.LuckiestGuy
toast.TextScaled = true
toast.Parent = top
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0.4, 0)
toastCorner.Parent = toast
local toasts = 0
-- (Features.NEW_UI: a new-look shout, the same words style as every new screen)
local toastGui: any = nil
local function shoutToast(text: string, mine: number)
	if not toastGui then
		toastGui = Base.screen("Ui_Toast", Base.ORDER.popup)
		Base.show(toastGui, true)
	end
	toastGui.canvas:ClearAllChildren()
	local l = Kit.shout(toastGui.canvas, 158, 270, 440, 36, string.upper(text), "go")
	task.delay(2.6, function()
		if toasts == mine and l.Parent then
			(l.Parent :: Instance):Destroy()
		end
	end)
end
local function toastNow(text: string)
	toasts += 1
	local mine = toasts
	if Features.CVC and Features.NEW_UI then
		shoutToast(text, mine)
		return
	end
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

-- Car VS Car: after a race the words wait their turn, one at a time, after the result and the
-- win cards (CvcLayout.AFTER_RACE: +50 COINS: JOB DONE! sat on the result's rows, Studio final-49)
local toastQueue: { string } = {}
local function showToast(text: string)
	if not Features.CVC then
		toastNow(text)
		return
	end
	table.insert(toastQueue, text)
	if #toastQueue > 1 then
		return -- (the first one's loop shows it)
	end
	task.spawn(function()
		task.wait(0.5) -- (the result card comes up with the race's end: give it a beat)
		while #toastQueue > 0 do
			CvcLayout.waitTurn(gui.Parent :: Instance, "Toast", 30)
			toastNow(toastQueue[1])
			task.wait(2.9)
			table.remove(toastQueue, 1)
		end
	end)
end

-- shown when this server can't save (Studio without API access, DataStore down)

local pop = Instance.new("TextLabel")
pop.Name = "MedalPop"
pop.Text = "" -- (not Roblox's "Label" while it waits)
pop.AnchorPoint = Vector2.new(0.5, 0.5)
pop.Position = UDim2.fromScale(0.5, 0.62) -- under the drift score pop
pop.Size = UDim2.fromScale(0.56, 0.16)
pop.BackgroundTransparency = 1
pop.Font = Enum.Font.LuckiestGuy
pop.TextScaled = true
pop.RichText = true
pop.TextColor3 = Color3.new(1, 1, 1)
pop.TextStrokeColor3 = Color3.new(0, 0, 0)
pop.TextTransparency = 1
pop.TextStrokeTransparency = 1
pop.Parent = top
pop.BackgroundColor3 = Color3.fromRGB(30, 32, 44) -- (shown only under the race result card)
local popCorner = Instance.new("UICorner")
popCorner.CornerRadius = UDim.new(0.2, 0)
popCorner.Parent = pop
local popPad = Instance.new("UIPadding")
popPad.PaddingLeft = UDim.new(0.03, 0)
popPad.PaddingRight = UDim.new(0.03, 0)
popPad.PaddingTop = UDim.new(0.08, 0)
popPad.PaddingBottom = UDim.new(0.08, 0)
popPad.Parent = pop
local popScale = Instance.new("UIScale")
popScale.Parent = pop

-- the race result card's bottom edge (screen scale) while it is up, else nil:
-- the medal pop and the prize card stack under it with a gap, never on it
local function resultBottom(): number?
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	local race = if pgui then pgui:FindFirstChild("ServerRace") else nil
	local result = if race then race:FindFirstChild("Result") else nil
	local bottom = if result then result:GetAttribute("Bottom") else nil
	if result and result:IsA("GuiObject") and result.Visible and type(bottom) == "number" then
		return bottom
	end
	return nil
end

local GAP = 0.04 -- between stacked cards (their rims and the pop-in bounce need the room)
local popBottom = 0 -- where the pop ends while it shows (the prize card goes under it)
local popUntil = 0

local function placePop()
	local under = resultBottom()
	if under then
		-- the result card is up: a smaller pop just under it
		pop.AnchorPoint = Vector2.new(0.5, 0)
		pop.Position = UDim2.fromScale(0.5, under + GAP)
		pop.Size = UDim2.fromScale(0.56, 0.11)
		popBottom = under + GAP + 0.11
		-- a dark backing like the card's: here it sits over the car and its world labels
		pop.BackgroundTransparency = 0.25
	else
		pop.AnchorPoint = Vector2.new(0.5, 0.5)
		pop.Position = UDim2.fromScale(0.5, 0.62)
		pop.Size = UDim2.fromScale(0.56, 0.16)
		popBottom = 0.7
		pop.BackgroundTransparency = 1
	end
end

-- ===== weekend banner and the daily gift =====

-- "2X COINS" over the top of the screen while workspace.CoinBoost is 2 (Saturday and Sunday)
local banner = Instance.new("TextLabel")
banner.Name = "WeekendBanner"
HudLayout.place(banner, "WeekendBanner") -- under the NEXT RACE chip
banner.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
banner.TextColor3 = Color3.fromRGB(70, 35, 0)
banner.Font = Enum.Font.LuckiestGuy
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
	l.Font = Enum.Font.LuckiestGuy
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

-- Is gui's `name` on screen (it and every frame it sits in)?
local function shownIn(gui: Instance?, name: string): boolean
	local f = gui and gui:FindFirstChild(name, true)
	if not (f and f:IsA("GuiObject") and f.Visible) then
		return false
	end
	local up = f.Parent
	while up and up ~= gui do
		if up:IsA("GuiObject") and not up.Visible then
			return false
		end
		up = up.Parent
	end
	return not (gui and gui:IsA("ScreenGui") and not gui.Enabled)
end

local cards = 0
local function hideCard()
	card.Visible = false
end
card.Activated:Connect(hideCard)
-- a new screen window opens over it: the gift steps away (it peeked out past the Train window,
-- Studio after818 shot 10)
Players.LocalPlayer:GetAttributeChangedSignal("UiBusy"):Connect(function()
	if Players.LocalPlayer:GetAttribute("UiBusy") == true then
		hideCard()
	end
end)
local function showDaily(coins: number, streak: number, boost: number, crate: boolean)
	cards += 1
	local mine = cards
	local today = math.min(streak, #DAILY)
	dayTitle.Text = if streak >= 2 then `DAY {streak} IN A ROW!` else "DAILY GIFT!"
	gift.Text = (if boost >= 2 then `+{coins} coins  (2X!)` else `+{coins} coins`)
		.. if crate then "  + FREE CRATE!" else ""
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
		-- (Car VS Car has no drive from your pad: the gift comes after the first crate instead)
		return (crate or me:GetAttribute("HasDriven") == true)
			and me:GetAttribute("Driving") ~= true
			and me:GetAttribute("Building") ~= true -- (it hid behind the build screen, tour 2)
			and not (race and race:GetAttribute("Busy") == true)
			and not (prizeCard and (prizeCard :: GuiObject).Visible)
			and not Popup.isOpen() -- (a shop or panel is up: no card on top of it)
			-- (the race result card, the win card, or a new screen is up: it waits for them, it
			-- landed under the result card, critic REPORT-1)
			and not (race and shownIn(race, "Result"))
			and not shownIn(pg:FindFirstChild("CvcRaceTop"), "Finish")
			and me:GetAttribute("UiBusy") ~= true
			and me:GetAttribute("Racing") ~= true
			-- (Smash: never on top of a crate reveal, the match end or any window, and not in a
			-- match: it waits for the garage or the warm-up yard, Studio 10-29)
			and not Screen.anyOver()
			and me:GetAttribute("InMatch") ~= true
	end
	-- (no give-up time: after one it opened on top of a match or a reveal; it waits for calm)
	local still = 0
	while still < 3 and cards == mine do
		local dt = task.wait(1)
		still = if calm() then still + dt else 0
	end
	if cards ~= mine then
		return
	end
	-- (Features.NEW_UI: the new Daily rewards window, the same look as every other window; the
	-- gift is already given, so its button just takes it)
	if Features.CVC and Features.NEW_UI then
		local tiles = {}
		for i = 1, #DAILY - 1 do
			table.insert(tiles, {
				icon = "coin",
				amount = if i == today then tostring(coins) else tostring(DAILY[i]),
				state = if i < today then "got" elseif i == today then "today" else "later",
			})
		end
		local h: any = nil
		local watch: RBXScriptConnection? = nil
		local close = function()
			if watch then
				watch:Disconnect()
				watch = nil
			end
			if h then
				h.close()
			end
		end
		h = Windows.daily({
			streak = streak,
			today = today,
			day7 = if today >= #DAILY then `+{coins} TODAY!` else `{DAILY[#DAILY]} COINS`,
			days = tiles,
			claimWords = if crate then `+{coins} + CRATE!` else `+{coins} COINS!`,
		}, { claim = close, close = close })
		-- a match started with it still up (a re-join put you straight in, Studio round 4): it
		-- steps away and comes back in the garage or yard, after the match
		watch = me:GetAttributeChangedSignal("InMatch"):Connect(function()
			if me:GetAttribute("InMatch") ~= true then
				return
			end
			local stillUp = h ~= nil and Screen.isOpen("daily")
			close()
			if stillUp and cards == mine then
				task.spawn(showDaily, coins, streak, boost, crate)
			end
		end)
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
	if flying or shownCoins == nil or not hud.Enabled or not StageGate.shows("coins") then
		return -- (a brand new player's first coins fly in the moment the coins number shows)
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
	-- (in StarsTop's offsets: AbsolutePosition starts under Roblox's top bar, so the +N sat 58 px
	-- too high, off the top edge, Studio polish-8)
	local chipAt = coinChip.AbsolutePosition - topOrigin.AbsolutePosition
	local chipPos = chipAt + coinChip.AbsoluteSize / 2
	local start = Vector2.new(view.X * 0.5, view.Y * 0.55)
	-- "+N" where the coins come from (by the chip it went off the top, and right of it sat on the
	-- league badge)
	local plus = Instance.new("TextLabel")
	plus.Name = "CoinPlus"
	plus.AnchorPoint = Vector2.new(0.5, 1)
	plus.Position = UDim2.fromOffset(start.X, start.Y - 56)
	plus.Size = UDim2.fromOffset(140, 40)
	plus.BackgroundTransparency = 1
	plus.Font = Enum.Font.LuckiestGuy
	plus.TextScaled = true
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

-- Car VS Car: new cars come out of crates (there is no car shop: the chip said BUY IT IN THE CAR
-- SHOP! even for a car you had, Studio final-17), so the goal is the next crate
local function cvcGoal(g: any): any
	if not Features.CVC or type(g) ~= "table" then
		return g
	end
	local price = Crates.price("basic") or 200
	local c = player:GetAttribute("Coins")
	local have = if type(c) == "number" then c elseif type(g.have) == "number" then g.have else 0
	return { kind = "crate", name = "CRATE", price = price, have = have, ready = have >= price }
end

local function goalText(g: any): (string, string, number)
	-- (what it is, how far, fill 0..1)
	local what = if g.kind == "car"
		then `NEXT CAR: {g.name}`
		elseif g.kind == "crate" then "NEXT CRATE"
		else "BIGGER GARAGE"
	local unit = "coins"
	local fill = if g.price > 0 then math.clamp(g.have / g.price, 0, 1) else 1
	if g.ready and g.kind == "crate" then
		return "GET A CRATE!", "AT THE CRATE SHOP!", 1
	end
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
	back.BackgroundColor3 = Color3.fromRGB(34, 36, 64)
	back.Parent = parent
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = back
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = KartStyle.INK
	rim.Thickness = 2
	rim.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.ClipsDescendants = true
	fill.Parent = back
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = fill
	-- Kart Party: a lit top on the fill, and a shine that runs along it now and then
	local lit = Instance.new("Frame")
	lit.Name = "Lit"
	lit.BorderSizePixel = 0
	lit.BackgroundColor3 = Color3.new(1, 1, 1)
	lit.BackgroundTransparency = 0.55
	lit.Position = UDim2.new(0, 3, 0.12, 0)
	lit.Size = UDim2.new(1, -6, 0.3, 0)
	lit.Parent = fill
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0.5, 0)
	lc.Parent = lit
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.Size = UDim2.fromScale(1, 1)
	shine.Parent = fill
	local sg = Instance.new("UIGradient")
	sg.Rotation = 20
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Offset = Vector2.new(-1, 0)
	sg.Parent = shine
	TweenService:Create(
		sg,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.2),
		{ Offset = Vector2.new(1, 0) }
	):Play()
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
local nextWhat = textLine(nextBox, 0, 0.45, GOLD, Enum.Font.LuckiestGuy)
local nextHow = textLine(nextBox, 0.45, 0.3, Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
nextHow.Size = UDim2.fromScale(0.6, 0.3)
local nextBar = bar(nextBox, 0.82, 0.18)
nextHow.Position = UDim2.fromScale(0, 0.47)

-- the after-race card (below) says the same thing bigger: the small bar waits while it's up
local goalUp = false
local prizeUp = false
local function showGoalBar(g: any)
	if type(g) ~= "table" or type(g.name) ~= "string" or type(g.price) ~= "number" then
		goalUp = false
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
	TweenService
		:Create(f, TweenInfo.new(0.6, Enum.EasingStyle.Quart), { Size = UDim2.fromScale(fill, 1) })
		:Play()
	goalUp = true
	nextBox.Visible = not prizeUp
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
-- left of middle: the right edge (0.58) stays clear of BRAKE and GAS, the bottom over the steer
-- hint (Studio check race-8)
prize.Position = UDim2.fromScale(0.4, 0.64)
prize.Size = UDim2.fromScale(0.36, 0.11)
prize.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
prize.BackgroundTransparency = 0.08
prize.Visible = false
prize.Parent = top
local prizeOrigin = topOrigin
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
local prizeTitle = textLine(prize, 0, 0.4, GOLD, Enum.Font.LuckiestGuy)
prizeTitle.TextXAlignment = Enum.TextXAlignment.Center
local prizeGoal = textLine(prize, 0.46, 0.24, Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
prizeGoal.TextXAlignment = Enum.TextXAlignment.Center
local prizeBar = bar(prize, 0.78, 0.18)
local prizeShows = 0
prize:GetPropertyChangedSignal("Visible"):Connect(function()
	prizeUp = prize.Visible
	nextBox.Visible = goalUp and not prizeUp
end)

-- After a server race (its result card shows first): how far your coins got you to the goal.
local lastGoal: any = nil
local function showPrize(before: any)
	if Features.CVC and Features.NEW_UI then
		return -- (the new podium screen has the rewards)
	end
	local g = lastGoal
	if type(g) ~= "table" or type(g.name) ~= "string" or type(g.price) ~= "number" then
		return
	end
	local gained = if type(before) == "table" then g.have - before.have else 0
	-- one coin number only (the result row has it): this card is what the coins are FOR
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
	-- just under the race result card (it grows with the racers) and the medal pop, else its
	-- usual spot
	local y = 0.64
	local bottom = resultBottom()
	if bottom then
		y = math.max(y, bottom + GAP)
	end
	if os.clock() < popUntil then
		y = math.max(y, popBottom + GAP * 0.5)
	end
	y = math.min(y, 0.73)
	-- Car VS Car: over the big JOIN button, never on it (CvcLayout.prizeY; it can come up later)
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	local cvcRace = if Features.CVC and pgui then pgui:FindFirstChild("CvcRace") else nil
	local join = if cvcRace then cvcRace:FindFirstChild("BigJoin") else nil
	if join and join:IsA("GuiObject") and top.AbsoluteSize.Y > 0 then
		-- (AbsolutePosition starts under Roblox's top bar; this card's scale starts at the top)
		local joinTop = join.AbsolutePosition.Y - prizeOrigin.AbsolutePosition.Y
		y = math.min(y, CvcLayout.prizeY(top.AbsoluteSize.Y, joinTop))
	end
	local P = CvcLayout.PRIZE
	prize.Size = if Features.CVC then UDim2.fromScale(P.w, P.h) else UDim2.fromScale(0.36, 0.11)
	prize.Position = UDim2.fromScale(if Features.CVC then P.x else 0.4, y)
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
	-- (Smash: no server race, so no race result; nothing waits for it)
	local raceEvent = ReplicatedStorage:FindFirstChild("ServerRace")
	if not (raceEvent and raceEvent:IsA("RemoteEvent")) then
		return
	end
	raceEvent.OnClientEvent:Connect(function(kind: unknown)
		if kind == "result" then
			-- the race pay comes in the next second or two: show the goal after it
			local before = lastGoal
			-- a medal pop still up moves under the card (once the card has its size)
			task.delay(0.1, function()
				if os.clock() < popUntil - 0.6 then -- (not once it has begun to fade)
					placePop()
				end
			end)
			task.delay(2.5, function()
				-- Car VS Car: its own turn, after the result and the win card (CvcLayout.AFTER_RACE)
				if Features.CVC then
					CvcLayout.waitTurn(player:WaitForChild("PlayerGui"), "RacePrize", 30)
				end
				showPrize(before)
			end)
		end
	end)
end)

remote.OnClientEvent:Connect(function(kind: unknown, info: unknown, saving: unknown, ...: unknown)
	if kind == "saving" then
		-- true = saving works; false = not saving; "retry" = DataStore down, trying again
		-- (Studio only: a player can't fix it, and it cluttered the phone screen, carter 10-29)
		noSave.Visible = info ~= true and RunService:IsStudio()
		noSave.Text = if info == "retry" then "SAVING IS OFF, TRYING AGAIN" else "NOT SAVING"
		return
	end
	if kind == "goal" then
		info = cvcGoal(info)
		lastGoal = info
		showGoal(info)
		return
	end
	if kind == "coins" and type(info) == "number" then
		setCoins(info)
		return
	end
	if kind == "daily" and type(info) == "number" and type(saving) == "number" then
		-- ("daily", coins, days in a row, boost)
		local boost, crate = select(1, ...)
		task.spawn(
			showDaily,
			info,
			saving,
			if type(boost) == "number" then boost else 1,
			crate == true
		) -- it may wait
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
end)

-- hide the lobby HUD while this player drives (Lobby.setDriving sets the attribute)
local function showWalkHud()
	-- (Features.NEW_UI: the new plot screen has the coins and the jobs, CvcScreens.client; NOT
	-- SAVING moves to the top layer so it still shows)
	hud.Enabled = not (Features.CVC and Features.NEW_UI)
		and player:GetAttribute("Driving") ~= true
		and player:GetAttribute("Building") ~= true
	if hud.Enabled then
		task.delay(0.5, flyCoins) -- coins won while driving fly in now
	end
end
player:GetAttributeChangedSignal("Driving"):Connect(showWalkHud)
player:GetAttributeChangedSignal("Building"):Connect(showWalkHud)
showWalkHud()

-- one new thing at a time (JoinStage): a brand new player sees none of these until their stage
StageGate.hold(coinChip, "coins")
StageGate.hold(jobs, "jobs")
StageGate.hold(banner, "boost")
StageGate.hold(card, "gift")
StageGate.hold(nextBox, "goal")
player:GetAttributeChangedSignal("Stage"):Connect(function()
	task.delay(0.5, flyCoins) -- the first lap's coins fly into the coins number as it appears
end)
