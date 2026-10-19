--!strict
-- A column of big lobby buttons on the left edge of the screen (Quests, Paint, Daily gift...).
-- Each feature registers its own button with `add`, so features never edit the same UI file.
-- The bar is hidden while a match is on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiLayoutConfig = require(ReplicatedStorage.Shared.UiLayoutConfig)
local UiStyle = require(script.Parent.UiStyle)

export type MenuBar = {
	-- Adds a button. Lower `order` sits higher. Adding the same id again replaces its label/callback.
	add: (id: string, label: string, order: number, onClick: () -> ()) -> (),
	-- Shows a small red dot on a button (e.g. a gift is ready).
	setBadge: (id: string, on: boolean) -> (),
	setVisible: (visible: boolean) -> (),
	-- Shows/hides one button (new-player menu, see MenuRules). Works before or after `add`.
	setShown: (id: string, shown: boolean) -> (),
	-- Tints a button's background (e.g. green/yellow/red for a difficulty).
	setColor: (id: string, color: Color3) -> (),
}

local MenuBar = {}

local BUTTON_W = UiLayoutConfig.menu.buttonW
local BUTTON_H = UiLayoutConfig.menu.buttonH -- over the 48 px thumb minimum
local GAP = UiLayoutConfig.menu.gap

function MenuBar.new(): MenuBar
	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0)
	-- Under the coins box, and under the Studio-only DEV button when it is there.
	local top = if RunService:IsStudio()
		then UiLayoutConfig.menu.topStudio
		else UiLayoutConfig.menu.top
	holder.Position = UDim2.new(0, 8, 0, top)
	-- Fixed height down to the bottom edge: when the buttons run out of room the column wraps
	-- into a second one instead of running off a 360 px tall phone screen (see UiLayout.menuRows).
	holder.Size = UDim2.new(0, 3 * (BUTTON_W + GAP), 1, -(top + UiLayoutConfig.menu.bottomMargin))
	holder.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Wraps = true
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = holder

	local buttons: { [string]: TextButton } = {}
	local badges: { [string]: Frame } = {}
	local clicks: { [string]: () -> () } = {}
	local hidden: { [string]: boolean } = {}

	local bar = {} :: MenuBar

	bar.add = function(id: string, label: string, order: number, onClick: () -> ())
		clicks[id] = onClick
		local button = buttons[id]
		if button == nil then
			button = Instance.new("TextButton")
			local b = button :: TextButton
			b.Size = UDim2.fromOffset(BUTTON_W, BUTTON_H)
			b.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
			b.BorderSizePixel = 0
			b.AutoButtonColor = true
			b.Font = Enum.Font.FredokaOne
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
			b.TextWrapped = true
			UiStyle.textLimit(b, UiLayoutConfig.minText, 22)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = b
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 6)
			pad.PaddingTop = UDim.new(0, 6)
			pad.PaddingBottom = UDim.new(0, 6)
			pad.Parent = b
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(16, 16)
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.Position = UDim2.new(1, -2, 0, 2)
			dot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			dot.BorderSizePixel = 0
			dot.Visible = false
			dot.ZIndex = 5
			local dotCorner = Instance.new("UICorner")
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot
			dot.Parent = b
			badges[id] = dot
			UiStyle.polish(b)
			b.Activated:Connect(function()
				local fn = clicks[id]
				if fn then
					fn()
				end
			end)
			b.Parent = holder
			buttons[id] = b
			button = b
		end
		local b = button :: TextButton
		b.Text = label
		b.LayoutOrder = order
		b.Visible = not hidden[id]
	end

	bar.setShown = function(id: string, shown: boolean)
		hidden[id] = not shown
		local b = buttons[id]
		if b then
			b.Visible = shown
		end
	end

	bar.setBadge = function(id: string, on: boolean)
		local dot = badges[id]
		if dot then
			dot.Visible = on
		end
	end

	bar.setColor = function(id: string, color: Color3)
		local b = buttons[id]
		if b then
			b.BackgroundColor3 = color
		end
	end

	bar.setVisible = function(visible: boolean)
		gui.Enabled = visible
	end

	return bar
end

return MenuBar
