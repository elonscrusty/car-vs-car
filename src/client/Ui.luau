--!strict
-- All on-screen UI, built in code (no assets). Big buttons so it works on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)

local Ui = {}

export type Handlers = {
	onPick: (carId: string) -> (),
	onConfirm: () -> (), -- LAUNCH / tap button
	onAimHold: (dir: number) -> (), -- -1 right, 0 stop, +1 left
	onBoost: () -> (),
}

export type View = {
	showPick: () -> (),
	showAim: (
		youHearts: number,
		enemyHearts: number,
		round: number,
		youCar: string,
		enemyCar: string
	) -> (),
	showPower: (power: number) -> (),
	showFight: () -> (),
	showRoundEnd: (youLost: boolean, youHearts: number, enemyHearts: number) -> (),
	showMatchEnd: (youWon: boolean) -> (),
	startBoostCooldown: (seconds: number) -> (),
}

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	return l
end

local function button(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3
): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = b
	return b
end

local function hearts(n: number): string
	return string.rep("♥", n) .. string.rep("♡", math.max(0, 3 - n))
end

function Ui.create(h: Handlers): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "CarVsCarUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Pick screen
	local pick = Instance.new("Frame")
	pick.Size = UDim2.fromScale(1, 1)
	pick.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
	pick.BackgroundTransparency = 0.25
	pick.Parent = gui
	label(pick, "PICK YOUR CAR", UDim2.fromScale(0.6, 0.15), UDim2.fromScale(0.2, 0.08))
	for i, id in CarConfig.Order do
		local stats = CarConfig.Cars[id]
		local color = Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
		local b = button(
			pick,
			stats.name,
			UDim2.fromScale(0.21, 0.5),
			UDim2.fromScale(0.04 + (i - 1) * 0.235, 0.3),
			color
		)
		local sub = label(b, stats.blurb, UDim2.fromScale(0.9, 0.25), UDim2.fromScale(0.05, 0.7))
		sub.Font = Enum.Font.GothamBold
		b.Activated:Connect(function()
			h.onPick(id)
		end)
	end

	-- Top bar
	local top = label(gui, "", UDim2.fromScale(0.7, 0.08), UDim2.fromScale(0.15, 0.02))
	top.Visible = false

	-- Center message
	local msg = label(gui, "", UDim2.fromScale(0.7, 0.14), UDim2.fromScale(0.15, 0.22))
	msg.Visible = false

	-- Aim controls
	local aimFrame = Instance.new("Frame")
	aimFrame.Size = UDim2.fromScale(1, 1)
	aimFrame.BackgroundTransparency = 1
	aimFrame.Visible = false
	aimFrame.Parent = gui
	local leftB = button(
		aimFrame,
		"◀",
		UDim2.fromScale(0.14, 0.2),
		UDim2.fromScale(0.03, 0.74),
		Color3.fromRGB(60, 90, 160)
	)
	local rightB = button(
		aimFrame,
		"▶",
		UDim2.fromScale(0.14, 0.2),
		UDim2.fromScale(0.19, 0.74),
		Color3.fromRGB(60, 90, 160)
	)
	local goB = button(
		aimFrame,
		"LOCK AIM",
		UDim2.fromScale(0.26, 0.2),
		UDim2.fromScale(0.7, 0.74),
		Color3.fromRGB(230, 90, 40)
	)
	local hint = label(
		aimFrame,
		"A / D or arrows to aim",
		UDim2.fromScale(0.5, 0.06),
		UDim2.fromScale(0.25, 0.88)
	)
	hint.Font = Enum.Font.GothamBold

	local function hold(b: TextButton, dir: number)
		b.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				h.onAimHold(dir)
			end
		end)
		b.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				h.onAimHold(0)
			end
		end)
	end
	hold(leftB, 1)
	hold(rightB, -1)
	goB.Activated:Connect(h.onConfirm)

	-- Power bar
	local powerBack = Instance.new("Frame")
	powerBack.Size = UDim2.fromScale(0.5, 0.06)
	powerBack.Position = UDim2.fromScale(0.25, 0.8)
	powerBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	powerBack.Visible = false
	powerBack.Parent = gui
	local powerFill = Instance.new("Frame")
	powerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	powerFill.BorderSizePixel = 0
	powerFill.Size = UDim2.fromScale(0, 1)
	powerFill.Parent = powerBack

	-- Boost button + cooldown bar (fight only)
	local boostB = button(
		gui,
		"BOOST",
		UDim2.fromScale(0.24, 0.2),
		UDim2.fromScale(0.72, 0.74),
		Color3.fromRGB(255, 150, 20)
	)
	boostB.Visible = false
	local boostBar = Instance.new("Frame")
	boostBar.AnchorPoint = Vector2.new(0, 1)
	boostBar.Size = UDim2.fromScale(1, 0.14)
	boostBar.Position = UDim2.fromScale(0, 1)
	boostBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	boostBar.BackgroundTransparency = 0.3
	boostBar.BorderSizePixel = 0
	boostBar.Parent = boostB
	local boostFill = Instance.new("Frame")
	boostFill.Size = UDim2.fromScale(1, 1)
	boostFill.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
	boostFill.BorderSizePixel = 0
	boostFill.Parent = boostBar
	local boostToken = 0
	boostB.Activated:Connect(h.onBoost)

	-- End screen
	local endFrame = Instance.new("Frame")
	endFrame.Size = UDim2.fromScale(1, 1)
	endFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	endFrame.BackgroundTransparency = 0.45
	endFrame.Visible = false
	endFrame.Parent = gui
	local endText = label(endFrame, "", UDim2.fromScale(0.8, 0.3), UDim2.fromScale(0.1, 0.2))
	local again = button(
		endFrame,
		"PLAY AGAIN",
		UDim2.fromScale(0.36, 0.2),
		UDim2.fromScale(0.32, 0.6),
		Color3.fromRGB(60, 190, 90)
	)

	local function hideAll()
		pick.Visible = false
		aimFrame.Visible = false
		powerBack.Visible = false
		endFrame.Visible = false
		msg.Visible = false
		boostB.Visible = false
	end

	local view: View = {} :: any

	view.showPick = function()
		hideAll()
		top.Visible = false
		pick.Visible = true
	end

	view.showAim = function(youHearts, enemyHearts, round, youCar, enemyCar)
		hideAll()
		top.Visible = true
		top.Text = `YOU {hearts(youHearts)}  vs  {hearts(enemyHearts)} BOT   (round {round})`
		msg.Visible = true
		msg.Text = `{youCar} vs {enemyCar}`
		aimFrame.Visible = true
		goB.Text = "LOCK AIM"
		hint.Text = "A / D or arrows to aim"
	end

	view.showPower = function(power)
		powerBack.Visible = true
		powerFill.Size = UDim2.fromScale(power, 1)
		goB.Text = "LAUNCH!"
		hint.Text = "Tap / click / space to launch"
	end

	view.showFight = function()
		hideAll()
		msg.Visible = true
		msg.Text = "FIGHT!"
		boostB.Visible = true
		boostToken += 1
		boostFill.Size = UDim2.fromScale(1, 1)
		boostFill.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
		task.delay(1, function()
			if msg.Text == "FIGHT!" then
				msg.Visible = false
			end
		end)
	end

	view.startBoostCooldown = function(seconds)
		boostToken += 1
		local token = boostToken
		boostFill.BackgroundColor3 = Color3.fromRGB(255, 90, 60)
		boostFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(
			boostFill,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 1) }
		):Play()
		task.delay(seconds, function()
			if token == boostToken then
				boostFill.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
			end
		end)
	end

	view.showRoundEnd = function(youLost, youHearts, enemyHearts)
		top.Text = `YOU {hearts(youHearts)}  vs  {hearts(enemyHearts)} BOT`
		msg.Visible = true
		msg.Text = if youLost then "ROUND LOST" else "ROUND WON!"
		boostB.Visible = false
	end

	view.showMatchEnd = function(youWon)
		hideAll()
		endFrame.Visible = true
		endText.Text = if youWon then "YOU WIN" else "YOU LOSE"
		endText.TextColor3 = if youWon
			then Color3.fromRGB(120, 255, 140)
			else Color3.fromRGB(255, 100, 100)
	end

	again.Activated:Connect(function()
		view.showPick()
	end)

	view.showPick()
	return view
end

return Ui
