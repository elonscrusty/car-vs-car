--!strict
-- The server race on screen: a chip counting down the break to the next race (and, for the last
-- 10 s, whose track it is on), a big "2ND PLACE!" when your car finishes, the clock the others
-- have left once someone has won, and when a race ends a pop-up with who won, for everyone. The
-- server decides everything (ServerRaceRunner); this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local CvcLayout = require(ReplicatedStorage.Shared.CvcLayout)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local KartStyle = require(ReplicatedStorage.Shared.KartStyle)
local RaceMaps = require(ReplicatedStorage.Shared.RaceMaps)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)
local Party = require(script.Parent:WaitForChild("Party"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local StageGate = require(script.Parent:WaitForChild("StageGate"))
local Podium = require(script.Parent:WaitForChild("Podium"))
local Features = require(ReplicatedStorage.Shared.Features)

local event = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent
local player = Players.LocalPlayer

local YELLOW = KartStyle.YELLOW
local DARK = KartStyle.INK

local gui = Instance.new("ScreenGui")
gui.Name = "ServerRace"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")
-- confetti falls in here, under the cards and words (ZIndex 0): over them it hid the results
-- (Studio check race-4-5)
local fall = Instance.new("Frame")
fall.Name = "Kart_Fall"
fall.BackgroundTransparency = 1
fall.Size = UDim2.fromScale(1, 1)
fall.ZIndex = 0
fall.Active = false
fall.Parent = gui

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

-- the countdown chip: a round pill at the top middle (thumbs stay free at the bottom corners)
local join = Instance.new("TextButton")
join.Name = "Join"
-- top right on foot, under the drift score in a car
local function placeJoin()
	HudLayout.place(
		join,
		"Join",
		if player:GetAttribute("Driving") == true then "drive" else "walk"
	)
end
placeJoin()
player:GetAttributeChangedSignal("Driving"):Connect(placeJoin)
join.BackgroundColor3 = YELLOW
join.TextColor3 = DARK
join.Font = Enum.Font.LuckiestGuy
join.TextScaled = true
join.AutoButtonColor = false
join.Active = false
join.Visible = false
join.Parent = gui
corner(join, 0.5)
StageGate.hold(join, "race") -- a brand new player drives their own plot first (JoinStage)
local joinPad = Instance.new("UIPadding")
joinPad.PaddingLeft = UDim.new(0.06, 0)
joinPad.PaddingRight = UDim.new(0.06, 0)
joinPad.PaddingTop = UDim.new(0.14, 0)
joinPad.PaddingBottom = UDim.new(0.14, 0)
joinPad.Parent = join
local joinSize = Instance.new("UITextSizeConstraint")
joinSize.MaxTextSize = 40
joinSize.Parent = join

-- the last seconds before a race: a huge banner up top, whose track and a giant clock
local call = Instance.new("Frame")
call.Name = "Call"
call.AnchorPoint = Vector2.new(0.5, 0)
call.Position = UDim2.new(0.5, 0, 0.12, 70) -- under the top-row buttons (FRIENDS, LOOKS; AUTO GAS..CAM)
call.Size = UDim2.fromScale(0.5, 0.36)
call.BackgroundTransparency = 1
call.Visible = false
call.Parent = gui
StageGate.hold(call, "race")
local callAspect = Instance.new("UIAspectRatioConstraint")
callAspect.AspectRatio = 2.6
callAspect.Parent = call
local callWhere = Instance.new("TextLabel")
callWhere.Size = UDim2.fromScale(1, 0.3)
callWhere.BackgroundColor3 = KartStyle.RED
callWhere.BackgroundTransparency = 0
callWhere.Font = Enum.Font.LuckiestGuy
callWhere.TextScaled = true
callWhere.TextColor3 = Color3.new(1, 1, 1)
callWhere.Parent = call
corner(callWhere, 0.5)
local callWhereRim = Instance.new("UIStroke")
callWhereRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
callWhereRim.Color = DARK
callWhereRim.Thickness = KartStyle.BUTTON_RIM
callWhereRim.Parent = callWhere
local callWherePad = Instance.new("UIPadding")
callWherePad.PaddingTop = UDim.new(0.12, 0)
callWherePad.PaddingBottom = UDim.new(0.12, 0)
callWherePad.PaddingLeft = UDim.new(0.05, 0)
callWherePad.PaddingRight = UDim.new(0.05, 0)
callWherePad.Parent = callWhere
local callClock = Instance.new("TextLabel")
callClock.Position = UDim2.fromScale(0, 0.32)
callClock.Size = UDim2.fromScale(1, 0.68)
callClock.BackgroundTransparency = 1
callClock.Font = Enum.Font.LuckiestGuy
callClock.TextScaled = true
callClock.TextColor3 = YELLOW
callClock.Parent = call
local callStroke = Instance.new("UIStroke")
callStroke.Thickness = 4
callStroke.Color = DARK
callStroke.Parent = callClock

-- the winner pop-up in the middle
local card = Instance.new("Frame")
card.Name = "Result"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.fromScale(0.5, 0.31) -- top edge below the lap box (FINISHED / BEST)
card.Size = UDim2.fromScale(0.46, 0.4)
card.BackgroundColor3 = KartStyle.BLUE
card.BackgroundTransparency = 0
card.Visible = false
card.Parent = gui
corner(card, 0.08)
local stroke = Instance.new("UIStroke")
stroke.Color = DARK
stroke.Thickness = KartStyle.PANEL_RIM
stroke.Parent = card
-- the title on a yellow ribbon sitting over the card's top edge (Kart Party)
local title = Instance.new("TextLabel")
title.Name = "Ribbon"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0)
title.Size = UDim2.fromScale(0.8, 0.36)
title.BackgroundColor3 = YELLOW
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = DARK
title.ZIndex = 3
title.Parent = card
corner(title, 0.3)
local titleRim = Instance.new("UIStroke")
titleRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
titleRim.Color = DARK
titleRim.Thickness = KartStyle.BUTTON_RIM
titleRim.Parent = title
local titlePad = Instance.new("UIPadding")
titlePad.PaddingTop = UDim.new(0.12, 0)
titlePad.PaddingBottom = UDim.new(0.1, 0)
titlePad.PaddingLeft = UDim.new(0.04, 0)
titlePad.PaddingRight = UDim.new(0.04, 0)
titlePad.Parent = title
local rowsText = Instance.new("TextLabel")
rowsText.Size = UDim2.fromScale(0.86, 0.52)
rowsText.Position = UDim2.fromScale(0.07, 0.43)
rowsText.BackgroundTransparency = 1
rowsText.Font = Enum.Font.LuckiestGuy
rowsText.TextScaled = true
rowsText.TextColor3 = Color3.new(1, 1, 1)
rowsText.TextYAlignment = Enum.TextYAlignment.Top
rowsText.RichText = true
rowsText.Parent = card
-- carter's pick 23: the top 3 cars on a podium, between the ribbon and the rows (big race)
local podium = Podium.new(card)
local PODIUM_H = CvcLayout.RESULT.podium -- of the screen
local raceStartedAt = 0 -- the server time this race started (the next one is 3 min after it)
local nextRaceAt = 0 -- Car VS Car: the next start, as the server fixed it when the race ended
local cardLines: { string } = {} -- the result card's rows; the last one (NEXT RACE IN) ticks down
-- Car VS Car: the next start: the server's (it sends it when every league's race is over), else
-- the same sum it does, from now
local function nextRace(): number
	local now = workspace:GetServerTimeNow()
	if nextRaceAt > now then
		return nextRaceAt
	end
	return ServerRace.nextAfterRace(raceStartedAt, now)
