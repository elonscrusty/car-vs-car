--!strict
-- All on-screen UI, built in code (no assets). Big buttons so it works on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local UiLayoutConfig = require(ReplicatedStorage.Shared.UiLayoutConfig)
local WinText = require(ReplicatedStorage.Shared.WinText)
local UiStyle = require(script.Parent.UiStyle)
local InviteUi = require(script.Parent.InviteUi)
local WinFx = require(script.Parent.WinFx)

local Ui = {}

export type Handlers = {
	onPick: (carId: string) -> (),
	onRematch: (() -> ())?, -- REMATCH tapped on the end screen
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
	showReady: (youCar: string, enemyCar: string, seconds: number, enemyName: string) -> (),
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
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	UiStyle.textLimit(l, UiLayoutConfig.minText, 100)
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
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = b
	-- Never smaller than a fingertip on a phone.
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(48, 48)
	minSize.Parent = b
	UiStyle.textLimit(b, UiLayoutConfig.minText, 40)
	UiStyle.polish(b)
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
		sub.Font = Enum.Font.FredokaOne
		b.Activated:Connect(function()
			h.onPick(id)
		end)
	end

	-- Where every fight piece goes (pure numbers in UiLayout, checked by tests/uilayout.test.luau).
	local camera = workspace.CurrentCamera
	local fightSpecs = UiLayout.fight(if camera then camera.ViewportSize.Y else 360)
	local endSpecs = UiLayout.endScreen()

	-- Top banner: dark slab, red edge on the left, cyan on the right. Small, under the top bar.
	local top = Instance.new("Frame")
	top.Name = "TopBanner"
	UiStyle.place(top, fightSpecs.vsBanner)
	top.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	top.BackgroundTransparency = 0.08
	top.BorderSizePixel = 0
	top.Visible = false
	top.Parent = gui
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 8)
	topCorner.Parent = top
	local topGlow = Instance.new("UIGradient")
	topGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 20, 30)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 60, 80)),
	})
	topGlow.Parent = top
	local function edge(x: number, color: Color3)
		local e = Instance.new("Frame")
		e.AnchorPoint = Vector2.new(x, 0)
		e.Position = UDim2.fromScale(x, 0)
		e.Size = UDim2.new(0, 5, 1, 0)
		e.BackgroundColor3 = color
		e.BorderSizePixel = 0
		e.Parent = top
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = e
	end
	edge(0, Color3.fromRGB(235, 50, 60))
	edge(1, Color3.fromRGB(40, 210, 240))
	local topText = Instance.new("TextLabel")
	topText.BackgroundTransparency = 1
	topText.Size = UDim2.fromScale(1, 1)
	topText.RichText = true
	topText.TextScaled = true
	topText.Font = Enum.Font.FredokaOne
	topText.TextColor3 = Color3.new(1, 1, 1)
	topText.Text = ""
	topText.Parent = top
	local topPad = Instance.new("UIPadding")
	topPad.PaddingTop = UDim.new(0, UiLayoutConfig.textPad)
	topPad.PaddingBottom = UDim.new(0, UiLayoutConfig.textPad)
	topPad.PaddingLeft, topPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	topPad.Parent = topText
	UiStyle.textLimit(topText, UiLayoutConfig.minText, UiLayoutConfig.maxTextBanner)

	-- "YOU vs BOT" with a small "vs", plus the countdown when there is one.
	local function setTop(enemyName: string, seconds: number?)
		local safe = enemyName:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		local text = `YOU  <font size="{UiLayoutConfig.minText}" color="#AAB4C8">vs</font>  {safe}`
		if seconds then
			text ..= `   <font color="#FFD84A">{seconds}</font>`
		end
		topText.Text = text
	end

	-- Message ("GO!", matchup): bottom-centre lane, below the empty middle of the screen.
	local msg = label(gui, "", UDim2.new(), UDim2.new())
	UiStyle.place(msg, fightSpecs.msg)
	UiStyle.textLimit(msg, UiLayoutConfig.minText, UiLayoutConfig.maxTextMsg)
	msg.Visible = false
	local msgScale = Instance.new("UIScale")
	msgScale.Parent = msg

	-- Aim hint (the aiming itself is a drag on the screen, see AimInput)
	local aimFrame = Instance.new("Frame")
	aimFrame.Size = UDim2.fromScale(1, 1)
	aimFrame.BackgroundTransparency = 1
	aimFrame.Visible = false
	aimFrame.Parent = gui
	local hint = label(aimFrame, "", UDim2.new(), UDim2.new())
	UiStyle.place(hint, fightSpecs.hint)
	UiStyle.textLimit(hint, UiLayoutConfig.minText, 24)

	-- Power bar
	local powerBack = Instance.new("Frame")
	UiStyle.place(powerBack, fightSpecs.powerBar)
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
	local banner = Instance.new("Frame")
	UiStyle.place(banner, endSpecs.banner)
	banner.BackgroundTransparency = 1
	banner.Parent = endFrame
	local head, sub = UiLayoutConfig.endScreen.head, UiLayoutConfig.endScreen.sub
	local endText =
		label(banner, "", UDim2.fromScale(head[3], head[4]), UDim2.fromScale(head[1], head[2]))
	endText.TextStrokeTransparency = 0
	local endSub =
		label(banner, "", UDim2.fromScale(sub[3], sub[4]), UDim2.fromScale(sub[1], sub[2]))
	endSub.TextColor3 = Color3.fromRGB(255, 225, 120)
	local rematchBtn =
		button(endFrame, "REMATCH", UDim2.new(), UDim2.new(), Color3.fromRGB(40, 160, 80))
	rematchBtn.Name = "RematchButton"
	UiStyle.place(rematchBtn, endSpecs.rematch)
	rematchBtn.Visible = false
	rematchBtn.Activated:Connect(function()
		if not rematchBtn.Active then
			return
		end
		rematchBtn.Active = false
		rematchBtn.AutoButtonColor = false
		rematchBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 95)
		rematchBtn.Text = "WAITING..."
		if h.onRematch then
			h.onRematch()
		end
	end)
	local invite = InviteUi.new(endFrame)
	local endFx: WinFx.Handle? = nil
	local endTweens: { Tween } = {}

	local function clearEndFx()
		if endFx then
			endFx.stop()
			endFx = nil
		end
		for _, t in endTweens do
			t:Cancel()
			t:Destroy()
		end
		table.clear(endTweens)
	end

	local function hideAll()
		clearEndFx()
		pick.Visible = false
		aimFrame.Visible = false
		powerBack.Visible = false
		endFrame.Visible = false
		invite.setVisible(false)
		rematchBtn.Visible = false
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
		setTop(enemyName)
		msg.Visible = true
		msg.TextColor3 = Color3.new(1, 1, 1)
		local matchup = `{youCar} vs {enemyCar}`
		msg.Text = matchup
		UiStyle.pop(msgScale)
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
				setTop(enemyName, math.ceil(deadline - os.clock()))
				task.wait(0.25)
			end
		end)
	end

	view.showReady = function(youCar, enemyCar, seconds, enemyName)
		hideAll()
		top.Visible = true
		setTop(enemyName)
		msg.Visible = true
		msg.TextColor3 = Color3.new(1, 1, 1)
		local matchup = `{youCar} vs {enemyCar}`
		msg.Text = matchup
		UiStyle.pop(msgScale)
		local deadline = os.clock() + seconds
		task.spawn(function()
			while os.clock() < deadline and top.Visible do
				setTop(enemyName, math.ceil(deadline - os.clock()))
				task.wait(0.25)
			end
			setTop(enemyName)
		end)
		task.delay(1.5, function()
			if msg.Text == matchup then
				msg.Visible = false
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
		msg.TextColor3 = Color3.fromRGB(120, 255, 150)
		UiStyle.pop(msgScale, 0.3)
		task.delay(1, function()
			if msg.Text == "GO!" then
				msg.Visible = false
			end
		end)
	end

	view.showRoundEnd = function(youLost)
		msg.Visible = true
		msg.Text = if youLost then "YOU ARE OUT" else "BOT IS OUT"
		msg.TextColor3 = if youLost
			then Color3.fromRGB(255, 110, 110)
			else Color3.fromRGB(255, 225, 120)
		UiStyle.pop(msgScale)
	end

	view.showMatchEnd = function(youWon)
		hideAll()
		endFrame.Visible = true
		rematchBtn.Visible = true
		rematchBtn.Active = true
		rematchBtn.AutoButtonColor = true
		rematchBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
		rematchBtn.Text = "REMATCH"
		endText.Text = WinText.headline(youWon)
		endSub.Text = WinText.subtitle(youWon, LobbyConfig.Rewards)
		endText.TextColor3 = if youWon
			then Color3.fromRGB(255, 205, 40)
			else Color3.fromRGB(235, 90, 90)
		invite.setVisible(youWon)
		WinFx.popIn(banner, youWon, endTweens)
		if youWon then
			endFx = WinFx.coinBurst(endFrame, math.floor(os.clock() * 1000))
		end
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
