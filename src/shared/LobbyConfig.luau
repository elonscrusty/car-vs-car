--!strict
-- All lobby numbers live here. Tweak freely.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")

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
-- Car id -> rarity. Comes from CarConfig, so a new car only needs a rarity there.
LobbyConfig.Rarity = {} :: { [string]: string }
for id, car in CarConfig.Cars do
	LobbyConfig.Rarity[id] = car.rarity
end
LobbyConfig.Gacha = {
	price = 100,
	firstPullFree = true,
	odds = { Common = 55, Rare = 28, Epic = 14, Legendary = 3 } :: { [string]: number }, -- percent, must sum to 100
	duplicateRefund = 50, -- fallback coins back on a car you already own
	-- Coins back for a duplicate, by rarity (PRETEND numbers). Rarer gives more.
	duplicateRefunds = { Common = 30, Rare = 60, Epic = 150, Legendary = 400 } :: { [string]: number },
}
-- Store counter prices by rarity. PLACEHOLDER numbers: carter will give the real ones later.
LobbyConfig.Store = {
	prices = { Common = 150, Rare = 400, Epic = 1000, Legendary = 2500 } :: { [string]: number },
	defaultPrice = 400, -- for a car whose rarity has no price
}

return LobbyConfig
