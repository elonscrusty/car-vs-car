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
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local League = require(Shared:WaitForChild("League"))
local Training = require(Shared:WaitForChild("Training"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Party = require(script.Parent:WaitForChild("Party"))
local Popup = require(script.Parent:WaitForChild("Popup"))

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

local function bigWords(text: string, color: Color3)
	CvcUi.bigWords(top, text, color)
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
		-- moved up: a big moment
		badgeScale.Scale = 1.6
		TweenService:Create(badgeScale, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		bigWords(`{string.upper(League.name(n))} LEAGUE!`, badge.BackgroundColor3)
		Party.confetti(fall, 60)
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

RunService.Heartbeat:Connect(function()
	coach.Visible = CvcState.loaded and training() and not driving()
	if not coach.Visible then
		return
	end
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
pickPanel.AnchorPoint = Vector2.new(0.5, 0.5)
pickPanel.Position = UDim2.fromScale(0.5, 0.54)
pickPanel.Size = UDim2.fromScale(0.8, 0.78)
pickPanel.BackgroundColor3 = KartStyle.BLUE
pickPanel.Parent = pickGui
CvcUi.corner(pickPanel, 0.05)
CvcUi.rim(pickPanel, KartStyle.PANEL_RIM)
local pickMax = Instance.new("UISizeConstraint")
pickMax.MaxSize = Vector2.new(900, 520)
pickMax.Parent = pickPanel
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
	for i, id in ids do
		local holder = Instance.new("Frame")
		holder.Name = "Choice"
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.new((i - 1) / n, 10, 0.17, 0)
		holder.Size = UDim2.new(1 / n, -20, 0.8, 0)
		holder.Parent = pickPanel
		local card = CvcUi.card(holder, CvcState.fresh(id))
		card.frame.Size = UDim2.fromScale(1, 0.82)
		local go = button(holder, "PICK!", KartStyle.GREEN)
		go.AnchorPoint = Vector2.new(0.5, 1)
		go.Position = UDim2.fromScale(0.5, 1)
		go.Size = UDim2.fromScale(0.8, 0.15)
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
				bigWords(`{CvcState.name(id)}!`, KartStyle.YELLOW)
				Party.confetti(fall, 60)
				task.delay(1.4, function()
					bigWords("IT'S TRAINING NOW!", KartStyle.GREEN)
				end)
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
