--!strict
-- Goal burst (audit #23). Reacts to the server's goal message (a "ko" update whose text is
-- "GOAL!" or "THEY SCORED!", with the ball position): confetti in the scorer's team colour, a
-- 1 s camera snap to the ball, the goal sound, and the scorer's name when the message carries
-- one (`u.scorer`, a display name; the server does not send it yet, so nothing shows until it
-- does). Everything is over inside GameConfig.Feel.goalBurstSeconds (< the 2.5 s goal pause).
-- Screen graphics only, no layout of the real UI is touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeelRules = require(ReplicatedStorage.Shared.FeelRules)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ModesConfig = require(ReplicatedStorage.Shared.ModesConfig)
local Quality = require(script.Parent.Quality)
local SoundFx = require(script.Parent.SoundFx)
local WinFx = require(script.Parent.WinFx)

local GoalFx = {}

local gui: ScreenGui? = nil
local seedCounter = 0

local function getGui(): ScreenGui
	local g = gui
	if g == nil or g.Parent == nil then
		g = Instance.new("ScreenGui")
		g.Name = "CarVsCarGoalFx"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 8
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = g
	end
	return g :: ScreenGui
end

-- Which soccer team you are on, from the colour the server gives your car's marker (0 = unknown).
local function myTeam(): number
	local uid = Players.LocalPlayer.UserId
	for _, arena in workspace:GetChildren() do
		if arena.Name == "Arena" then
			for _, m in arena:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("DriverUserId") == uid then
					local marker = m:FindFirstChild("Marker")
					if marker and marker:IsA("BasePart") then
						local c = marker.Color
						return FeelRules.teamOfColor(
							c.R * 255,
							c.G * 255,
							c.B * 255,
							ModesConfig.Soccer.colors
						)
					end
				end
			end
		end
	end
	return 0
end

-- u = the "ko" UiUpdate. director = CameraDirector. Does nothing for other ko texts.
function GoalFx.handle(u: any, director: any)
	local text = if type(u.text) == "string" then u.text else ""
	local isGoal, mine = FeelRules.parseGoal(text)
	if not isGoal then
		return
	end
	local feel = GameConfig.Feel
	SoundFx.play("goal")
	if typeof(u.pos) == "Vector3" and director and director.snap then
		director.snap(u.pos)
	end

	local team = FeelRules.scorerTeam(myTeam(), mine)
	local colors: { Color3 } = { Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 255, 255) }
	local labelColor = Color3.fromRGB(255, 255, 255)
	local rgb = ModesConfig.Soccer.colors[team]
	if rgb then
		local base = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		colors =
			{ base, base:Lerp(Color3.new(1, 1, 1), 0.45), base:Lerp(Color3.new(0, 0, 0), 0.25) }
		labelColor = base:Lerp(Color3.new(1, 1, 1), 0.3)
	end

	local parent = getGui()
	seedCounter += 1
	local count = math.max(8, math.floor(feel.goalConfetti * Quality.scale()))
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent
	WinFx.goalBurst(holder, seedCounter * 7919, count, colors, feel.goalBurstSeconds)

	-- Scorer name, only when the message has it.
	local who = u.scorer
	if type(who) == "string" and who ~= "" then
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.5, 0.3)
		label.Size = UDim2.fromScale(0.4, 0.07)
		label.Text = string.upper(string.sub(who, 1, 20)) .. " SCORES!"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = labelColor
		label.TextStrokeTransparency = 0.1
		label.Parent = holder
	end
	task.delay(feel.goalBurstSeconds, function()
		holder:Destroy()
	end)
end

return GoalFx
