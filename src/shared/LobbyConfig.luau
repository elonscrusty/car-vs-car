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
-- The fight: up to 4 cars; the wait lets friends and others join before bots fill (carter: 15 s).
LobbyConfig.Pad = { maxPlayers = 4, countdownSeconds = 15, pickSeconds = 15 }
-- endScreenSeconds: how long the match end screen stays (was 4: too short to read coins + rematch).
-- endScreenMaxSeconds: the longest the end screen may wait for a tap before the player is sent
-- back (the match code that wants "stay until tap" reads this; nothing waits longer than it).
-- PLACEHOLDER numbers.
LobbyConfig.Rewards = {
	winCoins = 60,
	loseCoins = 20,
	endScreenSeconds = 8,
	endScreenMaxSeconds = 20,
}
-- Coins by what happened (see ResultRewards). ALL PLACEHOLDER numbers: carter tunes them.
LobbyConfig.ResultRewards = {
	baseWin = LobbyConfig.Rewards.winCoins, -- a win (soccer, tag, duel...)
	baseOther = LobbyConfig.Rewards.loseCoins, -- finishing without a win
	-- Race coins by finishing place (1st..6th); later places use the last number. Replaces the base.
	racePlaceCoins = { 60, 45, 35, 25, 20, 20 } :: { number },
	perGoal = 5, -- soccer: coins per goal you scored
	maxGoalsPaid = 10, -- goals counted for coins (sanity cap)
	perTag = 5, -- tag: coins per car you tagged
	maxTagsPaid = 10,
	tagSurviveStep = 10, -- tag: seconds survived per bonus step (not-winners only)
	tagSurvivePerStep = 2, -- coins per full step
	tagSurviveMax = 30, -- cap on the survive bonus
	topHalfPlace = 3, -- tag/race: this place or better (of 6) keeps the win streak alive
	invitePromptMatches = 2, -- INVITE prompt after the 2nd+ match (or after any goal)
}
LobbyConfig.StarterCars = { "Sedan" } -- owned by a new player
LobbyConfig.PickChoices = 3
-- Car id -> rarity. Comes from CarConfig, so a new car only needs a rarity there.
LobbyConfig.Rarity = {} :: { [string]: string }
for id, car in CarConfig.Cars do
	LobbyConfig.Rarity[id] = car.rarity
end
LobbyConfig.Gacha = {
	price = 120, -- about 5 fights of coins (carter: medium); the odds are shown in the box
	firstPullFree = true,
	odds = { Common = 55, Rare = 28, Epic = 14, Legendary = 3 } :: { [string]: number }, -- percent, must sum to 100
	duplicateRefund = 50, -- fallback coins back on a car you already own
	-- Coins back for a duplicate, by rarity (PRETEND numbers). Rarer gives more.
	duplicateRefunds = { Common = 10, Rare = 25, Epic = 60, Legendary = 120 } :: { [string]: number },
	-- Pity: after this many pulls in a row without an Epic or better, the next pull is guaranteed
	-- one (the odds above are still shown). PLACEHOLDER: N = 10.
	pityEvery = 10,
	pityMinRarity = "Epic",
}
-- Text keys for the two ways to get a car (the client maps key -> words; nothing is shown here).
LobbyConfig.Labels = { claw = "clawSurprise", store = "storeChoose" } :: { [string]: string }
-- "Next goal" chip: show the cheapest unowned car when it is within this many coins, else prefer
-- a mode the player has not tried. PLACEHOLDER.
LobbyConfig.NextGoal = { nearCoins = 60 }
-- Store counter prices by rarity. PLACEHOLDER numbers: carter will give the real ones later.
LobbyConfig.Store = {
	prices = { Common = 150, Rare = 400, Epic = 1000, Legendary = 2500 } :: { [string]: number },
	defaultPrice = 400, -- for a car whose rarity has no price
}

return LobbyConfig
