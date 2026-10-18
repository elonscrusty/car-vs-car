--!strict
-- A column of big lobby buttons on the left edge of the screen (Quests, Paint, Daily gift...).
-- Each feature registers its own button with `add`, so features never edit the same UI file.
-- The bar is hidden while a match is on screen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UiStyle = require(script.Parent.UiStyle)

export type MenuBar = {
	-- Adds a button. Lower `order` sits higher. Adding the same id again replaces its label/callback.
	add: (id: string, label: string, order: number, onClick: () -> ()) -> (),
	-- Shows a small red dot on a button (e.g. a gift is ready).
	setBadge: (id: string, on: boolean) -> (),
	setVisible: (visible: boolean) -> (),
	-- Tints a button's background (e.g. green/yellow/red for a difficulty).
	setColor: (id: string, color: Color3) -> (),
}

local MenuBar = {}

local BUTTON_W = 96
local BUTTON_H = 52 -- over the 48 px thumb minimum
local GAP = 6

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
	holder.Position = UDim2.new(0, 8, 0, if RunService:IsStudio() then 160 else 84)
	holder.Size = UDim2.fromOffset(BUTTON_W, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = gui

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = holder

	local buttons: { [string]: TextButton } = {}
	local badges: { [string]: Frame } = {}
	local clicks: { [string]: () -> () } = {}

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
			b.Font = Enum.Font.GothamBlack
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
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
