--!strict
-- EDGE ARROWS (carter pick "2 Badge"): in a match a small round badge sits on the screen edge for each
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
local SIZE = 32

local gui = Instance.new("ScreenGui")
gui.Name = "EdgeArrows"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1
gui.Parent = player:WaitForChild("PlayerGui")

type Chevron = {
	root: Frame,
	disc: Frame,
	ring: UIStroke,
	tip: Frame,
	tipStroke: UIStroke,
	car: { Frame },
	q: TextLabel,
}
local pool: { Chevron } = {}

local function round(f: GuiObject, r: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = f
end

local function bit(parent: Frame, x: number, y: number, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BorderSizePixel = 0
	f.ZIndex = 4
	f.Parent = parent
	round(f, UDim.new(0, 2))
	return f
end

-- A round badge (Badge look carter picked): dark disc, coloured ring, a little car (enemy) or "?"
-- (box) that stays upright, and a pointer tip that sits on the rim toward the target.
local function make(): Chevron
	local root = Instance.new("Frame")
	root.Name = "Badge"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(SIZE, SIZE)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(11, 11)
	tip.BorderSizePixel = 0
	tip.ZIndex = 1
	tip.Parent = root
	local tipStroke = Instance.new("UIStroke")
	tipStroke.Color = INK
	tipStroke.Thickness = 1.5
	tipStroke.Parent = tip
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(SIZE, SIZE)
	disc.BackgroundColor3 = INK
	disc.ZIndex = 3
	disc.Parent = root
	round(disc, UDim.new(0.5, 0))
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.Parent = disc
	local half = SIZE / 2
	local car = { bit(root, half, half + 2, 16, 7), bit(root, half, half - 3, 10, 5) }
	local q = Instance.new("TextLabel")
	q.BackgroundTransparency = 1
	q.AnchorPoint = Vector2.new(0.5, 0.5)
	q.Position = UDim2.fromOffset(half, half)
	q.Size = UDim2.fromOffset(SIZE, SIZE)
	q.Text = "?"
	q.Font = Enum.Font.FredokaOne
	q.TextSize = 20
	q.ZIndex = 5
	q.Parent = root
	return {
		root = root,
		disc = disc,
		ring = ring,
		tip = tip,
		tipStroke = tipStroke,
		car = car,
		q = q,
	}
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
		local rad = math.rad(spot.angle) -- (0 = pointing right, turning clockwise on the screen)
		local half = SIZE / 2
		c.tip.Position =
			UDim2.fromOffset(half + math.cos(rad) * (half + 1), half + math.sin(rad) * (half + 1))
		c.tip.Rotation = spot.angle + 45
		local color = if t.enemy then RED else GOLD
		local alpha = 1 - EdgeArrow.strength(t.dist)
		c.tip.BackgroundColor3 = color
		c.tip.BackgroundTransparency = alpha
		c.tipStroke.Transparency = alpha + 0.1
		c.ring.Color = color
		c.ring.Transparency = alpha
		c.disc.BackgroundTransparency = 0.25 + alpha * 0.75
		for _, b in c.car do
			b.Visible = t.enemy
			b.BackgroundColor3 = color
			b.BackgroundTransparency = alpha
		end
		c.q.Visible = not t.enemy
		c.q.TextColor3 = color
		c.q.TextTransparency = alpha
	end
	hideFrom(shown + 1)
end)
