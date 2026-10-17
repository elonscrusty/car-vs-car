--!strict
-- All lobby numbers live here. Tweak freely.

local LobbyConfig = {}

-- Vector3 does not exist under plain Lune (tests), so fall back to a same-shaped table there.
local okOrigin, origin = pcall(function()
	return Vector3.new(0, 3, 500)
end)
LobbyConfig.Lobby = {
	origin = (if okOrigin then origin else { X = 0, Y = 3, Z = 500 }) :: Vector3,
	padCount = 4,
}
LobbyConfig.Pad = { maxPlayers = 2, countdownSeconds = 3, pickSeconds = 15 }
LobbyConfig.Rewards = { winCoins = 60, loseCoins = 20, endScreenSeconds = 4 }
LobbyConfig.StarterCars = { "Heavy" } -- owned by a new player
LobbyConfig.PickChoices = 3
LobbyConfig.Rarity = {
	Heavy = "Common",
	Light = "Common",
	Tank = "Common",
	Ramp = "Rare",
	Drift = "Rare",
	Bulldozer = "Rare",
	Spike = "Epic",
	Rocket = "Epic",
} :: { [string]: string }
LobbyConfig.Gacha = {
	price = 100,
	firstPullFree = true,
	odds = { Common = 60, Rare = 30, Epic = 10 } :: { [string]: number }, -- percent, must sum to 100
	duplicateRefund = 50, -- coins back on a car or weapon you own
	weaponChance = 40, -- percent of pulls that give a weapon instead of a car (never the first free pull)
}
-- Store counter prices by rarity. PLACEHOLDER numbers: carter will give the real ones later.
LobbyConfig.Store = {
	prices = { Common = 150, Rare = 400, Epic = 1000 } :: { [string]: number },
	defaultPrice = 400, -- for a car whose rarity has no price
}

return LobbyConfig
