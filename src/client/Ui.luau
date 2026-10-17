--!strict
-- All on-screen UI, built in code (no assets). Big buttons so it works on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)

local Ui = {}

export type Handlers = {
	onPick: (carId: string) -> (),
}

export type View = {
	showPick: () -> (),
	showAim: (
		round: number,
		youCar: string,
		enemyCar: string,
		seconds: number,
		enemyName: string
	) -> (),
	showWaiting: () -> (),
	showPower: (power: number) -> (),
	showFight: () -> (),
	showRoundEnd: (youLost: boolean) -> (),
	showMatchEnd: (youWon: boolean) -> (),
	hideMatch: () -> (), -- back to lobby: hide every match screen
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

	-- Aim hint (the aiming itself is a drag on the screen, see AimInput)
	local aimFrame = Instance.new("Frame")
	aimFrame.Size = UDim2.fromScale(1, 1)
	aimFrame.BackgroundTransparency = 1
	aimFrame.Visible = false
	aimFrame.Parent = gui
	local hint = label(aimFrame, "", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.2, 0.88))
	hint.Font = Enum.Font.GothamBold

	-- Power bar
	local powerBack = Instance.new("Frame")
	powerBack.Size = UDim2.fromScale(0.5, 0.04)
	powerBack.Position = UDim2.fromScale(0.25, 0.82)
	powerBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	powerBack.Visible = false
	powerBack.Parent = gui
	local powerFill = Instance.new("Frame")
	powerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	powerFill.BorderSizePixel = 0
	powerFill.Size = UDim2.fromScale(0, 1)
	powerFill.Parent = powerBack

	-- End screen
	local endFrame = Instance.new("Frame")
	endFrame.Size = UDim2.fromScale(1, 1)
	endFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	endFrame.BackgroundTransparency = 0.45
	endFrame.Visible = false
	endFrame.Parent = gui
	local endText = label(endFrame, "", UDim2.fromScale(0.8, 0.3), UDim2.fromScale(0.1, 0.2))

	local function hideAll()
		pick.Visible = false
		aimFrame.Visible = false
		powerBack.Visible = false
		endFrame.Visible = false
		msg.Visible = false
	end

	local view: View = {} :: any

	view.showPick = function()
		hideAll()
		top.Visible = false
		pick.Visible = true
	end

	view.showAim = function(_round, youCar, enemyCar, seconds, enemyName)
		hideAll()
		top.Visible = true
		top.Text = `YOU  vs  {enemyName}`
		msg.Visible = true
		local matchup = `{youCar} vs {enemyCar}`
		msg.Text = matchup
		-- Only a short intro: it must not sit on top of the cars while you aim.
		task.delay(1.5, function()
			if msg.Text == matchup then
				msg.Visible = false
			end
		end)
		aimFrame.Visible = true
		local deadline = os.clock() + seconds
		hint.Text = "PULL BACK, LET GO TO LAUNCH"
		task.spawn(function()
			while aimFrame.Visible and os.clock() < deadline do
				top.Text = `YOU  vs  {enemyName}   {math.ceil(deadline - os.clock())}`
				task.wait(0.25)
			end
		end)
	end

	view.showWaiting = function()
		hint.Text = "WAITING FOR THE OTHER PLAYER..."
	end

	view.showPower = function(power)
		powerBack.Visible = power > 0
		powerFill.Size = UDim2.fromScale(power, 1)
	end

	view.showFight = function()
		hideAll()
		msg.Visible = true
		msg.Text = "GO!"
		task.delay(1, function()
			if msg.Text == "GO!" then
				msg.Visible = false
			end
		end)
	end

	view.showRoundEnd = function(youLost)
		msg.Visible = true
		msg.Text = if youLost then "YOU ARE OUT" else "BOT IS OUT"
	end

	view.showMatchEnd = function(youWon)
		hideAll()
		endFrame.Visible = true
		endText.Text = if youWon then "YOU WIN" else "YOU LOSE"
		endText.TextColor3 = if youWon
			then Color3.fromRGB(120, 255, 140)
			else Color3.fromRGB(255, 100, 100)
	end

	view.hideMatch = function()
		hideAll()
		top.Visible = false
		powerBack.Visible = false
	end

	-- The lobby flow skips the old pick menu (the server starts matches with the chosen car).
	view.hideMatch()
	return view
end

return Ui
