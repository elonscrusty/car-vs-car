--!strict
-- Lobby UI: coins HUD, gacha screen (odds + price shown before the buy button), cars list,
-- pick-1-of-3 choices with timer, pad countdown. Neon night look, big touch buttons.
-- The server decides everything; this only renders LobbyUpdate and sends LobbyAction.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Gacha = require(ReplicatedStorage.Shared.Gacha)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local LobbyText = require(ReplicatedStorage.Shared.LobbyText)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local LobbyUi = {}

export type Hooks = {
	onToLobby: (coinsEarned: number, won: boolean) -> (), -- hide match UI, camera back to Custom
}

export type Handle = {
	handleUpdate: (u: Types.LobbyUpdate) -> (),
	hideChoices: () -> (),
}

local NAVY = Color3.fromRGB(10, 14, 32)
local PANEL = Color3.fromRGB(18, 22, 48)
local CYAN = Color3.fromRGB(60, 240, 255)
local PINK = Color3.fromRGB(255, 70, 190)
local GREEN = Color3.fromRGB(70, 255, 140)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREY = Color3.fromRGB(70, 74, 100)
local WHITE = Color3.new(1, 1, 1)

local RARITY_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 200, 220),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(200, 90, 255),
}

local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MIN_TOUCH = 56
local CLICK_GAP = 0.4

local function carColor(id: string): Color3
	local stats = CarConfig.get(id)
	if stats == nil then
		return GREY
	end
	return Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
end

local function carName(id: string): string
	local stats = CarConfig.get(id)
	return if stats then stats.name else id
end

local function rarityOf(id: string): string
	return LobbyConfig.Rarity[id] or "Common"
end

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function textLimit(parent: Instance, minSize: number, maxSize: number)
	local t = Instance.new("UITextSizeConstraint")
	t.MinTextSize = minSize
	t.MaxTextSize = maxSize
	t.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	textLimit(l, 14, 56)
	return l
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

-- Big neon button, never shorter than MIN_TOUCH px.
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
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = WHITE
	b.AutoButtonColor = false
	b.Parent = parent
	corner(b, 0.2)
	stroke(b, WHITE, 2)
	textLimit(b, 16, 44)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(MIN_TOUCH, MIN_TOUCH)
	limit.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			TweenService:Create(scale, FAST, { Scale = 0.93 }):Play()
		end
	end)
	b.InputEnded:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	return b
end

local function setEnabled(b: TextButton, enabled: boolean, color: Color3)
	b.Active = enabled
	b.BackgroundColor3 = if enabled then color else GREY
	b.TextTransparency = if enabled then 0 else 0.45
end

-- Calls fn at most once per CLICK_GAP seconds.
local function debounced(fn: () -> ()): () -> ()
	local last = 0
	return function()
		local now = os.clock()
		if now - last < CLICK_GAP then
			return
		end
		last = now
		fn()
	end
end

