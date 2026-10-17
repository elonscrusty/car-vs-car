--!strict
-- Client entry point. Shows UI, aims, and sends only: car choice, aim angle, launch power.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AimInput = require(script.AimInput)
local CameraDirector = require(script.CameraDirector)
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
})

aim = AimInput.new(function(power: number)
	view.showPower(power)
end, function(angle: number, power: number)
	remotes.Launch:FireServer(angle, power)
end)

remotes.UiUpdate.OnClientEvent:Connect(function(u: Types.UiUpdate)
	if u.kind == "aim" then
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
	elseif u.kind == "matchEnd" then
		aim.stop()
		view.showMatchEnd(u.youWon == true)
	end
end)
