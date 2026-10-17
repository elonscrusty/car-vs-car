--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AimInput = require(script.AimInput)
local CameraDirector = require(script.CameraDirector)
local Effects = require(script.Effects)
local FightFx = require(script.FightFx)
local LobbyUi = require(script.LobbyUi)
local Ui = require(script.Ui)

local remotes = Remotes.get()
local director = CameraDirector.new()

local aim: AimInput.AimInput
local view: Ui.View

view = Ui.create({
	onPick = function(carId: string)
		remotes.SelectCar:FireServer(carId)
	end,
})

local lobby = LobbyUi.new({
	onToLobby = function()
		aim.stop()
		view.hideMatch()
		director.release()
	end,
})
remotes.LobbyUpdate.OnClientEvent:Connect(lobby.handleUpdate)

aim = AimInput.new(function(power: number)
	view.showPower(power)
end, function(angle: number, power: number)
	view.showPower(0)
	remotes.Launch:FireServer(angle, power)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	if u.kind == "aim" then
		lobby.hideChoices() -- the pick card must not cover the match
		if u.center then
			director.overview(u.center)
		end
		view.showAim(u.round or 1, u.yourCar or "", u.enemyCar or "", u.seconds or 8)
		if u.carPos then
			aim.start(u.carPos)
		end
	elseif u.kind == "fight" then
		aim.stop()
		view.showFight()
	elseif u.kind == "roundEnd" then
		view.showRoundEnd(u.youLost == true)
		director.focus(u.focus)
	elseif u.kind == "hit" then
		local strength = u.strength or 0
		director.shake(strength)
		if u.pos then
			Effects.sparks(u.pos, strength)
			Effects.damageNumber(u.pos, u.damage or 0, u.youHit == true)
		end
	elseif u.kind == "ko" then
		FightFx.ko(u.text or "K.O.!")
		director.shake(0.8)
		director.punchFov(18)
	elseif u.kind == "matchEnd" then
		aim.stop()
		view.showMatchEnd(u.youWon == true)
	end
end)
