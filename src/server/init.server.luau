--!strict
-- Server entry point. One Match per player (solo vs bot). Each player gets their own arena slot.
-- Remotes are validated and rate limited here before reaching the match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Match = require(script.Match)

-- No avatars: the game is all cars and a fixed camera.
Players.CharacterAutoLoads = false

local remotes = Remotes.get()
local launchLimiter =
	RateLimiter.new(GameConfig.Remote.maxPerWindow, GameConfig.Remote.windowSeconds)
local selectLimiter = RateLimiter.new(3, GameConfig.Remote.windowSeconds)

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

local function onPlayerAdded(player: Player)
	if matches[player] then
		return
	end
	local slot = freeSlot()
	slots[player] = slot
	matches[player] = Match.new(player, slot, remotes)
end

local function onPlayerRemoving(player: Player)
	local m = matches[player]
	if m then
		m.destroy()
	end
	matches[player] = nil
	slots[player] = nil
	launchLimiter.clear(player)
	selectLimiter.clear(player)
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

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
