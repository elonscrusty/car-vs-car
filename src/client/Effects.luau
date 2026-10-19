--!strict
-- Client-only hit effects: sparks and floating damage numbers. The server only says where and how hard.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Quality = require(script.Parent.Quality)

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
	e.Color = ColorSequence.new(Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 140, 20))
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.15, 0.4)
	e.Speed = NumberRange.new(25, 55)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor((15 + 60 * strength) * Quality.scale()))

	-- Dust puff and flying chips for any real hit.
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 7 + 6 * strength),
	})
	dust.Lifetime = NumberRange.new(0.5, 1.1)
	dust.Speed = NumberRange.new(6, 18)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Rate = 0
	dust.Parent = p
	dust:Emit(math.floor((6 + 14 * strength) * Quality.scale()))

	local chips = Instance.new("ParticleEmitter")
	chips.Color = ColorSequence.new(Color3.fromRGB(90, 90, 100))
	chips.Size = NumberSequence.new(0.5)
	chips.Lifetime = NumberRange.new(0.6, 1.2)
	chips.Speed = NumberRange.new(20, 50)
	chips.SpreadAngle = Vector2.new(180, 180)
	chips.Acceleration = Vector3.new(0, -90, 0)
	chips.Rate = 0
	chips.Parent = p
	chips:Emit(math.floor((4 + 14 * strength) * Quality.scale()))
	-- A big hit also lights the spot white for a moment (a flash in the world, not over the screen).
	if strength >= 0.5 then
		local flash = Instance.new("PointLight")
		flash.Color = Color3.new(1, 1, 1)
		flash.Range = 12 -- small and dim: the cars and the floor stay readable
		flash.Brightness = 2.5
		flash.Parent = p
		TweenService:Create(flash, TweenInfo.new(0.12), { Brightness = 0 }):Play()
	end
	Debris:AddItem(p, 2)
end

-- Floating "-23" that rises and fades. Red = you took it, yellow = bot took it.
function Effects.damageNumber(pos: Vector3, damage: number, youHit: boolean, tag: string?)
	local p = anchorAt(pos + Vector3.new(0, 4, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = p
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = if tag then `-{math.floor(damage + 0.5)}\n{tag}` else `-{math.floor(damage + 0.5)}`
	l.TextColor3 = if youHit then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 220, 60)
	l.TextStrokeTransparency = 0.2
	l.Parent = gui
	-- Pop in big, settle, then drift up and fade. Bigger hits get bigger numbers.
	local big = math.clamp(damage / 25, 0, 1)
	local full = UDim2.fromOffset(120 + 60 * big, 50 + 24 * big)
	gui.Size = UDim2.fromOffset(40, 16)
	TweenService:Create(
		gui,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = full }
	):Play()
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Position = p.Position + Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 1)
end

-- Boost speed lines (audit #92): thin white streaks that rush outward from the screen edges for
-- `seconds`. Fewer on a slow device, and fewer and fainter with calm effects on.
function Effects.speedLines(seconds: number)
	local feel = GameConfig.Feel
	local calm = SoundService:GetAttribute(feel.calmAttribute) == true
	local count = math.ceil(feel.boostLines * Quality.scale() * (if calm then 0.5 else 1))
	if count <= 0 then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "CarVsCarSpeedLines"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 8
	g.Parent = playerGui
	local rng = Random.new()
	local fade = if calm then 0.75 else 0.5
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local dx, dy = math.cos(angle), math.sin(angle)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = fade
		line.Size = UDim2.fromOffset(rng:NextInteger(70, 130), 3)
		line.Rotation = math.deg(angle)
		line.Position = UDim2.fromScale(0.5 + dx * 0.34, 0.5 + dy * 0.34)
		line.Parent = g
		TweenService
			:Create(line, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(0.5 + dx * 0.62, 0.5 + dy * 0.62),
				BackgroundTransparency = 1,
			})
			:Play()
	end
	Debris:AddItem(g, seconds + 0.1)
end

return Effects
