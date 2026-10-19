--!strict
-- Fight screen juice: white KO flash and the big KO text. Cheap tweens, all cleaned up.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FightFx = {}

local gui: ScreenGui? = nil

local function getGui(): ScreenGui
	local g = gui
	if g == nil or g.Parent == nil then
		g = Instance.new("ScreenGui")
		g.Name = "CarVsCarFightFx"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 10
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = g
	end
	return g :: ScreenGui
end

local function bigText(text: string, color: Color3, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = getGui()
	return l
end

-- Quick white flash (0.15s) plus big text that pops in and fades out (~1.2s).
function FightFx.ko(text: string)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.1
	flash.BorderSizePixel = 0
	flash.Parent = getGui()
	TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function()
		flash:Destroy()
	end)

	local l = bigText(
		text,
		Color3.fromRGB(255, 70, 50),
		UDim2.fromScale(0.05, 0.02),
		UDim2.fromScale(0.5, 0.4)
	)
	TweenService:Create(
		l,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.7, 0.25) }
	):Play()
	task.delay(0.9, function()
		TweenService
			:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end)
	task.delay(1.2, function()
		l:Destroy()
	end)
end

return FightFx
