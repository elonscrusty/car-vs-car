--!strict
-- Shared look for buttons: a soft top-to-bottom shine, a dark outline and a little squash when
-- pressed. One place, so every screen feels the same.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local UiSize = require(ReplicatedStorage.Shared.UiSize)
local SoundFx = require(script.Parent.SoundFx)

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
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0.1
	stroke.Parent = b

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205))
	shine.Rotation = 90
	shine.Parent = b

	local scale = Instance.new("UIScale")
	scale.Name = "UiStyleScale"
	scale.Parent = b
	if b:GetAttribute("NoClickSound") ~= true then
		b.Activated:Connect(function()
			SoundFx.play("click")
		end)
	end
	local function to(goal: number, info: TweenInfo)
		TweenService:Create(scale, info, { Scale = goal }):Play()
	end
	b.MouseButton1Down:Connect(function()
		to(UiSize.PRESS_SCALE, PRESS)
	end)
	b.MouseButton1Up:Connect(function()
		to(1, RELEASE)
	end)
	b.MouseLeave:Connect(function()
		to(1, RELEASE)
	end)
end

-- Puts a GuiObject where a pure UiLayout spec says: anchor, scale position + pixel offset, scale
-- size, and a UISizeConstraint with the spec's min/max pixels (reused if there is one already).
function UiStyle.place(g: GuiObject, s: UiLayout.Spec)
	g.AnchorPoint = Vector2.new(s.ax, s.ay)
	g.Position = UDim2.new(s.px, s.ox, s.py, s.oy)
	g.Size = UDim2.new(s.sw, if s.sw == 0 then s.minW else 0, s.sh, if s.sh == 0 then s.minH else 0)
	local limit = g:FindFirstChildOfClass("UISizeConstraint")
	if limit == nil then
		limit = Instance.new("UISizeConstraint")
		limit.Parent = g
	end
	local c = limit :: UISizeConstraint
	c.MinSize = Vector2.new(s.minW, s.minH)
	c.MaxSize = Vector2.new(s.maxW, s.maxH)
end

-- Keeps TextScaled text between `min` and `max` px (min 14 is the phone readability floor).
function UiStyle.textLimit(g: GuiObject, min: number, max: number)
	local limit = g:FindFirstChildOfClass("UITextSizeConstraint")
	if limit == nil then
		limit = Instance.new("UITextSizeConstraint")
		limit.Parent = g
	end
	local c = limit :: UITextSizeConstraint
	c.MinTextSize = min
	c.MaxTextSize = max
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
