--!strict
-- Car VS Car SMASH (10-28): the match HUD (Ui/Screens/Hud.match) while you are in a match. The
-- server sets the player attributes (Health, MaxHealth, Shield, Place, MatchEndsAt, Weapon,
-- Ammo, and MatchKarts if it has it) and fires SmashFeed (attacker, victim, weapon) on each smash;
-- this only shows them. FIRE (the button, F, a gamepad's R2) asks the server through WeaponFire
-- with the camera's flat look; the server checks everything (aim, ammo, cooldown).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ui = script.Parent:WaitForChild("Ui")
local Screen = require(Ui:WaitForChild("Screen"))
local Hud = require(Ui:WaitForChild("Screens"):WaitForChild("Hud"))

local player = Players.LocalPlayer

local FIRE_REMOTE = "WeaponFire" -- (= Weapons.REMOTE, WEAPONS thread)
local FEED_REMOTE = "SmashFeed"
local FIRE_GAP = 0.12 -- the client's own spacing; the server drops asks faster than a cooldown
local DEFAULT_KARTS = 5

local function attr(name: string): any
	return player:GetAttribute(name)
end
local function num(name: string, default: number): number
	local v = attr(name)
	return if type(v) == "number" then v else default
end

local function inMatch(): boolean
	local ends = attr("MatchEndsAt")
	return type(ends) == "number"
		and type(attr("Health")) == "number"
		and ends > workspace:GetServerTimeNow() - 1
end

-- aim: where the camera looks, flat (the server keeps it within 30 deg of the kart's nose)
local function aim(): Vector3?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		return nil
	end
	return look.Unit
end

local lastFire = 0
local function fire()
	if not inMatch() then
		return
	end
	local now = os.clock()
	if now - lastFire < FIRE_GAP then
		return
	end
	lastFire = now
	local remote = ReplicatedStorage:FindFirstChild(FIRE_REMOTE)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(aim())
	end
end

local hud: Screen.Handle? = nil
local function close()
	if hud then
		hud.close()
		hud = nil
	end
end

local function refresh()
	local h = hud
	if not h then
		return
	end
	local api = h.api
	api.setPlace(num("Place", 1), num("MatchKarts", DEFAULT_KARTS))
	api.setHealth(num("Health", 100), num("MaxHealth", 100), attr("Shield") == true)
	local w = attr("Weapon")
	api.setWeapon(if type(w) == "string" then w else "", num("Ammo", 0))
end

local function open()
	hud = Hud.match({
		place = num("Place", 1),
		total = num("MatchKarts", DEFAULT_KARTS),
		secs = num("MatchEndsAt", 0) - workspace:GetServerTimeNow(),
		hp = num("Health", 100),
		maxHp = num("MaxHealth", 100),
		shield = attr("Shield") == true,
		weapon = attr("Weapon"),
		ammo = num("Ammo", 0),
	}, { fire = fire })
end

local function check()
	local want = inMatch()
	if want and not hud then
		open()
	elseif not want and hud then
		close()
	end
	refresh()
end

for _, name in
	{ "Health", "MaxHealth", "Shield", "Place", "MatchKarts", "Weapon", "Ammo", "MatchEndsAt" }
do
	player:GetAttributeChangedSignal(name):Connect(check)
end
check()

-- the clock: words change once a second at most
local lastSecs = -1
RunService.Heartbeat:Connect(function()
	local h = hud
	if not h then
		return
	end
	local left = num("MatchEndsAt", 0) - workspace:GetServerTimeNow()
	local secs = math.max(0, math.ceil(left))
	if secs ~= lastSecs then
		lastSecs = secs
		h.api.setClock(secs)
	end
	if left < -1 then
		check() -- (the match is over: the end screen takes it from here)
	end
end)

-- keyboard F and a gamepad's R2 fire too (the button is the phone's)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fire()
	end
end)

-- the kill list: names from the server (a player's DisplayName, a bot's name), your own rows lime
local function nameOf(who: unknown): string
	if type(who) == "string" then
		return who
	end
	if type(who) == "number" then
		local p = Players:GetPlayerByUserId(who)
		return if p then p.DisplayName else "BOT"
	end
	if typeof(who) == "Instance" and (who :: Instance):IsA("Player") then
		return (who :: Player).DisplayName
	end
	return "?"
end
local function isMe(who: unknown): boolean
	return who == player or who == player.UserId or who == player.DisplayName or who == player.Name
end

task.spawn(function()
	local feedRemote = ReplicatedStorage:WaitForChild(FEED_REMOTE, math.huge)
	if not (feedRemote and feedRemote:IsA("RemoteEvent")) then
		return
	end
	feedRemote.OnClientEvent:Connect(function(attacker: unknown, victim: unknown, weapon: unknown)
		local h = hud
		if not h then
			return
		end
		h.api.feed(
			nameOf(attacker),
			nameOf(victim),
			if type(weapon) == "string" then weapon else nil,
			isMe(attacker) or isMe(victim)
		)
	end)
end)
