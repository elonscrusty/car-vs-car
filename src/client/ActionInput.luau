--!strict
-- Fight move buttons: BOOST and ABILITY side by side in the bottom-right corner. Keys:
-- LeftShift = boost, E = ability (named after the car's ability), Space = jump (no button). Each button shows its cooldown as a fill and a timer. The server decides
-- everything; it tells us when a cooldown starts (UiUpdate kind "move"). The ability button
-- sends the "special" move.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudStyle = require(ReplicatedStorage.Shared.HudStyle)
local SoundFx = require(script.Parent.SoundFx)
local UiStyle = require(script.Parent.UiStyle)

export type ActionInput = {
	start: (abilityName: string?) -> (), -- names the ABILITY button after the car's ability
	stop: () -> (),
	cooldown: (move: string, seconds: number) -> (), -- the server started a cooldown
}

local ActionInput = {}

local MOVES = {
	{
		name = "boost",
		text = "BOOST",
		icon = ">>>",
		key = Enum.KeyCode.LeftShift,
		color = Color3.fromRGB(40, 190, 255),
	},
	{
		name = "special",
		text = "ABILITY",
		icon = "⚡",
		key = Enum.KeyCode.E,
		color = Color3.fromRGB(255, 190, 30),
	},
}

type Slot = {
	button: TextButton,
	fill: Frame,
	label: TextLabel,
	readyAt: number,
	total: number,
}

function ActionInput.new(send: (name: string) -> ()): ActionInput
	local gui: ScreenGui? = nil
	local running = false
	local slots: { [string]: Slot } = {}
	local conn: RBXScriptConnection? = nil

	local function press(name: string)
		local slot = slots[name]
		if name == "jump" then
			if running then
				send(name) -- Space only: no button, no cooldown shown
			end
			return
		end
		if not running or slot == nil or os.clock() < slot.readyAt then
			return
		end
		SoundFx.play(if name == "boost" then "boost" else "ability")
		send(name)
	end

	local function render()
		local now = os.clock()
		for _, slot in slots do
			local left = slot.readyAt - now
			if left > 0 and slot.total > 0 then
				slot.fill.Visible = true
				slot.fill.Size = UDim2.fromScale(1, math.clamp(left / slot.total, 0, 1))
				slot.label.Text = string.format("%.1f", left)
				slot.button.BackgroundTransparency = 0.55
			else
				slot.fill.Visible = false
				slot.button.BackgroundTransparency = 0
			end
		end
	end

	local function makeButton(parent: Frame, index: number, side: number, def: typeof(MOVES[1]))
		local b = Instance.new("TextButton")
		b.Name = def.name .. "Action"
		b.LayoutOrder = index
		b.Size = UDim2.fromOffset(side, side)
		b.BackgroundColor3 = def.color
		b.Text = ""
		b.AutoButtonColor = false
		b.ClipsDescendants = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.22, 0)
		corner.Parent = b
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromScale(0, 0.06)
		icon.Size = UDim2.fromScale(1, 0.5)
		icon.Text = def.icon
		icon.TextScaled = true
		icon.Font = Enum.Font.FredokaOne
		icon.TextColor3 = Color3.new(1, 1, 1)
		icon.Parent = b
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0, 0.62)
		name.Size = UDim2.fromScale(1, 0.26)
		name.Text = def.text
		name.TextScaled = true
		name.Font = Enum.Font.FredokaOne
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = name
		local fill = Instance.new("Frame") -- dark cover that shrinks as the cooldown runs out
		fill.Name = "Cooldown"
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.fromScale(0, 1)
		fill.Size = UDim2.fromScale(1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
		fill.BackgroundTransparency = 0.25
		fill.BorderSizePixel = 0
		fill.Visible = false
		fill.ZIndex = 2
		fill.Parent = b
		local label = Instance.new("TextLabel")
		label.Name = "Timer"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(1, 0.4)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = 3
		label.Parent = b
		b:SetAttribute("NoClickSound", true) -- boost/ability have their own sound
		UiStyle.polish(b)
		b.Activated:Connect(function()
			press(def.name)
		end)
		b.Parent = parent
		slots[def.name] = { button = b, fill = fill, label = label, readyAt = 0, total = 0 }
	end

	local keyMap: { [Enum.KeyCode]: string } = {}
	for _, def in MOVES do
		keyMap[def.key] = def.name
	end
	keyMap[Enum.KeyCode.Space] = "jump"
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local name = keyMap[input.KeyCode]
		if name and not processed then
			press(name)
		end
	end)

	local self: ActionInput = {} :: any

	self.start = function(abilityName: string?)
		if running then
			return
		end
		running = true
		local defs = table.clone(MOVES)
		if abilityName then
			defs[2] = {
				name = "special",
				text = abilityName,
				icon = MOVES[2].icon,
				key = MOVES[2].key,
				color = MOVES[2].color,
			}
		end
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "ActionGui"
		newGui.ResetOnSpawn = false
		newGui.IgnoreGuiInset = true
		newGui.DisplayOrder = 5
		newGui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		gui = newGui
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 400
		local side = HudStyle.buttonSize(height)
		local gap = HudStyle.BUTTON_GAP
		local stack = Instance.new("Frame")
		stack.Name = "Stack"
		stack.BackgroundTransparency = 1
		stack.AnchorPoint = Vector2.new(1, 1)
		stack.Position = UDim2.new(1, -HudStyle.EDGE, 1, -HudStyle.EDGE)
		stack.Size = UDim2.fromOffset(#defs * side + (#defs - 1) * gap, side)
		stack.Parent = newGui
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.Padding = UDim.new(0, gap)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = stack
		table.clear(slots)
		for i, def in defs do
			makeButton(stack, i, side, def)
		end
		render()
		conn = RunService.RenderStepped:Connect(render)
	end

	self.stop = function()
		if not running then
			return
		end
		running = false
		if conn then
			conn:Disconnect()
			conn = nil
		end
		table.clear(slots)
		if gui then
			gui:Destroy()
			gui = nil
		end
	end

	self.cooldown = function(move: string, seconds: number)
		local slot = slots[move]
		if slot and seconds > 0 then
			slot.readyAt = os.clock() + seconds
			slot.total = seconds
		end
	end

	return self
end

return ActionInput
