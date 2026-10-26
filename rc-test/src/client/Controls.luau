--!strict
-- Reads the player's hands: keyboard, game pad, and on a phone a steering stick on the left
-- plus gas, brake and drift buttons on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local RCCar = require(script.Parent.RCCar)
local StageGate = require(script.Parent.StageGate)

export type Controls = {
	read: () -> RCCar.Input,
	setRock: (on: boolean) -> (),
	setRace: (on: boolean) -> (), -- server race: fewer buttons (SMOKE, CAM and VIEW hide)
}

local Controls = {}

local STICK_RADIUS = 80
local DEADZONE = 0.08

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- A round button that stays "held" while a finger is on it.
local function holdButton(
	gui: ScreenGui,
	text: string,
	anchor: Vector2,
	pos: UDim2,
	heightScale: number,
	color: Color3
): () -> boolean
	local held = false
	local f = Instance.new("Frame")
	f.Name = text
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = UDim2.fromScale(heightScale, heightScale)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.35
	f.Active = true
	f.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = f
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.Text = text
	l.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = l

	f.InputBegan:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end
		held = true
		f.BackgroundTransparency = 0.05
		local conn: RBXScriptConnection
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				held = false
				f.BackgroundTransparency = 0.35
				conn:Disconnect()
			end
		end)
	end)
	return function()
		return held
	end
end

