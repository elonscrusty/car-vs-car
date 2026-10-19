--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power, steer and gas (-1..1).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local FirstWin = require(ReplicatedStorage.Shared.FirstWin)
local MenuRules = require(ReplicatedStorage.Shared.MenuRules)
local ActionInput = require(script.ActionInput)
local AimInput = require(script.AimInput)
local BuffUi = require(script.BuffUi)
local BuildUi = require(script.BuildUi)
local CameraDirector = require(script.CameraDirector)
local Effects = require(script.Effects)
local FightFx = require(script.FightFx)
local HintUi = require(script.HintUi)
local HitFlash = require(script.HitFlash)
local LobbyUi = require(script.LobbyUi)
local BotLevelUi = require(script.BotLevelUi)
local MenuBar = require(script.MenuBar)
local ModeBanner = require(script.ModeBanner)
local ProgressUi = require(script.ProgressUi)
local QuestUi = require(script.QuestUi)
local SaveNotice = require(script.SaveNotice)
local SpinUi = require(script.SpinUi)
local PaintUi = require(script.PaintUi)
local DriveCar = require(script.DriveCar)
local SkidFx = require(script.SkidFx)
local SoundFx = require(script.SoundFx)
local SteelLobby = require(script.SteelLobby)
local SteerInput = require(script.SteerInput)
local Ui = require(script.Ui)

local remotes = Remotes.get()
local modeBanner = ModeBanner.new()
local director = CameraDirector.new()
local buffs = BuffUi.new()
local menu = MenuBar.new() -- features add their own lobby buttons here (see MenuBar.luau)
local progressUi = ProgressUi.new()
-- Launch cuts live behind FeatureFlags: the UI is simply not built while a flag is off.
local botLevelUi = if FeatureFlags.enabled("botLevelButton")
	then BotLevelUi.new(menu, function(level: string)
		remotes.LobbyAction:FireServer("setBotLevel", level)
	end)
	else nil
SaveNotice.new()

local questUi = QuestUi.new(menu, function(action: string, arg: any?)
	remotes.LobbyAction:FireServer(action, arg)
end)
local spinUi = if FeatureFlags.enabled("dailySpin")
	then SpinUi.new(menu, function(action: string, arg: any?)
		remotes.LobbyAction:FireServer(action, arg)
	end)
	else nil
local paintUi = if FeatureFlags.enabled("paintShop") then PaintUi.new(menu) else nil
local buildUi = BuildUi.new(menu)
menu.setShown("quests", false) -- until the first profile update says the player has played enough
menu.setShown("garage", false)

local camSide: Vector3? = nil -- from the middle toward your car, fixed for the whole match
local aim: AimInput.AimInput
local steering: SteerInput.SteerInput
local driver: DriveCar.DriveCar
local skids = SkidFx.new()
task.spawn(SteelLobby.start)
local actions: ActionInput.ActionInput
local view: Ui.View

local lastWins = 0 -- saved win count from the last profile (a first win is decided from it)

-- First-time hints: the server saves which ones were shown (profile.hintsSeen).
local hints = HintUi.new(function(id: string)
	remotes.LobbyAction:FireServer("hintSeen", id)
end)

view = Ui.create({
	onPick = function(carId: string)
		remotes.SelectCar:FireServer(carId)
	end,
	onRematch = function()
		remotes.LobbyAction:FireServer("rematch")
	end,
})

local lobby = LobbyUi.new({
	onToLobby = function()
		aim.stop()
		steering.stop()
		driver.stop()
		skids.stop()
		actions.stop()
		modeBanner.hide()
		view.hideMatch()
		ProximityPromptService.Enabled = true
		director.release()
		menu.setVisible(true)
		progressUi.setVisible(true)
		SoundFx.music("music_lobby")
		hints.trigger("claw") -- after a match: point at the claw machine
	end,
})
remotes.LobbyUpdate.OnClientEvent:Connect(function(u: Types.LobbyUpdate)
	lobby.handleUpdate(u)
	questUi.handleUpdate(u)
	if spinUi then
		spinUi.handleUpdate(u)
	end
	if paintUi then
		paintUi.handleUpdate(u)
	end
	buildUi.handleUpdate(u)
	if u.kind == "profile" then
		lastWins = u.wins
		hints.loadSeen(u.hintsSeen)
		progressUi.update(
			u.carLevels,
			if FeatureFlags.enabled("rankBadges") then u.rank else nil,
			u.streak
		)
		if botLevelUi then
			botLevelUi.handleProfile(u.botLevel)
		end
		-- New players see only GIFT until they have finished a couple of matches.
		local shown = MenuRules.visible({ matches = u.matches })
		menu.setShown("gift", shown.gift)
		menu.setShown("quests", shown.quests)
		menu.setShown("garage", shown.garage)
		hints.trigger("pad") -- no-op once seen
	elseif u.kind == "countdown" and u.seconds > 0 then
		hints.done("pad") -- stepped on a pad
	end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "GachaPrompt" and hints.loaded() then
		hints.done("claw")
	elseif
		prompt.Name == "CustomizePrompt"
		or (
			prompt.Name == "BayPrompt"
			and prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		)
	then
		buildUi.open() -- the paint / customize booth, or your own bay
	end
end)

