--!strict
-- Server entry point. Players walk around the lobby; a Match is created on demand when a player
-- picks a car on a pad (one Match per player, solo vs bot, each in its own arena slot).
-- Remotes are validated and rate limited here before reaching the match or the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MovesConfig = require(ReplicatedStorage.Shared.MovesConfig)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Atmosphere = require(script.Atmosphere)
local BattleService = require(script.BattleService)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local Lobby = require(script.Lobby)
local LobbyPads = require(script.LobbyPads)
local LobbyPlayers = require(script.LobbyPlayers)
local LobbyService = require(script.LobbyService)
local Leaderboards = require(script.Leaderboards)
local GroupMatch = require(script.GroupMatch)
local Match = require(script.Match)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Profiles = require(script.Profiles)
local RematchService = require(script.RematchService)
local GroupResults = require(script.GroupResults)
local Telemetry = require(script.Telemetry)

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
local matchCounter = 0 -- which fight mode comes next (Modes.pick goes round ModesConfig.Order)
local rematch = RematchService.new()
local startMatch: (participants: { Match.Participant }) -> () -- defined below

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
function startMatch(participants: { Match.Participant }, repeatMode: string?)
	local chosenMode: string? = nil -- set below; the rematch closures read it later
	local ok: { Match.Participant } = {}
	local okOriginal: { Match.Participant } = {}
	for _, part in participants do
		if part.player.Parent ~= nil and groups[part.player] == nil then
			local player, finished = part.player, part.onFinished
			table.insert(ok, {
				player = player,
				carId = part.carId,
				appearance = part.appearance,
				botLevel = part.botLevel,
				mode = part.mode,
				onEndScreen = function()
					rematch.open(player)
					Telemetry.endScreen(player)
				end,
				onFinished = function(won: boolean)
					local result = GroupResults.take(player) -- nil for the 1v1 modes
					Telemetry.matchEnded(player, won, result)
					local again = rematch.settle(player)
					leaveGroup(player)
					finished(won, again, result :: any)
					local restart = rematch.finish(player)
					if restart then
						startMatch(restart, chosenMode)
					end
				end,
			})
			table.insert(okOriginal, part)
		else
			-- Skipped (left or already fighting): release the lobby stage so they are not stuck "busy".
			part.onFinished(false, false)
		end
	end
	if #ok == 0 then
		return
	end
	rematch.begin(okOriginal)
	local slot = freeSlot()
	usedSlots[slot] = true
	local group: Group = { match = nil :: any, slot = slot, remaining = #ok }
	local picks: { any } = {}
	for _, part in ok do
		table.insert(picks, part.mode)
	end
	local mode = Modes.choose(picks, matchCounter, repeatMode)
	chosenMode = mode
	if repeatMode == nil then
		matchCounter += 1 -- the rotation moves on only for a fresh match, not a rematch
	end
	Telemetry.matchStarted(ok, mode, Modes.isGroup(mode))
	group.match = if Modes.isGroup(mode)
		then GroupMatch.new(ok, slot, remotes, mode)
		else Match.new(ok, slot, remotes, mode)
	for _, part in ok do
		groups[part.player] = group
	end
end

Profiles.init()
Atmosphere.apply()
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
	startMatch = startMatch,
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
	local g = groups[player]
	Telemetry.leftMatch(player, if g then "fight" else "end") -- before the match records are cleared
	if g then
		g.match.playerLeft(player)
		leaveGroup(player)
	end
	battle.playerRemoving(player)
	lobbyPads.remove(player)
	local restart = rematch.remove(player)
	lobbyService.onPlayerRemoving(player)
	if restart then
		startMatch(restart)
	end
	launchLimiter.clear(player)
	steerLimiter.clear(player)
	actionLimiter.clear(player)
	lobbyLimiter.clear(player)
end

-- LOBBY button: the player leaves their match (the other human, if any, wins) and goes to the lobby.
local function leaveMatch(player: Player)
	-- No group is fine: a player waiting for a rematch (their own end screen is over) has none.
	local g = groups[player]
	if g then
		g.match.playerLeft(player)
		leaveGroup(player)
	end
	local restart = rematch.remove(player)
	lobbyService.leftMatch(player) -- no-op unless the lobby thinks they are in a match
	if restart then
		startMatch(restart)
	end
end

remotes.Launch.OnServerEvent:Connect(function(player: Player, angle: any, power: any)
	local g = groups[player]
	if g and launchLimiter.allow(player, os.clock()) then
		g.match.launch(player, angle, power)
	end
end)

remotes.Steer.OnServerEvent:Connect(function(player: Player, value: any, throttle: any, attack: any)
	if battle.isBusy(player) then
		if steerLimiter.allow(player, os.clock()) then
			battle.steer(player, value, throttle, attack)
		end
		return
	end
	local g = groups[player]
	if g and steerLimiter.allow(player, os.clock()) then
		g.match.steer(player, value, throttle)
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
	if action == "leaveMatch" then
		leaveMatch(player)
		return
	end
	if action == "rematch" then
		rematch.tap(player)
		Telemetry.rematchTapped(player)
		return
	end
	lobbyService.action(player, action, arg)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
