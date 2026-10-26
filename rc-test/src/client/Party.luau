--!strict
-- Kart Party moments (KartStyle): confetti down the screen, a burst of bits out of one spot, and
-- slow spinning light rays behind a big win. Each makes its own bits and cleans them up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local KartStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartStyle"))

local Party = {}

local function bit(parent: Instance, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Kart_Bit"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = KartStyle.PARTY[math.random(1, #KartStyle.PARTY)]
	f.ZIndex = 50
	f.Active = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 2)
	c.Parent = f
	f.Parent = parent
	return f
end

-- paper bits fall from the top of `parent` (a ScreenGui or a full-screen frame), tumbling
function Party.confetti(parent: Instance, count: number?)
	for _ = 1, count or 46 do
		task.delay(math.random() * 0.7, function()
			local f = bit(parent, math.random(7, 11), math.random(11, 16))
			local x = math.random()
			f.Position = UDim2.fromScale(x, -0.05)
			f.Rotation = math.random(0, 360)
			local t = 1.8 + math.random() * 1.6
			local drift = (math.random() - 0.5) * 0.18
			TweenService
				:Create(f, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Position = UDim2.fromScale(x + drift, 1.08),
					Rotation = f.Rotation + math.random(-540, 540),
				})
				:Play()
			task.delay(t, function()
				f:Destroy()
			end)
		end)
	end
end

-- bits fly out from `at` (a spot in `parent`) and fade: a BUY, a new car, a prize
function Party.burst(parent: Instance, at: UDim2, count: number?)
	local n = count or 16
	for i = 1, n do
		local f = bit(parent, 10, 10)
		f.Position = at
		local a = (i / n) * math.pi * 2 + math.random() * 0.3
		local reach = 70 + math.random() * 50
		local info = TweenInfo.new(
			0.55 + math.random() * 0.2,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		TweenService:Create(f, info, {
			Position = at + UDim2.fromOffset(math.cos(a) * reach, math.sin(a) * reach),
			Rotation = math.random(-200, 200),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(4, 4),
		}):Play()
		task.delay(info.Time, function()
			f:Destroy()
		end)
	end
end

-- soft light rays spinning slowly behind `under` (put in its parent, just below it), until
-- the returned stop() is called
function Party.rays(under: GuiObject, color: Color3?): () -> ()
	local holder = Instance.new("Frame")
	holder.Name = "Kart_Rays"
	holder.Active = false
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = under.AnchorPoint
	holder.Position = under.Position
	holder.Size = under.Size
	holder.ZIndex = math.max(under.ZIndex - 1, 0)
	holder.Parent = under.Parent
	local bars: { Frame } = {}
	for i = 0, 7 do
		local b = Instance.new("Frame")
		b.Active = false
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.new(1.4, 0, 0.16, 0)
		b.SizeConstraint = Enum.SizeConstraint.RelativeXX
		b.BackgroundColor3 = color or KartStyle.WHITE
		b.BackgroundTransparency = 0
		b.Rotation = i * 22.5
		b.ZIndex = holder.ZIndex
		-- bright in the middle, gone at both ends; thin at the middle
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = b
		b.Parent = holder
		table.insert(bars, b)
	end
	local turn = 0
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		turn += dt * 20 -- degrees a second
		holder.Position = under.Position
		holder.Size = under.Size
		holder.Visible = under.Visible
		for i, b in bars do
			b.Rotation = (i - 1) * 22.5 + turn
		end
	end)
	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		spin:Disconnect()
		holder:Destroy()
	end
end

return Party
