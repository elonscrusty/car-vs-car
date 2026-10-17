--!strict
-- Fight move buttons: BOOST, JUMP and SPECIAL in a vertical stack on the right edge, above the
-- right steer arrow (SteerInput keeps the bottom corners). Keys: LeftShift = boost,
-- Space = jump, E = special, Q = weapon (only when the car wears an active weapon). Each button shows its cooldown as a fill and a timer. The server
-- decides everything; it tells us when a cooldown starts (UiUpdate kind "move").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UiStyle = require(script.Parent.UiStyle)

export type ActionInput = {
	start: (hasWeaponButton: boolean?) -> (), -- true = also show the WEAPON button
	stop: () -> (),
	cooldown: (move: string, seconds: number) -> (), -- the server started a cooldown
}

local ActionInput = {}

local BUTTON = 60 -- px (touch targets must stay at least 52)
local GAP = 8
local EDGE = 16
local ARROW_SCALE = 0.2 -- the steer arrows are up to this fraction of the screen height
local ARROW_MIN, ARROW_MAX = 80, 170 -- ... clamped to these pixel sizes (SteerInput)

local MOVES = {
	{
		name = "special",
		text = "SPECIAL",
		key = Enum.KeyCode.E,
		color = Color3.fromRGB(190, 90, 255),
	},
	{
		name = "jump",
		text = "JUMP",
		key = Enum.KeyCode.Space,
		color = Color3.fromRGB(80, 200, 255),
	},
	{
		name = "boost",
		text = "BOOST",
		key = Enum.KeyCode.LeftShift,
		color = Color3.fromRGB(255, 160, 40),
	},
}

local WEAPON = {
	name = "weapon",
	text = "WEAPON",
	key = Enum.KeyCode.Q,
	color = Color3.fromRGB(235, 70, 60),
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
		if not running or slot == nil or os.clock() < slot.readyAt then
			return
		end
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
				slot.button.BackgroundTransparency = 0.7
			else
				slot.fill.Visible = false
				slot.button.BackgroundTransparency = 0.35
			end
		end
	end

	local function makeButton(parent: Frame, index: number, def: typeof(WEAPON))
		local b = Instance.new("TextButton")
		b.Name = def.name .. "Action"
		b.LayoutOrder = index
		b.Size = UDim2.fromOffset(BUTTON, BUTTON)
		b.BackgroundColor3 = def.color
		b.BackgroundTransparency = 0.35
		b.Text = def.text
		b.TextScaled = true
		b.Font = Enum.Font.GothamBlack
		b.TextColor3 = Color3.new(1, 1, 1)
		b.AutoButtonColor = false
		b.ClipsDescendants = true
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
		pad.Parent = b
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = b
		local limit = Instance.new("UISizeConstraint")
		limit.MinSize = Vector2.new(52, 52)
		limit.Parent = b
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
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -2)
		label.Size = UDim2.new(1, 0, 0, 14)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = 3
		label.Parent = b
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
	keyMap[WEAPON.key] = WEAPON.name
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local name = keyMap[input.KeyCode]
		if name and not processed then
			press(name)
		end
	end)

	local self: ActionInput = {} :: any

	self.start = function(hasWeaponButton: boolean?)
		if running then
			return
		end
		running = true
		local defs = table.clone(MOVES)
		if hasWeaponButton then
			table.insert(defs, 1, WEAPON)
		end
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "ActionGui"
		newGui.ResetOnSpawn = false
		newGui.IgnoreGuiInset = true
		newGui.DisplayOrder = 5
		newGui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		gui = newGui
		-- Stack sits above the right steer arrow (its size is a clamped fraction of the height).
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 400
		local arrow = math.clamp(height * ARROW_SCALE, ARROW_MIN, ARROW_MAX)
		local stack = Instance.new("Frame")
		stack.Name = "Stack"
		stack.BackgroundTransparency = 1
		stack.AnchorPoint = Vector2.new(1, 1)
		stack.Position = UDim2.new(1, -EDGE, 1, -(EDGE + arrow + GAP))
		stack.Size = UDim2.fromOffset(BUTTON, #defs * BUTTON + (#defs - 1) * GAP)
		stack.Parent = newGui
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = stack
		table.clear(slots)
		for i, def in defs do
			makeButton(stack, i, def)
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