end
local function nextLine(secs: number): string
	return `<font color="#CFE3FF">NEXT RACE IN {ServerRace.clock(secs)}</font>`
end

local rowsSize = Instance.new("UITextSizeConstraint")
rowsSize.MaxTextSize = 34
rowsSize.Parent = rowsText

-- your finish: a huge place in the middle, then it slides up out of the way
local placeText = Instance.new("TextLabel")
placeText.Name = "Place"
placeText.AnchorPoint = Vector2.new(0.5, 0.5)
placeText.Position = UDim2.fromScale(0.5, 0.36)
placeText.Size = UDim2.fromScale(0.6, 0.16)
placeText.BackgroundTransparency = 1
placeText.Font = Enum.Font.LuckiestGuy
placeText.TextScaled = true
placeText.TextColor3 = YELLOW
placeText.Visible = false
placeText.Parent = gui
local placeStroke = Instance.new("UIStroke")
placeStroke.Thickness = 5
placeStroke.Color = DARK
placeStroke.Parent = placeText

-- once someone has won: how long the rest have to finish (a red pill up top)
local hurry = Instance.new("TextLabel")
hurry.Name = "Hurry"
hurry.AnchorPoint = Vector2.new(0.5, 0)
hurry.Position = UDim2.new(0.5, 0, 0, 58)
hurry.Size = UDim2.fromScale(0.34, 0.07)
hurry.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
hurry.TextColor3 = Color3.new(1, 1, 1)
hurry.Font = Enum.Font.LuckiestGuy
hurry.TextScaled = true
hurry.Visible = false
hurry.Parent = gui
corner(hurry, 0.5)
local hurryPad = Instance.new("UIPadding")
hurryPad.PaddingTop = UDim.new(0.14, 0)
hurryPad.PaddingBottom = UDim.new(0.14, 0)
hurryPad.Parent = hurry

