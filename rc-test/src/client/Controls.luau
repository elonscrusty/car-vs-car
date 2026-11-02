--!strict
-- Reads the player's hands: keyboard, game pad, and on a phone a steering stick on the left
-- plus gas, brake and drift buttons on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local RCCar = require(script.Parent.RCCar)
local StageGate = require(script.Parent.StageGate)

export type Controls = {
	read: () -> RCCar.Input,
	setRock: (on: boolean) -> (),
	setRace: (on: boolean) -> (), -- server race: fewer buttons (SMOKE, CAM and VIEW hide)
	autoOff: () -> (), -- AUTO GAS off (each race's grid, each put-back)
}

local Controls = {}

local STICK_RADIUS = 80
local KNOB_TRAVEL = STICK_RADIUS - 38 - 6 -- (the knob is 76 across; the ring's rim)
local DEADZONE = 0.05
-- the touch stick reaches full lock at this part of its ring: small thumb moves steer (input only)
local STEER_REACH = 0.7
-- SMASH on a phone: the stick is the gas too (Lead 10-28: "joystick + fire only"). Push up to
-- go, pull down to brake and back up. Input only: the car's numbers don't change.
local GAS_START, GAS_FULL = 0.1, 0.55 -- (stick up this far: gas starts, gas is full)
local BRAKE_START, BRAKE_FULL = 0.3, 0.8 -- (a bit more pull: a sideways drag never brakes)

local function ramp(v: number, start: number, full: number): number
	return math.clamp((v - start) / (full - start), 0, 1)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- ===== the chunky look (carter picked "A Kit Chunky" 10-29: dark ring, arrows, glossy blue ball) =====
-- Looks only: every number above (radius, dead zone, gas and brake ramps) is untouched.
local INK = Color3.fromRGB(13, 44, 64)
local FONT = Enum.Font.Oswald -- big words (UiFonts.TITLE)

local function stroke(obj: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or INK
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	return s
end

local function round(obj: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = obj
end

local function gradient(obj: Instance, a: Color3, b: Color3, c: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.4, b),
		ColorSequenceKeypoint.new(1, c),
	})
	g.Rotation = 90
	g.Parent = obj
end

-- a white shine band on the top of a round face
local function gloss(parent: GuiObject)
	local g = Instance.new("Frame")
	g.Name = "Gloss"
	g.AnchorPoint = Vector2.new(0.5, 0)
	g.Position = UDim2.fromScale(0.5, 0.07)
	g.Size = UDim2.fromScale(0.64, 0.3)
	g.BackgroundColor3 = Color3.new(1, 1, 1)
	g.BackgroundTransparency = 0.55
	g.BorderSizePixel = 0
	g.Parent = parent
	round(g)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0, 1)
	fade.Parent = g
end

local KNOB_SIZE = 76
local ARROWS: { { glyph: string, at: UDim2, color: Color3 } } = {
	{ glyph = "▲", at = UDim2.fromScale(0.5, 0.1), color = Color3.fromRGB(139, 232, 28) }, -- push = gas
	{ glyph = "▼", at = UDim2.fromScale(0.5, 0.9), color = Color3.fromRGB(255, 106, 106) }, -- pull = brake
	{ glyph = "◀", at = UDim2.fromScale(0.09, 0.5), color = Color3.new(1, 1, 1) },
	{ glyph = "▶", at = UDim2.fromScale(0.91, 0.5), color = Color3.new(1, 1, 1) },
}

-- the ring + ball. `ghost` is the see-through copy that waits bottom left until a thumb lands.
local function makeStick(parent: Instance, ghost: boolean): (GuiObject, Frame)
	local base: GuiObject
	if ghost then
		local cg = Instance.new("CanvasGroup")
		cg.GroupTransparency = 0.4
		base = cg
	else
		base = Instance.new("Frame")
	end
	base.Name = if ghost then "StickGhost" else "StickBase"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Size = UDim2.fromOffset(STICK_RADIUS * 2, STICK_RADIUS * 2)
	base.BackgroundColor3 = Color3.fromRGB(19, 48, 74)
	base.BackgroundTransparency = 0
	base.Parent = parent
	round(base)
	stroke(base, 5)
	-- the thin light rim just inside the dark edge
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.new(1, -10, 1, -10)
	rim.BackgroundTransparency = 1
	rim.Parent = base
	round(rim)
	stroke(rim, 3, Color3.fromRGB(143, 216, 255)).Transparency = 0.45
	for _, a in ARROWS do
		local l = Instance.new("TextLabel")
		l.Name = "Arrow"
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = a.at
		l.Size = UDim2.fromOffset(26, 26)
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.Text = a.glyph
		l.TextSize = 22
		l.TextColor3 = a.color
		l.Parent = base
		stroke(l, 3)
	end
	-- the ball: a deep blue base, a light-to-dark blue face, a shine
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = base
	round(knob)
	stroke(knob, 4)
	gradient(
		knob,
		Color3.fromRGB(196, 236, 255),
		Color3.fromRGB(63, 184, 255),
		Color3.fromRGB(28, 132, 234)
	)
	gloss(knob)
	return base, knob
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
	-- solid: see-through they vanished over the yellow boost pads (carter's phone 10-28); a press
	-- shows as a lighter face
	f.BackgroundTransparency = 0
	f.Active = true
	f.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = f
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	-- chunky look (carter's kit): ink edge, a darker bottom, a shine, the word stroked in ink
	stroke(f, 4)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shade.Rotation = 90
	shade.Parent = f
	gloss(f)
	local squash = Instance.new("UIScale")
	squash.Parent = f
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.Text = text
	l.Parent = f
	stroke(l, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = l

	f.InputBegan:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end
		held = true
		f.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
		squash.Scale = 0.94 -- (the kit: squash in 0.05 s, spring back)
		local conn: RBXScriptConnection
		conn = input.Changed:Connect(function()
			if
				input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel
			then
				held = false
				f.BackgroundColor3 = color
				TweenService:Create(
					squash,
					TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
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
	local touchGas, touchBrake = 0, 0
	local touchUi = UserInputService.TouchEnabled
	local stickGas = touchUi and (Features :: any).SMASH == true

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

		local base, knob = makeStick(gui, false)
		base.Visible = false
		-- waits bottom left (the kit keeps that corner clear) until a thumb lands
		local ghost = makeStick(gui, true)
		ghost.Position = UDim2.new(0, 44 + STICK_RADIUS + 18, 1, -(24 + STICK_RADIUS + 6))

		local hint = Instance.new("TextLabel")
		hint.Name = "StickHint"
		hint.BackgroundTransparency = 1
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.new(0, 44 + STICK_RADIUS + 18, 1, -(24 + STICK_RADIUS * 2 + 12))
		hint.Size = UDim2.fromOffset(200, 22)
		hint.Font = Enum.Font.Roboto
		hint.TextSize = 14
		hint.TextTransparency = 0.35
		hint.TextColor3 = Color3.new(1, 1, 1)
		hint.Text = if stickGas then "PUSH TO DRIVE" else "STEER"
		hint.Parent = gui
		stroke(hint, 3)

		-- one finger drives the stick; a second one in the zone is ignored until it lets go
		local active: InputObject? = nil
		local stickConn: RBXScriptConnection? = nil
		local function letGo()
			if stickConn then
				stickConn:Disconnect()
				stickConn = nil
			end
			active = nil
			touchSteer = 0
			touchGas, touchBrake = 0, 0
			base.Visible = false
			hint.Visible = true
			ghost.Visible = true
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
		-- (a touch the phone takes away ends as Cancel, not End: the gas must not stay down)
		UserInputService.WindowFocusReleased:Connect(letGo)
		zone.InputBegan:Connect(function(input: InputObject)
			if not isPress(input) or active then
				return
			end
			active = input
			local origin = input.Position
			if stickGas then
				-- room below the thumb to pull down and brake (BRAKE_FULL of the ring)
				origin = Vector3.new(
					origin.X,
					math.min(origin.Y, gui.AbsoluteSize.Y - STICK_RADIUS * BRAKE_FULL),
					0
				)
			end
			base.Position = UDim2.fromOffset(origin.X, origin.Y)
			base.Visible = true
			hint.Visible = false
			ghost.Visible = false
			stickConn = input.Changed:Connect(function()
				if
					input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel
				then
					letGo()
					return
				end
				local dx = input.Position.X - origin.X
				local x = math.clamp(dx / STICK_RADIUS, -1, 1)
				-- (the knob stays inside its ring: it went half out at full lock, phone 10-28)
				knob.Position = UDim2.fromOffset(STICK_RADIUS + x * KNOB_TRAVEL, STICK_RADIUS)
				if stickGas then
					local y = math.clamp((origin.Y - input.Position.Y) / STICK_RADIUS, -1, 1)
					local v = Vector2.new(x, -y)
					local k = if v.Magnitude > 1 then v.Unit else v
					knob.Position = UDim2.fromOffset(
						STICK_RADIUS + k.X * KNOB_TRAVEL,
						STICK_RADIUS + k.Y * KNOB_TRAVEL
					)
					touchGas = ramp(y, GAS_START, GAS_FULL)
					touchBrake = ramp(-y, BRAKE_START, BRAKE_FULL)
				end
				local sx = math.clamp(dx / (STICK_RADIUS * STEER_REACH), -1, 1)
				if math.abs(sx) < DEADZONE then
					touchSteer = 0
				else
					touchSteer = math.sign(sx) * math.abs(sx) ^ 1.2
				end
			end)
		end)
	end
	-- DRIFT stays in SMASH too (carter: drifting is part of the game), above FIRE at the right edge
	if touchUi then
		drift = holdButton(
			gui,
			"DRIFT",
			Vector2.new(1, 1),
			-- (lower in SMASH: at 0.58 the kill list's bottom edge covered its top; FIRE is below)
			UDim2.fromScale(0.97, if stickGas then 0.54 else 0.58),
			0.22,
			Color3.fromRGB(70, 130, 235)
		)
	end
	if touchUi and not stickGas then
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
	resetBtn.Font = Enum.Font.Oswald
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
		b.Font = Enum.Font.Oswald
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
		l.Font = Enum.Font.Oswald
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
		help.Font = Enum.Font.Roboto
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
	-- (not in SMASH at all: the stick is a phone's gas, W a computer's; Audit F12)
	local smash = (Features :: any).SMASH == true
	autoBtn.Visible = not smash
	-- alone (SMOKE, VIEW and CAM held back for a new player) it takes CAM's spot at the right edge:
	-- at its own spot it stood alone in the middle of a wide screen, over the track signs (Studio
	-- batch-2035 6)
	StageGate.watch(function()
		HudLayout.place(
			autoBtn,
			if StageGate.shows("carbuttons") then "AutoGas" else "Cam",
			"drive"
		)
	end)
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
		autoBtn.Visible = not on and not smash
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
	-- (not on setRace: it only runs on a change, and between races Main's render step stops
	-- calling it while you walk, so the next race never saw one; critic run 2)
	function controls.autoOff()
		setAuto(false)
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
			else math.max(padGas, touchGas)
		local brakeIn = if down(Enum.KeyCode.S)
				or down(Enum.KeyCode.Down)
				or brake()
			then 1
			else math.max(padBrake, touchBrake)
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
