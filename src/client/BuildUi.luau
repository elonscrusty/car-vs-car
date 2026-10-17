--!strict
-- Garage modal (build-and-watch): pick your car, wear parts, level up a slot.
-- Display only: the server checks coins, ownership and where you are (LobbyAction build*).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildConfig = require(ReplicatedStorage.Shared.BuildConfig)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local BuildUi = {}

export type Menu = {
	add: (id: string, label: string, order: number, onClick: () -> ()) -> (),
}

export type Handle = {
	handleUpdate: (u: Types.LobbyUpdate) -> (),
	close: () -> (),
}

local NAVY = Color3.fromRGB(10, 14, 32)
local PANEL = Color3.fromRGB(18, 22, 48)
local CELL = Color3.fromRGB(30, 34, 62)
local CYAN = Color3.fromRGB(60, 240, 255)
local PINK = Color3.fromRGB(255, 70, 190)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(70, 255, 140)
local GOLD = Color3.fromRGB(255, 210, 70)
local WHITE = Color3.new(1, 1, 1)

local TOUCH = 56
local HEADER = 68
local CARD = 76
local CLICK_GAP = 0.3

local REASONS: { [string]: string } = {
	busy = "Leave the pad first",
	loading = "Still loading, try again",
	notowned = "You do not own that",
	owned = "You already have that",
	coins = "Not enough coins",
	max = "Already the top level",
	unknown = "Can't do that",
}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function text(
	parent: Instance,
	str: string,
	size: UDim2,
	pos: UDim2,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = str
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MinTextSize = 12
	lim.MaxTextSize = 26
	lim.Parent = l
	return l
end

local function button(parent: Instance, str: string, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = str
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = WHITE
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 12)
	local lim = Instance.new("UITextSizeConstraint")
	lim.MinTextSize = 12
	lim.MaxTextSize = 24
	lim.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

function BuildUi.new(menu: Menu): Handle
	local remotes = Remotes.get()

	-- Mirrored from the server (display only).
	local coins = 0
	local ownedCars: { [string]: boolean } = {}
	local build: {
		carId: string,
		parts: { [string]: string },
		owned: { string },
		levels: { [string]: number },
		power: number,
	}? =
		nil
	local lastTap = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = NAVY
	backdrop.BackgroundTransparency = 0.35
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false
	backdrop.Active = true
	backdrop.Parent = gui
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, -24, 1, -24)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Parent = backdrop
	corner(panel, 16)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = CYAN
	pStroke.Thickness = 3
	pStroke.Parent = panel
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(760, 560)
	maxSize.Parent = panel

	text(panel, "GARAGE", UDim2.new(0.4, 0, 0, 40), UDim2.fromOffset(14, 14), CYAN)
	local info = text(panel, "", UDim2.new(0.45, -70, 0, 34), UDim2.new(0.4, 0, 0, 16), GOLD)
	info.TextXAlignment = Enum.TextXAlignment.Right
	local close = button(panel, "X", UDim2.fromOffset(TOUCH, TOUCH), PINK)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)

	local message = text(panel, "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -36), RED)

	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -24, 1, -HEADER - 48)
	body.Position = UDim2.fromOffset(12, HEADER)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local function tap(action: string, arg: string)
		local now = os.clock()
		if now - lastTap < CLICK_GAP then
			return
		end
		lastTap = now
		message.Text = ""
		remotes.LobbyAction:FireServer(action, arg)
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function header(str: string): TextLabel
		local l = text(body, str, UDim2.new(1, -8, 0, 30), UDim2.new(), WHITE)
		l.LayoutOrder = nextOrder()
		return l
	end

	-- Cars row
	header("YOUR CAR")
	local carButtons: { [string]: TextButton } = {}
	for _, id in CarConfig.Order do
		local stats = CarConfig.Cars[id]
		local b = button(body, stats.name, UDim2.new(1, -8, 0, 52), CELL)
		b.LayoutOrder = nextOrder()
		b.Activated:Connect(function()
			if ownedCars[id] then
				tap("buildCar", id)
			end
		end)
		carButtons[id] = b
	end

	-- One block per slot: level bar + part cards
	local slotUi: { [string]: { level: TextLabel, upgrade: TextButton } } = {}
	local partUi: { [string]: { button: TextButton, status: TextLabel, stroke: UIStroke } } = {}
	for _, slot in BuildConfig.Slots do
		local head = Instance.new("Frame")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, -8, 0, TOUCH)
		head.LayoutOrder = nextOrder()
		head.Parent = body
		text(
			head,
			BuildConfig.SlotNames[slot],
			UDim2.new(0.4, 0, 0, 30),
			UDim2.fromOffset(0, 4),
			CYAN
		)
		local level = text(head, "", UDim2.new(0.4, 0, 0, 22), UDim2.fromOffset(0, 32), WHITE)
		local up = button(head, "UPGRADE", UDim2.new(0.5, 0, 1, 0), GREEN)
		up.AnchorPoint = Vector2.new(1, 0)
		up.Position = UDim2.fromScale(1, 0)
		up.Activated:Connect(function()
			tap("buildUpgrade", slot)
		end)
		slotUi[slot] = { level = level, upgrade = up }
		for _, id in BuildConfig.Order[slot] do
			local def = BuildConfig.Parts[id]
			local b = button(body, "", UDim2.new(1, -8, 0, CARD), CELL)
			b.LayoutOrder = nextOrder()
			local st = Instance.new("UIStroke")
			st.Color = WHITE
			st.Thickness = 1
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = b
			text(b, def.name, UDim2.new(0.55, 0, 0, 30), UDim2.fromOffset(10, 6), WHITE)
			text(b, def.blurb, UDim2.new(0.6, 0, 0, 24), UDim2.fromOffset(10, 42), WHITE).TextTransparency =
				0.2
			local status = text(b, "", UDim2.new(0.4, -10, 0, 40), UDim2.new(0.6, 0, 0, 18), GREEN)
			status.TextXAlignment = Enum.TextXAlignment.Right
			b.Activated:Connect(function()
				local has = false
				if build then
					for _, o in build.owned do
						if o == id then
							has = true
						end
					end
				end
				tap(if has then "buildEquip" else "buildBuy", id)
			end)
			partUi[id] = { button = b, status = status, stroke = st }
		end
	end

	local function refresh()
		local b = build
		if b == nil then
			return
		end
		info.Text = `POWER {b.power}   COINS {coins}`
		for id, btn in carButtons do
			local has = ownedCars[id] == true
			btn.BackgroundTransparency = if has then 0 else 0.6
			btn.AutoButtonColor = has
			local name = CarConfig.Cars[id].name
			btn.Text = if id == b.carId
				then `{name}  (USING)`
				elseif has then name
				else `{name}  (WIN AT CLAW)`
			btn.TextColor3 = if id == b.carId then GOLD else WHITE
		end
		local ownedSet: { [string]: boolean } = {}
		for _, o in b.owned do
			ownedSet[o] = true
		end
		for _, slot in BuildConfig.Slots do
			local lv = b.levels[slot] or 1
			local ui = slotUi[slot]
			ui.level.Text = `LEVEL {lv} / {BuildConfig.MaxLevel}`
			local cost = BuildConfig.LevelCost[lv]
			if lv >= BuildConfig.MaxLevel or cost == nil then
				ui.upgrade.Text = "MAX"
				ui.upgrade.AutoButtonColor = false
				ui.upgrade.BackgroundColor3 = CELL
			else
				ui.upgrade.Text = `UPGRADE {cost}`
				ui.upgrade.AutoButtonColor = true
				ui.upgrade.BackgroundColor3 = if coins >= cost then GREEN else CELL
			end
			for _, id in BuildConfig.Order[slot] do
				local pu = partUi[id]
				local def = BuildConfig.Parts[id]
				local wearing = b.parts[slot] == id
				pu.stroke.Color = if wearing then GOLD else WHITE
				pu.stroke.Thickness = if wearing then 4 else 1
				if wearing then
					pu.status.Text = "WEARING"
					pu.status.TextColor3 = GREEN
				elseif ownedSet[id] then
					pu.status.Text = "WEAR"
					pu.status.TextColor3 = WHITE
				else
					pu.status.Text = `BUY {def.cost}`
					pu.status.TextColor3 = if coins >= def.cost then GOLD else RED
				end
			end
		end
	end

	close.Activated:Connect(function()
		backdrop.Visible = false
	end)

	menu.add("garage", "GARAGE", 20, function()
		message.Text = ""
		refresh()
		backdrop.Visible = true
	end)

	local handle: Handle = {} :: any
	handle.close = function()
		backdrop.Visible = false
	end
	handle.handleUpdate = function(u: Types.LobbyUpdate)
		if u.kind == "profile" then
			coins = u.coins
			table.clear(ownedCars)
			for _, id in u.owned do
				ownedCars[id] = true
			end
			build = u.build
			refresh()
		elseif u.kind == "buildResult" then
			message.Text = if u.ok then "" else (REASONS[u.reason or ""] or REASONS.unknown)
		elseif (u.kind == "countdown" and u.seconds > 0) or u.kind == "choices" then
			backdrop.Visible = false
		end
	end
	return handle
end

return BuildUi
