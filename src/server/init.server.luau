--!strict
-- Server entry point. Players walk around the lobby; PLAY (button or pad) queues for the 1v1
-- Battle (BattleService). Remotes are validated and rate limited here before reaching the
-- battle or the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Atmosphere = require(script.Atmosphere)
local BattleService = require(script.BattleService)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local Gacha = require(ReplicatedStorage.Shared.Gacha)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Lobby = require(script.Lobby)
local LobbyPads = require(script.LobbyPads)
local LobbyPlayers = require(script.LobbyPlayers)
local LobbyService = require(script.LobbyService)
local Leaderboards = require(script.Leaderboards)
local Profiles = require(script.Profiles)
local Telemetry = require(script.Telemetry)
local TutorialService = require(script.TutorialService)

-- Real characters walk in the lobby (spawn is the lobby SpawnLocation).
Players.CharacterAutoLoads = true

local remotes = Remotes.get()
local steerLimiter =
	RateLimiter.new(GameConfig.Remote.steerMaxPerWindow, GameConfig.Remote.steerWindowSeconds)
local lobbyLimiter = RateLimiter.new(6, GameConfig.Remote.windowSeconds)

Profiles.init()
Atmosphere.apply()
-- the odds sign reads the gumball pool when it is built, so the battle cars must be in first
if FeatureFlags.enabled("battleMode") then
	Gacha.useFighters()
end
local lobby = Lobby.build()
local lobbyPlayers = LobbyPlayers.start() -- faster walk + name tags
-- The two physical boards; the weekly #1 gets the gold car on the workshop stage and a crown tag.
Leaderboards.init(lobby.boards, Enum.NormalId.Back, function(userId: number?, name: string)
	lobby.showcase.setChampion(if userId then name else nil)
	lobbyPlayers.setChampion(userId)
end)

-- Studio templates ship a default SpawnLocation; players must always spawn in the lobby.
for _, child in workspace:GetChildren() do
	if child:IsA("SpawnLocation") and child ~= lobby.spawn then
		child:Destroy()
	end
end
Players.PlayerAdded:Connect(function(player: Player)
	player.RespawnLocation = lobby.spawn
end)
for _, player in Players:GetPlayers() do
	player.RespawnLocation = lobby.spawn
end
local lobbyService = LobbyService.start({
	lobby = lobby,
	remotes = remotes,
})

-- The 1v1 auto-battle: PLAY queues for it, its own remotes carry pick/lock/leave.
local lobbyPads: LobbyPads.Handle? = nil -- made right below (it needs `battle`)
local battle = BattleService.start({
	remotes = remotes,
	sendProfile = lobbyService.sendProfile,
	padCount = #LobbyLayout.pads(),
	park = function(player: Player)
		if lobbyPads then
			lobbyPads.park(player)
		end
	end,
	returnToLobby = function(player: Player)
		if lobbyPads then
			lobbyPads.returnToLobby(player)
		end
	end,
})
lobbyPads = LobbyPads.start({
	pads = lobby.pads,
	origin = lobby.origin,
	battle = battle,
	remotes = remotes,
})
-- The first-time tutorial: its flags, the coin gift, and parking the character during the practice
-- drive (the drive itself runs on the player's device).
local tutorial = TutorialService.start({
	remotes = remotes,
	sendProfile = lobbyService.sendProfile,
	profiles = Profiles,
	addCoins = Inventory.addCoins,
	pads = lobbyPads,
	isBusy = battle.isBusy,
})
remotes.BattleAction.OnServerEvent:Connect(function(player: Player, name: any, arg: any)
	if type(name) == "string" and (arg == nil or type(arg) == "string") then
		battle.action(player, name, arg)
	end
end)

local function onPlayerAdded(player: Player)
	Telemetry.joined(player)
	lobbyService.onPlayerAdded(player)
end

local function onPlayerRemoving(player: Player)
	Telemetry.left(player)
	battle.playerRemoving(player)
	lobbyPads.remove(player)
	tutorial.remove(player)
	lobbyService.onPlayerRemoving(player)
	steerLimiter.clear(player)
	lobbyLimiter.clear(player)
end

remotes.Steer.OnServerEvent:Connect(function(player: Player, value: any, throttle: any, attack: any)
	if battle.isBusy(player) then
		if steerLimiter.allow(player, os.clock()) then
			battle.steer(player, value, throttle, attack)
		end
	end
end)

remotes.LobbyAction.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
	if type(action) ~= "string" or not lobbyLimiter.allow(player, os.clock()) then
		return
	end
	if action == "pickCar" and type(arg) ~= "string" then
		return
	end
	if tutorial.action(player, action, arg) then
		return
	end
	if FeatureFlags.enabled("battleMode") then
		-- Champions UI buttons: PLAY / cancel / leave go to the battle
		if action == "play" then
			if lobbyPads then
				lobbyPads.play(player) -- walks you onto a PLAY pad
			end
			return
		elseif action == "cancelPlay" or action == "leavePad" then
			if lobbyPads then
				lobbyPads.cancel(player)
			end
			return
		elseif action == "leaveMatch" then
			battle.action(player, "leave", nil)
			return
		end
	end
	lobbyService.action(player, action, arg)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
