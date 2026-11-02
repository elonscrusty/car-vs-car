--!strict
-- The race start on screen: a giant 3, 2, 1 (red) and GO! (green) in the middle that pops in
-- and fades, so nobody can miss the start. Looks only: the start itself is RaceStart.
-- (carter's pick 13, 10-26: bigger and louder: a huge number that slams in with a little tilt,
-- a ring that bursts out behind it, and a flash of the whole screen on GO!)

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
	-- (up off the car's YOU tag, carter's phone 10-28)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoCondensed
	label.TextScaled = true
	label.TextTransparency = 1
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 9
	stroke.Color = Color3.fromRGB(25, 25, 30)
	stroke.Transparency = 1
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	-- a ring that bursts out behind the number
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = label.Position
	ring.Size = UDim2.fromScale(0.3, 0.3)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 0
	ring.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local ringLine = Instance.new("UIStroke")
	ringLine.Thickness = 16
	ringLine.Transparency = 1
	ringLine.Parent = ring
	-- GO!: the whole screen flashes green for a blink
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = GREEN
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = -1
	flash.Parent = gui
	local id = 0

	local self = {} :: BigCount
	function self.show(_step: number, text: string, go: boolean)
		id += 1
		local mine = id
		label.Text = text
		label.TextColor3 = if go then GREEN else RED
		label.TextTransparency = 0
		stroke.Transparency = 0
		scale.Scale = 2.2 -- slams in from big
		label.Rotation = if go then 0 else (if id % 2 == 0 then -8 else 8)
		TweenService:Create(
			scale,
			TweenInfo.new(0.28, Enum.EasingStyle.Back),
			{ Scale = if go then 1.25 else 1 }
		):Play()
		TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = 0 })
			:Play()
		if go then
			-- the ring bursts out on GO! only (a faint red ring on 3, 2, 1 looked like a test
			-- mark, phone 10-28)
			ring.Size = UDim2.fromScale(0.2, 0.2)
			ringLine.Color = GREEN
			ringLine.Transparency = 0
			local burst = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(ring, burst, { Size = UDim2.fromScale(0.75, 0.75) }):Play()
			TweenService:Create(ringLine, burst, { Transparency = 1 }):Play()
			flash.BackgroundTransparency = 0.55
			TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		end
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
