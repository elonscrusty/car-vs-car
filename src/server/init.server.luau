--!strict
-- Server entry point. Players walk around the lobby; a Match is created on demand when a player
-- picks a car on a pad (one Match per player, solo vs bot, each in its own arena slot).
-- Remotes are validated and rate limited here before reaching the match or the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Lobby = require(script.Lobby)
local LobbyService = require(script.LobbyService)
local Match = require(script.Match)
local Profiles = require(script.Profiles)

-- Real characters walk in the lobby (spawn is the lobby SpawnLocation).
Players.CharacterAutoLoads = true

local remotes = Remotes.get()
local launchLimiter =
	RateLimiter.new(GameConfig.Remote.maxPerWindow, GameConfig.Remote.windowSeconds)
local selectLimiter = RateLimiter.new(3, GameConfig.Remote.windowSeconds)
local abilityLimiter = RateLimiter.new(4, GameConfig.Remote.windowSeconds)
local lobbyLimiter = RateLimiter.new(6, GameConfig.Remote.windowSeconds)

local matches: { [Player]: Match.Handle } = {}
local slots: { [Player]: number } = {}

local function freeSlot(): number
	local used: { [number]: boolean } = {}
	for _, s in slots do
		used[s] = true
	end
	local s = 0
	while used[s] do
		s += 1
	end
	return s
end

local function endMatch(player: Player)
	local m = matches[player]
	if m then
		m.destroy()
	end
	matches[player] = nil
	slots[player] = nil
end

-- Create the player's match (only the lobby service calls this, after a validated pick).
local function startMatch(player: Player, carId: string, onFinished: (won: boolean) -> ())
	if matches[player] or player.Parent == nil then
		return
	end
	local slot = freeSlot()
	slots[player] = slot
	matches[player] = Match.new(player, slot, remotes, {
		carId = carId,
		onFinished = function(won: boolean)
			endMatch(player)
			onFinished(won)
		end,
	})
end

Profiles.init()
local lobby = Lobby.build()
local lobbyService = LobbyService.start({
	lobby = lobby,
	remotes = remotes,
	startMatch = startMatch,
})

local function onPlayerAdded(player: Player)
	lobbyService.onPlayerAdded(player)
end

local function onPlayerRemoving(player: Player)
	endMatch(player)
	lobbyService.onPlayerRemoving(player)
	launchLimiter.clear(player)
	selectLimiter.clear(player)
	abilityLimiter.clear(player)
	lobbyLimiter.clear(player)
end

remotes.SelectCar.OnServerEvent:Connect(function(player: Player, carId: any)
	local m = matches[player]
	if m and selectLimiter.allow(player, os.clock()) then
		m.selectCar(carId)
	end
end)

remotes.Launch.OnServerEvent:Connect(function(player: Player, angle: any, power: any)
	local m = matches[player]
	if m and launchLimiter.allow(player, os.clock()) then
		m.launch(angle, power)
	end
end)

remotes.Ability.OnServerEvent:Connect(function(player: Player)
	local m = matches[player]
	if m and abilityLimiter.allow(player, os.clock()) then
		m.boost()
	end
end)

remotes.LobbyAction.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
	if type(action) ~= "string" or not lobbyLimiter.allow(player, os.clock()) then
		return
	end
	if action == "pickCar" and type(arg) ~= "string" then
		return
	end
	lobbyService.action(player, action, arg)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