local phase = "wait"
local startAt = 0
local where = ""
local endsAt = 0 -- server time the race ends for the ones still driving (0 = nobody won yet)
local finished = false -- this player's car is over the line
local kind = "race" -- this round: "race" | "drift" (the picked plot's)
local driftEnds = false -- endsAt is a drift round's end (shown to everyone still in)

-- the words change once a second: built 10 times a second, not every frame (and right away
-- when the phase changes or a chip comes up, so it never shows old words)
local nextText = 0
local lastPhase = ""
RunService.RenderStepped:Connect(function()
	local secs = startAt - workspace:GetServerTimeNow()
	local clock = os.clock()
	local words = clock >= nextText or phase ~= lastPhase
	if words then
		nextText, lastPhase = clock + 0.1, phase
	end
	local wasHurry, wasCall, wasJoin = hurry.Visible, call.Visible, join.Visible
	local wasStrip = callAspect.AspectRatio > 3
	-- the call: the small chip steps aside for the huge banner
	-- the call, and on through the 3-2-1: whose track this is
	-- (gone at the race start: the giant 3-2-1-GO sat on top of it, Studio backyard-1)
	call.Visible = phase == "call" and startAt > 0
	-- on foot (at spawn, in a shop) the call is a thin strip up top, clock and all: the big banner
	-- covered the middle of a new kid's screen (check kid-03); in a car it stays big
	local strip = player:GetAttribute("Driving") ~= true
	callAspect.AspectRatio = if strip then 7 else 2.6
	callWhere.Size = UDim2.fromScale(1, if strip then 1 else 0.3)
	call.Position = if strip
		then UDim2.new(0.5, 0, 0, 58) -- (where the hurry pill sits in a race: the top middle is free)
		else UDim2.new(0.5, 0, 0.12, 70)
	callClock.Visible = not strip
	-- the result card's NEXT RACE IN counts down (Car VS Car: to the start the race call shows)
	if words and card.Visible and Features.CVC and raceStartedAt > 0 and #cardLines > 0 then
		cardLines[#cardLines] = nextLine(nextRace() - workspace:GetServerTimeNow())
		rowsText.Text = table.concat(cardLines, "\n")
	end
	-- the daily gift (Stars) waits while a race or its card is on screen
	gui:SetAttribute("Busy", phase == "racing" or phase == "call" or card.Visible)
	local hurryLeft = endsAt - workspace:GetServerTimeNow()
	-- (over the line already: how long until the results, so waiting on the others isn't a mystery)
	hurry.Visible = phase == "racing" and endsAt > 0 and hurryLeft > 0 and not card.Visible -- (the results are in: the card sat on it)
	if hurry.Visible and (words or not wasHurry) then
		-- (blue once you're in: red is for the ones still racing)
		hurry.BackgroundColor3 = if finished
			then Color3.fromRGB(40, 110, 210)
			else Color3.fromRGB(200, 40, 40)
		hurry.Text = if finished
			then `RESULTS IN {ServerRace.clock(hurryLeft)}`
			elseif driftEnds then `DRIFT!  {ServerRace.clock(hurryLeft)} LEFT`
			else `FINISH IN {ServerRace.clock(hurryLeft)}!`
	end
	-- (the build screen has its own clock)
	-- while driving it waits for the last minute (it sat in the middle of the road on a phone)
	local driving = player:GetAttribute("Driving") == true
	join.Visible = phase ~= "racing"
		and phase ~= "call"
		and not card.Visible -- (the result card has the screen: CvcLayout.AFTER_RACE_HIDES)
		and startAt > 0
		and player:GetAttribute("Building") ~= true
		and (not driving or secs <= 60)
	if call.Visible then
		if words or not wasCall or strip ~= wasStrip then
			local verb = if kind == "drift" then "DRIFT" else "RACE"
			-- a map is a place ("RACE IN THE KITCHEN!"), an old plot track was someone's
			callWhere.Text = if where == ""
				then `{verb}!`
				elseif RaceMaps.live() then `{verb} IN THE {where}!`
				else `{verb} ON {where}!`
			callClock.Text = ServerRace.clock(secs)
			if strip then
				callWhere.Text ..= `  {callClock.Text}`
			end
		end
		-- a little pulse each second
		local f = secs % 1
		callClock.Size = UDim2.fromScale(1, 0.62 + 0.06 * f)
	end
	if not (join.Visible and (words or not wasJoin)) then
		return
	end
	local left = ServerRace.clock(secs)
	if phase == "call" then
		join.BackgroundColor3 = YELLOW
		join.TextColor3 = DARK
		join.Text = if where ~= "" then `RACE IN {left}  {where}` else `RACE IN {left}`
	else
		-- a red race clock, like a kart game's start board
		join.BackgroundColor3 = KartStyle.RED
		join.TextColor3 = KartStyle.WHITE
		join.Text = `NEXT RACE  {left}`
	end
end)

-- what a racer won (the server sends coins per row): "   +100"
-- (just the coins: the star chip counts stars, and short rows read bigger on a phone)
local function paidText(r: any): string
	if type(r.coins) == "number" and r.coins > 0 then
		return `   <font color="#FFD54F">+{r.coins}</font>`
	end
	return ""
end

local showId = 0
local function showPlace(place: number)
	finished = true
	Sfx.finish(place)
	placeText.Text = `{ServerRace.medal(place)} {ServerRace.ordinal(place)} PLACE!`
	placeText.TextColor3 = if place == 1 then YELLOW else Color3.new(1, 1, 1)
	placeText.Visible = true
	placeText.Position = UDim2.fromScale(0.5, 0.36)
	placeText.Size = UDim2.fromScale(0.3, 0.08)
	TweenService:Create(
		placeText,
		TweenInfo.new(0.4, Enum.EasingStyle.Back),
		{ Size = UDim2.fromScale(0.6, 0.16) }
	):Play()
	-- the top 3: light rays turn behind the place, and the winner gets confetti
	local stopRays = if place <= 3
		then Party.rays(placeText, if place == 1 then YELLOW else nil)
		else nil
	if place == 1 then
		Party.confetti(fall, 40)
	end
	task.delay(2.5, function()
		if stopRays then
			stopRays()
		end
		if finished then
			-- out of the way of the results, still there while the others finish
			TweenService:Create(placeText, TweenInfo.new(0.5), {
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(0.36, 0.09),
			}):Play()
		end
	end)
end

local function showResult(rows: { any })
	placeText.Visible = false
	if #rows == 0 or not StageGate.shows("race") then
		return -- (a brand new player isn't in the race: no winner card over their first lap)
	end
	local first = rows[1]
	local won = first.time or (type(first.score) == "number" and first.score > 0)
	-- the winner's car in the title: cars get shown off
	local firstCar = if type(first.car) == "string" then string.upper(first.car) else nil
	-- your own win: YOU WIN! (the others see your name)
	local meFirst = first.uid == player.UserId
		or (first.uid == nil and first.name == player.DisplayName)
	title.Text = if won and meFirst
		then "🏆 YOU WIN!"
		elseif won and firstCar then `🏆 {first.name} WINS IN {firstCar}!`
		elseif won then `🏆 {first.name} WINS!`
		else "TIME UP!"
	local lines = {}
	local mine: number? = nil
	for i, r in rows do
		if r.name == player.DisplayName then
			mine = i
		end
	end
	for i = 1, math.min(#rows, 4) do
		local r = rows[i]
		local what = if type(r.score) == "number"
			then `{r.score} pts`
			elseif type(r.time) == "number" then CarMath.formatTime(r.time)
			else "-" -- (didn't finish before the race ended: "1/2 LAPS" read like a score)
		local paid = paidText(r)
		local medal = ServerRace.medal(i)
		-- (no car on the row: the winner's car is in the title, and short rows read bigger)
		local line = `{if medal ~= "" then medal else `{i}.`} {r.name}   {what}`
		-- your own row in yellow, so you find yourself at once
		table.insert(
			lines,
			-- (yellow is enough: "◀ YOU" made the line too long to read on a phone)
			if i == mine then `<font color="#FFCD3C">{line}</font>{paid}` else line .. paid
		)
	end
	-- not in the top 4: your place still shows at the bottom
	if mine and mine > 4 then
		local r = rows[mine]
		table.insert(lines, `<font color="#FFCD3C">{mine}. YOU</font>{paidText(r)}`)
	end
	-- the winner's prize: double coins for a while (Car VS Car: training coins, CvcRules)
	if won and first.time and first.bot ~= true then -- (a bot that wins gets no prize)
		local mins = math.floor(ServerRace.BOOST_TIME / 60)
		table.insert(
			lines,
			if mine == 1
				then `<font color="#7CFF6B">{if Features.CVC then "YOU" else "YOUR GARAGE"}: 2X COINS {mins} MIN!</font>`
				else `<font color="#7CFF6B">{first.name}: 2X COINS {mins} MIN</font>`
		)
	end
	-- the next race: Car VS Car = the start the server fixed at the race end (the race call counts
	-- down to the same one); before that, a fixed break
	local untilNext = if Features.CVC and raceStartedAt > 0
		then nextRace() - workspace:GetServerTimeNow()
		elseif RaceMaps.live() then ServerRace.MAP_BREAK
		else ServerRace.BREAK
	table.insert(lines, nextLine(untilNext))
	cardLines = lines
	rowsText.Text = table.concat(lines, "\n")
	-- the card fits its rows (one racer = a short card, no empty gap)
	-- (rows 6.5% of the screen tall each: big enough to read on a phone)
	local cars = if Features.CVC and type(first.score) ~= "number" then podium.show(rows) else 0
	local podH = if cars > 0 then PODIUM_H else 0
	local tall = 0.2 + 0.065 * #lines + podH
	rowsText.Size = UDim2.fromScale(0.86, (0.065 * #lines) / tall)
	-- (the inside is laid out in parts of `tall`; the whole card shrinks to stay on the screen)
	local fit = tall * CvcLayout.resultFit(#lines, cars > 0)
	showId += 1
	local me = showId
	card.Visible = true
	card.Size = UDim2.fromScale(0.44, fit * 0.65)
	card:SetAttribute("Bottom", card.Position.Y.Scale + fit) -- the prize card (Stars) goes under it
	title.Size = UDim2.fromScale(0.8, 0.13 / tall)
	-- (the ribbon sits half over the top edge: the rows start under its lower half)
	rowsText.Position = UDim2.fromScale(0.07, 0.04 + (0.08 + podH) / tall)
	podium.frame.Position = UDim2.fromScale(0.05, 0.02 + 0.08 / tall)
	podium.frame.Size = UDim2.fromScale(0.9, podH / tall)
	TweenService
		:Create(
			card,
			TweenInfo.new(0.35, Enum.EasingStyle.Back),
			{ Size = UDim2.fromScale(0.68, fit) }
		)
		:Play()
	-- a podium finish: confetti behind the card
	if mine and mine <= 3 and won then
		Party.confetti(fall, if mine == 1 then 60 else 30)
	end
	task.delay(ServerRace.SHOW, function()
		if me == showId then
			card.Visible = false
			podium.hide()
		end
	end)
end

event.OnClientEvent:Connect(
	function(what: unknown, a: unknown, b: unknown, _c: unknown, d: unknown, e: unknown)
		if what == "state" and type(a) == "string" and type(b) == "number" then
			kind = if d == "drift" then "drift" else "race"
			if a == "racing" and phase ~= "racing" then
				raceStartedAt = b
			end
			phase, startAt = a, b
			where = if type(e) == "string" then e else ""
			if phase ~= "racing" then
				endsAt, finished, driftEnds = 0, false, false
				placeText.Visible = false
			end
		elseif what == "finished" and type(a) == "number" then
			showPlace(a)
		elseif what == "ends" and type(a) == "number" then
			endsAt, driftEnds = a, b == "drift"
		elseif what == "next" and type(a) == "number" then
			nextRaceAt = a
		elseif what == "result" and type(a) == "table" then
			showResult(a :: { any })
		end
	end
)
