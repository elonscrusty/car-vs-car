--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power, steer and gas (-1..1).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local FirstWin = require(ReplicatedStorage.Shared.FirstWin)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MenuRules = require(ReplicatedStorage.Shared.MenuRules)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local AimInput = require(script.AimInput)
local BallFx = require(script.BallFx)
local BuffUi = require(script.BuffUi)
local BuildUi = require(script.BuildUi)
local CameraDirector = require(script.CameraDirector)
local Effects = require(script.Effects)
require(script.OwnRing).start() -- glow ring under my own car
local FightFx = require(script.FightFx)
local GoalFx = require(script.GoalFx)
local HintUi = require(script.HintUi)
local HitFlash = require(script.HitFlash)
local ChampionsBridge = require(script.ChampionsBridge)
local BotLevelUi = require(script.BotLevelUi)
local MenuBar = require(script.MenuBar)
local CenterBanner = require(script.CenterBanner)
local ModeBanner = require(script.ModeBanner)
local Quality = require(script.Quality)
local QuestUi = require(script.QuestUi)
local SaveNotice = require(script.SaveNotice)
local SpinUi = require(script.SpinUi)
local PaintUi = require(script.PaintUi)
local DriveCar = require(script.DriveCar)
local SkidFx = require(script.SkidFx)
local SoundFx = require(script.SoundFx)
local SteelLobby = require(script.SteelLobby)
local SteerInput = require(script.SteerInput)
local TeamIcons = require(script.TeamIcons)
local WheelFx = require(script.WheelFx)
local Ui = require(script.Ui)

Quality.start() -- low-end phones: fewer particles when the frame time is high
local remotes = Remotes.get()
local modeBanner = ModeBanner.new()
local centerBanner = CenterBanner.new()
local director = CameraDirector.new()
local buffs = BuffUi.new()
local menu = MenuBar.new() -- features add their own lobby buttons here (see MenuBar.luau)
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
WheelFx.start()
local view: Ui.View

local lastWins = 0 -- saved win count from the last profile (a first win is decided from it)

-- First-time hints: the server saves which ones were shown (profile.hintsSeen).
local hints = HintUi.new(function(id: string)
	remotes.LobbyAction:FireServer("hintSeen", id)
end)

view = Ui.create()

-- Carter's Champions UI (src/champions) draws every lobby and match screen; the bridge feeds it.
local champions = ChampionsBridge.new()

-- Back at the lobby: stop every match piece and give the camera back.
local function onToLobby()
	aim.stop()
	steering.stop()
	driver.stop()
	skids.stop()
	BallFx.stop()
	TeamIcons.stop()
	modeBanner.hide()
	view.hideMatch()
	ProximityPromptService.Enabled = true
	director.release()
	menu.setVisible(true)
	SoundFx.music("music_lobby")
	hints.trigger("claw") -- after a match: point at the claw machine
end
remotes.LobbyUpdate.OnClientEvent:Connect(function(u: Types.LobbyUpdate)
	champions.handleLobby(u)
	if u.kind == "toLobby" then
		onToLobby()
	end
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
		if botLevelUi then
			botLevelUi.handleProfile(u.botLevel)
		end
		-- New players see only GIFT until they have finished a couple of matches.
		local shown = MenuRules.visible({ matches = u.matches })
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

driver = DriveCar.new(steering.read, function()
	-- Your car just boosted: widen the view and rush some speed lines for 0.8 s.
	director.boost()
	Effects.speedLines(GameConfig.Feel.boostFxSeconds)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	champions.handleUi(u)
	if u.kind == "aim" then
		menu.setVisible(false)
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
		ProximityPromptService.Enabled = false -- no "Join" pad prompt floating over the arena
		if u.center then
			camSide = if u.carPos then u.carPos - u.center else nil
			director.overview(u.center, camSide)
		end
		director.soccer(u.soccer == true) -- car soccer: camera follows your car and the ball
		if u.soccer == true then
			BallFx.start() -- ball trail and kick sparks
		end
		TeamIcons.start()
		view.showReady()
		hints.done("pad")
		hints.stopAimNudge()
	elseif u.kind == "fight" then
		aim.stop()
		hints.done("aim")
		hints.stopAimNudge()
		view.showFight()
		SoundFx.music("music_arena")
		skids.start()
		TeamIcons.start()
		if u.auto ~= true then
			steering.start() -- the server ignores Steer outside the fight
			driver.start() -- drives your own car here once the server hands it over
		end
	elseif u.kind == "modeInfo" then
		modeBanner.show(u.text or "")
	elseif u.kind == "banner" then
		local countdownSound = Sounds.countdownEvent(u.text or "")
		if countdownSound then
			SoundFx.play(countdownSound) -- silent until carter fills the id in SoundConfig
		end
		centerBanner.show(u.text or "", u.seconds or 1)
	elseif u.kind == "buff" then
		buffs.handleUpdate(u)
	elseif u.kind == "roundEnd" then
		buffs.clear()
		steering.stop()
		driver.stop()
		skids.stop()
		BallFx.stop()
		TeamIcons.stop()
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
		GoalFx.handle(u, director) -- soccer goal: confetti, camera snap to the ball, scorer name
		director.shake(0.8)
		director.punchFov(18)
	elseif u.kind == "matchEnd" then
		buffs.clear()
		aim.stop()
		steering.stop()
		driver.stop()
		skids.stop()
		BallFx.stop()
		TeamIcons.stop()
		modeBanner.hide()
		hints.stopAimNudge()
		centerBanner.hide()
		view.showMatchEnd(u.youWon == true, FirstWin.isFirstWin(lastWins, u.youWon == true))
		SoundFx.play(if u.youWon == true then "win" else "lose")
	end
end)

SoundFx.music("music_lobby") -- silent until carter fills the id in SoundConfig
