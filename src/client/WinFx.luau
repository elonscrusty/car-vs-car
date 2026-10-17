--!strict
-- End-of-match effects: banner pop-in and a burst of flying coins. Built from Frames, no assets.

local TweenService = game:GetService("TweenService")

local WinText = require(game:GetService("ReplicatedStorage").Shared.WinText)

local WinFx = {}

export type Handle = { stop: () -> () }

local GOLD = Color3.fromRGB(255, 205, 40)

local function makeCoin(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Size = UDim2.fromScale(size, size)
	coin.BackgroundColor3 = GOLD
	coin.BorderSizePixel = 0
	coin.ZIndex = 5
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectType = Enum.AspectType.ScaleWithParentSize
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = coin
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = coin
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(190, 130, 10)
	stroke.Thickness = 3
	stroke.Parent = coin
	local sign = Instance.new("TextLabel")
	sign.BackgroundTransparency = 1
	sign.Size = UDim2.fromScale(1, 1)
	sign.Text = "$"
	sign.TextScaled = true
	sign.Font = Enum.Font.GothamBlack
	sign.TextColor3 = Color3.fromRGB(150, 95, 0)
	sign.ZIndex = 6
	sign.Parent = coin
	coin.Parent = parent
	return coin
end

-- Pop the banner in with a bounce (win) or a calm fade-in (lose). Returns tweens to cancel.
function WinFx.popIn(banner: GuiObject, won: boolean, tweens: { Tween })
	local scale = banner:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = banner
	end
	local s = scale :: UIScale
	s.Scale = if won then 0.2 else 0.8
	local t = TweenService:Create(
		s,
		if won
			then TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			else TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	table.insert(tweens, t)
	t:Play()
end

-- Launch the coin burst under `parent`. Everything is destroyed after ~2.5 s or on stop().
function WinFx.coinBurst(parent: GuiObject, seed: number): Handle
	local tweens: { Tween } = {}
	local coins: { Frame } = {}
	local stopped = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 5
	holder.Parent = parent

	local function play(inst: Instance, info: TweenInfo, goal: { [string]: any })
		local t = TweenService:Create(inst, info, goal)
		table.insert(tweens, t)
		t:Play()
		return t
	end

	for _, p in WinText.coinParticles(seed, WinText.DefaultCoins) do
		task.delay(p.delay, function()
			if stopped then
				return
			end
			local coin = makeCoin(holder, p.size)
			table.insert(coins, coin)
			coin.Position = UDim2.fromScale(p.startX, 1.1)
			local up = play(
				coin,
				TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(p.peakX, p.peakY) }
			)
			up.Completed:Once(function()
				if stopped then
					return
				end
				play(
					coin,
					TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.fromScale(p.endX, 1.15), Rotation = 180 }
				)
				local sign = coin:FindFirstChildOfClass("TextLabel")
				play(coin, TweenInfo.new(1.1), { BackgroundTransparency = 1 })
				if sign then
					play(sign, TweenInfo.new(1.1), { TextTransparency = 1 })
				end
			end)
		end)
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		for _, t in tweens do
			t:Cancel()
			t:Destroy()
		end
		table.clear(tweens)
		table.clear(coins)
		holder:Destroy()
	end
	task.delay(2.8, stop)
	return { stop = stop }
end

return WinFx
