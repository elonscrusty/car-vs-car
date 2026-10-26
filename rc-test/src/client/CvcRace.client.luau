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
local CvcLayout = require(Shared:WaitForChild("CvcLayout"))
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
boost.Visible = false
CvcUi.corner(boost, 0.5)
-- square, just left of DRIFT on every screen (HudLayout.box; place() alone gave it no width)
local boostSpot = HudLayout.find("Boost", "drive") :: HudLayout.Spot
local function fitBoost()
	local size = hud.AbsoluteSize
	local l, t, r, b = HudLayout.box(boostSpot, size.X, size.Y)
	boost.AnchorPoint = Vector2.zero
	boost.Position = UDim2.fromOffset(l, t)
	boost.Size = UDim2.fromOffset(r - l, b - t)
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoost)
fitBoost()
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
CvcLayout.place(chat, "finish", "Chat")
chat.BackgroundTransparency = 1
chat.Visible = false
chat.Parent = top
local gg = button(chat, "GG!", KartStyle.SKY)
CvcLayout.place(gg, "finish", "GG")
local again = button(chat, "AGAIN!", KartStyle.GREEN)
CvcLayout.place(again, "finish", "Again")
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

-- a quick white flash over the whole screen (a win)
local function flash()
	local f = Instance.new("Frame")
	f.Name = "Kart_Flash"
	f:SetAttribute("NoKart", true)
	f.Active = false
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0.35
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 1
	f.Parent = fall
	TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		f:Destroy()
	end)
end

-- The result card: the place slams in big, the trophy pops up with rays (top 3), then the coins
-- count up. A win gets a flash, a burst and lots of confetti.
local function finish(place: number, coins: number, trophy: boolean)
	local card = Instance.new("Frame")
	card.Name = "Finish"
	CvcLayout.place(card, "finish", "Card")
	card.BackgroundColor3 = KartStyle.BLUE
	card.ZIndex = 2
	card.Parent = top
	CvcUi.corner(card, 0.08)
	CvcUi.rim(card, KartStyle.PANEL_RIM)
	local color = if trophy then TROPHY_COLORS[place] or WHITE else WHITE
	local word = label(card, placeWord(place), color)
	word.Position = UDim2.fromScale(0.05, 0.06)
	word.Size = UDim2.fromScale(0.9, 0.36)
	word.ZIndex = 3
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 3
	s.Parent = word
	pop(card, 0.3)
	-- the place word: from huge down onto the card
	local wordScale = Instance.new("UIScale")
	wordScale.Scale = 2.4
	wordScale.Parent = word
	TweenService:Create(wordScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if place == 1 then
		flash()
		local at = card.AbsolutePosition + card.AbsoluteSize / 2
		Party.burst(top, UDim2.fromOffset(at.X, at.Y), 24)
	end
	if trophy then
		local cup = label(card, "🏆", WHITE)
		cup.Name = "Trophy"
		cup.Position = UDim2.fromScale(0.05, 0.42)
		cup.Size = UDim2.fromScale(0.9, 0.3)
		cup.ZIndex = 3
		local cupScale = Instance.new("UIScale")
		cupScale.Scale = 0
		cupScale.Parent = cup
		task.delay(0.3, function()
			TweenService:Create(cupScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			-- a little wiggle once it's up
			cup.Rotation = -12
			TweenService:Create(
				cup,
				TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
				{ Rotation = 12 }
			):Play()
			task.delay(0.8, function()
				cup.Rotation = 0
			end)
			Party.rays(cup, color)
		end)
		Party.confetti(fall, if place == 1 then 110 else 50)
	end
	-- the coins count up
	local got = label(card, "", KartStyle.YELLOW)
	got.Position = UDim2.fromScale(0.05, if trophy then 0.74 else 0.5)
	got.Size = UDim2.fromScale(0.9, 0.2)
	got.ZIndex = 3
	if coins > 0 then
		task.delay(0.6, function()
			local start = os.clock()
			local secs = 0.9
			while card.Parent and os.clock() - start < secs do
				local f = (os.clock() - start) / secs
				got.Text = `+{math.floor(coins * (1 - (1 - f) ^ 2))} COINS`
				task.wait()
			end
			got.Text = `+{coins} COINS`
			pop(got, 1.4)
		end)
	end
	if place >= 1 then
		Sfx.trophy(place)
	end
	task.delay(5, function()
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
