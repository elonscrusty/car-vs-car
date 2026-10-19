-- Catalog and economy values come from the game (see below); only the pictures are chosen here.
local Config = {}
-- The live roster comes from the game itself (CarConfig / Store / Gacha), so names, rarities,
-- abilities, prices and odds can never drift from what the server does. Only the picture is chosen
-- here: the closest of the 12 generated car pictures (Assets.Vehicles is keyed by game car id).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameShared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(GameShared:WaitForChild("CarConfig"))
local Gacha = require(GameShared:WaitForChild("Gacha"))
local LobbyConfig = require(GameShared:WaitForChild("LobbyConfig"))
local QuestsConfig = require(GameShared:WaitForChild("QuestsConfig"))
local Store = require(GameShared:WaitForChild("Store"))

Config.Vehicles = {}
for index, id in CarConfig.Order do
	local stats = CarConfig.Cars[id]
	table.insert(Config.Vehicles, {
		Id = id,
		Name = string.upper(stats.name),
		Rarity = stats.rarity,
		Ability = stats.ability,
		Price = Store.price(id),
		Color = Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3]),
		ArtIndex = index,
	})
end
Config.ById = {}
for _, vehicle in Config.Vehicles do
	Config.ById[vehicle.Id] = vehicle
end
Config.RarityColors = {
	Common = Color3.fromRGB(186, 205, 224),
	Rare = Color3.fromRGB(31, 188, 255),
	Epic = Color3.fromRGB(201, 73, 255),
	Legendary = Color3.fromRGB(255, 211, 43),
}
-- Car fights are the only mode now. The id stays "DUEL" so the existing icon and layout apply.
Config.Modes = {
	{ Id = "DUEL", Name = "FIGHT", Description = "4 cars. Last car alive wins." },
}
Config.ClawPrice = LobbyConfig.Gacha.price
Config.ClawOdds = {}
for _, row in Gacha.oddsTable() do
	table.insert(Config.ClawOdds, {
		Rarity = row.rarity,
		Chance = row.percent,
		PerCar = math.floor(row.percent / #row.cars * 10 + 0.5) / 10,
	})
end
-- A duplicate pays coins back by rarity; show the range instead of one number.
do
	local low, high = math.huge, 0
	for _, amount in LobbyConfig.Gacha.duplicateRefunds do
		low, high = math.min(low, amount), math.max(high, amount)
	end
	Config.DuplicateRefund = LobbyConfig.Gacha.duplicateRefund
	Config.RefundText = if low == math.huge
		then tostring(Config.DuplicateRefund)
		else low .. " TO " .. high
end
-- One short line per ability for the car cards (what it does).
Config.AbilityLines = {
	Dash = "BURST OF SPEED",
	Jump = "LEAP OVER CARS",
	Slam = "SMASH + SHOVE CARS",
	Ram = "CHARGE FORWARD",
	Magnet = "PULLS CARS IN",
	Shield = "BLOCKS 1 HIT",
}
Config.DailyGift = 100
Config.DailyStreak = QuestsConfig.Daily.streakCoins -- coins for login day 1, 2 ... 7
return Config
