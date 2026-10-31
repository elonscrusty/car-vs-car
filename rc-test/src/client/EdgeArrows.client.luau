--!strict
-- EDGE ARROWS (Lead pick "1 Chevron"): in a match a small chevron sits on the screen edge for each
-- of the 3 nearest enemy karts and the nearest box that is up, when they are off screen. Red =
-- kart, gold = box. Small, see-through, nearer = stronger. The maths is in shared/EdgeArrow.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EdgeArrow = require(Shared:WaitForChild("EdgeArrow"))
local MatchGoal = require(Shared:WaitForChild("MatchGoal")) -- (MatchGoal.live: still in a running match)

local player = Players.LocalPlayer
local myCar = "Car_" .. player.UserId

local RED = Color3.fromRGB(227, 23, 30)
local GOLD = Color3.fromRGB(255, 210, 60)
local INK = Color3.fromRGB(13, 44, 64)
local SIZE = 30
local ARM, THICK = 17, 5

local gui = Instance.new("ScreenGui")
gui.Name = "EdgeArrows"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1
gui.Parent = player:WaitForChild("PlayerGui")

type Chevron = { root: Frame, bars: { Frame }, strokes: { UIStroke } }
local pool: { Chevron } = {}

local function arm(parent: Frame, cy: number, rot: number): (Frame, UIStroke)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(ARM, THICK)
	f.Position = UDim2.fromOffset(SIZE * 0.53, cy)
	f.Rotation = rot
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 2)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 1.5
	s.Parent = f
	return f, s
end

local function make(): Chevron
	local root = Instance.new("Frame")
	root.Name = "Chevron"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(SIZE, SIZE)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local a, sa = arm(root, SIZE * 0.33, 40)
	local b, sb = arm(root, SIZE * 0.67, -40)
	return { root = root, bars = { a, b }, strokes = { sa, sb } }
end

local function chevron(i: number): Chevron
	while #pool < i do
		table.insert(pool, make())
	end
	return pool[i]
end

type Target = { pos: Vector3, enemy: boolean, dist: number }

local function targets(eye: Vector3): { Target }
	local out: { Target } = {}
	for _, c in workspace:GetChildren() do
		if
			c:IsA("Model")
			and c.Name ~= myCar
			and string.match(c.Name, "^Car_%-?%d+$") ~= nil
			and c.PrimaryPart
			and c:GetAttribute("Smashed") ~= true
			and c:GetAttribute("Wrecked") ~= true
		then
			local p = (c :: Model).PrimaryPart :: BasePart
			table.insert(
				out,
				{ pos = p.Position, enemy = true, dist = (p.Position - eye).Magnitude }
			)
		end
	end
	for _, m in CollectionService:GetTagged("SmashBox") do
		if m:IsA("Model") and m:GetAttribute("Up") == true and m.PrimaryPart then
			local p = (m :: Model).PrimaryPart :: BasePart
			table.insert(
				out,
				{ pos = p.Position, enemy = false, dist = (p.Position - eye).Magnitude }
			)
		end
	end
	return out
end

local function hideFrom(i: number)
	for j = i, #pool do
		pool[j].root.Visible = false
	end
end

local lastAt = 0
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if
		not cam
		or not MatchGoal.live(
			player:GetAttribute("InMatch"),
			player:GetAttribute("MatchEndsAt"),
			workspace:GetServerTimeNow()
		)
	then
		hideFrom(1)
		return
	end
	-- 20 times a second is plenty for a pointer
	local now = os.clock()
	if now - lastAt < 0.05 then
		return
	end
	lastAt = now
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local list = targets(cam.CFrame.Position)
	local picks = EdgeArrow.pick(list)
	local shown = 0
	local phone = size.X < 1000
	local side, top, bottom =
		if phone then 36 else 48, if phone then 74 else 90, if phone then 110 else 90
	for _, idx in picks do
		local t = list[idx]
		local v, onScreen = cam:WorldToViewportPoint(t.pos)
		local sx, sy = v.X, v.Y
		if v.Z < 0 then
			sx, sy = EdgeArrow.behind(size.X, size.Y, sx, sy)
		end
		local spot = EdgeArrow.place(size.X, size.Y, sx, sy, side, top, side, bottom)
		-- phone: the right edge below this line is the DRIFT / FIRE / SPECIAL thumb buttons, which
		-- would hide the chevron, so it stays above them (EdgeArrow.rightCeiling)
		if phone and spot.x > size.X / 2 then
			spot.y = math.min(spot.y, EdgeArrow.rightCeiling(size.Y))
		end
		if v.Z >= 0 and onScreen and spot.inside then
			continue
		end
		shown += 1
		local c = chevron(shown)
		c.root.Visible = true
		c.root.Position = UDim2.fromOffset(spot.x, spot.y)
		c.root.Rotation = spot.angle
		local color = if t.enemy then RED else GOLD
		local alpha = 1 - EdgeArrow.strength(t.dist)
		for k, bar in c.bars do
			bar.BackgroundColor3 = color
			bar.BackgroundTransparency = alpha
			c.strokes[k].Transparency = alpha + 0.1
		end
	end
	hideFrom(shown + 1)
end)
