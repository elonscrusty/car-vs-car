--!strict
-- Car VS Car race buttons (carter 10-26, rc-game/cvc-plan.md), in the Kart Party look. Only with
-- Features.CVC on.
--   * the big JOIN button over the goal line, with the clock to the next BIG RACE
--   * the big BOOST thumb button while racing (left of DRIFT), with how many are saved up
--   * the finish: your place, the trophy for the top 3, the coins, confetti; then GG! / AGAIN!
--   * a friend in the server: "PLAYING WITH SAM! +100"
-- The race thread's hooks: ServerRace ("join"), RaceJoined, workspace NextRaceAt (server time),
-- the BoostTap bindable and Racing / BoostLeft / BoostOn; the finish is TrainingServer's ("race").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
if not Features.CVC then
	return
end
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local KartStyle = require(Shared:WaitForChild("KartStyle"))
local CvcState = require(script.Parent:WaitForChild("CvcState"))
local CvcUi = require(script.Parent:WaitForChild("CvcUi"))
local Party = require(script.Parent:WaitForChild("Party"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local INK, WHITE = KartStyle.INK, KartStyle.WHITE
local label, button = CvcUi.label, CvcUi.button
local GREY = Color3.fromRGB(110, 110, 120)

CvcState.start()

local hud = Instance.new("ScreenGui")
hud.Name = "CvcRace"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = HudLayout.HUD
hud.Parent = player:WaitForChild("PlayerGui")
local top, fall = CvcUi.topGui("CvcRaceTop", HudLayout.POPUP + 1, player:WaitForChild("PlayerGui"))

local raceEvent = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent

local function driving(): boolean
	return player:GetAttribute("Driving") == true
end

local function pop(obj: GuiObject, from: number)
	local s = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Scale = from
	s.Parent = obj
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function clock(secs: number): string
	local s = math.max(0, math.ceil(secs))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== the big JOIN button =====

local join = button(hud, "JOIN RACE!", KartStyle.GREEN)
join.Name = "BigJoin"
HudLayout.place(join, "BigJoin")
join.Visible = false
join.Activated:Connect(function()
	if player:GetAttribute("RaceJoined") ~= true then
		raceEvent:FireServer("join")
		pop(join, 1.25)
	end
end)

-- ===== the BOOST thumb button =====

local boost = button(hud, "BOOST", KartStyle.RED)
boost.Name = "Boost"
HudLayout.place(boost, "Boost", "drive")
boost.Visible = false
CvcUi.corner(boost, 0.5)
local boostSquare = Instance.new("UIAspectRatioConstraint")
boostSquare.DominantAxis = Enum.DominantAxis.Height
boostSquare.AspectRatio = 1
boostSquare.Parent = boost
CvcUi.rim(boost, KartStyle.BUTTON_RIM)
-- how many are saved up, a little white ball on its corner
local boostCount = label(boost, "0", INK)
boostCount.Name = "Left"
boostCount.AnchorPoint = Vector2.new(0.5, 0.5)
boostCount.Position = UDim2.fromScale(0.86, 0.04)
boostCount.Size = UDim2.fromScale(0.42, 0.42)
boostCount.BackgroundColor3 = WHITE
boostCount.BackgroundTransparency = 0
boostCount.ZIndex = 3
CvcUi.corner(boostCount, 0.5)
CvcUi.rim(boostCount, KartStyle.BUTTON_RIM)

local boostTap = ReplicatedStorage:WaitForChild("BoostTap") :: BindableEvent
local function boostLeft(): number
	local n = player:GetAttribute("BoostLeft")
	return if type(n) == "number" then n else 0
end
boost.Activated:Connect(function()
	if boostLeft() > 0 and player:GetAttribute("BoostOn") ~= true then
		boostTap:Fire()
		pop(boost, 1.3)
	end
end)
local function showBoost()
	boost.Visible = player:GetAttribute("Racing") == true
	local left = boostLeft()
	boostCount.Text = tostring(left)
	if player:GetAttribute("BoostOn") == true then
		boost.Text = "GO!!"
		boost.BackgroundColor3 = KartStyle.YELLOW
		boost.TextColor3 = INK
		boost:SetAttribute("KartPulse", nil)
	elseif left > 0 then
		boost.Text = "BOOST"
		boost.BackgroundColor3 = KartStyle.RED
		boost.TextColor3 = WHITE
		boost:SetAttribute("KartPulse", true) -- one is ready: it breathes (KartSkin)
	else
		boost.Text = "BOOST"
		boost.BackgroundColor3 = GREY
		boost.TextColor3 = WHITE
		boost:SetAttribute("KartPulse", nil)
	end
	boostCount.Visible = left > 0
end
for _, a in { "Racing", "BoostLeft", "BoostOn" } do
	player:GetAttributeChangedSignal(a):Connect(showBoost)
end
showBoost()

-- a new BOOST saved up (each lap): the count pops
local lastLeft = 0
player:GetAttributeChangedSignal("BoostLeft"):Connect(function()
	local left = boostLeft()
	if left > lastLeft then
		pop(boostCount, 1.8)
	end
	lastLeft = left
end)

RunService.Heartbeat:Connect(function()
	local show = CvcState.loaded and player:GetAttribute("Picked") == true and not driving()
	join.Visible = show
	if not show then
		return
	end
	local raw = workspace:GetAttribute("NextRaceAt")
	local left = if type(raw) == "number" then raw - workspace:GetServerTimeNow() else nil
	if player:GetAttribute("RaceJoined") == true then
		join.Text = if left then `YOU'RE IN! {clock(left)}` else "YOU'RE IN!"
		join.BackgroundColor3 = KartStyle.YELLOW
		join.TextColor3 = INK
		join:SetAttribute("KartPulse", nil)
	else
		join.Text = if left then `JOIN RACE! {clock(left)}` else "JOIN NEXT RACE!"
		join.BackgroundColor3 = KartStyle.GREEN
		join.TextColor3 = WHITE
		join:SetAttribute("KartPulse", true)
	end
end)

-- ===== the finish: place, trophy, coins; then GG! / AGAIN! =====

local PLACE_WORDS = { "1ST!", "2ND!", "3RD!" }
local TROPHY_COLORS = {
	Color3.fromRGB(255, 199, 44), -- gold
	Color3.fromRGB(205, 214, 230), -- silver
	Color3.fromRGB(214, 140, 80), -- bronze
}

local function placeWord(place: number): string
	if place <= 0 then
		return "GOOD TRY!"
	end
	return PLACE_WORDS[place] or `{place}TH`
end

local chat = Instance.new("Frame")
chat.Name = "QuickChat"
chat.AnchorPoint = Vector2.new(0.5, 0.5)
chat.Position = UDim2.fromScale(0.5, 0.66)
chat.Size = UDim2.new(0, 300, 0, 60)
chat.BackgroundTransparency = 1
chat.Visible = false
chat.Parent = top
local gg = button(chat, "GG!", KartStyle.SKY)
gg.Size = UDim2.new(0.47, 0, 1, 0)
local again = button(chat, "AGAIN!", KartStyle.GREEN)
again.Position = UDim2.fromScale(0.53, 0)
again.Size = UDim2.new(0.47, 0, 1, 0)
again:SetAttribute("KartPulse", true)

local function say(text: string)
	-- (the plain chat channel; nothing if chat is off for this player)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:SendAsync(text)
		end
	end)
end

local chatShown = 0
local function hideChat()
	chat.Visible = false
end
gg.Activated:Connect(function()
	say("GG!")
	hideChat()
end)
again.Activated:Connect(function()
	say("AGAIN!")
	raceEvent:FireServer("join")
	hideChat()
end)

local function finish(place: number, coins: number, trophy: boolean)
	local card = Instance.new("Frame")
	card.Name = "Finish"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.36)
	card.Size = UDim2.fromScale(0.36, 0.34)
	card.BackgroundColor3 = KartStyle.BLUE
	card.ZIndex = 2
	card.Parent = top
	CvcUi.corner(card, 0.08)
	CvcUi.rim(card, KartStyle.PANEL_RIM)
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(420, 260)
	max.Parent = card
	local color = if trophy then TROPHY_COLORS[place] or WHITE else WHITE
	local word = label(card, placeWord(place), color)
	word.Position = UDim2.fromScale(0.05, 0.06)
	word.Size = UDim2.fromScale(0.9, 0.36)
	word.ZIndex = 3
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 3
	s.Parent = word
	if trophy then
		local cup = label(card, "🏆", WHITE)
		cup.Name = "Trophy"
		cup.Position = UDim2.fromScale(0.05, 0.42)
		cup.Size = UDim2.fromScale(0.9, 0.3)
		cup.ZIndex = 3
		Party.rays(cup, color)
	end
	local got = label(card, if coins > 0 then `+{coins} COINS` else "", KartStyle.YELLOW)
	got.Position = UDim2.fromScale(0.05, if trophy then 0.74 else 0.5)
	got.Size = UDim2.fromScale(0.9, 0.2)
	got.ZIndex = 3
	pop(card, 0.3)
	if trophy then
		Party.confetti(fall, if place == 1 then 90 else 50)
	end
	if place >= 1 then
		Sfx.trophy(place)
	end
	task.delay(4.5, function()
		TweenService:Create(card, TweenInfo.new(0.4), { Position = UDim2.fromScale(0.5, -0.4) })
			:Play()
		task.delay(0.4, function()
			card:Destroy()
		end)
	end)
	chat.Visible = true
	pop(chat, 0.4)
	chatShown += 1
	local mine = chatShown
	task.delay(12, function()
		if mine == chatShown then
			hideChat()
		end
	end)
end

CvcState.event:Connect(function(kind: unknown, place: unknown, coins: unknown, trophy: unknown)
	if kind == "race" and type(place) == "number" then
		finish(place, if type(coins) == "number" then coins else 0, trophy == true)
	end
end)

-- ===== a friend in the server (bring-a-friend coins) =====

task.spawn(function()
	local bonus = ReplicatedStorage:WaitForChild("FriendBonus", 120)
	if not (bonus and bonus:IsA("RemoteEvent")) then
		return
	end
	bonus.OnClientEvent:Connect(function(name: unknown, coins: unknown)
		if type(name) == "string" and type(coins) == "number" then
			CvcUi.bigWords(top, `PLAYING WITH {string.upper(name)}! +{coins}`, KartStyle.GREEN, 0.3)
			Party.confetti(fall, 40)
		end
	end)
end)
