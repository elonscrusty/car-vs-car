--!strict
-- Driving during the fight: a joystick in the bottom-left corner (touch or mouse) plus WASD and
-- the arrow keys. Up/W = gas, Down/S = reverse, Left/Right (A/D) = steer. Sends two numbers
-- to the server: steer (-1 left .. 1 right) and gas (-1 back .. 1 forward). Sends on every
-- change and re-sends the held values every ~0.1 s, so the server (which treats old values as
-- 0) never keeps driving after a lost release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HudStyle = require(ReplicatedStorage.Shared.HudStyle)

export type SteerInput = {
	start: () -> (),
	stop: () -> (),
	read: () -> (number, number), -- steer, gas right now (for driving the own car on this device)
}

local SteerInput = {}

local MIN_GAP = 0.04 -- seconds between sends while the stick moves (max 25 per second)
local DEADZONE = 0.15 -- share of the radius that does nothing
local RIM_COLOR = Color3.fromRGB(235, 240, 250)
local KNOB_COLOR = Color3.fromRGB(215, 218, 225)

-- Pushes a stick offset (px from the middle) into steer/gas, with a small dead zone and full
-- strength at the edge.
local function stickValue(offset: number, radius: number): number
	local v = math.clamp(offset / radius, -1, 1)
	if math.abs(v) < DEADZONE then
		return 0
	end
	return (v - math.sign(v) * DEADZONE) / (1 - DEADZONE)
end

