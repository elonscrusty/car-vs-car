--!strict
-- Steering during the fight: two big translucent arrow buttons in the bottom corners (touch or
-- mouse) plus A/D and Left/Right keys. Sends one number to the server: -1 left, 0 straight,
-- 1 right. Sends on every change and re-sends the held value every ~0.1 s, so the server (which
-- treats old values as 0) never keeps steering after a lost release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type SteerInput = {
	start: () -> (),
	stop: () -> (),
}

local SteerInput = {}

local MIN_SIZE = 80 -- px, smallest button side
local MAX_SIZE = 170
local IDLE_COLOR = Color3.fromRGB(255, 255, 255)
local PRESS_COLOR = Color3.fromRGB(255, 220, 40)

function SteerInput.new(send: (value: number) -> ()): SteerInput
	local gui: ScreenGui? = nil
	local running = false
	local generation = 0
	local pointerHeld: { [string]: boolean } = { left = false, right = false } -- on-screen buttons
	local keyCount: { [string]: number } = { left = 0, right = 0 } -- keys down per side (A and Left can both be held)
	local sent = 0
	local buttons: { [string]: TextButton } = {}

	local function isHeld(side: string): boolean
		return pointerHeld[side] or keyCount[side] > 0
	end

	local function value(): number
		return (if isHeld("right") then 1 else 0) - (if isHeld("left") then 1 else 0)
	end

	local function paint()
		for side, b in buttons do
			local down = isHeld(side)
			b.BackgroundTransparency = if down then 0.2 else 0.6
			b.TextColor3 = if down then PRESS_COLOR else IDLE_COLOR
			b.Size = if down then UDim2.fromScale(0.2, 0.2) else UDim2.fromScale(0.18, 0.18)
		end
	end

	local function update()
		paint()
		local v = value()
		if v ~= sent then
			sent = v
			send(v)
		end
	end

	local function makeButton(parent: ScreenGui, side: string, text: string, xScale: number)
		local b = Instance.new("TextButton")
		b.Name = side .. "Steer"
		b.AnchorPoint = Vector2.new(xScale, 1)
		b.Position = UDim2.new(xScale, if xScale == 0 then 16 else -16, 1, -16)
		b.Size = UDim2.fromScale(0.18, 0.18)
		b.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		b.BackgroundTransparency = 0.6
		b.Text = text
		b.TextScaled = true
		b.Font = Enum.Font.GothamBlack
		b.TextColor3 = IDLE_COLOR
		b.AutoButtonColor = false
		b.Active = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = IDLE_COLOR
		stroke.Transparency = 0.4
		stroke.Parent = b
		local limit = Instance.new("UISizeConstraint")
		limit.MinSize = Vector2.new(MIN_SIZE, MIN_SIZE)
		limit.MaxSize = Vector2.new(MAX_SIZE, MAX_SIZE)
		limit.Parent = b
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.Parent = b
		b.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			pointerHeld[side] = true
			update()
			-- Released anywhere (even after sliding off the button) counts as let go.
			local conn: RBXScriptConnection? = nil
			conn = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					pointerHeld[side] = false
					if conn then
						conn:Disconnect()
					end
					if running then
						update()
					end
				end
			end)
		end)
		b.Parent = parent
		buttons[side] = b
	end

	local keyMap: { [Enum.KeyCode]: string } = {
		[Enum.KeyCode.A] = "left",
		[Enum.KeyCode.Left] = "left",
		[Enum.KeyCode.D] = "right",
		[Enum.KeyCode.Right] = "right",
	}
	local keysDown: { [Enum.KeyCode]: boolean } = {}

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local side = keyMap[input.KeyCode]
		if running and side and not processed and not keysDown[input.KeyCode] then
			keysDown[input.KeyCode] = true
			keyCount[side] += 1
			update()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local side = keyMap[input.KeyCode]
		if side and keysDown[input.KeyCode] then
			keysDown[input.KeyCode] = nil
			keyCount[side] -= 1
			if running then
				update()
			end
		end
	end)

	local self: SteerInput = {} :: any

	self.start = function()
		if running then
			return
		end
		running = true
		generation += 1
		local mine = generation
		pointerHeld.left, pointerHeld.right = false, false
		keyCount.left, keyCount.right = 0, 0
		table.clear(keysDown)
		sent = 0
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "SteerGui"
		newGui.ResetOnSpawn = false
		newGui.IgnoreGuiInset = true
		newGui.DisplayOrder = 5
		newGui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		gui = newGui
		makeButton(newGui, "left", "<", 0)
		makeButton(newGui, "right", ">", 1)
		paint()
		-- Keep the server fresh while a direction is held.
		task.spawn(function()
			while running and generation == mine do
				task.wait(GameConfig.Steer.resendSeconds)
				local v = value()
				if running and generation == mine and v ~= 0 then
					send(v)
				end
			end
		end)
	end

	self.stop = function()
		if not running then
			return
		end
		running = false
		generation += 1
		table.clear(buttons)
		if gui then
			gui:Destroy()
			gui = nil
		end
		sent = 0
		send(0)
	end

	return self
end

return SteerInput
