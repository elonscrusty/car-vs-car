--!strict
-- Match feedback that carter's Champions UI does not draw: the short center message ("GO!",
-- "YOU ARE OUT") and the win/lose headline with coins and confetti. The scoreboard, clock, boost and
-- ability buttons, LOBBY and REMATCH all live in the Champions UI (src/champions, client/ChampionsBridge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirstWin = require(ReplicatedStorage.Shared.FirstWin)
local FirstWinConfig = require(ReplicatedStorage.Shared.FirstWinConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local UiLayoutConfig = require(ReplicatedStorage.Shared.UiLayoutConfig)
local WinText = require(ReplicatedStorage.Shared.WinText)
local UiStyle = require(script.Parent.UiStyle)
local InviteUi = require(script.Parent.InviteUi)
local WinFx = require(script.Parent.WinFx)

local Ui = {}

export type View = {
	showAim: (
		round: number,
		youCar: string,
		enemyCar: string,
		seconds: number,
		enemyName: string
	) -> (),
	showReady: () -> (),
	showWaiting: () -> (),
	showPower: (power: number) -> (),
	showFight: () -> (),
	showRoundEnd: (youLost: boolean) -> (),
	showMatchEnd: (youWon: boolean, firstWin: boolean?) -> (),
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

function Ui.create(): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "CarVsCarUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Where every fight piece goes (pure numbers in UiLayout, checked by tests/uilayout.test.luau).
	local camera = workspace.CurrentCamera
	local fightSpecs = UiLayout.fight(if camera then camera.ViewportSize.Y else 360)
	local endSpecs = UiLayout.endScreen()

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
		aimFrame.Visible = false
		powerBack.Visible = false
		endFrame.Visible = false
		invite.setVisible(false)
		msg.Visible = false
	end

	local view: View = {} :: any

	view.showAim = function(_round, youCar, enemyCar, _seconds, _enemyName)
		hideAll()
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
		hint.Text = "PULL BACK, LET GO TO LAUNCH"
	end

	-- The ready countdown is the center banner (CenterBanner); nothing extra to draw here.
	view.showReady = function()
		hideAll()
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
		msg.Text = if youLost then "YOU ARE OUT" else "SOMEONE IS OUT"
		msg.TextColor3 = if youLost
			then Color3.fromRGB(255, 110, 110)
			else Color3.fromRGB(255, 225, 120)
		UiStyle.pop(msgScale)
	end

	view.showMatchEnd = function(youWon, firstWin)
		hideAll()
		endFrame.Visible = true
		local big = youWon and firstWin == true
		endText.Text = if big then FirstWin.headline() else WinText.headline(youWon)
		endSub.Text = WinText.subtitle(youWon, LobbyConfig.Rewards)
		endText.TextColor3 = if youWon
			then Color3.fromRGB(255, 205, 40)
			else Color3.fromRGB(235, 90, 90)
		invite.setVisible(youWon)
		WinFx.popIn(banner, youWon, endTweens, if big then FirstWinConfig.bannerScale else nil)
		if youWon then
			local seed = math.floor(os.clock() * 1000)
			local coins =
				WinFx.coinBurst(endFrame, seed, if big then FirstWinConfig.coinCount else nil)
			local confetti = if big
				then WinFx.confetti(endFrame, seed + 1, FirstWinConfig.confettiCount)
				else nil
			endFx = {
				stop = function()
					coins.stop()
					if confetti then
						confetti.stop()
					end
				end,
			}
		end
	end

	view.hideMatch = function()
		hideAll()
		powerBack.Visible = false
	end

	view.hideMatch()
	return view
end

return Ui