function LobbyUi.new(hooks: Hooks): Handle
	local remotes = Remotes.get()

	-- State mirrored from the server (display only).
	local coins, wins = 0, 0
	local owned: { [string]: boolean } = {}
	local freePull = false
	local waitingForPull = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- respects top bar / safe areas on phones
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function send(action: string, arg: any?)
		remotes.LobbyAction:FireServer(action, arg)
	end

	-- HUD: coins + wins, top-left, small
	local hud = frame(gui, UDim2.fromScale(0.2, 0.1), UDim2.fromOffset(12, 8), PANEL)
	hud.BackgroundTransparency = 0.2
	corner(hud, 0.25)
	stroke(hud, GOLD, 2)
	local hudSize = Instance.new("UISizeConstraint")
	hudSize.MinSize = Vector2.new(130, 52)
	hudSize.MaxSize = Vector2.new(240, 80)
	hudSize.Parent = hud
	local coinsLabel = label(hud, "0", UDim2.fromScale(0.9, 0.55), UDim2.fromScale(0.05, 0.04))
	coinsLabel.TextColor3 = GOLD
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	local winsLabel = label(hud, "0 WINS", UDim2.fromScale(0.9, 0.34), UDim2.fromScale(0.05, 0.62))
	winsLabel.TextColor3 = CYAN
	winsLabel.TextXAlignment = Enum.TextXAlignment.Left

	local function refreshHud()
		coinsLabel.Text = LobbyText.coinsText(coins)
		winsLabel.Text = LobbyText.winsText(wins)
	end

	-- Modal base: dim backdrop + neon panel with a big close button.
	local function modal(title: string, accent: Color3): (Frame, Frame, () -> ())
		local backdrop = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NAVY)
		backdrop.BackgroundTransparency = 0.35
		backdrop.Visible = false
		backdrop.Active = true -- swallow taps
		backdrop.ZIndex = 10
		local panel = frame(backdrop, UDim2.fromScale(0.9, 0.86), UDim2.fromScale(0.5, 0.5), PANEL)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.ZIndex = 11
		corner(panel, 0.04)
		stroke(panel, accent, 3)
		local maxSize = Instance.new("UISizeConstraint")
		maxSize.MaxSize = Vector2.new(760, 560)
		maxSize.Parent = panel
		local t = label(panel, title, UDim2.fromScale(0.6, 0.11), UDim2.fromScale(0.04, 0.02))
		t.TextColor3 = accent
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.ZIndex = 12
		local close =
			button(panel, "X", UDim2.fromScale(0.12, 0.11), UDim2.fromScale(0.84, 0.02), PINK)
		close.ZIndex = 12
		local scale = Instance.new("UIScale")
		scale.Parent = panel
		local function open()
			backdrop.Visible = true
			scale.Scale = 0.85
			TweenService:Create(scale, POP, { Scale = 1 }):Play()
		end
		close.Activated:Connect(function()
			backdrop.Visible = false
		end)
		return backdrop, panel, open
	end

	-- GACHA screen
	local gachaBack, gachaPanel, gachaOpen = modal("GACHA", PINK)
	local oddsBox = frame(gachaPanel, UDim2.fromScale(0.92, 0.4), UDim2.fromScale(0.04, 0.16), NAVY)
	oddsBox.ZIndex = 12
	corner(oddsBox, 0.06)
	stroke(oddsBox, CYAN, 2)
	local oddsHeader =
		label(oddsBox, "ODDS", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.03))
	oddsHeader.TextColor3 = CYAN
	oddsHeader.TextXAlignment = Enum.TextXAlignment.Left
	oddsHeader.ZIndex = 13
	local oddsList = Instance.new("Frame")
	oddsList.BackgroundTransparency = 1
	oddsList.Size = UDim2.fromScale(0.9, 0.72)
	oddsList.Position = UDim2.fromScale(0.05, 0.25)
	oddsList.ZIndex = 13
	oddsList.Parent = oddsBox
	local oddsLayout = Instance.new("UIListLayout")
	oddsLayout.Padding = UDim.new(0.04, 0)
	oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	oddsLayout.Parent = oddsList
	for i, row in Gacha.oddsTable() do
		local names = {}
		for _, id in row.cars do
			table.insert(names, carName(id))
		end
		local l = label(
			oddsList,
			LobbyText.oddsLine(row.rarity, row.percent, names),
			UDim2.fromScale(1, 0.26),
			UDim2.fromScale(0, 0)
		)
		l.LayoutOrder = i
		l.TextColor3 = RARITY_COLOR[row.rarity] or WHITE
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 14
	end
	local priceLabel =
		label(gachaPanel, "", UDim2.fromScale(0.92, 0.09), UDim2.fromScale(0.04, 0.6))
	priceLabel.TextColor3 = GOLD
	priceLabel.ZIndex = 12
	local dupeNote = label(
		gachaPanel,
		`Duplicates give {LobbyConfig.Gacha.duplicateRefund} coins back`,
		UDim2.fromScale(0.92, 0.06),
		UDim2.fromScale(0.04, 0.69)
	)
	dupeNote.Font = Enum.Font.GothamBold
	dupeNote.TextColor3 = Color3.fromRGB(190, 200, 230)
	dupeNote.ZIndex = 12
	local buyButton =
		button(gachaPanel, "OPEN", UDim2.fromScale(0.7, 0.16), UDim2.fromScale(0.15, 0.78), GREEN)
	buyButton.ZIndex = 12
	local gachaMsg = label(gachaPanel, "", UDim2.fromScale(0.92, 0.05), UDim2.fromScale(0.04, 0.95))
	gachaMsg.Font = Enum.Font.GothamBold
	gachaMsg.TextColor3 = Color3.fromRGB(255, 120, 120)
	gachaMsg.ZIndex = 12

	-- Result popup (inside the gacha backdrop, above everything)
	local resultBack = frame(gachaBack, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NAVY)
	resultBack.BackgroundTransparency = 0.25
	resultBack.Active = true
	resultBack.Visible = false
	resultBack.ZIndex = 20
	local resultCard =
		frame(resultBack, UDim2.fromScale(0.7, 0.6), UDim2.fromScale(0.5, 0.5), PANEL)
	resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
	resultCard.ZIndex = 21
	corner(resultCard, 0.06)
	local resultStroke = Instance.new("UIStroke")
	resultStroke.Thickness = 4
	resultStroke.Parent = resultCard
	local resultSize = Instance.new("UISizeConstraint")
	resultSize.MaxSize = Vector2.new(520, 400)
	resultSize.Parent = resultCard
	local resultScale = Instance.new("UIScale")
	resultScale.Parent = resultCard
	local resultTitle =
		label(resultCard, "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.05))
	resultTitle.ZIndex = 22
	local resultSwatch =
		frame(resultCard, UDim2.fromScale(0.5, 0.22), UDim2.fromScale(0.25, 0.28), WHITE)
	resultSwatch.ZIndex = 22
	corner(resultSwatch, 0.2)
	local resultName =
		label(resultCard, "", UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.52))
	resultName.ZIndex = 22
	local resultSub = label(resultCard, "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.69))
	resultSub.ZIndex = 22
	local resultOk =
		button(resultCard, "NICE!", UDim2.fromScale(0.5, 0.16), UDim2.fromScale(0.25, 0.8), GREEN)
	resultOk.ZIndex = 22
	resultOk.Activated:Connect(function()
		resultBack.Visible = false
	end)

	local function refreshGacha()
		local profile = Inventory.default()
		profile.coins = coins
		profile.freePullUsed = not freePull
		local ok = Gacha.canBuy(profile)
		priceLabel.Text = LobbyText.priceText(LobbyConfig.Gacha.price, freePull)
		buyButton.Text = LobbyText.buyButtonText(coins, LobbyConfig.Gacha.price, freePull)
		local enabled = ok and not waitingForPull
		setEnabled(buyButton, enabled, GREEN)
	end

	buyButton.Activated:Connect(debounced(function()
		if not buyButton.Active then
			return
		end
		waitingForPull = true
		gachaMsg.Text = ""
		refreshGacha()
		send("buyGacha")
		task.delay(5, function() -- safety: never stay stuck if the reply is lost
			if waitingForPull then
				waitingForPull = false
				refreshGacha()
			end
		end)
	end))

	local function showGachaResult(u: {
		carId: string,
		isNew: boolean,
		refund: number,
		free: boolean,
		coins: number,
	})
		waitingForPull = false
		coins = u.coins
		freePull = if u.free then false else freePull
		refreshHud()
		refreshGacha()
		local id = u.carId
		local rarity = rarityOf(id)
		resultTitle.Text = LobbyText.resultText(u.isNew, u.refund)
		resultTitle.TextColor3 = if u.isNew then GREEN else GOLD
		resultName.Text = carName(id)
		resultName.TextColor3 = RARITY_COLOR[rarity] or WHITE
		resultSub.Text = rarity
		resultSub.TextColor3 = RARITY_COLOR[rarity] or WHITE
		resultSwatch.BackgroundColor3 = carColor(id)
		resultStroke.Color = RARITY_COLOR[rarity] or WHITE
		resultBack.Visible = true
		resultScale.Scale = 0.4
		TweenService:Create(resultScale, POP, { Scale = 1 }):Play()
	end

	-- STORE screen (list only, no buying)
	local storeBack, storePanel, storeOpen = modal("CARS", CYAN)
	local storeList = Instance.new("ScrollingFrame")
	storeList.Size = UDim2.fromScale(0.92, 0.8)
	storeList.Position = UDim2.fromScale(0.04, 0.16)
	storeList.BackgroundTransparency = 1
	storeList.BorderSizePixel = 0
	storeList.ScrollBarThickness = 6
	storeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	storeList.CanvasSize = UDim2.fromScale(0, 0)
	storeList.ZIndex = 12
	storeList.Parent = storePanel
	local storeLayout = Instance.new("UIListLayout")
	storeLayout.Padding = UDim.new(0, 8)
	storeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	storeLayout.Parent = storeList
	local storeRows: { [string]: { frame: Frame, tag: TextLabel, name: TextLabel } } = {}
	for i, id in CarConfig.Order do
		local stats = CarConfig.Cars[id]
		local row = frame(storeList, UDim2.new(1, -8, 0, 84), UDim2.fromScale(0, 0), NAVY)
		row.LayoutOrder = i
		row.ZIndex = 13
		corner(row, 0.14)
		local swatch =
			frame(row, UDim2.fromOffset(52, 52), UDim2.new(0, 12, 0.5, -26), carColor(id))
		swatch.ZIndex = 14
		corner(swatch, 0.25)
		local n = label(row, stats.name, UDim2.new(0.5, -80, 0.5, 0), UDim2.new(0, 76, 0, 4))
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.ZIndex = 14
		local b = label(row, stats.blurb, UDim2.new(0.5, -80, 0.36, 0), UDim2.new(0, 76, 0.56, 0))
		b.Font = Enum.Font.GothamBold
		b.TextColor3 = Color3.fromRGB(190, 200, 230)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.ZIndex = 14
		local tag = label(row, "", UDim2.new(0.3, 0, 0.5, 0), UDim2.new(0.68, -8, 0.05, 0))
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.ZIndex = 14
		local rar =
			label(row, rarityOf(id), UDim2.new(0.3, 0, 0.32, 0), UDim2.new(0.68, -8, 0.58, 0))
		rar.TextColor3 = RARITY_COLOR[rarityOf(id)] or WHITE
		rar.TextXAlignment = Enum.TextXAlignment.Right
		rar.ZIndex = 14
		storeRows[id] = { frame = row, tag = tag, name = n }
	end
	local function refreshStore()
		for id, r in storeRows do
			local has = owned[id] == true
			r.tag.Text = if has then "OWNED" else "LOCKED"
			r.tag.TextColor3 = if has then GREEN else Color3.fromRGB(150, 150, 170)
			r.name.TextTransparency = if has then 0 else 0.4
		end
	end

	-- CHOICES (pick 1 of N) with timer
	local choicesBack = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NAVY)
	choicesBack.BackgroundTransparency = 0.3
	choicesBack.Active = true
	choicesBack.Visible = false
	choicesBack.ZIndex = 30
	local choicesTitle =
		label(choicesBack, "PICK YOUR CAR", UDim2.fromScale(0.6, 0.12), UDim2.fromScale(0.2, 0.04))
	choicesTitle.TextColor3 = CYAN
	choicesTitle.ZIndex = 31
	local timerLabel =
		label(choicesBack, "", UDim2.fromScale(0.2, 0.12), UDim2.fromScale(0.78, 0.04))
	timerLabel.TextColor3 = GOLD
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.ZIndex = 31
	local choicesRow = Instance.new("Frame")
	choicesRow.BackgroundTransparency = 1
	choicesRow.Size = UDim2.fromScale(0.94, 0.68)
	choicesRow.Position = UDim2.fromScale(0.03, 0.2)
	choicesRow.ZIndex = 31
	choicesRow.Parent = choicesBack
	local choicesLayout = Instance.new("UIListLayout")
	choicesLayout.FillDirection = Enum.FillDirection.Horizontal
	choicesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choicesLayout.Padding = UDim.new(0.02, 0)
	choicesLayout.Parent = choicesRow
	local choiceDeadline = 0
	local choiceToken = 0
	local choiceSent = false

	local function hideChoices()
		choiceToken += 1
		choicesBack.Visible = false
		for _, c in choicesRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function showChoices(cars: { string }, seconds: number)
		hideChoices()
		choiceSent = false
		local token = choiceToken
		choiceDeadline = os.clock() + seconds
		choicesBack.Visible = true
		local count = math.max(1, #cars)
		local width = (1 - 0.02 * (count - 1)) / count
		local buttons: { TextButton } = {}
		for _, id in cars do
			local stats = CarConfig.get(id)
			local rarity = rarityOf(id)
			local b = button(
				choicesRow,
				"",
				UDim2.fromScale(math.min(width, 0.32), 1),
				UDim2.fromScale(0, 0),
				carColor(id)
			)
			b.ZIndex = 32
			local pad = b:FindFirstChildOfClass("UIPadding")
			if pad then
				pad:Destroy()
			end
			local n = label(b, carName(id), UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.08))
			n.ZIndex = 33
			local r = label(b, rarity, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.3))
			r.TextColor3 = RARITY_COLOR[rarity] or WHITE
			r.ZIndex = 33
			local blurb = label(
				b,
				if stats then stats.blurb else "",
				UDim2.fromScale(0.9, 0.3),
				UDim2.fromScale(0.05, 0.55)
			)
			blurb.Font = Enum.Font.GothamBold
			blurb.ZIndex = 33
			b.Activated:Connect(function()
				if choiceSent then
					return
				end
				choiceSent = true
				send("pickCar", id)
				for _, other in buttons do
					other.Active = false
					if other ~= b then
						other.BackgroundTransparency = 0.7
					end
				end
				choicesTitle.Text = "GET READY..."
			end)
			table.insert(buttons, b)
		end
		choicesTitle.Text = "PICK YOUR CAR"
		task.spawn(function()
			while token == choiceToken and choicesBack.Visible do
				timerLabel.Text = LobbyText.timerText(choiceDeadline - os.clock())
				task.wait(0.1)
			end
		end)
	end

	-- COUNTDOWN (pad): big number + leave button
	local countLabel = label(gui, "", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.35, 0.22))
	countLabel.TextColor3 = GOLD
	countLabel.TextStrokeTransparency = 0
	countLabel.Visible = false
	countLabel.ZIndex = 25
	textLimit(countLabel, 40, 200)
	local countScale = Instance.new("UIScale")
	countScale.Parent = countLabel
	local leaveButton =
		button(gui, "LEAVE", UDim2.fromScale(0.24, 0.12), UDim2.fromScale(0.38, 0.72), PINK)
	leaveButton.Visible = false
	leaveButton.ZIndex = 25
	leaveButton.Activated:Connect(debounced(function()
		send("leavePad")
	end))

	local function showCountdown(seconds: number)
		local text = LobbyText.countdownText(seconds)
		if text == nil then
			countLabel.Visible = false
			leaveButton.Visible = false
			return
		end
		countLabel.Visible = true
		leaveButton.Visible = true
		countLabel.Text = text
		countScale.Scale = 1.6
		TweenService:Create(countScale, POP, { Scale = 1 }):Play()
	end

	-- Reward toast after the match
	local toast = label(gui, "", UDim2.fromScale(0.7, 0.12), UDim2.fromScale(0.15, 0.14))
	toast.Visible = false
	toast.ZIndex = 40
	local toastToken = 0
	local function showToast(text: string, color: Color3)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.TextColor3 = color
		toast.Visible = true
		task.delay(3.5, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end

	-- Prompts
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "GachaPrompt" then
			resultBack.Visible = false
			gachaMsg.Text = ""
			refreshGacha()
			gachaOpen()
		elseif prompt.Name == "StorePrompt" then
			refreshStore()
			storeOpen()
		end
	end)

	local function closeModals()
		gachaBack.Visible = false
		storeBack.Visible = false
	end

	local handle: Handle = {} :: any
	handle.hideChoices = hideChoices
	handle.handleUpdate = function(u: Types.LobbyUpdate)
		if u.kind == "profile" then
			coins = u.coins
			wins = u.wins
			owned = {}
			for _, id in u.owned do
				owned[id] = true
			end
			freePull = u.freePullAvailable
			refreshHud()
			refreshStore()
			refreshGacha()
		elseif u.kind == "gacha" then
			showGachaResult(u)
		elseif u.kind == "gachaError" then
			waitingForPull = false
			gachaMsg.Text = LobbyText.gachaErrorText(u.reason)
			refreshGacha()
		elseif u.kind == "countdown" then
			closeModals()
			showCountdown(u.seconds)
		elseif u.kind == "choices" then
			closeModals()
			showCountdown(0)
			showChoices(u.cars, u.seconds)
		elseif u.kind == "toLobby" then
			hideChoices()
			showCountdown(0)
			closeModals()
			hooks.onToLobby(u.coinsEarned, u.won)
			showToast(LobbyText.rewardText(u.coinsEarned, u.won), if u.won then GREEN else PINK)
		end
	end

	refreshHud()
	refreshStore()
	refreshGacha()
	return handle
end

return LobbyUi
