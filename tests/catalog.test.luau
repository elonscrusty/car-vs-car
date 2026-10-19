--!strict
local H = require("./harness")
local Abilities = require("../src/shared/Abilities")
local Build = require("../src/shared/Build")
local BuildConfig = require("../src/shared/BuildConfig")
local CarCatalog = require("../src/shared/CarCatalog")
local CarConfig = require("../src/shared/CarConfig")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local Store = require("../src/shared/Store")

local test, eq, truthy = H.test, H.eq, H.truthy

print("CarCatalog")

test("the pack has 30 cars with unique ids, names and models", function()
	eq(#CarCatalog.Entries, 30)
	local ids, names, models = {}, {}, {}
	for i, e in CarCatalog.Entries do
		truthy(not ids[e.id], "duplicate id " .. e.id)
		truthy(not names[e.name], "duplicate name " .. e.name)
		truthy(not models[e.model], "duplicate model " .. e.model)
		ids[e.id], names[e.name], models[e.model] = true, true, true
		truthy(
			string.match(e.model, `^{string.format("%02d", i)}_`) ~= nil,
			e.model .. " is not #" .. i
		)
	end
end)

test("every car is registered with a rarity, a real ability and a model", function()
	eq(#CarConfig.FullOrder, 30)
	for _, id in CarConfig.Order do
		local c = CarConfig.get(id)
		truthy(c ~= nil, id)
		local car = c :: any
		truthy(table.find(CarConfig.Rarities, car.rarity), id .. " rarity")
		truthy(Abilities.forCar(car) ~= nil, id .. " ability")
		eq(LobbyConfig.Rarity[id], car.rarity)
	end
	for _, e in CarCatalog.Entries do
		eq((CarConfig.get(e.id) :: any).model, e.model)
	end
end)

test("catalog cars share the neutral stats until a row overrides them", function()
	for _, e in CarCatalog.Entries do
		if e.stats == nil then
			local c = CarConfig.Cars[e.id]
			eq(c.hp, CarCatalog.Neutral.hp, e.id)
			eq(c.mass, CarCatalog.Neutral.mass, e.id)
			eq(c.maxSpeed, CarCatalog.Neutral.maxSpeed, e.id)
		end
	end
	local custom = CarCatalog.statsFor({
		id = "X",
		name = "X",
		model = "x",
		rarity = "Rare",
		ability = "Dash",
		rgb = { 1, 2, 3 },
		stats = { hp = 999 },
	})
	eq(custom.hp, 999)
	eq(custom.mass, CarCatalog.Neutral.mass)
end)

test("all six abilities and all four rarities are used", function()
	local abilities, rarities = {}, {}
	for _, id in CarConfig.FullOrder do
		local c = CarConfig.Cars[id]
		abilities[c.ability] = true
		rarities[c.rarity] = true
	end
	for _, a in { "Dash", "Shield", "Slam", "Ram", "Magnet", "Jump" } do
		truthy(abilities[a], a .. " unused")
	end
	for _, r in CarConfig.Rarities do
		truthy(rarities[r], r .. " unused")
	end
end)

test("get rejects ids that are not cars", function()
	eq(CarConfig.get("Nope"), nil)
	eq(CarConfig.get(7), nil)
	eq(CarConfig.get(nil), nil)
	truthy(CarConfig.get("Sedan") ~= nil)
end)

test("claw odds list every car once and sum to 100", function()
	local seen, sum = {}, 0
	for _, row in Gacha.oddsTable() do
		sum += row.percent
		truthy(#row.cars > 0, row.rarity .. " has no cars")
		for _, id in row.cars do
			truthy(not seen[id], id .. " listed twice")
			seen[id] = true
		end
	end
	eq(sum, 100)
	for _, id in CarConfig.Order do
		truthy(seen[id], id .. " missing from the claw")
	end
end)

test("the claw can give any car and a duplicate pays coins", function()
	local got = {}
	for _, row in Gacha.oddsTable() do
		for i = 1, #row.cars do
			local p = Inventory.default()
			p.freePullUsed = true
			p.coins = 1000
			local roll = row.percent / 100
			local before = 0
			for _, other in Gacha.oddsTable() do
				if other.rarity == row.rarity then
					break
				end
				before += other.percent / 100
			end
			local n = 0
			local rolls = { before + roll / 2, (i - 0.5) / #row.cars }
			local r = Gacha.pull(p, function()
				n += 1
				return rolls[n] or 0
			end)
			got[r.carId] = true
			eq(CarConfig.Cars[r.carId].rarity, row.rarity)
		end
	end
	for _, id in CarConfig.Order do
		truthy(got[id], id .. " can not be won")
	end
	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = LobbyConfig.Gacha.price
	local r = Gacha.pull(p, function()
		return 0
	end)
	eq(r.carId, "Sedan")
	eq(r.isNew, false)
	eq(p.coins, LobbyConfig.Gacha.duplicateRefunds.Common)
end)

test("every car has a store price, Legendary the highest", function()
	for _, id in CarConfig.Order do
		truthy(Store.price(id) > 0, id)
	end
	local prices = LobbyConfig.Store.prices
	truthy(
		prices.Legendary > prices.Epic and prices.Epic > prices.Rare and prices.Rare > prices.Common
	)
end)

test("wheel, engine and armor upgrades work on every car", function()
	local parts = Build.default()
	for _, slot in BuildConfig.Slots do
		parts.levels[slot] = BuildConfig.MaxLevel
	end
	for _, id in CarConfig.Order do
		local base = CarConfig.Cars[id]
		local plain = Build.stats(base, Build.default())
		local maxed = Build.stats(base, parts)
		truthy(maxed.hp >= plain.hp and maxed.maxSpeed >= plain.maxSpeed, id)
		eq(maxed.ability, base.ability)
		eq(maxed.rarity, base.rarity)
		eq(maxed.model, base.model)
		truthy(Build.power(base, parts) >= Build.power(base, Build.default()), id)
	end
end)

test("a saved build can wear a pack car", function()
	local b = Build.clean({ carId = "Semi" })
	eq(b.carId, "Semi")
	local p = Inventory.default()
	p.owned.Semi = true
	local ok = Build.setCar(p :: any, "Semi")
	eq(ok, true)
	eq(p.build.carId, "Semi")
	eq(Build.setCar(p :: any, "Nope"), false)
end)