function SteerInput.new(send: (steer: number, gas: number) -> ()): SteerInput
	local gui: ScreenGui? = nil
	local running = false
	local generation = 0
	local stickSteer, stickGas = 0, 0 -- joystick values
	local keyCount: { [string]: number } = { left = 0, right = 0, up = 0, down = 0 } -- keys down per direction
	local sentSteer, sentGas = 0, 0
	local base: Frame? = nil
	local knob: Frame? = nil
	local activeInput: InputObject? = nil

	local function steerValue(): number
		local keys = (if keyCount.right > 0 then 1 else 0) - (if keyCount.left > 0 then 1 else 0)
		return math.clamp(stickSteer + keys, -1, 1)
	end

	local function gasValue(): number
		local keys = (if keyCount.up > 0 then 1 else 0) - (if keyCount.down > 0 then 1 else 0)
		return math.clamp(stickGas + keys, -1, 1)
	end

	-- Sends when the values changed, at most every MIN_GAP seconds (a moving thumb changes them
	-- 60 times a second, and flooding the server would get the newest ones dropped). The
	-- keep-alive loop below flushes whatever was held back.
	local lastSendAt = 0
	local function update()
		local s, g = steerValue(), gasValue()
		if s ~= sentSteer or g ~= sentGas then
			local now = os.clock()
			if now - lastSendAt >= MIN_GAP or (s == 0 and g == 0) then
				lastSendAt = now
				sentSteer, sentGas = s, g
				send(s, g)
			end
		end
	end

	local function moveKnob(dx: number, dy: number, radius: number)
		local k = knob
		if k then
			local len = math.sqrt(dx * dx + dy * dy)
			if len > radius then
				dx, dy = dx / len * radius, dy / len * radius
			end
			k.Position = UDim2.new(0.5, dx, 0.5, dy)
			k.BackgroundTransparency = if activeInput then 0 else 0.1
		end
	end

	-- Turns a pointer position into stick values.
	local function track(position: Vector3)
		local b = base
		if b == nil then
			return
		end
		local radius = b.AbsoluteSize.X / 2
		local centre = b.AbsolutePosition + b.AbsoluteSize / 2
		local dx, dy = position.X - centre.X, position.Y - centre.Y
		stickSteer = stickValue(dx, radius * 0.85)
		stickGas = -stickValue(dy, radius * 0.85)
		moveKnob(dx, dy, radius * 0.85)
		update()
	end

	local function release()
		activeInput = nil
		stickSteer, stickGas = 0, 0
		moveKnob(0, 0, 1)
		if running then
			update()
		end
	end

	local function makeStick(parent: ScreenGui)
		local camera = workspace.CurrentCamera
		local side = HudStyle.joystickSize(if camera then camera.ViewportSize.Y else 400)
		local b = Instance.new("Frame")
		b.Name = "Stick"
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, HudStyle.EDGE, 1, -HudStyle.EDGE)
		b.Size = UDim2.fromOffset(side, side)
		b.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		b.BackgroundTransparency = 0.4
		b.Active = true
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = RIM_COLOR
		stroke.Transparency = 0.45
		stroke.Parent = b

		-- Four small triangles: up, down, left, right.
		for _, a in
			{ { "▲", 0.5, 0.1 }, { "▼", 0.5, 0.9 }, { "◀", 0.1, 0.5 }, { "▶", 0.9, 0.5 } }
		do
			local arrow = Instance.new("TextLabel")
			arrow.Name = "Arrow"
			arrow.AnchorPoint = Vector2.new(0.5, 0.5)
			arrow.Position = UDim2.fromScale(a[2] :: number, a[3] :: number)
			arrow.Size = UDim2.fromScale(0.16, 0.16)
			arrow.BackgroundTransparency = 1
			arrow.Text = a[1] :: string
			arrow.TextScaled = true
			arrow.Font = Enum.Font.FredokaOne
			arrow.TextColor3 = RIM_COLOR
			arrow.TextTransparency = 0.25
			arrow.Parent = b
		end

		local k = Instance.new("Frame")
		k.Name = "Knob"
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Position = UDim2.fromScale(0.5, 0.5)
		k.Size = UDim2.fromScale(0.42, 0.42)
		k.BackgroundColor3 = KNOB_COLOR
		k.BackgroundTransparency = 0.1
		local kr = Instance.new("UICorner")
		kr.CornerRadius = UDim.new(0.5, 0)
		kr.Parent = k
		local ks = Instance.new("UIStroke")
		ks.Color = Color3.fromRGB(255, 255, 255)
		ks.Thickness = 2
		ks.Transparency = 0.3
		ks.Parent = k
		k.Parent = b

		b.InputBegan:Connect(function(input: InputObject)
			if
				activeInput == nil
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				activeInput = input
				track(input.Position)
			end
		end)
		b.Parent = parent
		base, knob = b, k
	end

	-- Follow the finger/mouse that grabbed the stick, even when it slides off the circle.
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if running and activeInput ~= nil then
			if
				input == activeInput
				or (
					input.UserInputType == Enum.UserInputType.MouseMovement
					and activeInput.UserInputType == Enum.UserInputType.MouseButton1
				)
			then
				track(input.Position)
			end
		end
	end)

	local keyMap: { [Enum.KeyCode]: string } = {
		[Enum.KeyCode.A] = "left",
		[Enum.KeyCode.Left] = "left",
		[Enum.KeyCode.D] = "right",
		[Enum.KeyCode.Right] = "right",
		[Enum.KeyCode.W] = "up",
		[Enum.KeyCode.Up] = "up",
		[Enum.KeyCode.S] = "down",
		[Enum.KeyCode.Down] = "down",
	}
	local keysDown: { [Enum.KeyCode]: boolean } = {}

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local dir = keyMap[input.KeyCode]
		if running and dir and not processed and not keysDown[input.KeyCode] then
			keysDown[input.KeyCode] = true
			keyCount[dir] += 1
			update()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if activeInput ~= nil and input == activeInput then
			release()
		end
		local dir = keyMap[input.KeyCode]
		if dir and keysDown[input.KeyCode] then
			keysDown[input.KeyCode] = nil
			keyCount[dir] -= 1
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
		stickSteer, stickGas = 0, 0
		activeInput = nil
		for dir in keyCount do
			keyCount[dir] = 0
		end
		table.clear(keysDown)
		sentSteer, sentGas = 0, 0
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "SteerGui"
		newGui.ResetOnSpawn = false
		newGui.IgnoreGuiInset = true
		newGui.DisplayOrder = 5
		newGui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		gui = newGui
		makeStick(newGui)
		-- Keep the server fresh while something is held.
		task.spawn(function()
			while running and generation == mine do
				task.wait(MIN_GAP)
				local s, g = steerValue(), gasValue()
				local now = os.clock()
				if running and generation == mine then
					local changed = s ~= sentSteer or g ~= sentGas
					local stale = (s ~= 0 or g ~= 0)
						and now - lastSendAt >= GameConfig.Steer.resendSeconds
					if changed or stale then
						lastSendAt = now
						sentSteer, sentGas = s, g
						send(s, g)
					end
				end
			end
		end)
	end

	self.read = function()
		return steerValue(), gasValue()
	end

	self.stop = function()
		if not running then
			return
		end
		running = false
		generation += 1
		base, knob, activeInput = nil, nil, nil
		if gui then
			gui:Destroy()
			gui = nil
		end
		sentSteer, sentGas = 0, 0
		send(0, 0)
	end

	return self
end

return SteerInput
