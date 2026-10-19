--!strict
-- Big centered text for a moment ("3", "2", "1", "GO!", a goal score). The server sends it
-- as UiUpdate kind "banner" with `text` and `seconds` (how long it stays). Car soccer uses it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CenterBanner = {}

export type Banner = {
	show: (text: string, seconds: number) -> (),
	hide: () -> (),
}

function CenterBanner.new(): Banner
	local gui: ScreenGui? = nil
	local label: TextLabel? = nil
	local token = 0

	local function ensure(): TextLabel
		local g, l = gui, label
		if g == nil or l == nil or g.Parent == nil then
			g = Instance.new("ScreenGui")
			g.Name = "CarVsCarCenterBanner"
			g.ResetOnSpawn = false
			g.IgnoreGuiInset = true
			g.DisplayOrder = 9
			g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
			l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, 0.38)
			l.Size = UDim2.fromScale(0.6, 0.2)
			l.BackgroundTransparency = 1
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0
			l.TextStrokeColor3 = Color3.fromRGB(14, 18, 30)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Visible = false
			l.Parent = g
			gui, label = g, l
		end
		return l :: TextLabel
	end

	local function hide()
		token += 1
		if label then
			label.Visible = false
		end
	end

	return {
		show = function(text: string, seconds: number)
			local l = ensure()
			token += 1
			local mine = token
			l.Text = text
			l.Visible = true
			-- A quick pop: starts big and settles.
			l.Size = UDim2.fromScale(0.9, 0.3)
			TweenService:Create(l, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
				Size = UDim2.fromScale(0.6, 0.2),
			}):Play()
			task.delay(math.max(0.2, seconds), function()
				if token == mine then
					l.Visible = false
				end
			end)
		end,
		hide = hide,
	}
end

return CenterBanner
