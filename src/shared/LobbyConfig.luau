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
	-- PRETEND numbers: carter gives real ones. Percent, must sum to 100. A rarity with no cars yet is
	-- skipped and the shown odds are re-scaled to 100 (see Gacha.oddsTable).
	odds = { Common = 55, Rare = 28, Epic = 14, Legendary = 3 } :: { [string]: number },
	duplicateRefund = 50, -- fallback coins back on a car you own
	-- Coins back for a duplicate, by rarity (PRETEND). Higher rarity gives more.
	duplicateRefunds = { Common = 30, Rare = 60, Epic = 150, Legendary = 400 } :: { [string]: number },
	weaponChance = 0, -- weapons are out; kept so old weapon code still compiles
}
-- Store counter prices by rarity. PLACEHOLDER numbers: carter will give the real ones later.
LobbyConfig.Store = {
	prices = { Common = 150, Rare = 400, Epic = 1000, Legendary = 2500 } :: { [string]: number },
	defaultPrice = 400, -- for a car whose rarity has no price
}

return LobbyConfig
