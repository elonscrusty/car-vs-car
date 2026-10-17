--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
	onConfirm = function()
		aim.confirm()
	end,
	onAimHold = function(dir: number)
		aim.setHold(dir)
	end,
	onBoost = function()
		remotes.Ability:FireServer("boost")
	end,
	onSpecial = function()
		remotes.Ability:FireServer("special")
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

-- Keyboard: E or left shift = boost, Q = special (server decides if ready).
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.LeftShift then
		remotes.Ability:FireServer("boost")
	elseif input.KeyCode == Enum.KeyCode.Q then
		remotes.Ability:FireServer("special")
	end
end)

aim = AimInput.new(function(power: number)
	view.showPower(power)
end, function(angle: number, power: number)
	remotes.Launch:FireServer(angle, power)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	if u.kind == "aim" then
		lobby.hideChoices() -- the pick card must not cover the match
		if u.center then
			director.overview(u.center)
		end
		view.showAim(
			u.youHearts or 3,
			u.enemyHearts or 3,
			u.round or 1,
			u.yourCar or "",
			u.enemyCar or ""
		)
		if u.carPos and u.baseDir then
			aim.start(u.carPos, u.baseDir)
		end
	elseif u.kind == "fight" then
		aim.stop()
		view.showFight()
	elseif u.kind == "roundEnd" then
		view.showRoundEnd(u.youLost == true, u.youHearts or 0, u.enemyHearts or 0)
		director.focus(u.focus)
	elseif u.kind == "hit" then
		local strength = u.strength or 0
		director.shake(strength)
		if u.pos then
			Effects.sparks(u.pos, strength)
			Effects.damageNumber(u.pos, u.damage or 0, u.youHit == true)
		end
	elseif u.kind == "boost" then
		view.startBoostCooldown(u.cooldown or 5)
	elseif u.kind == "special" then
		view.startSpecialCooldown(u.cooldown or 8)
	elseif u.kind == "counter" then
		FightFx.counter()
		director.shake(1)
		if u.pos then
			Effects.counterSparks(u.pos)
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
