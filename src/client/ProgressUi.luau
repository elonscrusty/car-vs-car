--!strict
-- Progress panel: rank badge (Bronze/Silver/Gold), win streak, best car level, plus a
-- "LEVEL UP!" toast. Sits top-left, right of the coins HUD (the MenuBar column is on the left edge, middle).
-- Display only: the server decides everything and sends carLevels/rank/streak with the profile.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CarConfig = require(game:GetService("ReplicatedStorage").Shared.CarConfig)

export type ProgressUi = {
	-- Call with the "profile" LobbyUpdate fields.
	update: (carLevels: { [string]: number }?, rank: string?, streak: number?) -> (),
	setVisible: (visible: boolean) -> (),
}

local ProgressUi = {}

local RANK_COLOR: { [string]: Color3 } = {
	Bronze = Color3.fromRGB(205, 127, 50),
	Silver = Color3.fromRGB(205, 215, 230),
	Gold = Color3.fromRGB(255, 210, 70),
}
local PANEL = Color3.fromRGB(18, 22, 48)
local CYAN = Color3.fromRGB(60, 240, 255)
local GREEN = Color3.fromRGB(70, 255, 140)

local function makeLabel(parent: Instance, pos: UDim2, size: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

function ProgressUi.new(): ProgressUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "ProgressUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.2
	panel.Position = UDim2.fromOffset(426, 8) -- right of the coin box
	panel.Size = UDim2.fromOffset(190, 56)
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = RANK_COLOR.Bronze
	stroke.Parent = panel

	local rankLabel =
		makeLabel(panel, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.4), RANK_COLOR.Bronze)
	local infoLabel =
		makeLabel(panel, UDim2.fromScale(0.05, 0.52), UDim2.fromScale(0.9, 0.38), CYAN)

	local toast = makeLabel(gui, UDim2.fromScale(0.5, 0.22), UDim2.fromOffset(320, 64), GREEN)
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextStrokeTransparency = 0
	toast.Visible = false
	toast.ZIndex = 20

	local known: { [string]: number }? = nil
	local toastToken = 0

	local function showLevelUp(carId: string, level: number)
		toastToken += 1
		local token = toastToken
		local stats = CarConfig.get(carId)
		toast.Text = `LEVEL UP! {if stats then stats.name else carId} LV {level}`
		toast.Visible = true
		toast.TextTransparency = 0
		TweenService:Create(
			toast,
			TweenInfo.new(0.3, Enum.EasingStyle.Back),
			{ Position = UDim2.fromScale(0.5, 0.25) }
		):Play()
		task.delay(3.5, function()
			if token == toastToken then
				toast.Visible = false
				toast.Position = UDim2.fromScale(0.5, 0.22)
			end
		end)
	end

	return {
		update = function(carLevels, rank, streak)
			local levels = carLevels or {}
			-- rank nil = rank badges are off (FeatureFlags.rankBadges): no rank text.
			local name = rank or "Bronze"
			local color = RANK_COLOR[name] or RANK_COLOR.Bronze
			rankLabel.Text = if rank then string.upper(name) else ""
			rankLabel.TextColor3 = color
			stroke.Color = color
			local best = 1
			for _, lv in levels do
				best = math.max(best, lv)
			end
			infoLabel.Text = `STREAK {streak or 0}  |  CAR LV {best}`
			if known ~= nil then
				for id, lv in levels do
					if lv > (known[id] or 1) then
						showLevelUp(id, lv)
						break
					end
				end
			end
			known = table.clone(levels)
		end,
		setVisible = function(visible)
			gui.Enabled = visible
		end,
	}
end

return ProgressUi
