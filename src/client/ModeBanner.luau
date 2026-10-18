--!strict
-- One line at the top of the screen for the fight mode ("KING OF THE HILL: ...", live scores).
-- The server sends the text (UiUpdate "modeInfo"); this only shows and hides it.

local Players = game:GetService("Players")

local ModeBanner = {}

export type Banner = {
	show: (text: string) -> (),
	hide: () -> (),
}

function ModeBanner.new(): Banner
	local gui: ScreenGui? = nil
	local label: TextLabel? = nil

	local function ensure(): TextLabel
		local g, l = gui, label
		if g == nil or l == nil or g.Parent == nil then
			g = Instance.new("ScreenGui")
			g.Name = "CarVsCarModeBanner"
			g.ResetOnSpawn = false
			g.DisplayOrder = 8
			g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
			l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0)
			l.Position = UDim2.fromScale(0.5, 0.01) -- top edge only: nothing over the screen middle
			l.Size = UDim2.fromScale(0.7, 0.06)
			l.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
			l.BackgroundTransparency = 0.25
			l.TextColor3 = Color3.new(1, 1, 1)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Parent = g
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.3, 0)
			corner.Parent = l
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 26
			limit.Parent = l
			gui, label = g, l
		end
		return l :: TextLabel
	end

	return {
		show = function(text: string)
			local l = ensure()
			l.Text = text
			l.Visible = true
		end,
		hide = function()
			if label then
				label.Visible = false
			end
		end,
	}
end

return ModeBanner
