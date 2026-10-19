--!strict
-- Quests + daily gift modal. Opened from two MenuBar buttons; fed by the "profile" LobbyUpdate.
-- Clients only ask: LobbyAction "claimQuest" (index) and "claimDaily". The server decides.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local MenuBar = require(script.Parent.MenuBar)
local UiStyle = require(script.Parent.UiStyle)

local NAVY = Color3.fromRGB(10, 12, 28)
local PANEL = Color3.fromRGB(18, 22, 48)
local ROW = Color3.fromRGB(30, 34, 62)
local CYAN = Color3.fromRGB(60, 240, 255)
local PINK = Color3.fromRGB(255, 70, 190)
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(70, 220, 120)
local GREY = Color3.fromRGB(90, 96, 120)
local WHITE = Color3.new(1, 1, 1)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BTN = 56 -- tap height, over the 52 px minimum

export type QuestUi = {
	handleUpdate: (u: Types.LobbyUpdate) -> (),
}

local QuestUi = {}

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
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function button(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3
): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Parent = parent
	corner(b, 12)
	UiStyle.polish(b)
	return b
end

function QuestUi.new(menu: MenuBar.MenuBar, onAction: (action: string, arg: any?) -> ()): QuestUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestUi"
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
	maxSize.MaxSize = Vector2.new(560, 560)
	maxSize.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local title = label(panel, "QUESTS", UDim2.new(1, -84, 0, 48), UDim2.fromOffset(14, 10))
	title.TextColor3 = GOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(panel, "X", UDim2.fromOffset(BTN, BTN), UDim2.new(1, -8, 0, 6), PINK)
	close.AnchorPoint = Vector2.new(1, 0)

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -24, 1, -80)
	body.Position = UDim2.fromOffset(12, 68)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	-- Daily gift card
	local gift = frame(body, UDim2.new(1, -8, 0, 96), UDim2.new(), ROW)
	gift.LayoutOrder = 0
	corner(gift, 12)
	local giftText = label(gift, "DAILY GIFT", UDim2.new(1, -180, 0, 30), UDim2.fromOffset(12, 8))
	giftText.TextXAlignment = Enum.TextXAlignment.Left
	giftText.TextColor3 = CYAN
	local giftSub = label(gift, "", UDim2.new(1, -180, 0, 24), UDim2.fromOffset(12, 50))
	giftSub.TextXAlignment = Enum.TextXAlignment.Left
	giftSub.Font = Enum.Font.FredokaOne
	giftSub.TextColor3 = Color3.fromRGB(190, 200, 220)
	local giftBtn =
		button(gift, "CLAIM GIFT", UDim2.fromOffset(160, BTN), UDim2.new(1, -8, 0.5, 0), GREEN)
	giftBtn.AnchorPoint = Vector2.new(1, 0.5)

	-- Quest rows (three fixed slots, filled from the profile)
	type Row = { root: Frame, name: TextLabel, fill: Frame, count: TextLabel, claim: TextButton }
	local rows: { Row } = {}
	local function makeRow(index: number): Row
		local root = frame(body, UDim2.new(1, -8, 0, 96), UDim2.new(), ROW)
		root.LayoutOrder = index
		corner(root, 12)
		local name = label(root, "", UDim2.new(1, -180, 0, 30), UDim2.fromOffset(12, 8))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local bar = frame(root, UDim2.new(1, -190, 0, 22), UDim2.fromOffset(12, 56), GREY)
		corner(bar, 11)
		local fill = frame(bar, UDim2.fromScale(0, 1), UDim2.new(), GOLD)
		corner(fill, 11)
		local count = label(bar, "", UDim2.fromScale(1, 1), UDim2.new())
		count.ZIndex = 3
		count.TextColor3 = WHITE
		local claim =
			button(root, "CLAIM", UDim2.fromOffset(160, BTN), UDim2.new(1, -8, 0.5, 0), GREEN)
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Activated:Connect(function()
			onAction("claimQuest", index)
		end)
		return { root = root, name = name, fill = fill, count = count, claim = claim }
	end
	for i = 1, 3 do
		table.insert(rows, makeRow(i))
	end

	giftBtn.Activated:Connect(function()
		onAction("claimDaily", nil)
	end)

	local function open()
		backdrop.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
	close.Activated:Connect(function()
		backdrop.Visible = false
	end)
	menu.add("quests", "QUESTS", 10, open)
	menu.add("gift", "GIFT", 11, open)

	local self = {} :: QuestUi
	self.handleUpdate = function(u: Types.LobbyUpdate)
		if u.kind ~= "profile" then
			return
		end
		local quests = u.quests or {}
		local anyDone = false
		for i, row in rows do
			local q = quests[i]
			row.root.Visible = q ~= nil
			if q then
				row.name.Text = `{q.title}  (+{q.reward})`
				row.fill.Size =
					UDim2.fromScale(math.clamp(q.progress / math.max(q.target, 1), 0, 1), 1)
				row.count.Text = `{q.progress} / {q.target}`
				row.claim.Visible = q.done
				anyDone = anyDone or q.done
			end
		end
		local daily = u.daily
		local ready = daily ~= nil and daily.ready
		giftBtn.Visible = ready
		if daily == nil then
			giftSub.Text = ""
		elseif ready then
			giftSub.Text = "Free claw try waiting!"
		else
			giftSub.Text = `Come back tomorrow. Free tries: {daily.freePulls}`
		end
		menu.setBadge("quests", anyDone)
		menu.setBadge("gift", ready)
	end
	return self
end

return QuestUi
