--!strict
-- Shared look for buttons: a soft top-to-bottom shine, a dark outline and a little squash when
-- pressed. One place, so every screen feels the same.

local TweenService = game:GetService("TweenService")

local UiStyle = {}

local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Adds the shine, outline and press squash to a button. Safe to call once per button.
function UiStyle.polish(b: GuiButton)
	if b:FindFirstChild("UiStyleScale") then
		return
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(10, 12, 24)
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0.2
	stroke.Parent = b

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 218))
	shine.Rotation = 90
	shine.Parent = b

	local scale = Instance.new("UIScale")
	scale.Name = "UiStyleScale"
	scale.Parent = b
	local function to(goal: number, info: TweenInfo)
		TweenService:Create(scale, info, { Scale = goal }):Play()
	end
	b.MouseButton1Down:Connect(function()
		to(0.92, PRESS)
	end)
	b.MouseButton1Up:Connect(function()
		to(1, RELEASE)
	end)
	b.MouseLeave:Connect(function()
		to(1, RELEASE)
	end)
end

-- Pops a label or frame in: grows from small with a little overshoot. `scale` is a UIScale on it.
function UiStyle.pop(scale: UIScale, from: number?)
	scale.Scale = from or 0.55
	TweenService:Create(
		scale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

return UiStyle
