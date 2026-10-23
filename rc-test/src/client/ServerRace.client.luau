--!strict
-- The server race on screen: for the last minute before a race a big JOIN button (tap again to
-- leave), and when a race ends a pop-up with who won, for everyone. The server decides
-- everything (ServerRaceRunner); this only shows it and sends the taps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CarMath = require(ReplicatedStorage.Shared.CarMath)
local ServerRace = require(ReplicatedStorage.Shared.ServerRace)

local event = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent
local player = Players.LocalPlayer

local YELLOW = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(70, 200, 90)
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

-- JOIN: a big round pill at the top middle (thumbs stay free at the bottom corners)
local join = Instance.new("TextButton")
join.Name = "Join"
join.AnchorPoint = Vector2.new(0.5, 0)
join.Position = UDim2.fromScale(0.5, 0.17)
join.Size = UDim2.fromScale(0.42, 0.1)
join.BackgroundColor3 = YELLOW
join.TextColor3 = DARK
join.Font = Enum.Font.GothamBlack
join.TextScaled = true
join.AutoButtonColor = true
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
local count = 0
local mine = false

join.Activated:Connect(function()
	event:FireServer(if mine then "leave" else "join")
end)

RunService.RenderStepped:Connect(function()
	join.Visible = phase == "call"
	if phase ~= "call" then
		return
	end
	local left = ServerRace.clock(startAt - workspace:GetServerTimeNow())
	if mine then
		join.BackgroundColor3 = GREEN
		join.Text = `JOINED!  {left}  ({count} racing)`
	else
		join.BackgroundColor3 = YELLOW
		join.Text = `SERVER RACE  {left}  TAP TO JOIN`
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

event.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
	if kind == "state" and type(a) == "string" and type(b) == "number" and type(c) == "number" then
		phase, startAt, count, mine = a, b, c, d == true
	elseif kind == "result" and type(a) == "table" then
		showResult(a :: { any })
	end
end)
