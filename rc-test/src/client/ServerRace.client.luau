--!strict
-- The server race on screen: a chip counting down the break to the next race (and, for the last
-- 10 s, whose track it is on), and when a race ends a pop-up with who won, for everyone. The
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
-- under QUICK RACE on foot, under the drift score in a car
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
call.Position = UDim2.new(0.5, 0, 0, 58)
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
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.42)
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
rowsText.Parent = card
local rowsSize = Instance.new("UITextSizeConstraint")
rowsSize.MaxTextSize = 34
rowsSize.Parent = rowsText

local phase = "wait"
local startAt = 0
local where = ""

RunService.RenderStepped:Connect(function()
	local secs = startAt - workspace:GetServerTimeNow()
	-- the call: the small chip steps aside for the huge banner
	call.Visible = phase == "call" and startAt > 0
	-- (the build screen has its own clock)
	join.Visible = phase ~= "racing"
		and phase ~= "call"
		and startAt > 0
		and player:GetAttribute("Building") ~= true
	if call.Visible then
		callWhere.Text = if where ~= "" then `RACE ON {where}` else "RACE!"
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

local showId = 0
local function showResult(rows: { any })
	if #rows == 0 then
		return
	end
	local first = rows[1]
	title.Text = if first.time then `🏆 {first.name} WINS!` else "TIME UP!"
	local lines = {}
	for i = 1, math.min(#rows, 4) do
		local r = rows[i]
		local what = if type(r.time) == "number"
			then CarMath.formatTime(r.time)
			else `{r.laps}/{ServerRace.LAPS} laps`
		table.insert(lines, `{i}. {r.name}   {what}`)
	end
	rowsText.Text = table.concat(lines, "\n")
	showId += 1
	local me = showId
	card.Visible = true
	card.Size = UDim2.fromScale(0.3, 0.26)
	TweenService
		:Create(
			card,
			TweenInfo.new(0.35, Enum.EasingStyle.Back),
			{ Size = UDim2.fromScale(0.46, 0.4) }
		)
		:Play()
	task.delay(ServerRace.SHOW, function()
		if me == showId then
			card.Visible = false
		end
	end)
end

event.OnClientEvent:Connect(
	function(kind: unknown, a: unknown, b: unknown, _c: unknown, _d: unknown, e: unknown)
		if kind == "state" and type(a) == "string" and type(b) == "number" then
			phase, startAt = a, b
			where = if type(e) == "string" then e else ""
		elseif kind == "result" and type(a) == "table" then
			showResult(a :: { any })
		end
	end
)
