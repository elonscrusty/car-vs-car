--!strict
local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local CarPower = require("../src/shared/CarPower")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local PickChoices = require("../src/shared/PickChoices")
local QuestsConfig = require("../src/shared/QuestsConfig")
local Store = require("../src/shared/Store")

local test, eq, truthy = H.test, H.eq, H.truthy

print("LaunchRoster")

test("the roster is ~12 real cars, starts with the free starter, spans all rarities", function()
	local r = CarConfig.LaunchRoster
	truthy(#r >= 10 and #r <= 14, "size")
	eq(r[1], LobbyConfig.StarterCars[1])
	local rarities, seen = {}, {}
	for _, id in r do
		truthy(CarConfig.Cars[id] ~= nil, id)
		truthy(not seen[id], id .. " twice")
		seen[id] = true
		rarities[CarConfig.Cars[id].rarity] = true
	end
	for _, name in CarConfig.Rarities do
		truthy(rarities[name], name .. " missing")
	end
end)

test("with the flag off only roster cars are live; all ids stay valid", function()
	eq(CarConfig.useFullRoster, false)
	eq(#CarConfig.Order, #CarConfig.LaunchRoster)
	for _, id in CarConfig.Order do
		truthy(table.find(CarConfig.LaunchRoster, id) ~= nil, id)
		truthy(CarConfig.isLive(id))
	end
	eq(CarConfig.isLive("Van"), false)
	truthy(CarConfig.get("Van") ~= nil) -- still a real car (saves, remotes)
	eq(#CarConfig.FullOrder, 30)
end)

test("claw odds, store, quests and picks exclude hidden cars; odds sum to 100", function()
	local sum = 0
	for _, row in Gacha.oddsTable() do
		sum += row.percent
		for _, id in row.cars do
			truthy(CarConfig.isLive(id), id .. " in claw")
		end
	end
	eq(sum, 100)
	local p = Inventory.default()
	p.coins = 100000
	local ok, why = Store.canBuy(p, "Van")
	eq(ok, false)
	eq(why, "unknown")
	ok = Store.canBuy(p, "Compact")
	truthy(ok)
	for _, def in QuestsConfig.Catalog do
		if def.carId then
			truthy(CarConfig.isLive(def.carId), def.id)
		end
	end
	local owned = Inventory.ownedList(p)
	for _, id in
		PickChoices.choose(owned, 3, function()
			return 0.5
		end)
	do
		truthy(CarConfig.isLive(id))
	end
end)

test("a hidden car a player already owns survives loading a save", function()
	local p = Inventory.migrate({ owned = { Van = true, Sedan = true } })
	eq(p.owned.Van, true)
	eq(Inventory.owns(p, "Van"), true)
end)

test("odds re-scale to 100 when a rarity has no live cars", function()
	local saved = CarConfig.Order
	CarConfig.Order = { "Sedan", "Kart" } -- Common + Rare only
	local rows = Gacha.oddsTable()
	CarConfig.Order = saved
	eq(#rows, 2)
	local sum = 0
	for _, row in rows do
		sum += row.percent
	end
	eq(sum, 100)
	truthy(math.abs(rows[1].percent - 55 / 83 * 100) < 0.1)
end)

test("each roster car has its own stats and a role line", function()
	local sigs: { [string]: string } = {}
	for _, id in CarConfig.LaunchRoster do
		local c = CarConfig.Cars[id]
		truthy(#c.blurb > 3 and #c.blurb <= 40, id .. " role")
		local sig =
			table.concat({ c.hp, c.mass, c.maxSpeed, c.accel, c.turnRate, c.damageMult }, "/")
		truthy(sigs[sig] == nil, id .. " has the same stats as " .. tostring(sigs[sig]))
		sigs[sig] = id
		eq(string.find(c.blurb, "Common ", 1, true), nil, id .. " still has a placeholder blurb")
	end
end)

test("no roster car's power is over 20% above the average of its rarity", function()
	for _, rarity in CarConfig.Rarities do
		local list = {}
		for _, id in CarConfig.LaunchRoster do
			if CarConfig.Cars[id].rarity == rarity then
				table.insert(list, CarConfig.Cars[id])
			end
		end
		truthy(#list > 0, rarity)
		local avg = CarPower.average(list, CarConfig.PowerWeights)
		for _, c in list do
			local score = CarPower.score(c, CarConfig.PowerWeights)
			truthy(score <= avg * (1 + CarConfig.PowerTolerance), `{c.name} {score} vs avg {avg}`)
		end
	end
end)

test("CarPower is a plain weighted sum", function()
	local w = { hp = 1, mass = 2, maxSpeed = 3, accel = 4, turnRate = 5, damageMult = 6 }
	local one = { hp = 1, mass = 1, maxSpeed = 1, accel = 1, turnRate = 1, damageMult = 1 }
	eq(CarPower.score(one, w), 21)
	eq(CarPower.average({}, w), 0)
end)

test("a save that owns removed blocky cars drops them and gets coins back", function()
	local p =
		Inventory.migrate({ coins = 10, owned = { Heavy = true, Spike = true, Sedan = true } })
	eq(p.owned.Heavy, nil)
	eq(p.owned.Spike, nil)
	eq(p.owned.Sedan, true)
	eq(p.coins, 10 + LobbyConfig.Store.prices.Common + LobbyConfig.Store.prices.Epic)
	-- only blocky cars: the starter is granted so the player is never car-less
	local q = Inventory.migrate({ owned = { Heavy = true } })
	eq(Inventory.owns(q, "Sedan"), true)
	eq(q.coins, LobbyConfig.Store.prices.Common)
	-- a build/paint/progress entry for a removed car does not crash loading
	local r = Inventory.migrate({
		owned = { Heavy = true },
		build = { carId = "Heavy" },
		paint = { equipped = { Heavy = { color = "blue" } } },
	})
	eq(r.build.carId, "Sedan")
end)
