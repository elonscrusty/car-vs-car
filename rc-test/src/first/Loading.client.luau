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
-- (one group under everything: the whole screen fades as one, no layer showing through another)
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

-- the world behind: sky over a sandy floor with a red / white wall line
local sky = frame(root, "Sky", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE)
sky.ZIndex = 0
gradient(sky, { "3fb3ff", "8fd8ff", "e6f5ff" })
local floor = frame(root, "Floor", UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.42), WHITE)
floor.ZIndex = 1
gradient(floor, { "f3c99a", "e0a571" })
local wall = frame(root, "Wall", UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.035), hex("ec1c2e"))
wall.ZIndex = 2
for i = 0, 12 do
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
stage.ZIndex = 3
stage.Parent = root
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 844 / 390
ar.Parent = stage

-- the logo, one stacked piece like the kit: an ink layer with a thick outline and a drop, a white
-- outline over it, then the letters in their colors (Car blue, vs yellow, Car red), a slight lean
local logo = Instance.new("Frame")
logo.Name = "Logo"
logo.BackgroundTransparency = 1
logo.AnchorPoint = Vector2.new(0.5, 0)
logo.Position = UDim2.fromScale(0.5, 0.06)
logo.Size = UDim2.fromScale(0.66, 0.3)
logo.Rotation = -3
logo.ZIndex = 5
logo.Parent = stage
local LOGO_RICH = '<font color="#1fa8f5">Car</font><font color="#ffd93b"> vs </font>'
	.. '<font color="#ff4a4a">Car</font>'
for i, layer in { "Drop", "Outline", "Letters" } do
	local l = Instance.new("TextLabel")
	l.Name = layer
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	-- (all three RichText: a plain TextScaled layer stops at 100 px and a rich one doesn't, so a
	-- smaller white logo peeked out behind the big letters, Studio qa_r58)
	l.RichText = true
	l.Text = if layer == "Letters" then LOGO_RICH else "Car vs Car"
	l.TextColor3 = if layer == "Drop" then INK else WHITE
	l.Position = if layer == "Drop" then UDim2.fromScale(0, 0.07) else UDim2.new()
	l.Size = UDim2.fromScale(1, 1)
	l.ZIndex = 5 + i
	l.Parent = logo
	if layer == "Drop" then
		stroke(l, 9, INK, true)
	elseif layer == "Outline" then
		stroke(l, 5, WHITE, true)
	else
		stroke(l, 2, INK, true)
	end
end
-- (a soft shine down the letters, as the kit's glossy words)
local shineG = Instance.new("UIGradient")
shineG.Rotation = 90
shineG.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 245, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 215, 235)),
})
shineG.Parent = logo:FindFirstChild("Letters")

-- the arena's edges like the kit: a wooden fence along the wall, a round tree each side
local fence = Instance.new("Frame")
fence.Name = "Fence"
fence.BackgroundTransparency = 1
fence.Position = UDim2.fromScale(0, 0.46)
fence.Size = UDim2.fromScale(1, 0.09)
fence.ZIndex = 2
fence.Parent = root
local WOOD = hex("b97a45")
for _, y in { 0.2, 0.6 } do
	local rail = frame(fence, "Rail", UDim2.fromScale(0, y), UDim2.fromScale(1, 0.2), WOOD)
	rail.ZIndex = 2
	stroke(rail, 2, INK)
end
for i = 0, 20 do
	local post =
		frame(fence, "Post", UDim2.fromScale(i / 20 - 0.006, 0), UDim2.fromScale(0.012, 1), WOOD)
	post.ZIndex = 3
	stroke(post, 2, INK)
