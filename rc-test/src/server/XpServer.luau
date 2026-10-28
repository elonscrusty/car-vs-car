--!strict
-- XP and levels on the server (Smash plan, REWARDS row). MatchRunner calls matchDone once for each
-- player when a match ends; this pays the XP (Xp.forMatch), saves it, and sets the attributes the
-- screens read: Level (the badge by each name), Xp, XpInto, XpNeed (the level bar) and Coins.
-- Server -> client on RemoteEvent ReplicatedStorage.LevelUp: (newLevel, coins) for the popup.
-- The client never sends anything here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Xp = require(ReplicatedStorage.Shared.Xp)
local PlayerData = require(script.Parent.PlayerData)

local XpServer = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "LevelUp"
remote.Parent = ReplicatedStorage

local function show(player: Player, xp: number)
	local level, into, need = Xp.levelOf(xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("Xp", xp)
	player:SetAttribute("XpInto", into)
	player:SetAttribute("XpNeed", need)
end

-- Add `amount` XP to `player` (saved). Returns the Gain, or nil if their save isn't loaded.
function XpServer.give(player: Player, amount: number): Xp.Gain?
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not player.Parent then
		return nil
	end
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local gain = Xp.add(data, amount)
	PlayerData.touch(player)
	show(player, data.xp)
	if gain.to > gain.from then
		player:SetAttribute("Coins", data.coins)
		remote:FireClient(player, gain.to, gain.coins)
	end
	return gain
end

-- A match ended: `place` 1.. and `smashes` (bumps too) for this player. Bots: don't call.
function XpServer.matchDone(player: Player, place: number, smashes: number): Xp.Gain?
	return XpServer.give(player, Xp.forMatch(place, smashes))
end

function XpServer.start()
	PlayerData.loaded:Connect(function(player: Player, data)
		show(player, data.xp)
	end)
	PlayerData.synced:Connect(function(player: Player, data)
		show(player, data.xp)
	end)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			show(player, data.xp)
		end
	end
end

return XpServer
