--!strict
-- Car VS Car on screen (carter 10-26, rc-game/cvc-plan.md; who builds what: rc-game/cvc/SPLIT.md),
-- in the Kart Party look. Only with Features.CVC on.
--   * PICK YOUR FIRST CAR: 3 cards (picture, name, 3 bars), tap one
--   * the league badge by the coins (BRONZE / SILVER / GOLD / DIAMOND)
--   * COACH: 2x training for 10 s, once a minute (shows the wait, then the 2X time)
-- The server (TrainingServer, RemoteEvent Garage) decides everything; this shows it and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local CvcLayout = require(Shared:WaitForChild("CvcLayout"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local League = require(Shared:WaitForChild("League"))
local Training = require(Shared:WaitForChild("Training"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Party = require(script.Parent:WaitForChild("Party"))
local Popup = require(script.Parent:WaitForChild("Popup"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local INK, WHITE = KartStyle.INK, KartStyle.WHITE
local label, button = CvcUi.label, CvcUi.button

CvcState.start()

local hud = Instance.new("ScreenGui")
hud.Name = "Cvc"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")

local top = Instance.new("ScreenGui")
top.Name = "CvcTop"
top.ResetOnSpawn = false
top.IgnoreGuiInset = true
top.DisplayOrder = HudLayout.POPUP + 1 -- big words and the pick screen, over a popup
top.Parent = player:WaitForChild("PlayerGui")
local fall = Instance.new("Frame") -- confetti under the words and cards, not over them
fall.Name = "Kart_Fall"
fall.BackgroundTransparency = 1
fall.Size = UDim2.fromScale(1, 1)
fall.ZIndex = 0
fall.Active = false
fall.Parent = top

local function driving(): boolean
	return player:GetAttribute("Driving") == true
end

local function bigWords(text: string, color: Color3): TextLabel
	return CvcUi.bigWords(top, text, color)
end

-- ===== the league badge (by the coins: the tycoon's coins-a-minute spot, off in Car VS Car) =====

local badge = label(hud, "BRONZE", INK)
badge.Name = "League"
HudLayout.place(badge, "Income")
badge.BackgroundTransparency = 0
CvcUi.corner(badge, 0.3)
CvcUi.rim(badge, KartStyle.BUTTON_RIM)
local badgePad = Instance.new("UIPadding")
badgePad.PaddingTop = UDim.new(0.16, 0)
badgePad.PaddingBottom = UDim.new(0.12, 0)
badgePad.PaddingLeft = UDim.new(0.08, 0)
badgePad.PaddingRight = UDim.new(0.08, 0)
badgePad.Parent = badge
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = badge

local shownLeague: number? = nil
local function showLeague()
	local n = League.clamp(player:GetAttribute("League"))
	local c = League.COLORS[n]
	badge.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
	badge.Text = string.upper(League.name(n))
	badge.Visible = not driving()
	if shownLeague and n > shownLeague then
		-- moved up: a big moment, in its own turn after a race (CvcLayout.AFTER_RACE: after the
		-- result and the win card, where it was never seen)
		local color = badge.BackgroundColor3
		task.spawn(function()
			CvcLayout.waitTurn(player:WaitForChild("PlayerGui"), "Kart_League", 30)
			badgeScale.Scale = 1.6
			TweenService
				:Create(badgeScale, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			bigWords(`{string.upper(League.name(n))} LEAGUE!`, color).Name = "Kart_League"
			Party.confetti(fall, 80)
			-- fireworks all over (carter's pick 27)
			Sfx.fireworks()
			for i = 1, 7 do
				task.delay(i * 0.18, function()
					Party.burst(
						top,
						UDim2.fromScale(0.15 + math.random() * 0.7, 0.12 + math.random() * 0.45),
						18
					)
				end)
			end
		end)
	end
	if player:GetAttribute("League") ~= nil then
		shownLeague = n
	end
end
player:GetAttributeChangedSignal("League"):Connect(showLeague)
player:GetAttributeChangedSignal("Driving"):Connect(showLeague)
showLeague()

-- ===== COACH =====

local coach = button(hud, "COACH!", KartStyle.GREEN)
coach.Name = "Coach"
HudLayout.place(coach, "Coach")
coach.Visible = false
local coachScale = Instance.new("UIScale")
coachScale.Parent = coach

local function training(): boolean
	for _, st in CvcState.stations do
		if st.uid ~= "" then
			return true
		end
	end
	return false
end

coach.Activated:Connect(function()
	local at = player:GetAttribute("CoachAt")
	if
		Training.coachReady(if type(at) == "number" then at else 0, workspace:GetServerTimeNow())
	then
		CvcState.ask("coach")
		coachScale.Scale = 1.25
		TweenService:Create(coachScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		bigWords("2X TRAINING!", KartStyle.YELLOW)
	end
end)

-- the race call strip up top (ServerRace.client): COACH steps down under it while it shows
local coachSpot = coach.Position
local function callShowing(): boolean
	local g = player.PlayerGui:FindFirstChild("ServerRace")
	-- (StageGate.hold wraps it: ServerRace.Stage_race.Call; the wrap hides it too)
	local c = g and g:FindFirstChild("Call", true)
	if not (c and c:IsA("GuiObject") and c.Visible and (g :: ScreenGui).Enabled) then
		return false
	end
	local up = c.Parent
	while up and up ~= g do
		if up:IsA("GuiObject") and not up.Visible then
			return false
		end
		up = up.Parent
	end
	return true
end

-- the win card after a race (CvcRace "Finish") is up: COACH steps away for its few seconds
local function winCardUp(): boolean
	local g = player.PlayerGui:FindFirstChild("CvcRaceTop")
	local f = g and g:FindFirstChild("Finish", true)
	return f ~= nil and f:IsA("GuiObject") and f.Visible
end

RunService.Heartbeat:Connect(function()
	coach.Visible = CvcState.loaded and training() and not driving() and not winCardUp()
	if not coach.Visible then
		return
	end
	coach.Position = if callShowing()
		then UDim2.new(0.5, 0, 0, CvcLayout.coachUnderCall(hud.AbsoluteSize.X))
		else coachSpot
	local raw = player:GetAttribute("CoachAt")
	local at = if type(raw) == "number" then raw else 0
	local now = workspace:GetServerTimeNow()
	if Training.coaching(at, now) then
		local left = Training.COACH_SECS - (now - at)
		coach.Text = `2X! {math.ceil(left)}`
		coach.BackgroundColor3 = KartStyle.YELLOW
		coach.TextColor3 = INK
		coach:SetAttribute("KartPulse", nil)
	elseif Training.coachReady(at, now) then
		coach.Text = "COACH!"
		coach.BackgroundColor3 = KartStyle.GREEN
		coach.TextColor3 = WHITE
		coach:SetAttribute("KartPulse", true) -- ready: it breathes (KartSkin)
	else
		local left = math.max(0, math.ceil(Training.COACH_EVERY - (now - at)))
		coach.Text = string.format("COACH %d:%02d", left // 60, left % 60)
		coach.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
		coach.TextColor3 = WHITE
		coach:SetAttribute("KartPulse", nil)
	end
end)

-- ===== the gift box: your first car drives out of it (carter's pick 1) =====

local function giftBox(id: string)
	local gift = Instance.new("Frame")
	gift.Name = "Gift"
	gift.AnchorPoint = Vector2.new(0.5, 0.5)
	gift.Position = UDim2.fromScale(0.5, 0.5)
	gift.Size = UDim2.fromOffset(130, 110)
	gift.BackgroundColor3 = KartStyle.RED
	gift.ZIndex = 2
	gift.Parent = top
	CvcUi.corner(gift, 0.1)
	CvcUi.rim(gift, KartStyle.PANEL_RIM)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0)
	band.Position = UDim2.fromScale(0.5, 0)
	band.Size = UDim2.fromScale(0.2, 1)
	band.BackgroundColor3 = KartStyle.YELLOW
	band.BorderSizePixel = 0
	band.ZIndex = 2
	band.Parent = gift
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.AnchorPoint = Vector2.new(0.5, 1)
	lid.Position = UDim2.new(0.5, 0, 0.5, -52)
	lid.Size = UDim2.fromOffset(150, 30)
	lid.BackgroundColor3 = KartStyle.RED
	lid.ZIndex = 3
	lid.Parent = top
	CvcUi.corner(lid, 0.25)
	CvcUi.rim(lid, KartStyle.PANEL_RIM)
	local bow = label(lid, "🎀", WHITE)
	bow.AnchorPoint = Vector2.new(0.5, 1)
	bow.Position = UDim2.fromScale(0.5, 0.2)
	bow.Size = UDim2.fromOffset(56, 44)
	bow.ZIndex = 4
	local giftScale = Instance.new("UIScale")
	giftScale.Scale = 0.2
	giftScale.Parent = gift
	local lidScale = Instance.new("UIScale")
	lidScale.Scale = 0.2
	lidScale.Parent = lid
	TweenService:Create(giftScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(lidScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- it wobbles, faster and faster
	local start = os.clock()
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local r = math.sin(t * (14 + 20 * t)) * math.min(t * 10, 8)
		gift.Rotation = r
		lid.Rotation = r
	end)
	task.delay(1.1, function()
		wobble:Disconnect()
		gift.Rotation = 0
		-- the lid pops off, the box opens and the car drives out
		TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 70, 0.5, -200),
			Rotation = 40,
		}):Play()
		local at = gift.AbsolutePosition + gift.AbsoluteSize / 2
		Party.burst(top, UDim2.fromOffset(at.X, at.Y), 24)
		Sfx.crate(1)
		local car = CvcUi.carPic(top, id)
		car.Name = "NewCar"
		car.AnchorPoint = Vector2.new(0.5, 0.5)
		car.Position = UDim2.fromScale(0.5, 0.5)
		car.Size = UDim2.fromOffset(240, 150)
		car.BackgroundTransparency = 1
		car.ZIndex = 3
		local carScale = Instance.new("UIScale")
		carScale.Scale = 0.1
		carScale.Parent = car
		TweenService:Create(carScale, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		TweenService:Create(car, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
			Position = UDim2.fromScale(0.5, 0.42),
		}):Play()
		local stopRays = Party.rays(car, KartStyle.YELLOW)
		TweenService:Create(gift, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(giftScale, TweenInfo.new(0.4), { Scale = 0.5 }):Play()
		Party.confetti(fall, 60)
		task.delay(0.5, function()
			gift:Destroy()
			bigWords(`{CvcState.name(id)}!`, KartStyle.YELLOW)
		end)
		task.delay(1.9, function()
			bigWords("IT'S TRAINING NOW!", KartStyle.GREEN)
		end)
		task.delay(3.2, function()
			-- off it goes to your plot
			stopRays()
			lid:Destroy()
			TweenService
				:Create(car, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.fromScale(1.3, 0.42),
				})
				:Play()
			task.delay(0.5, function()
				car:Destroy()
			end)
		end)
	end)
end

-- ===== PICK YOUR FIRST CAR =====

local pickGui = Instance.new("ScreenGui")
pickGui.Name = "CvcPick"
pickGui.ResetOnSpawn = false
pickGui.IgnoreGuiInset = true
pickGui.DisplayOrder = HudLayout.POPUP
pickGui.Enabled = false
pickGui.Parent = player:WaitForChild("PlayerGui")
local dim = Instance.new("Frame") -- (no tap-outside: a car must be picked)
dim.Name = "Dim"
dim:SetAttribute("NoKart", true)
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.Active = true
dim.Parent = pickGui

local pickPanel = Instance.new("Frame")
pickPanel.Name = "Panel"
CvcLayout.place(pickPanel, "pick", "Panel")
pickPanel.BackgroundColor3 = KartStyle.BLUE
pickPanel.Parent = pickGui
CvcUi.corner(pickPanel, 0.05)
CvcUi.rim(pickPanel, KartStyle.PANEL_RIM)
CvcUi.ribbon(pickPanel, "PICK YOUR FIRST CAR!")
local pickHint = label(pickPanel, "IT TRAINS ON YOUR PLOT, THEN YOU RACE IT!", WHITE)
pickHint.Position = UDim2.fromScale(0.05, 0.08)
pickHint.Size = UDim2.fromScale(0.9, 0.07)

local picking = false
local showPick: () -> ()
local function buildPick()
	for _, c in pickPanel:GetChildren() do
		if c.Name == "Choice" then
			c:Destroy()
		end
	end
	local ids = CvcState.starters()
	local n = math.max(#ids, 1)
	-- a full bar is a bit past the best of these cars, so 26 and 18 look different (Studio polish-6)
	local most = 1
	for _, id in ids do
		for _, b in Training.BARS do
			most = math.max(most, (CvcState.bar(CvcState.fresh(id), b)))
		end
	end
	most = math.ceil(most * 1.15)
	for i, id in ids do
		local holder = Instance.new("Frame")
		holder.Name = "Choice"
		holder.BackgroundTransparency = 1
		CvcLayout.place(holder, "pick", "Choice") -- (the first; each next one a third further right)
		holder.Position += UDim2.fromScale((i - 1) / n, 0)
		holder.Size =
			UDim2.new(1 / n, holder.Size.X.Offset, holder.Size.Y.Scale, holder.Size.Y.Offset)
		holder.Parent = pickPanel
		local card = CvcUi.card(holder, CvcState.fresh(id), { barMost = most, best = true })
		CvcLayout.place(card.frame, "pick", "Card")
		local go = button(holder, "PICK!", KartStyle.GREEN)
		CvcLayout.place(go, "pick", "Pick")
		go:SetAttribute("KartPulse", true)
		go.Activated:Connect(function()
			if picking then
				return
			end
			picking = true
			CvcState.ask("pick", id)
			task.delay(6, function()
				-- the server said no (or is slow): the cards come back
				if player:GetAttribute("Picked") ~= true then
					picking = false
					showPick()
				end
			end)
			local at = go.AbsolutePosition + go.AbsoluteSize / 2
			Party.burst(top, UDim2.fromOffset(at.X, at.Y), 16)
			task.delay(0.35, function()
				pickGui.Enabled = false
				Popup.shown("cvcPick", false)
				giftBox(id)
			end)
		end)
	end
end

showPick = function()
	local want = CvcState.loaded and player:GetAttribute("Picked") == false and not picking
	if want and not pickGui.Enabled then
		buildPick()
		pickGui.Enabled = true
		Popup.shown("cvcPick", true) -- (shuts any other popup)
	elseif not want and pickGui.Enabled and not picking then
		pickGui.Enabled = false
		Popup.shown("cvcPick", false)
	end
end
player:GetAttributeChangedSignal("Picked"):Connect(function()
	if player:GetAttribute("Picked") == true then
		picking = false
	end
	showPick()
end)
CvcState.changed:Connect(showPick)
showPick()

-- ===== a bar goes up: "+1 SPEED!" pops (pick 6); full: a gold "SPEED MAX!" (pick 8) =====

local GOLD = Color3.fromRGB(255, 199, 44)
local popQueue: { { text: string, color: Color3, max: boolean } } = {}
local popping = false
local function nextPop()
	local p = table.remove(popQueue, 1)
	if not p then
		popping = false
		return
	end
	popping = true
	if not driving() then
		local w = label(hud, p.text, p.color)
		w.Name = "Kart_BarPop"
		w.AnchorPoint = Vector2.new(0.5, 0.5)
		w.Position = UDim2.fromScale(0.78, 0.42)
		w.Size = UDim2.fromOffset(260, 44)
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = 3
		s.Parent = w
		local sc = Instance.new("UIScale")
		sc.Scale = 0.3
		sc.Parent = w
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(w, TweenInfo.new(1.2), { Position = UDim2.fromScale(0.78, 0.3) }):Play()
		task.delay(0.8, function()
			TweenService:Create(w, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end)
		task.delay(1.25, function()
			w:Destroy()
		end)
		if p.max then
			Sfx.maxed()
			local at = w.AbsolutePosition + w.AbsoluteSize / 2
			Party.burst(top, UDim2.fromOffset(at.X, at.Y), 14)
		else
			Sfx.speedUp()
		end
	end
	task.delay(0.45, nextPop)
end
local function addPop(text: string, color: Color3, max: boolean)
	if #popQueue >= 4 then
		return -- (lots at once: the newest wait for the next change)
	end
	table.insert(popQueue, { text = text, color = color, max = max })
	if not popping then
		nextPop()
	end
end

-- the whole numbers each training car's bars were at last time (uid .. bar)
local lastBars: { [string]: number } = {}
CvcState.changed:Connect(function()
	for _, st in CvcState.stations do
		local car = st.uid ~= "" and CvcState.find(st.uid) or nil
		if car then
			for _, b in Training.BARS do
				local v, cap = CvcState.bar(car, b)
				local now = math.floor(v)
				local key = car.uid .. b
				local was = lastBars[key]
				if was and now > was then
					local word = CvcUi.BAR_WORDS[b] or string.upper(b)
					if v >= cap then
						addPop(`{word} MAX!`, GOLD, true)
					else
						addPop(`+{now - was} {word}!`, CvcUi.BAR_COLORS[b] or WHITE, false)
					end
				end
				lastBars[key] = now
			end
		end
	end
end)
