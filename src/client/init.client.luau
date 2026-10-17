--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power, steer and gas (-1..1).

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local ActionInput = require(script.ActionInput)
local AimInput = require(script.AimInput)
local BuffUi = require(script.BuffUi)
local CameraDirector = require(script.CameraDirector)
local Effects = require(script.Effects)
local FightFx = require(script.FightFx)
local HintUi = require(script.HintUi)
local LobbyUi = require(script.LobbyUi)
local BotLevelUi = require(script.BotLevelUi)
local MenuBar = require(script.MenuBar)
local ProgressUi = require(script.ProgressUi)
local QuestUi = require(script.QuestUi)
local PaintUi = require(script.PaintUi)
local SteerInput = require(script.SteerInput)
local Ui = require(script.Ui)

local remotes = Remotes.get()
local director = CameraDirector.new()
local buffs = BuffUi.new()
local menu = MenuBar.new() -- features add their own lobby buttons here (see MenuBar.luau)
local progressUi = ProgressUi.new()
local botLevelUi = BotLevelUi.new(menu, function(level: string)
	remotes.LobbyAction:FireServer("setBotLevel", level)
end)

local questUi = QuestUi.new(menu, function(action: string, arg: any?)
	remotes.LobbyAction:FireServer(action, arg)
end)
local paintUi = PaintUi.new(menu)

local camSide: Vector3? = nil -- from the middle toward your car, fixed for the whole match
local aim: AimInput.AimInput
local steering: SteerInput.SteerInput
local actions: ActionInput.ActionInput
local view: Ui.View

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
		actions.stop()
		view.hideMatch()
		director.release()
		menu.setVisible(true)
		progressUi.setVisible(true)
		hints.trigger("claw") -- after a match: point at the claw machine
	end,
})
remotes.LobbyUpdate.OnClientEvent:Connect(function(u: Types.LobbyUpdate)
	lobby.handleUpdate(u)
	questUi.handleUpdate(u)
	paintUi.handleUpdate(u)
	if u.kind == "profile" then
		hints.loadSeen(u.hintsSeen)
		progressUi.update(u.carLevels, u.rank, u.streak)
		botLevelUi.handleProfile(u.botLevel)
		hints.trigger("pad") -- no-op once seen
	elseif u.kind == "countdown" and u.seconds > 0 then
		hints.done("pad") -- stepped on a pad
	end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "GachaPrompt" and hints.loaded() then
		hints.done("claw")
	end
end)

aim = AimInput.new(function(power: number)
	view.showPower(power)
end, function(angle: number, power: number)
	view.showPower(0)
	hints.done("aim")
	view.showWaiting()
	remotes.Launch:FireServer(angle, power)
end)

steering = SteerInput.new(function(steer: number, gas: number)
	remotes.Steer:FireServer(steer, gas)
end)

actions = ActionInput.new(function(name: string)
	remotes.Action:FireServer(name)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	if u.kind == "aim" then
		menu.setVisible(false)
		progressUi.setVisible(false)
		lobby.hideChoices() -- the pick card must not cover the match
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
	elseif u.kind == "fight" then
		aim.stop()
		hints.done("aim")
		view.showFight()
		steering.start() -- the server ignores Steer outside the fight
		actions.start()
	elseif u.kind == "move" then
		actions.cooldown(u.move or "", u.seconds or 0)
	elseif u.kind == "buff" then
		buffs.handleUpdate(u)
	elseif u.kind == "roundEnd" then
		buffs.clear()
		steering.stop()
		actions.stop()
		view.showRoundEnd(u.youLost == true)
		director.focus(u.focus)
	elseif u.kind == "hit" then
		local strength = u.strength or 0
		director.shake(strength)
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
		actions.stop()
		view.showMatchEnd(u.youWon == true)
	end
end)