aim = AimInput.new(function(power: number)
	view.showPower(power)
	if power > 0 then
		hints.stopAimNudge() -- they are dragging, no arrow needed
	end
end, function(angle: number, power: number)
	view.showPower(0)
	hints.done("aim")
	hints.stopAimNudge()
	view.showWaiting()
	remotes.Launch:FireServer(angle, power)
end)

steering = SteerInput.new(function(steer: number, gas: number)
	remotes.Steer:FireServer(steer, gas)
end)

driver = DriveCar.new(steering.read)

actions = ActionInput.new(function(name: string)
	remotes.Action:FireServer(name)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	if u.kind == "aim" then
		menu.setVisible(false)
		progressUi.setVisible(false)
		lobby.hideChoices() -- the pick card must not cover the match
		ProximityPromptService.Enabled = false -- no "Join" pad prompt over the arena
		if u.center then
			if u.round == 1 or camSide == nil then
				camSide = if u.carPos then u.carPos - u.center else nil
			end
			director.overview(u.center, camSide)
		end
		view.showAim(
			u.round or 1,
			u.yourCar or "",
			u.enemyCar or "",
			u.seconds or 8,
			u.enemyName or "BOT"
		)
		if u.carPos then
			aim.start(u.carPos)
		end
		hints.done("pad")
		hints.trigger("aim")
		hints.startAimNudge(u.carPos) -- pulsing arrow if they have not dragged after 3 s
	elseif u.kind == "ready" then
		menu.setVisible(false)
		progressUi.setVisible(false)
		lobby.hideChoices()
		ProximityPromptService.Enabled = false -- no "Join" pad prompt floating over the arena
		if u.center then
			camSide = if u.carPos then u.carPos - u.center else nil
			director.overview(u.center, camSide)
		end
		view.showReady(u.yourCar or "", u.enemyCar or "", u.seconds or 3, u.enemyName or "BOT")
		hints.done("pad")
		hints.stopAimNudge()
	elseif u.kind == "fight" then
		aim.stop()
		hints.done("aim")
		hints.stopAimNudge()
		view.showFight()
		SoundFx.music("music_arena")
		skids.start()
		if u.auto ~= true then
			steering.start() -- the server ignores Steer outside the fight
			driver.start() -- drives your own car here once the server hands it over
		end
		if u.auto ~= true then
			actions.start(u.ability)
		end
	elseif u.kind == "modeInfo" then
		modeBanner.show(u.text or "")
	elseif u.kind == "move" then
		actions.cooldown(u.move or "", u.seconds or 0)
	elseif u.kind == "buff" then
		buffs.handleUpdate(u)
	elseif u.kind == "roundEnd" then
		buffs.clear()
		steering.stop()
		driver.stop()
		skids.stop()
		actions.stop()
		view.showRoundEnd(u.youLost == true)
		director.focus(u.focus)
	elseif u.kind == "hit" then
		local strength = u.strength or 0
		SoundFx.hit(strength)
		director.shake(strength)
		HitFlash.play(u, director)
		if strength > 0.5 then
			director.punchFov(6 + 8 * strength)
		end
		if u.pos then
			Effects.sparks(u.pos, strength)
			Effects.damageNumber(u.pos, u.damage or 0, u.youHit == true, u.tag)
		end
	elseif u.kind == "ko" then
		FightFx.ko(u.text or "K.O.!")
		director.shake(0.8)
		director.punchFov(18)
	elseif u.kind == "matchEnd" then
		buffs.clear()
		aim.stop()
		steering.stop()
		driver.stop()
		skids.stop()
		actions.stop()
		modeBanner.hide()
		hints.stopAimNudge()
		view.showMatchEnd(u.youWon == true, FirstWin.isFirstWin(lastWins, u.youWon == true))
		SoundFx.play(if u.youWon == true then "win" else "lose")
	end
end)

SoundFx.music("music_lobby") -- silent until carter fills the id in SoundConfig
local addMusicButton
function addMusicButton()
	menu.add("music", if SoundFx.isMuted() then "MUSIC OFF" else "MUSIC", 90, function()
		SoundFx.toggleMute()
		addMusicButton()
	end)
end
addMusicButton()
