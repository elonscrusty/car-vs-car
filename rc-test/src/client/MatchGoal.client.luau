--!strict
-- The tiny match goal (carter 10-31 pick 3): a small pill on the left edge, under the kill list / scoreboard and above the stick in a match, "SMASH 3"
-- with a thin bar. Its own ScreenGui under the HUD, so it never covers a button. Words come from
-- shared/MatchGoal. Looks only. (Spot checked against the HUD pieces in tests/match_goal.test; not seen in Studio yet.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchGoal = require(Shared:WaitForChild("MatchGoal"))
local UiFonts = require(Shared:WaitForChild("UiFonts"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local player = Players.LocalPlayer
local INK = Color3.fromRGB(20, 26, 44)
local LIME = Color3.fromRGB(150, 230, 80)

local gui = Instance.new("ScreenGui")
gui.Name = "MatchGoal"
gui.ResetOnSpawn = false
gui.DisplayOrder = Base.ORDER.hud - 1
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(0, 0)
pill.Position = UDim2.new(0, MatchGoal.PILL.x, MatchGoal.PILL.top, 0)
pill.Size = UDim2.fromOffset(MatchGoal.PILL.w, MatchGoal.PILL.h)
pill.BackgroundColor3 = INK
pill.BackgroundTransparency = 0.25
pill.BorderSizePixel = 0
pill.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = pill

local label = Instance.new("TextLabel")
label.Name = "Words"
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(8, 2)
label.Size = UDim2.new(1, -16, 0, 18)
label.Font = UiFonts.TITLE
label.TextSize = 15
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = pill

local track = Instance.new("Frame")
track.Name = "Track"
track.Position = UDim2.new(0, 8, 1, -11)
track.Size = UDim2.new(1, -16, 0, 5)
track.BackgroundColor3 = Color3.fromRGB(60, 70, 100)
track.BorderSizePixel = 0
track.Parent = pill
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = LIME
fill.BorderSizePixel = 0
fill.Parent = track

local function inMatch(): boolean
	return MatchGoal.live(
		player:GetAttribute("InMatch"),
		player:GetAttribute("MatchEndsAt"),
		workspace:GetServerTimeNow()
	)
end

local function refresh()
	gui.Enabled = inMatch()
	local v = MatchGoal.read(player:GetAttribute("Smashes"))
	label.Text = v.words
	fill.Size = UDim2.fromScale(v.f, 1)
end

for _, name in { "Smashes", "InMatch", "MatchEndsAt" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
-- (the server keeps InMatch on through the break between rounds: no attribute changes when the
-- clock runs out, so look at the clock a few times a second)
task.spawn(function()
	while true do
		task.wait(0.25)
		local on = inMatch()
		if gui.Enabled ~= on then
			refresh()
		end
	end
end)
