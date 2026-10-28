--!strict
-- Smash how-to (WINDOWS): in your first match of a visit, one tip card at a time over the arena:
-- DRIVE! (arrow at the stick), GRAB A ? (the red box), TAP FIRE! (arrow at FIRE). Each goes as
-- soon as you've done it (SmashScreens.step: doing a later one first skips ahead), a tap on the
-- card skips it, and the round ending puts it away. Only reads the server's player attributes
-- (InMatch, Weapon, Ammo); asks the server nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
-- (only with the SMASH game on, as MatchHud)
if (Features :: any).SMASH ~= true then
	return
end
local SmashScreens = require(Shared:WaitForChild("SmashScreens"))
local Ui = script.Parent:WaitForChild("Ui")
local Smash = require(Ui:WaitForChild("Screens"):WaitForChild("Smash"))

local player = Players.LocalPlayer

local done = false -- (this visit; once saves know about it, SAVES can keep it)
local running = false

local function weapon(): string
	local w = player:GetAttribute("Weapon")
	return if type(w) == "string" then w else ""
end

local function ammo(): number
	local a = player:GetAttribute("Ammo")
	return if type(a) == "number" then a else 0
end

-- where the camera looks (the chase cam follows your kart, so this moves when you drive)
local function where(): Vector3
	local cam = workspace.CurrentCamera
	return if cam then cam.Focus.Position else Vector3.zero
end

local function run()
	if done or running then
		return
	end
	running = true
	local step = 1
	local start = where()
	local lastWeapon, lastAmmo = weapon(), ammo()
	local fired = false
	local shown = step
	local handle = Smash.howTo(step, {
		skip = function()
			step += 1
		end,
	})
	while player:GetAttribute("InMatch") == true do
		local w, a = weapon(), ammo()
		-- fired: the ammo went down on the same weapon, or the weapon was used up
		if lastWeapon ~= "" and ((w == lastWeapon and a < lastAmmo) or w == "") then
			fired = true
		end
		lastWeapon, lastAmmo = w, a
		local now = SmashScreens.step(step, {
			moved = (where() - start).Magnitude,
			weapon = w,
			fired = fired,
		})
		if now > #SmashScreens.STEPS then
			done = true
			break
		end
		-- (rebuild the card only when the step changes: each build pops it in)
		if now ~= shown then
			step, shown = now, now
			handle.set(step)
		end
		task.wait(0.2)
	end
	handle.close()
	running = false
end

local function check()
	if player:GetAttribute("InMatch") == true then
		task.delay(1.5, function() -- (after the round's own GO moment)
			if player:GetAttribute("InMatch") == true then
				run()
			end
		end)
	end
end

player:GetAttributeChangedSignal("InMatch"):Connect(check)
check()