function Controls.new(
	gui: ScreenGui,
	onReset: () -> (),
	onCam: () -> (),
	onView: () -> (),
	onSmoke: () -> (),
	onAutoGas: (on: boolean) -> ()
): Controls
	local keys: { [Enum.KeyCode]: boolean } = {}
	local padSteer, padGas, padBrake = 0, 0, 0
	local touchSteer = 0
	local touchUi = UserInputService.TouchEnabled

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keys[input.KeyCode] = true
			if input.KeyCode == Enum.KeyCode.R then
				onReset()
			elseif input.KeyCode == Enum.KeyCode.C then
				onCam()
			elseif input.KeyCode == Enum.KeyCode.V then
				onView()
			elseif input.KeyCode == Enum.KeyCode.K then
				onSmoke()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonY then
			onReset()
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			keys[Enum.KeyCode.ButtonA] = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Keyboard
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			keys[input.KeyCode] = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			padSteer = if math.abs(input.Position.X) > 0.1 then input.Position.X else 0
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			padGas = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			padBrake = input.Position.Z
		end
	end)

	-- Phone controls
	local gas = function(): boolean
		return false
	end
	local brake = gas
	local drift = gas
	if touchUi then
		-- steering zone: left half, the stick appears where the thumb lands
		local zone = Instance.new("Frame")
		zone.Name = "SteerZone"
		zone.BackgroundTransparency = 1
		zone.Active = true
		zone.Position = UDim2.fromScale(0, 0.2)
		zone.Size = UDim2.fromScale(0.5, 0.8)
		zone.Parent = gui

		local base = Instance.new("Frame")
		base.Name = "StickBase"
		base.AnchorPoint = Vector2.new(0.5, 0.5)
		base.Size = UDim2.fromOffset(STICK_RADIUS * 2, STICK_RADIUS * 2)
		base.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		base.BackgroundTransparency = 0.75
		base.Visible = false
		base.Parent = gui
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = base
		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Size = UDim2.fromOffset(70, 70)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BackgroundTransparency = 0.2
		knob.Parent = base
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(0.5, 0)
		kc.Parent = knob

		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.fromScale(0.22, 0.93)
		hint.Size = UDim2.fromScale(0.3, 0.08)
		hint.Font = Enum.Font.GothamBold
		hint.TextScaled = true
		hint.TextColor3 = Color3.fromRGB(255, 255, 255)
		hint.TextTransparency = 0.45
		hint.Text = "◄  STEER  ►"
		hint.Parent = gui

		zone.InputBegan:Connect(function(input: InputObject)
			if not isPress(input) then
				return
			end
			local origin = input.Position
			base.Position = UDim2.fromOffset(origin.X, origin.Y)
			base.Visible = true
			hint.Visible = false
			local conn: RBXScriptConnection
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					touchSteer = 0
					base.Visible = false
					hint.Visible = true
					knob.Position = UDim2.fromScale(0.5, 0.5)
					conn:Disconnect()
					return
				end
				local dx = input.Position.X - origin.X
				local x = math.clamp(dx / STICK_RADIUS, -1, 1)
				knob.Position =
					UDim2.fromOffset(STICK_RADIUS + x * STICK_RADIUS * 0.8, STICK_RADIUS)
				if math.abs(x) < DEADZONE then
					touchSteer = 0
				else
					touchSteer = math.sign(x) * math.abs(x) ^ 1.2
				end
			end)
		end)

		gas = holdButton(
			gui,
			"GAS",
			Vector2.new(1, 1),
			UDim2.fromScale(0.97, 0.95),
			0.34,
			Color3.fromRGB(60, 190, 90)
		)
		brake = holdButton(
			gui,
			"BRAKE",
			Vector2.new(1, 1),
			UDim2.fromScale(0.76, 0.95),
			0.22,
			Color3.fromRGB(215, 70, 70)
		)
		drift = holdButton(
			gui,
			"DRIFT",
			Vector2.new(1, 1),
			UDim2.fromScale(0.97, 0.58),
			0.22,
			Color3.fromRGB(70, 130, 235)
		)
		-- BRAKE sits just left of GAS on every screen (GAS is 0.34 of the height wide, so on a
		-- 4:3 tablet a fixed 0.76 would push them together). See HudLayout "Brake".
		local brakePad = gui:FindFirstChild("BRAKE") :: Frame
		local function fitBrake()
			brakePad.Position =
				UDim2.new(0.97, -math.floor(gui.AbsoluteSize.Y * 0.34 + 12), 0.95, 0)
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBrake)
		fitBrake()
	end

	-- Right side: a row of small CAM / VIEW buttons below the Roblox top bar (58 px) and above
	-- the DRIFT button. No reset button: the car resets by itself when it falls off (R still
	-- works on a keyboard).
	local resetBtn = Instance.new("TextButton") -- template for the small buttons
	resetBtn.AnchorPoint = Vector2.new(1, 0)
	resetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	resetBtn.BackgroundTransparency = 0.25
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextScaled = true
	resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	-- the same word size on all four (SMOKE was tiny next to a big VIEW), a little inside the edge
	local btnText = Instance.new("UITextSizeConstraint")
	btnText.MaxTextSize = 16
	btnText.Parent = resetBtn
	local btnPad = Instance.new("UIPadding")
	btnPad.PaddingLeft = UDim.new(0, 3)
	btnPad.PaddingRight = UDim.new(0, 3)
	btnPad.Parent = resetBtn
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.3, 0)
	rc.Parent = resetBtn

	local camBtn = resetBtn:Clone()
	camBtn.Name = "Cam"
	camBtn.Text = "CAM"
	HudLayout.place(camBtn, "Cam", "drive") -- thumb size on a phone (44+ px tall)
	camBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	camBtn.Parent = gui
	camBtn.Activated:Connect(onCam)
	-- (CAM, VIEW, SMOKE and the key line wait for the first lap: JoinStage "carbuttons")
	StageGate.hold(camBtn, "carbuttons")

	local viewBtn = resetBtn:Clone()
	viewBtn.Name = "View"
	viewBtn.Text = "VIEW"
	HudLayout.place(viewBtn, "View", "drive")
	viewBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	viewBtn.Parent = gui
	viewBtn.Activated:Connect(onView)
	StageGate.hold(viewBtn, "carbuttons")

	-- tyre smoke colour (looks only); not on rocks, which hardly slide
	local smokeBtn = resetBtn:Clone()
	smokeBtn.Name = "Smoke"
	smokeBtn.Text = "SMOKE"
	HudLayout.place(smokeBtn, "Smoke", "drive")
	smokeBtn.Parent = gui
	StageGate.hold(smokeBtn, "carbuttons")
	smokeBtn.Activated:Connect(function()
		onSmoke()
	end)

	-- rocks only: a RESET button (where CAM sits elsewhere) that puts the car back a bit
	local backBtn = resetBtn:Clone()
	backBtn.Name = "Reset"
	backBtn.Text = "RESET"
	HudLayout.place(backBtn, "Cam", "drive")
	backBtn.Visible = false
	backBtn.Parent = gui
	backBtn.Activated:Connect(function()
		onReset()
	end)

	-- phones on rocks: there is no drifting, so a big RESET takes the DRIFT button's spot, and a
	-- faint label shows where a thumb can drag to look around (open screen, not on a button)
	local driftBtn = gui:FindFirstChild("DRIFT") :: GuiObject?
	local bigReset: TextButton? = nil
	local lookHint: TextLabel? = nil
	if touchUi then
		local b = Instance.new("TextButton")
		b.Name = "BigReset"
		b.Text = "RESET"
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.fromScale(0.97, 0.58)
		b.Size = UDim2.fromScale(0.22, 0.22)
		b.BackgroundColor3 = Color3.fromRGB(235, 150, 40)
		b.BackgroundTransparency = 0.25
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Visible = false
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = b
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.32, 0)
		pad.PaddingBottom = UDim.new(0.32, 0)
		pad.PaddingLeft = UDim.new(0.1, 0)
		pad.PaddingRight = UDim.new(0.1, 0)
		pad.Parent = b
		b.Parent = gui
		b.Activated:Connect(function()
			onReset()
		end)
		bigReset = b

		local l = Instance.new("TextLabel")
		l.Name = "LookHint"
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.62, 0.4)
		l.Size = UDim2.fromScale(0.2, 0.06)
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(255, 255, 255)
		l.TextTransparency = 0.5
		l.Text = "◄  DRAG TO LOOK  ►"
		l.Visible = false
		l.Parent = gui
		lookHint = l
	end

	local help: TextLabel? = nil
	if not touchUi then
		help = Instance.new("TextLabel")
		assert(help)
		help.BackgroundTransparency = 1
		help.AnchorPoint = Vector2.new(0.5, 1)
		help.Position = UDim2.fromScale(0.5, 0.985)
		help.Size = UDim2.fromScale(0.6, 0.035)
		help.Font = Enum.Font.GothamBold
		help.TextScaled = true
		help.TextColor3 = Color3.fromRGB(255, 255, 255)
		help.TextTransparency = 0.35
		help.Text =
			"W/S gas + brake    A/D steer    SPACE drift    C show cam    V chase cam    K smoke    G auto gas    E walk"
		help.Parent = gui
		StageGate.hold(help, "carbuttons")
	end

	-- AUTO GAS: the car keeps the gas down by itself (brake still brakes and backs up), so a
	-- phone player only steers. Input only: the car's numbers don't change. Not on rocks.
	local autoGas = false
	local autoBtn = resetBtn:Clone()
	autoBtn.Name = "AutoGas"
	autoBtn.Text = "AUTO GAS"
	HudLayout.place(autoBtn, "AutoGas", "drive")
	autoBtn.Parent = gui
	local onRockNow = false
	local function setAuto(on: boolean)
		autoGas = on
		autoBtn.BackgroundColor3 = if on
			then Color3.fromRGB(60, 190, 90)
			else Color3.fromRGB(40, 40, 46)
	end
	local function toggleAuto()
		if onRockNow then
			return
		end
		setAuto(not autoGas)
		onAutoGas(autoGas)
	end
	autoBtn.Activated:Connect(toggleAuto)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			toggleAuto()
		end
	end)

	local controls = {} :: Controls
	local NORMAL_HELP =
		"W/S gas + brake    A/D steer    SPACE drift    C show cam    V chase cam    K smoke    G auto gas    E walk"
	local ROCK_HELP =
		"W/S gas + brake    A/D steer    drag to look    wheel to zoom    R back to flag    E walk"
	local onRock: boolean? = nil
	local inRace = false
	-- the PC key line shows for a few seconds each time things change, then gets out of the way
	local helpShown = 0
	local function flashHelp()
		helpShown += 1
		local me = helpShown
		if help then
			help.Visible = true
		end
		task.delay(12, function()
			if me == helpShown and help then
				help.Visible = false
			end
		end)
	end
	-- rocks is free cam only: no camera buttons, and the help says how to look around
	function controls.setRock(on: boolean)
		if on == onRock then
			return
		end
		onRock = on
		-- CAM and VIEW do nothing there, so hide both and close the gap
		viewBtn.Visible = not on
		onRockNow = on
		autoBtn.Visible = not on
		smokeBtn.Visible = not on and not inRace
		camBtn.Visible = not on and not inRace
		backBtn.Visible = on and not touchUi
		if driftBtn then
			driftBtn.Visible = not on
		end
		if bigReset then
			bigReset.Visible = on
		end
		if lookHint then
			lookHint.Visible = on
		end
		if help then
			help.Text = if on then ROCK_HELP else NORMAL_HELP
		end
		flashHelp()
	end
	function controls.setRace(on: boolean)
		if on == inRace then
			return
		end
		inRace = on
		smokeBtn.Visible = not on and not onRockNow
		camBtn.Visible = not on and not onRockNow
		viewBtn.Visible = not on -- the race picks the chase view; just place, lap, gas and steer
	end
	function controls.read(): RCCar.Input
		local function down(code: Enum.KeyCode): boolean
			return keys[code] == true
		end
		local steer = 0
		if down(Enum.KeyCode.D) or down(Enum.KeyCode.Right) then
			steer += 1
		end
		if down(Enum.KeyCode.A) or down(Enum.KeyCode.Left) then
			steer -= 1
		end
		if steer == 0 then
			steer = if touchSteer ~= 0 then touchSteer else padSteer
		end
		local throttle = if down(Enum.KeyCode.W)
				or down(Enum.KeyCode.Up)
				or gas()
			then 1
			else padGas
		local brakeIn = if down(Enum.KeyCode.S)
				or down(Enum.KeyCode.Down)
				or brake()
			then 1
			else padBrake
		if autoGas and not onRockNow then
			-- gas down unless braking (the car only brakes or backs up with the gas off)
			throttle = if brakeIn > 0 then 0 else 1
		end
		local driftIn = down(Enum.KeyCode.Space)
			or down(Enum.KeyCode.LeftShift)
			or down(Enum.KeyCode.ButtonA)
			or drift()
		return { steer = steer, throttle = throttle, brake = brakeIn, drift = driftIn }
	end
	return controls
end

return Controls
