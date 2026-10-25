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
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)

local event = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent
local player = Players.LocalPlayer

local YELLOW = Color3.fromRGB(255, 205, 60)
local DARK = Color3.fromRGB(25, 25, 30)

local gui = Instance.new("ScreenGui")
gui.Name = "ServerRace"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

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
join.Font = Enum.Font.GothamBlack
join.TextScaled = true
join.AutoButtonColor = false
join.Active = false
join.Visible = false
join.Parent = gui
corner(join, 0.5)
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
local callAspect = Instance.new("UIAspectRatioConstraint")
callAspect.AspectRatio = 2.6
callAspect.Parent = call
local callWhere = Instance.new("TextLabel")
callWhere.Size = UDim2.fromScale(1, 0.3)
callWhere.BackgroundColor3 = DARK
callWhere.BackgroundTransparency = 0.15
callWhere.Font = Enum.Font.GothamBlack
callWhere.TextScaled = true
callWhere.TextColor3 = Color3.new(1, 1, 1)
callWhere.Parent = call
corner(callWhere, 0.5)
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
callClock.Font = Enum.Font.GothamBlack
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
card.BackgroundColor3 = DARK
card.BackgroundTransparency = 0.1
card.Visible = false
card.Parent = gui
corner(card, 0.08)
local stroke = Instance.new("UIStroke")
stroke.Color = YELLOW
stroke.Thickness = 4
stroke.Parent = card
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(0.9, 0.36)
title.Position = UDim2.fromScale(0.05, 0.05)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = YELLOW
title.Parent = card
local rowsText = Instance.new("TextLabel")
rowsText.Size = UDim2.fromScale(0.86, 0.52)
rowsText.Position = UDim2.fromScale(0.07, 0.43)
rowsText.BackgroundTransparency = 1
rowsText.Font = Enum.Font.GothamBold
rowsText.TextScaled = true
rowsText.TextColor3 = Color3.new(1, 1, 1)
rowsText.TextYAlignment = Enum.TextYAlignment.Top
rowsText.RichText = true
rowsText.Parent = card
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
placeText.Font = Enum.Font.GothamBlack
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
hurry.Font = Enum.Font.GothamBlack
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
local racingAt = 0 -- os.clock() when this race started (the banner stays up over the 3-2-1)
local BANNER = 5 -- seconds the "RACE ON MIA'S TRACK!" banner stays up once the race is on

RunService.RenderStepped:Connect(function()
	local secs = startAt - workspace:GetServerTimeNow()
	-- the call: the small chip steps aside for the huge banner
	-- the call, and on through the 3-2-1: whose track this is
	local starting = phase == "racing" and os.clock() - racingAt < BANNER
	call.Visible = (phase == "call" and startAt > 0) or starting
	callClock.Visible = not starting -- the giant 3-2-1 takes over from the clock
	-- the daily gift (Stars) waits while a race or its card is on screen
	gui:SetAttribute("Busy", phase == "racing" or phase == "call" or card.Visible)
	local hurryLeft = endsAt - workspace:GetServerTimeNow()
	hurry.Visible = phase == "racing" and endsAt > 0 and not finished and hurryLeft > 0
	if hurry.Visible then
		hurry.Text = if driftEnds
			then `DRIFT!  {ServerRace.clock(hurryLeft)} LEFT`
			else `FINISH IN {ServerRace.clock(hurryLeft)}!`
	end
	-- (the build screen has its own clock)
	-- while driving it waits for the last minute (it sat in the middle of the road on a phone)
	local driving = player:GetAttribute("Driving") == true
	join.Visible = phase ~= "racing"
		and phase ~= "call"
		and startAt > 0
		and player:GetAttribute("Building") ~= true
		and (not driving or secs <= 60)
	if call.Visible then
		local verb = if kind == "drift" then "DRIFT" else "RACE"
		callWhere.Text = if where ~= "" then `{verb} ON {where}!` else `{verb}!`
		callClock.Text = ServerRace.clock(secs)
		-- a little pulse each second
		local f = secs % 1
		callClock.Size = UDim2.fromScale(1, 0.62 + 0.06 * f)
	end
	if not join.Visible then
		return
	end
	local left = ServerRace.clock(secs)
	if phase == "call" then
		join.BackgroundColor3 = YELLOW
		join.TextColor3 = DARK
		join.Text = if where ~= "" then `RACE IN {left}  {where}` else `RACE IN {left}`
	else
		join.BackgroundColor3 = DARK
		join.TextColor3 = YELLOW
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
	task.delay(2.5, function()
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
	if #rows == 0 then
		return
	end
	local first = rows[1]
	local won = first.time or (type(first.score) == "number" and first.score > 0)
	-- the winner's car in the title: cars get shown off
	local firstCar = if type(first.car) == "string" then string.upper(first.car) else nil
	title.Text = if won and firstCar
		then `🏆 {first.name} WINS IN {firstCar}!`
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
			else `{r.laps}/{ServerRace.LAPS} laps`
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
	table.insert(
		lines,
		`<font color="#9AA0AA">NEXT RACE IN {ServerRace.clock(ServerRace.BREAK)}</font>`
	)
	rowsText.Text = table.concat(lines, "\n")
	-- the card fits its rows (one racer = a short card, no empty gap)
	-- (rows 6.5% of the screen tall each: big enough to read on a phone)
	local tall = 0.2 + 0.065 * #lines
	rowsText.Size = UDim2.fromScale(0.86, (0.065 * #lines) / tall)
	showId += 1
	local me = showId
	card.Visible = true
	card.Size = UDim2.fromScale(0.44, tall * 0.65)
	card:SetAttribute("Bottom", card.Position.Y.Scale + tall) -- the prize card (Stars) goes under it
	title.Size = UDim2.fromScale(0.9, 0.14 / tall)
	rowsText.Position = UDim2.fromScale(0.07, 0.05 + 0.16 / tall)
	TweenService:Create(
		card,
		TweenInfo.new(0.35, Enum.EasingStyle.Back),
		{ Size = UDim2.fromScale(0.68, tall) }
	):Play()
	task.delay(ServerRace.SHOW, function()
		if me == showId then
			card.Visible = false
		end
	end)
end

event.OnClientEvent:Connect(
	function(what: unknown, a: unknown, b: unknown, _c: unknown, d: unknown, e: unknown)
		if what == "state" and type(a) == "string" and type(b) == "number" then
			kind = if d == "drift" then "drift" else "race"
			if a == "racing" and phase ~= "racing" then
				racingAt = os.clock()
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
		elseif what == "result" and type(a) == "table" then
			showResult(a :: { any })
		end
	end
)
