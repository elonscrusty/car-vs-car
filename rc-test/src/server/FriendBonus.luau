--!strict
-- Bring a friend (Car VS Car, carter 10-26): when a Roblox friend is in the same server, you both
-- get Profile.FRIEND_COINS, once per friend per day and up to Profile.FRIENDS_PER_DAY friends a
-- day (Profile.friendBonus keeps count in the save, so it can't be farmed across servers).
-- Server -> client on RemoteEvent ReplicatedStorage.FriendBonus: (friendName, coins) for a toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(ReplicatedStorage.Shared.Profile)
local PlayerData = require(script.Parent.PlayerData)

local FriendBonus = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "FriendBonus"
remote.Parent = ReplicatedStorage

local function friends(a: Player, b: Player): boolean
	local ok, yes = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and yes == true
end

-- `player` gets the coins for being with `friend` (if they're due today).
local function pay(player: Player, friend: Player, now: number)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local mult = Profile.boost(now)
	if Profile.friendBonus(data, player.UserId, friend.UserId, Profile.day(now), mult) then
		PlayerData.touch(player)
		player:SetAttribute("Coins", data.coins)
		remote:FireClient(player, friend.DisplayName, Profile.FRIEND_COINS * mult)
	end
end

-- A save just loaded: check this player against everyone already here (both ways).
local function joined(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player and PlayerData.get(other) and friends(player, other) then
			if player.Parent and other.Parent then
				local now = os.time()
				pay(player, other, now)
				pay(other, player, now)
			end
		end
	end
end

function FriendBonus.start()
	PlayerData.loaded:Connect(function(player: Player)
		-- IsFriendsWith asks Roblox (it waits): off the load listener
		task.spawn(joined, player)
	end)
end

return FriendBonus