end
local function tree(x: number)
	local t = Instance.new("Frame")
	t.Name = "Tree"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, 0.12)
	t.Size = UDim2.fromScale(0.16, 0.5)
	t.ZIndex = 4
	t.Parent = root
	local trunk =
		frame(t, "Trunk", UDim2.fromScale(0.42, 0.55), UDim2.fromScale(0.16, 0.45), hex("8a5a30"))
	trunk.ZIndex = 4
	stroke(trunk, 2.5, INK)
	for k, b in { { 0.05, 0.25, 0.6 }, { 0.35, 0.05, 0.6 }, { 0.4, 0.3, 0.55 } } do
		local ball = frame(
			t,
			"Leaves",
			UDim2.fromScale(b[1], b[2]),
			UDim2.fromScale(b[3], b[3] * 0.62),
			WHITE
		)
		ball.ZIndex = 4 + k
		round(ball)
		gradient(ball, { "8be81c", "4fbf1a", "2f8a10" })
		stroke(ball, 3, INK)
	end
	local ar2 = Instance.new("UIAspectRatioConstraint")
	ar2.AspectRatio = 0.62
	ar2.Parent = t
end
tree(-0.04)
tree(0.88)

-- the bar: a recessed dark track, a striped yellow fill that runs as things load
local track = frame(stage, "Track", UDim2.fromScale(0.2, 0.76), UDim2.fromScale(0.6, 0.085), WHITE)
gradient(track, { "071226", "10264a" })
round(track)
stroke(track, 3, INK)
local rim =
	frame(stage, "Rim", UDim2.fromScale(0.195, 0.75), UDim2.fromScale(0.61, 0.105), hex("1fa8f5"))
rim.ZIndex = 0
round(rim)
stroke(rim, 3, INK)
track.ZIndex = 1
-- (a CanvasGroup clips its stripes to the rounded ends; ClipsDescendants would leave them square)
local fill = Instance.new("CanvasGroup")
fill.Name = "Fill"
fill.BorderSizePixel = 0
fill.BackgroundTransparency = 1
fill.Size = UDim2.fromScale(0.04, 1)
fill.Parent = track
round(fill)
-- (the yellow is its own frame: a UIGradient on the group would tint the stripes and shine yellow
-- too, Studio r52)
local color = frame(fill, "Color", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE)
gradient(color, { "fff6b0", "ffd93b", "ffb000" })
round(color)
color.ZIndex = 1
-- the kit's diagonal stripes: light bars leaning across the fill, sliding along
local stripes = Instance.new("Frame")
stripes.Name = "Stripes"
stripes.BackgroundTransparency = 1
stripes.Size = UDim2.new(0, 2000, 1, 0)
stripes.ZIndex = 2
stripes.Parent = fill
local STEP = 22 -- px between stripes
for i = 0, 2000 / STEP do
	local st =
		frame(stripes, "Stripe", UDim2.new(0, i * STEP, -0.5, 0), UDim2.new(0, 9, 2, 0), WHITE)
	st.BackgroundTransparency = 0.72
	st.Rotation = 35
