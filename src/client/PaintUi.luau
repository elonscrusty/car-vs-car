--!strict
-- Paint shop modal: pick one of your cars, tap a color or sticker to preview it, then BUY / EQUIP / REMOVE.
-- Display only: the server checks coins, ownership and where you are (LobbyAction buyPaint / equipPaint).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local Paint = require(ReplicatedStorage.Shared.Paint)
local PaintConfig = require(ReplicatedStorage.Shared.PaintConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local PaintUi = {}

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
local GREEN = Color3.fromRGB(70, 255, 140)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREY = Color3.fromRGB(70, 74, 100)
local WHITE = Color3.new(1, 1, 1)

local TOUCH = 56 -- every tappable thing is at least this many px per side
local HEADER = 68

local REASONS: { [string]: string } = {
	coins = "Not enough coins",
	owned = "You already own that",
	busy = "Leave the pad first",
	loading = "Still loading, try again",
	car = "Pick one of your cars",
	notowned = "Buy it first",
	unknown = "Can't do that",
	kind = "Can't do that",
}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
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
	l.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MinTextSize = 12
	lim.MaxTextSize = 30
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
	lim.MaxTextSize = 26
	lim.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

local function carColor(id: string): Color3
	local stats = CarConfig.get(id)
	if stats == nil then
		return GREY
	end
	return Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function PaintUi.new(menu: Menu): Handle
	local remotes = Remotes.get()

	-- Mirrored from the server (display only).
	local coins = 0
	local ownedCars: { string } = {}
	local data: Paint.PaintData = Paint.default()
	local selCar: string? = nil
	local selColor: string? = nil -- previewed (may be unowned)
	local selSticker: string? = nil
	local lastTapped: string? = nil -- the item the action button works on

	local gui = Instance.new("ScreenGui")
	gui.Name = "PaintUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local backdrop = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NAVY)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Visible = false
	backdrop.Active = true -- swallow taps
	local panel = frame(backdrop, UDim2.new(1, -24, 1, -24), UDim2.fromScale(0.5, 0.5), PANEL)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(panel, 16)
	stroke(panel, PINK, 3)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(760, 560)
	maxSize.Parent = panel

	local title =
		text(panel, "PAINT SHOP", UDim2.new(1, -200, 0, 40), UDim2.fromOffset(14, 14), PINK)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local coinsLabel = text(panel, "0", UDim2.fromOffset(110, 32), UDim2.new(1, -184, 0, 18), GOLD)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	local close = button(panel, "X", UDim2.fromOffset(TOUCH, TOUCH), PINK)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)

	-- Car picker row.
	local carRow = Instance.new("ScrollingFrame")
	carRow.Size = UDim2.new(1, -24, 0, 64)
	carRow.Position = UDim2.fromOffset(12, HEADER)
	carRow.BackgroundTransparency = 1
	carRow.BorderSizePixel = 0
	carRow.ScrollBarThickness = 4
	carRow.ScrollingDirection = Enum.ScrollingDirection.X
	carRow.CanvasSize = UDim2.new()
	carRow.AutomaticCanvasSize = Enum.AutomaticSize.X
	carRow.Parent = panel
	local carList = Instance.new("UIListLayout")
	carList.FillDirection = Enum.FillDirection.Horizontal
	carList.Padding = UDim.new(0, 8)
	carList.Parent = carRow

	-- Live preview swatch (left) + action button and message (right).
	local previewTop = HEADER + 72
	local preview = frame(panel, UDim2.fromOffset(150, 84), UDim2.fromOffset(12, previewTop), GREY)
	corner(preview, 12)
	stroke(preview, WHITE, 2)
	local previewSticker =
		text(preview, "", UDim2.fromScale(0.6, 0.7), UDim2.fromScale(0.2, 0.15), WHITE)
	previewSticker.TextStrokeTransparency = 0.2
	local previewName =
		text(panel, "", UDim2.fromOffset(150, 20), UDim2.fromOffset(12, previewTop + 88), WHITE)

	local action = button(panel, "", UDim2.new(1, -190, 0, TOUCH), PINK)
	action.Position = UDim2.fromOffset(176, previewTop)
	stroke(action, WHITE, 2)
	local message =
		text(panel, "", UDim2.new(1, -190, 0, 28), UDim2.fromOffset(176, previewTop + 62), WHITE)
	message.TextXAlignment = Enum.TextXAlignment.Left

	-- Color and sticker grids.
	local gridTop = previewTop + 116
	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -24, 1, -gridTop - 12)
	body.Position = UDim2.fromOffset(12, gridTop)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = panel
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 8)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.Parent = body

	local function section(name: string, order: number): Frame
		local head = text(body, name, UDim2.new(1, 0, 0, 24), UDim2.new(), CYAN)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.LayoutOrder = order
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = order + 1
		grid.Parent = body
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(104, 72)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		return grid
	end
	local colorGrid = section("COLORS", 1)
	local stickerGrid = section("STICKERS", 3)

	local carButtons: { [string]: TextButton } = {}
	local itemButtons: { [string]: TextButton } = {}

	local function equippedOf(carId: string?): Paint.Equipped
		if carId == nil then
			return {}
		end
		return data.equipped[carId] or {}
	end

	local function tag(id: string): string
		local e = equippedOf(selCar)
		if e.color == id or e.sticker == id then
			return "EQUIPPED"
		elseif data.owned[id] then
			return "OWNED"
		end
		return tostring(Paint.price(id)) .. " $"
	end

	local function refresh()
		coinsLabel.Text = tostring(coins) .. " $"
		-- car picker highlight
		for id, b in carButtons do
			b.BackgroundColor3 = if id == selCar then PINK else CELL
		end
		-- preview
		local base = if selCar then carColor(selCar) else GREY
		local c = PaintConfig.color(selColor)
		preview.BackgroundColor3 = if c then rgb(c.rgb) else base
		local s = PaintConfig.sticker(selSticker)
		previewSticker.Text = if s then s.text else ""
		local stats = if selCar then CarConfig.get(selCar) else nil
		previewName.Text = if stats then stats.name else ""
		-- item tiles
		for id, b in itemButtons do
			local label = b:FindFirstChild("Tag") :: TextLabel?
			if label then
				label.Text = tag(id)
				label.TextColor3 = if label.Text == "EQUIPPED" then GREEN else WHITE
			end
			local chosen = id == selColor or id == selSticker
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = if chosen then GOLD else WHITE
				st.Thickness = if chosen then 4 else 1
			end
		end
		-- action button for the last tapped item
		local id = lastTapped
		if selCar == nil then
			action.Text = "NO CARS"
			action.BackgroundColor3 = GREY
		elseif id == nil then
			action.Text = "PICK ONE"
			action.BackgroundColor3 = GREY
		elseif not data.owned[id] then
			action.Text = "BUY " .. tostring(Paint.price(id)) .. " $"
			action.BackgroundColor3 = if coins >= (Paint.price(id) or 0) then GREEN else GREY
		else
			local e = equippedOf(selCar)
			if e.color == id or e.sticker == id then
				action.Text = "REMOVE"
				action.BackgroundColor3 = PINK
			else
				action.Text = "EQUIP"
				action.BackgroundColor3 = CYAN
			end
		end
	end

	local function selectCar(id: string)
		selCar = id
		local e = equippedOf(id)
		selColor = e.color
		selSticker = e.sticker
		lastTapped = nil
		message.Text = ""
		refresh()
	end

	local function rebuildCars()
		for _, b in carButtons do
			b:Destroy()
		end
		table.clear(carButtons)
		for i, id in ownedCars do
			local stats = CarConfig.get(id)
			local b =
				button(carRow, if stats then stats.name else id, UDim2.fromOffset(110, 60), CELL)
			b.LayoutOrder = i
			b.Activated:Connect(function()
				selectCar(id)
			end)
			carButtons[id] = b
		end
		if selCar == nil or not table.find(ownedCars, selCar) then
			selCar = nil
			if ownedCars[1] then
				selectCar(ownedCars[1])
			end
		end
		refresh()
	end

	local function addTile(grid: Frame, id: string, order: number, fill: Color3?, face: string)
		local b = button(grid, "", UDim2.fromOffset(104, 72), fill or CELL)
		b.LayoutOrder = order
		stroke(b, WHITE, 1)
		local big = text(b, face, UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), WHITE)
		big.TextStrokeTransparency = 0.3
		big.ZIndex = 2
		local t = text(b, "", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.62), WHITE)
		t.Name = "Tag"
		t.TextStrokeTransparency = 0.3
		t.ZIndex = 2
		b.Activated:Connect(function()
			lastTapped = id
			if Paint.kindOf(id) == "color" then
				selColor = id
			else
				selSticker = id
			end
			message.Text = ""
			refresh()
		end)
		itemButtons[id] = b
	end
	for i, c in PaintConfig.Colors do
		addTile(colorGrid, c.id, i, rgb(c.rgb), c.name)
	end
	for i, s in PaintConfig.Stickers do
		addTile(stickerGrid, s.id, i, nil, s.text)
	end

	action.Activated:Connect(function()
		local id = lastTapped
		local carId = selCar
		if id == nil or carId == nil then
			return
		end
		if not data.owned[id] then
			if coins < (Paint.price(id) or 0) then
				message.Text = REASONS.coins
				return
			end
			remotes.LobbyAction:FireServer("buyPaint", id)
			return
		end
		local kind = Paint.kindOf(id)
		local e = equippedOf(carId)
		local wearing = e.color == id or e.sticker == id
		remotes.LobbyAction:FireServer(
			"equipPaint",
			{ carId = carId, kind = kind, id = if wearing then nil else id }
		)
		if wearing then
			if kind == "color" then
				selColor = nil
			else
				selSticker = nil
			end
		end
	end)

	close.Activated:Connect(function()
		backdrop.Visible = false
	end)

	menu.add("paint", "PAINT", 20, function()
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
			ownedCars = u.owned
			local p = u.paint
			local raw: any = if p then { owned = {}, equipped = p.equipped } else nil
			if p then
				for _, id in p.owned do
					raw.owned[id] = true
				end
			end
			data = Paint.clean(raw)
			-- keep the preview in sync with what the server says is worn
			if selCar ~= nil and table.find(ownedCars, selCar) then
				local e = equippedOf(selCar)
				if lastTapped == nil then
					selColor = e.color
					selSticker = e.sticker
				end
			end
			rebuildCars()
		elseif u.kind == "paintResult" then
			if u.ok then
				message.Text = ""
			else
				message.Text = REASONS[u.reason or ""] or REASONS.unknown
			end
		elseif (u.kind == "countdown" and u.seconds > 0) or u.kind == "choices" then
			backdrop.Visible = false -- stepped on a pad
		end
	end

	refresh()
	return handle
end

return PaintUi
