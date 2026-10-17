--!strict
-- Server entry point. Players walk around the lobby; a Match is created on demand when a player
-- picks a car on a pad (one Match per player, solo vs bot, each in its own arena slot).
-- Remotes are validated and rate limited here before reaching the match or the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
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
local steerLimiter =
	RateLimiter.new(GameConfig.Remote.steerMaxPerWindow, GameConfig.Remote.steerWindowSeconds)
local actionLimiter =
	RateLimiter.new(MovesConfig.Remote.maxPerWindow, MovesConfig.Remote.windowSeconds)
local lobbyLimiter = RateLimiter.new(6, GameConfig.Remote.windowSeconds)

type Group = { match: Match.Handle, slot: number, remaining: number }
local groups: { [Player]: Group } = {} -- every player in a match -> that match
local usedSlots: { [number]: boolean } = {}

local function freeSlot(): number
	local s = 0
	while usedSlots[s] do
		s += 1
	end
	return s
end

-- A player is done with their match (end screen over, or they left). The last one out closes it.
local function leaveGroup(player: Player)
	local g = groups[player]
	if g == nil then
		return
	end
	groups[player] = nil
	g.remaining -= 1
	if g.remaining <= 0 then
		g.match.destroy()
		usedSlots[g.slot] = nil
	end
end

-- Start one match for 1 or 2 players (only the lobby service calls this, after validated picks).
-- A missing second player is a bot.
local function startMatch(participants: { Match.Participant })
	local ok: { Match.Participant } = {}
	for _, part in participants do
		if part.player.Parent ~= nil and groups[part.player] == nil then
			local player, finished = part.player, part.onFinished
			table.insert(ok, {
				player = player,
				carId = part.carId,
				appearance = part.appearance,
				botLevel = part.botLevel,
				onFinished = function(won: boolean)
					leaveGroup(player)
					finished(won)
				end,
			})
		end
	end
	if #ok == 0 then
		return
	end
	local slot = freeSlot()
	usedSlots[slot] = true
	local group: Group = { match = nil :: any, slot = slot, remaining = #ok }
	group.match = Match.new(ok, slot, remotes)
	for _, part in ok do
		groups[part.player] = group
	end
end

Profiles.init()
local lobby = Lobby.build()

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
	startMatch = startMatch,
})

local function onPlayerAdded(player: Player)
	lobbyService.onPlayerAdded(player)
end

local function onPlayerRemoving(player: Player)
	local g = groups[player]
	if g then
		g.match.playerLeft(player)
		leaveGroup(player)
	end
	lobbyService.onPlayerRemoving(player)
	launchLimiter.clear(player)
	steerLimiter.clear(player)
	actionLimiter.clear(player)
	lobbyLimiter.clear(player)
end

remotes.Launch.OnServerEvent:Connect(function(player: Player, angle: any, power: any)
	local g = groups[player]
	if g and launchLimiter.allow(player, os.clock()) then
		g.match.launch(player, angle, power)
	end
end)

remotes.Steer.OnServerEvent:Connect(function(player: Player, value: any)
	local g = groups[player]
	if g and steerLimiter.allow(player, os.clock()) then
		g.match.steer(player, value)
	end
end)

remotes.Action.OnServerEvent:Connect(function(player: Player, name: any)
	local g = groups[player]
	if g and type(name) == "string" and actionLimiter.allow(player, os.clock()) then
		g.match.action(player, name)
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
