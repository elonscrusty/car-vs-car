--!strict
-- Car VS Car: the loading screen (carter's UI kit v41, screens/Loading.png): sky, the Car vs Car
-- logo, a striped yellow bar and one tip line. It runs first (ReplicatedFirst), hides the world
-- popping in on a phone join, and goes as soon as the lobby is ready: the game is loaded and your
-- save is in (the server sets Coins), at most MAX_WAIT seconds. No Ui modules here: they are not
-- in yet.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MAX_WAIT = 15 -- seconds: never hold a kid longer than this
local FADE = 0.3

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local INK = Color3.fromRGB(13, 44, 64)
local WHITE = Color3.new(1, 1, 1)
local function hex(h: string): Color3
	return Color3.fromRGB(
		tonumber(h:sub(1, 2), 16) :: number,
		tonumber(h:sub(3, 4), 16) :: number,
		tonumber(h:sub(5, 6), 16) :: number
	)
end
local function gradient(obj: GuiObject, stops: { string }, rotation: number?)
	local keys = {}
	for i, h in stops do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#stops - 1), hex(h)))
	end
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 90
	g.Color = ColorSequence.new(keys)
	g.Parent = obj
end
local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = pos
	f.Size = size
	f.Parent = parent
	return f
end
local function round(obj: GuiObject, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = obj
end
local function stroke(obj: GuiObject, px: number, color: Color3, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = px
	s.Color = color
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = if contextual
		then Enum.ApplyStrokeMode.Contextual
		else Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "CvcLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- the world behind: sky over a sandy floor with a red / white wall line
local sky = frame(gui, "Sky", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE)
gradient(sky, { "3fb3ff", "8fd8ff", "e6f5ff" })
local floor = frame(gui, "Floor", UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.42), WHITE)
gradient(floor, { "f3c99a", "e0a571" })
local wall = frame(gui, "Wall", UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.035), hex("ec1c2e"))
for i = 0, 24 do
	frame(wall, "White", UDim2.fromScale(i / 12.5, 0), UDim2.fromScale(1 / 25, 1), WHITE)
end
wall.ClipsDescendants = true

-- everything else sits on a 16:9-ish stage in the middle, so a phone and a PC look the same
local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.BackgroundTransparency = 1
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
stage.Size = UDim2.fromScale(1, 1)
stage.Parent = gui
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 844 / 390
ar.Parent = stage

-- the logo: Car (blue) vs (yellow) Car (red), white then ink outlines, a slight lean
local logo = Instance.new("Frame")
logo.Name = "Logo"
logo.BackgroundTransparency = 1
logo.AnchorPoint = Vector2.new(0.5, 0)
logo.Position = UDim2.fromScale(0.5, 0.08)
logo.Size = UDim2.fromScale(0.62, 0.3)
logo.Rotation = -3
logo.Parent = stage
local function word(text: string, x: number, w: number, stops: { string }, small: boolean?)
	for _, layer in { "Ink", "Fill" } do
		local l = Instance.new("TextLabel")
		l.Name = text .. layer
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = if layer == "Ink" then INK else WHITE
		l.Position = UDim2.fromScale(x, if small then 0.3 else 0)
			+ (if layer == "Ink" then UDim2.fromScale(0, 0.06) else UDim2.new())
		l.Size = UDim2.fromScale(w, if small then 0.6 else 1)
		l.ZIndex = if layer == "Ink" then 2 else 3
		l.Parent = logo
		if layer == "Ink" then
			stroke(l, 6, INK, true)
		else
			stroke(l, 3, WHITE, true)
			gradient(l, stops)
		end
	end
end
word("Car", 0, 0.4, { "8fd8ff", "1fa8f5", "0b78c9" })
word("vs", 0.4, 0.2, { "fff7b8", "ffd93b", "ffb400" }, true)
word("Car", 0.6, 0.4, { "ffd3c6", "ff4a4a", "e01428" })

-- the bar: a recessed dark track, a striped yellow fill that runs as things load
local track = frame(stage, "Track", UDim2.fromScale(0.2, 0.83), UDim2.fromScale(0.6, 0.085), WHITE)
gradient(track, { "071226", "10264a" })
round(track)
stroke(track, 3, INK)
local rim =
	frame(stage, "Rim", UDim2.fromScale(0.195, 0.82), UDim2.fromScale(0.61, 0.105), hex("1fa8f5"))
rim.ZIndex = 0
round(rim)
stroke(rim, 3, INK)
track.ZIndex = 1
local fill = frame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0.04, 1), WHITE)
gradient(fill, { "fff6b0", "ffd93b", "ffb000" })
round(fill)
fill.ClipsDescendants = true
local shine = frame(fill, "Shine", UDim2.fromScale(0.02, 0.12), UDim2.fromScale(0.96, 0.25), WHITE)
shine.BackgroundTransparency = 0.45
round(shine)

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.FredokaOne
tip.TextScaled = true
tip.TextColor3 = WHITE
tip.Text = "TIP: grab a ? box, then smash the others!"
tip.Position = UDim2.fromScale(0.2, 0.935)
tip.Size = UDim2.fromScale(0.6, 0.05)
tip.Parent = stage
stroke(tip, 2.5, INK, true)

gui.Parent = player:WaitForChild("PlayerGui")

local started = os.clock()
local shown = 0.04
local done = false
local function ready(): boolean
	return game:IsLoaded() and type(player:GetAttribute("Coins")) == "number"
end
local conn: RBXScriptConnection
conn = RunService.RenderStepped:Connect(function(dt: number)
	-- the bar: creeps toward 0.4, then 0.7 once the game is in, toward 0.9 with time, full when
	-- ready; never back
	local t = math.clamp((os.clock() - started) / MAX_WAIT, 0, 1)
	local base = if game:IsLoaded() then 0.7 else 0.4
	local goal = if ready() then 1 else base + (0.9 - base) * t
	shown = math.max(shown, math.min(1, shown + (goal - shown) * math.min(1, dt * 6)))
	fill.Size = UDim2.fromScale(math.max(0.04, shown), 1)
	if done then
		return
	end
	if ready() or os.clock() - started >= MAX_WAIT then
		done = true
		fill.Size = UDim2.fromScale(1, 1)
		local info = TweenInfo.new(FADE)
		for _, d in gui:GetDescendants() do
			if d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(FADE + 0.05, function()
			conn:Disconnect()
			gui:Destroy()
		end)
	end
end)
