--!strict
-- Weapons modal: shows all car weapons, tap one you own to wear it.
-- Display only: the server checks ownership and where you are (LobbyAction equipWeapon).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local WeaponsConfig = require(ReplicatedStorage.Shared.WeaponsConfig)

local WeaponUi = {}

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

local RARITY_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 200, 220),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(200, 90, 255),
}

local TOUCH = 56 -- every tappable thing is at least this many px per side
local HEADER = 68
local CARD = 92
local CLICK_GAP = 0.4

local REASONS: { [string]: string } = {
	busy = "Leave the pad first",
	loading = "Still loading, try again",
	notowned = "You do not own that",
	unknown = "Can't do that",
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

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function WeaponUi.new(menu: Menu): Handle
	local remotes = Remotes.get()

	-- Mirrored from the server (display only).
	local owned: { [string]: boolean } = {}
	local equipped: string? = nil
	local lastTap = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponUi"
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
	stroke(panel, CYAN, 3)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(760, 560)
	maxSize.Parent = panel

	local title = text(panel, "WEAPONS", UDim2.new(1, -200, 0, 40), UDim2.fromOffset(14, 14), CYAN)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(panel, "X", UDim2.fromOffset(TOUCH, TOUCH), PINK)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)

	local message = text(panel, "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -36), RED)
	message.TextXAlignment = Enum.TextXAlignment.Left

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

	local cards: { [string]: { button: TextButton, stroke: UIStroke, status: TextLabel } } = {}

	for i, id in WeaponsConfig.Order do
		local def = WeaponsConfig.get(id)
		if def == nil then
			continue
		end
		local b = button(body, "", UDim2.new(1, -8, 0, CARD), CELL)
		b.LayoutOrder = i
		local st = Instance.new("UIStroke")
		st.Color = WHITE
		st.Thickness = 1
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = b

		local swatch =
			frame(b, UDim2.fromOffset(TOUCH, TOUCH), UDim2.fromOffset(8, 12), rgb(def.color))
		swatch.AnchorPoint = Vector2.new(0, 0)
		swatch.Position = UDim2.new(0, 8, 0.5, -TOUCH / 2)
		corner(swatch, 10)
		stroke(swatch, WHITE, 2)

		local name = text(b, def.name, UDim2.new(1, -230, 0, 28), UDim2.fromOffset(76, 8), WHITE)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local rarity = text(
			b,
			string.upper(def.rarity),
			UDim2.fromOffset(90, 22),
			UDim2.fromOffset(76, 38),
			RARITY_COLOR[def.rarity] or WHITE
		)
		rarity.TextXAlignment = Enum.TextXAlignment.Left
		local kindTag = text(
			b,
			if def.kind == "passive" then "PASSIVE" else "BUTTON",
			UDim2.fromOffset(90, 22),
			UDim2.fromOffset(172, 38),
			CYAN
		)
		kindTag.TextXAlignment = Enum.TextXAlignment.Left
		local blurb = text(b, def.blurb, UDim2.new(1, -90, 0, 22), UDim2.fromOffset(76, 62), WHITE)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextTransparency = 0.2

		local status = text(b, "", UDim2.fromOffset(140, 40), UDim2.new(1, -148, 0, 8), GREEN)
		status.TextXAlignment = Enum.TextXAlignment.Right

		b.Activated:Connect(function()
			if not owned[id] then
				return
			end
			local now = os.clock()
			if now - lastTap < CLICK_GAP then
				return
			end
			lastTap = now
			message.Text = ""
			remotes.LobbyAction:FireServer("equipWeapon", id)
		end)
		cards[id] = { button = b, stroke = st, status = status }
	end

	local function refresh()
		for id, c in cards do
			local has = owned[id] == true
			local wearing = has and id == equipped
			c.button.BackgroundTransparency = if has then 0 else 0.55
			c.button.AutoButtonColor = has
			c.stroke.Color = if wearing then GOLD else WHITE
			c.stroke.Thickness = if wearing then 4 else 1
			c.stroke.Transparency = if has then 0 else 0.6
			if wearing then
				c.status.Text = "WEARING"
				c.status.TextColor3 = GREEN
			elseif has then
				c.status.Text = ""
			else
				c.status.Text = "WIN IT AT THE CLAW"
				c.status.TextColor3 = GOLD
			end
			c.status.TextTransparency = if has then 0 else 0.3
		end
	end

	close.Activated:Connect(function()
		backdrop.Visible = false
	end)

	menu.add("weapons", "WEAPONS", 21, function()
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
			local w = u.weapons
			table.clear(owned)
			if w then
				for _, id in w.owned do
					owned[id] = true
				end
				equipped = w.equipped
			else
				equipped = nil
			end
			refresh()
		elseif u.kind == "weaponResult" then
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

return WeaponUi