end
local shine = frame(fill, "Shine", UDim2.fromScale(0.02, 0.12), UDim2.fromScale(0.96, 0.25), WHITE)
shine.ZIndex = 3
shine.BackgroundTransparency = 0.45
round(shine)

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.FredokaOne
tip.TextScaled = true
tip.TextColor3 = WHITE
tip.Text = "TIP: grab a ? box, then smash the others!"
-- (above a phone's home bar, readable on a 667x375 phone, not huge on a PC)
tip.Position = UDim2.fromScale(0.15, 0.885)
tip.Size = UDim2.fromScale(0.7, 0.065)
tip.Parent = stage
stroke(tip, 2.5, INK, true)
local cap = Instance.new("UITextSizeConstraint")
cap.MaxTextSize = 28
cap.Parent = tip

gui.Parent = player:WaitForChild("PlayerGui")
-- (only now: ours is up, so nothing shows uncovered in between)
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- the karts (the kit's three: pink, lime, blue): the game's real ones in 3D as soon as they can be
-- made (CarSkin, once the player scripts are in); until then the sky and the logo. Their own layer
-- over the group: a ViewportFrame may not draw inside a CanvasGroup.
local KARTS = {
	-- (every kart's wheels end over the bar's top at 0.75, not on it: Studio qa_r58)
	{ id = "race_berry", x = 0.1, y = 0.36, w = 0.26, h = 0.34 },
	{ id = "race_lime", x = 0.34, y = 0.28, w = 0.32, h = 0.42 },
	{ id = "race_dart", x = 0.64, y = 0.36, w = 0.26, h = 0.34 },
}
local kartLayer = Instance.new("Frame")
kartLayer.Name = "Karts"
kartLayer.BackgroundTransparency = 1
kartLayer.AnchorPoint = Vector2.new(0.5, 0.5)
kartLayer.Position = UDim2.fromScale(0.5, 0.5)
kartLayer.Size = UDim2.fromScale(1, 1)
kartLayer.ZIndex = 10
kartLayer.Parent = gui
local kar = Instance.new("UIAspectRatioConstraint")
kar.AspectRatio = 844 / 390
kar.Parent = kartLayer
local views: { ViewportFrame } = {}
local done = false
local function showKart(spot: { [string]: any }, model: Model)
	local view = Instance.new("ViewportFrame")
	view.Name = spot.id
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(190, 190, 200)
	view.LightDirection = Vector3.new(-0.4, -1, -0.6)
	view.Position = UDim2.fromScale(spot.x, spot.y)
	view.Size = UDim2.fromScale(spot.w, spot.h)
	view.ZIndex = 10
	view.Parent = kartLayer
	local world = Instance.new("WorldModel")
	world.Parent = view
	model:PivotTo(CFrame.identity)
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local mid = cf.Position
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- (from the front and a little above, nose to -Z: far enough that it fills the spot)
	local dist = math.max(size.X, size.Y, size.Z) * 2.1
	cam.CFrame = CFrame.lookAt(mid + Vector3.new(-0.45, 0.35, -1).Unit * dist, mid)
	cam.Parent = view
	view.CurrentCamera = cam
	table.insert(views, view)
end
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts", 10)
	local client = ps and ps:WaitForChild("Client", 10)
	local mod = client and client:WaitForChild("CarSkin", 10)
	if not (mod and mod:IsA("ModuleScript")) then
		return
	end
	-- (CarSkin reaches the game's shared modules on load: only once the game is in, or a failed
	-- first load would break it for the whole visit)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	if done then
		return
	end
	local ok, CarSkin = pcall(require, mod)
	if not ok then
		return
	end
	local left = table.clone(KARTS)
	-- (a kart built in game can take a moment: try again until the screen goes. Until it is
	-- built copyOf gives the plain toy, so wait for the kart itself; after a few tries, the toy.)
	local tries = 0
	while not done and #left > 0 do
		tries += 1
		for i = #left, 1, -1 do
			local made, m = pcall(function()
				local skin = CarSkin :: any
				if tries < 8 and not skin.kartFor(left[i].id) then
					return nil
				end
				return skin.copyOf(left[i].id)
			end)
			if made and typeof(m) == "Instance" and m:IsA("Model") and not done then
				showKart(left[i], m)
				table.remove(left, i)
			end
		end
		task.wait(0.4)
	end
end)

local started = os.clock()
local shown = 0.04
local function ready(): boolean
	return game:IsLoaded() and type(player:GetAttribute("Coins")) == "number"
end
local conn: RBXScriptConnection
conn = RunService.RenderStepped:Connect(function(dt: number)
	if done then
		return
	end
	-- the bar: creeps toward 0.4, then 0.7 once the game is in, toward 0.9 with time, full when
	-- ready; never back
	local t = math.clamp((os.clock() - started) / MAX_WAIT, 0, 1)
	local base = if game:IsLoaded() then 0.7 else 0.4
	local goal = if ready() then 1 else base + (0.9 - base) * t
	shown = math.max(shown, math.min(1, shown + (goal - shown) * math.min(1, dt * 6)))
	fill.Size = UDim2.fromScale(math.max(0.04, shown), 1)
	stripes.Position = UDim2.fromOffset(-((os.clock() * 30) % STEP), 0)
	if ready() or os.clock() - started >= MAX_WAIT then
		done = true
		shown = 1
		fill.Size = UDim2.fromScale(1, 1)
		TweenService:Create(root, TweenInfo.new(FADE), { GroupTransparency = 1 }):Play()
		for _, v in views do
			TweenService:Create(v, TweenInfo.new(FADE), { ImageTransparency = 1 }):Play()
		end
		task.delay(FADE + 0.05, function()
			conn:Disconnect()
			gui:Destroy()
		end)
	end
end)
