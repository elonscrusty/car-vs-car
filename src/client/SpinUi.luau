--!strict
-- Daily spin wheel modal (MenuBar button "SPIN"). Shows the odds BEFORE you spin.
-- Client only asks: LobbyAction "spin". The server rolls, pays, and replies with a "spinResult".

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spin = require(ReplicatedStorage.Shared.Spin)
local SpinConfig = require(ReplicatedStorage.Shared.SpinConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local MenuBar = require(script.Parent.MenuBar)

local NAVY = Color3.fromRGB(10, 12, 28)
local PANEL = Color3.fromRGB(18, 22, 48)
local ROW = Color3.fromRGB(30, 34, 62)
local PINK = Color3.fromRGB(255, 70, 190)
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(70, 220, 120)
local GREY = Color3.fromRGB(90, 96, 120)
local WHITE = Color3.new(1, 1, 1)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPIN_TIME = 3.5
local BTN = 56 -- tap height, over the 52 px minimum
local WHEEL = 220

export type SpinUi = {
	handleUpdate: (u: Types.LobbyUpdate) -> (),
}

local SpinUi = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Parent = parent
	return l
end

function SpinUi.new(menu: MenuBar.MenuBar, onAction: (action: string, arg: any?) -> ()): SpinUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local backdrop = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NAVY)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Visible = false
	backdrop.Active = true -- swallow taps
	local panel = frame(backdrop, UDim2.new(1, -24, 1, -24), UDim2.fromScale(0.5, 0.5), PANEL)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(panel, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 3
	stroke.Parent = panel
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(560, 700)
	maxSize.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local title = label(panel, "DAILY SPIN", UDim2.new(1, -84, 0, 48), UDim2.fromOffset(14, 10))
	title.TextColor3 = GOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(BTN, BTN)
	close.Position = UDim2.new(1, -8, 0, 6)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundColor3 = PINK
	close.BorderSizePixel = 0
	close.Text = "X"
	close.Font = Enum.Font.GothamBlack
	close.TextColor3 = WHITE
	close.TextScaled = true
	close.Parent = panel
	corner(close, 12)

	-- The wheel: a round disc whose labels sit around it, a gold pointer at the top.
	local wheel =
		frame(panel, UDim2.fromOffset(WHEEL, WHEEL), UDim2.new(0.5, 0, 0, 80 + WHEEL / 2), ROW)
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(wheel, WHEEL / 2)
	local wheelStroke = Instance.new("UIStroke")
	wheelStroke.Color = GOLD
	wheelStroke.Thickness = 4
	wheelStroke.Parent = wheel
	local n = #SpinConfig.Segments
	for i, seg in SpinConfig.Segments do
		local mid = math.rad((i - 0.5) / n * 360)
		local r = WHEEL / 2 - 36
		local l = label(
			wheel,
			seg.label,
			UDim2.fromOffset(70, 28),
			UDim2.new(0.5, math.sin(mid) * r, 0.5, -math.cos(mid) * r)
		)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Rotation = math.deg(mid)
		l.TextColor3 = if seg.freePulls > 0 then GREEN else WHITE
	end
	local pointer = label(panel, "▼", UDim2.fromOffset(40, 40), UDim2.new(0.5, 0, 0, 80 - 18))
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.TextColor3 = GOLD
	pointer.ZIndex = 5

	local result = label(panel, "", UDim2.new(1, -40, 0, 36), UDim2.new(0, 20, 0, 80 + WHEEL + 14))
	result.TextColor3 = GOLD

	local spinBtn = Instance.new("TextButton")
	spinBtn.Size = UDim2.new(1, -40, 0, BTN)
	spinBtn.Position = UDim2.new(0, 20, 0, 80 + WHEEL + 58)
	spinBtn.BackgroundColor3 = GREEN
	spinBtn.BorderSizePixel = 0
	spinBtn.Text = "SPIN!"
	spinBtn.Font = Enum.Font.GothamBlack
	spinBtn.TextColor3 = WHITE
	spinBtn.TextScaled = true
	spinBtn.Parent = panel
	corner(spinBtn, 12)

	-- Odds, always visible (same weights the server rolls with).
	local odds = Instance.new("TextLabel")
	odds.BackgroundTransparency = 1
	odds.Size = UDim2.new(1, -40, 0, 150)
	odds.Position = UDim2.new(0, 20, 0, 80 + WHEEL + 58 + BTN + 10)
	odds.Font = Enum.Font.GothamBold
	odds.TextColor3 = Color3.fromRGB(190, 200, 220)
	odds.TextSize = 14
	odds.TextWrapped = true
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextYAlignment = Enum.TextYAlignment.Top
	local lines = { "ODDS (rewards are placeholders):" }
	for _, row in Spin.oddsTable() do
		table.insert(lines, `{row.percent}%  {row.label}`)
	end
	odds.Text = table.concat(lines, "\n")
	odds.Parent = panel

	local ready = false
	local spinning = false
	local function refresh()
		spinBtn.Active = ready and not spinning
		spinBtn.BackgroundColor3 = if ready and not spinning then GREEN else GREY
		spinBtn.Text = if ready then "SPIN!" else "COME BACK TOMORROW"
		menu.setBadge("spin", ready and not spinning)
	end

	spinBtn.Activated:Connect(function()
		if ready and not spinning then
			result.Text = ""
			onAction("spin", nil)
		end
	end)
	menu.add("spin", "SPIN", 12, function()
		backdrop.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end)
	close.Activated:Connect(function()
		backdrop.Visible = false
	end)

	local self = {} :: SpinUi
	self.handleUpdate = function(u: Types.LobbyUpdate)
		if u.kind == "profile" then
			if not spinning then
				ready = u.spinReady == true
				refresh()
			end
		elseif u.kind == "spinResult" then
			-- Land the chosen slice under the pointer. The server already decided and paid.
			spinning = true
			refresh()
			local mid = (u.index - 0.5) / n * 360
			local target = wheel.Rotation + 360 * 4 + (360 - (wheel.Rotation % 360)) - mid
			local tween = TweenService:Create(
				wheel,
				TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Rotation = target }
			)
			tween.Completed:Connect(function()
				spinning = false
				ready = false
				result.Text = `YOU WON: {u.label}`
				refresh()
			end)
			tween:Play()
		end
	end
	return self
end

return SpinUi
