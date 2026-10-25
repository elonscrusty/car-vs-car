--!strict
-- The plot looks shop screen: a LOOKS button (under the bolts chip, only while you own a plot)
-- opens a card per look (shared/PlotShop): the themes on top, the decor under them. A look you
-- don't have shows BUY and its price (or how many coins are missing, and the stars that give it
-- free); one you have says OWNED, with EQUIPPED / USE. Every tap asks the server (PlotShopEvent), which answers with the new state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local PlotShop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlotShop"))
local Popup = require(script.Parent:WaitForChild("Popup"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PlotShopEvent") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 213, 79)
local GREEN = Color3.fromRGB(70, 190, 90)
local GREY = Color3.fromRGB(110, 110, 118)
local BLUE = Color3.fromRGB(40, 120, 230)

type State = { coins: number, stars: number, have: { string }, on: { string } }
local state: State = { coins = 0, stars = 0, have = {}, on = {} }

local gui = Instance.new("ScreenGui")
gui.Name = "PlotShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = HudLayout.POPUP
gui.Parent = player:WaitForChild("PlayerGui")

-- the LOOKS button sits with the other lobby buttons, under the popups; hidden while driving
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "PlotShopButton"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = HudLayout.HUD
hudGui.Parent = player:WaitForChild("PlayerGui")
local function showButton()
	hudGui.Enabled = player:GetAttribute("Driving") ~= true
		and player:GetAttribute("Building") ~= true
end
player:GetAttributeChangedSignal("Driving"):Connect(showButton)
player:GetAttributeChangedSignal("Building"):Connect(showButton)
showButton()

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

local function text(class: string, parent: Instance, t: string, color: Color3): any
	local l = Instance.new(class) :: any
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = t
	l.Parent = parent
	return l
end

local openBtn = text("TextButton", hudGui, "LOOKS", Color3.new(1, 1, 1)) :: TextButton
openBtn.Name = "Looks"
HudLayout.place(openBtn, "Looks") -- right of RIVALS, under the coins
openBtn.BackgroundColor3 = Color3.fromRGB(176, 70, 255)
openBtn.BackgroundTransparency = 0.15
openBtn.Visible = false
corner(openBtn, 0.3)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.86, 0.8)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
panel.Visible = false
panel.Parent = gui
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1.6
ratio.Parent = panel
corner(panel, 0.05)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(176, 70, 255)
stroke.Parent = panel

local title = text("TextLabel", panel, "MY PLOT LOOKS", Color3.new(1, 1, 1)) :: TextLabel
title.Position = UDim2.fromScale(0.04, 0.03)
title.Size = UDim2.fromScale(0.5, 0.1)
title.TextXAlignment = Enum.TextXAlignment.Left

local wallet = text("TextLabel", panel, "", GOLD) :: TextLabel
wallet.Position = UDim2.fromScale(0.5, 0.04)
wallet.Size = UDim2.fromScale(0.36, 0.08)
wallet.TextXAlignment = Enum.TextXAlignment.Right

local close = text("TextButton", panel, "X", Color3.new(1, 1, 1)) :: TextButton
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(0.97, 0.03)
close.Size = UDim2.fromScale(0.07, 0.1)
close.BackgroundTransparency = 0
close.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
corner(close, 0.3)

type Card = { item: PlotShop.Item, button: TextButton, note: TextLabel }
local cardList: { Card } = {}

local function row(kind: string, y: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.04, y)
	holder.Size = UDim2.fromScale(0.92, 0.4)
	holder.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.03, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	for i, it in PlotShop.ITEMS do
		if it.kind ~= kind then
			continue
		end
		local c = Instance.new("Frame")
		c.Size = UDim2.fromScale(0.3, 1)
		c.LayoutOrder = i
		c.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
		c.Parent = holder
		corner(c, 0.08)
		local icon = text("TextLabel", c, it.icon, Color3.new(1, 1, 1))
		icon.Position = UDim2.fromScale(0.05, 0.04)
		icon.Size = UDim2.fromScale(0.9, 0.36)
		local name = text("TextLabel", c, it.name, Color3.new(1, 1, 1))
		name.Position = UDim2.fromScale(0.08, 0.41)
		name.Size = UDim2.fromScale(0.84, 0.15)
		local note = text("TextLabel", c, "", Color3.fromRGB(200, 200, 205))
		note.Position = UDim2.fromScale(0.08, 0.57)
		note.Size = UDim2.fromScale(0.84, 0.1)
		local button = text("TextButton", c, "", Color3.new(1, 1, 1))
		button.Position = UDim2.fromScale(0.1, 0.71)
		button.Size = UDim2.fromScale(0.8, 0.22)
		button.BackgroundTransparency = 0
		corner(button, 0.3)
		-- the price words stay inside the pill
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.1, 0)
		pad.PaddingRight = UDim.new(0.1, 0)
		pad.PaddingTop = UDim.new(0.16, 0)
		pad.PaddingBottom = UDim.new(0.16, 0)
		pad.Parent = button
		button.Activated:Connect(function()
			local has = table.find(state.have, it.id) ~= nil
			remote:FireServer(if has then "toggle" else "buy", it.id)
		end)
		table.insert(cardList, { item = it, button = button, note = note })
	end
end
row("theme", 0.15)
row("decor", 0.57)

local function show()
	wallet.Text = `⭐ {state.stars}    {state.coins} coins`
	for _, c in cardList do
		local it = c.item
		if table.find(state.have, it.id) then
			-- yours: EQUIPPED (tap to take it off) or USE (tap to put it on)
			local on = table.find(state.on, it.id) ~= nil
			c.button.Text = if on then "EQUIPPED" else "USE"
			c.button.BackgroundColor3 = if on then GREEN else BLUE
			c.note.Text = "OWNED"
		else
			-- one big BUY with the price, or how many coins are still missing
			local can = state.coins >= it.price
			c.button.Text = if can then `BUY {it.price}` else `{it.price - state.coins} MORE`
			c.button.BackgroundColor3 = if can then GOLD else GREY
			c.button.TextColor3 = if state.coins >= it.price
				then Color3.fromRGB(40, 30, 0)
				else Color3.new(1, 1, 1)
			c.note.Text = if it.stars then `or free at ⭐ {it.stars}` else ""
			continue
		end
		c.button.TextColor3 = Color3.new(1, 1, 1)
	end
end
show()

remote.OnClientEvent:Connect(function(kind: string, info: any)
	if kind == "state" and type(info) == "table" then
		state = info
		show()
	end
end)

openBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		remote:FireServer("open")
	end
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
-- tap outside shuts it too, and it never stacks on another popup
Popup.add("looks", gui, function()
	panel.Visible = false
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	Popup.shown("looks", panel.Visible)
end)

-- the LOOKS button only while you own a plot
-- (owns a plot, is driving one): LOOKS shows only while walking with a plot of your own
local function myPlot(): (boolean, boolean)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return false, false
	end
	local mine, driving = false, false
	for _, m in plots:GetChildren() do
		if m:GetAttribute("OwnerId") == player.UserId then
			mine = true
		end
		if m:GetAttribute("DriverId") == player.UserId then
			driving = true
		end
	end
	return mine, driving
end
while true do
	local mine, driving = myPlot()
	-- (and not for a brand new player: fewer buttons until the first drive)
	openBtn.Visible = mine and not driving and player:GetAttribute("DroveOnce") == true
	if not mine then
		panel.Visible = false
	end
	task.wait(0.5)
end
