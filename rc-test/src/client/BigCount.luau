--!strict
-- The race start on screen: a giant 3, 2, 1 (red) and GO! (green) in the middle that pops in
-- and fades, so nobody can miss the start. Looks only: the start itself is RaceStart.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

export type BigCount = { show: (step: number, text: string, go: boolean) -> () }

local BigCount = {}

local RED = Color3.fromRGB(255, 70, 60)
local GREEN = Color3.fromRGB(80, 230, 100)

function BigCount.new(): BigCount
	local gui = Instance.new("ScreenGui")
	gui.Name = "BigCount"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.5, 0.3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextTransparency = 1
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(25, 25, 30)
	stroke.Transparency = 1
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	local id = 0

	local self = {} :: BigCount
	function self.show(_step: number, text: string, go: boolean)
		id += 1
		local mine = id
		label.Text = text
		label.TextColor3 = if go then GREEN else RED
		label.TextTransparency = 0
		stroke.Transparency = 0
		scale.Scale = 0.4
		TweenService
			:Create(
				scale,
				TweenInfo.new(0.3, Enum.EasingStyle.Back),
				{ Scale = if go then 1.2 else 1 }
			)
			:Play()
		task.delay(if go then 0.9 else 0.55, function()
			if mine ~= id then
				return
			end
			local fade = TweenInfo.new(0.25)
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end)
	end
	return self
end

return BigCount
