--!strict
-- "HIT!" style flash for a car-to-car hit. Human-driven matches skip the server hit-stop, so
-- this screen flash, the big number and an extra shake carry the "bang". No sound here.
-- Numbers: GameConfig.Feel (flashFrom, strongFrom, extraShake). Rule: shared/HitFeel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HitFeel = require(ReplicatedStorage.Shared.HitFeel)

local HitFlash = {}

local gui: ScreenGui? = nil

local function getGui(): ScreenGui
	local g = gui
	if g == nil or g.Parent == nil then
		g = Instance.new("ScreenGui")
		g.Name = "CarVsCarHitFlash"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 9
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = g
	end
	return g :: ScreenGui
end

-- u = the "hit" UiUpdate (strength, damage, youHit). director = CameraDirector (for extra shake).
function HitFlash.play(u: any, director: any)
	local feel = GameConfig.Feel
	local strength = u.strength or 0
	local tier = HitFeel.tier(strength, feel.flashFrom, feel.strongFrom)
	if tier == 0 then
		return
	end
	local youHit = u.youHit == true
	local strong = tier == 2
	local power = HitFeel.emphasis(strength, feel.flashFrom)
	-- Red when you are the one hurt, warm yellow when you land it.
	local color = if youHit then Color3.fromRGB(255, 60, 50) else Color3.fromRGB(255, 220, 70)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.88 - 0.2 * power
	flash.BorderSizePixel = 0
	flash.Parent = getGui()
	TweenService:Create(flash, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function()
		flash:Destroy()
	end)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.1, 0.04)
	label.Rotation = if youHit then -6 else 6
	label.Text = if strong then "HIT! -" .. tostring(math.floor((u.damage or 0) + 0.5)) else "HIT!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Parent = getGui()
	local big = if strong then UDim2.fromScale(0.34, 0.14) else UDim2.fromScale(0.2, 0.08)
	TweenService:Create(
		label,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = big }
	):Play()
	task.delay(0.35, function()
		TweenService
			:Create(
				label,
				TweenInfo.new(0.25),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			:Play()
	end)
	task.delay(0.62, function()
		label:Destroy()
	end)

	if strong and director and director.shake then
		director.shake(strength * feel.extraShake)
	end
end

return HitFlash
