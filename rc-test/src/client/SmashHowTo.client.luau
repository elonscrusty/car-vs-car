--!strict
-- Smash how-to (WINDOWS): in your first match ever (no XP yet), one tip card at a time over the arena:
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

local DRIVE_SECS = 3 -- the DRIVE! card goes by itself after this (audit R3-2, 3 s: R8-4)

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

-- where you are (your character sits in the kart, so this moves when you drive)
local function where(): Vector3?
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function alive(): boolean
	local h = player:GetAttribute("Health")
	return type(h) ~= "number" or h > 0
end

local function run()
	if done or running then
		return
	end
	running = true
	local step = 1
	local start = where()
	local last = start
	local lastWeapon, lastAmmo = weapon(), ammo()
	local fired = false
	local shown = step
	local shownAt = os.clock()
	local startedAt = os.clock()
	local handle = Smash.howTo(step, {
		skip = function()
			-- (from the card on screen: two quick taps still skip only one step)
			if shown > 0 then
				step = shown + 1
			end
		end,
	})
	while player:GetAttribute("InMatch") == true do
		local w, a = weapon(), ammo()
		-- fired: the ammo went down on the same weapon, or its last shot used it up (a weapon
		-- lost by being smashed is not a shot)
		if
			lastWeapon ~= ""
			and a < lastAmmo
			and (w == lastWeapon or (w == "" and lastAmmo == 1 and alive()))
		then
			fired = true
		end
		-- a respawn or teleport is not driving: start counting again from there
		local pos = where()
		if pos and (not start or not last or (pos - last).Magnitude > 40) then
			start = pos
		end
		last = pos
		lastWeapon, lastAmmo = w, a
		local now = SmashScreens.step(step, {
			moved = if pos and start then (pos - start).Magnitude else 0,
			weapon = w,
			fired = fired,
			secs = os.clock() - startedAt,
		})
		if now == 1 and shown == 1 and os.clock() - shownAt >= DRIVE_SECS then
			now = 2
		end
		if now > #SmashScreens.STEPS then
			break
		end
		-- (rebuild the card only when it changes: each build pops it in)
		step = now
		local card = SmashScreens.cardFor(now, w)
		if card ~= shown then
			shown = card
			shownAt = os.clock()
			handle.set(card)
		end
		task.wait(0.2)
	end
	handle.close()
	-- (once a visit: a round that ends halfway through doesn't start the tips over)
	done = true
	running = false
end

-- a kid's first match only: no XP yet (each match pays some; carter 10-29: the cards cluttered
-- every match on a phone). No Xp attribute yet = saves not loaded: a first match too.
local function firstMatch(): boolean
	local xp = player:GetAttribute("Xp")
	return type(xp) ~= "number" or xp <= 0
end

local function check()
	if player:GetAttribute("InMatch") == true and firstMatch() then
		task.delay(1.5, function() -- (after the round's own GO moment)
			if player:GetAttribute("InMatch") == true then
				run()
			end
		end)
	end
end

player:GetAttributeChangedSignal("InMatch"):Connect(check)
check()
