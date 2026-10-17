--!strict
-- Client-only hit effects: sparks and floating damage numbers. The server only says where and how hard.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local function anchorAt(pos: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	return p
end

-- A burst of sparks. Harder hit = more sparks.
function Effects.sparks(pos: Vector3, strength: number)
	local p = anchorAt(pos)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 120, 30))
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Speed = NumberRange.new(25, 55)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor(12 + 40 * strength))
	Debris:AddItem(p, 1.5)
end

-- Floating "-23" that rises and fades. Red = you took it, yellow = bot took it.
function Effects.damageNumber(pos: Vector3, damage: number, youHit: boolean)
	local p = anchorAt(pos + Vector3.new(0, 4, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = p
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = `-{math.floor(damage + 0.5)}`
	l.TextColor3 = if youHit then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 220, 60)
	l.TextStrokeTransparency = 0.2
	l.Parent = gui
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Position = p.Position + Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 1)
end

return Effects
