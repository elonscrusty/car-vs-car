--!strict
local H = require("./harness")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local Weapons = require("../src/shared/Weapons")
local WeaponsConfig = require("../src/shared/WeaponsConfig")

print("Weapons")

local function fixed(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

H.test("there are 8 weapons and every one is complete", function()
	H.eq(#WeaponsConfig.Order, 8)
	for _, id in WeaponsConfig.Order do
		local w = WeaponsConfig.get(id)
		H.truthy(w ~= nil, id)
		local def = w :: WeaponsConfig.WeaponDef
		H.eq(def.id, id)
		H.truthy(def.kind == "passive" or def.kind == "active", id)
		H.truthy(def.rarity == "Common" or def.rarity == "Rare" or def.rarity == "Epic", id)
		if def.kind == "active" then
			H.truthy(def.cooldown > 0, id .. " cooldown")
		end
	end
	H.truthy(WeaponsConfig.get(WeaponsConfig.Starter) ~= nil)
	H.eq(WeaponsConfig.get("Nope"), nil)
	H.eq(WeaponsConfig.get(5), nil)
end)

H.test("new profiles own and wear the starter weapon", function()
	local p = Inventory.default()
	H.eq(p.weapons.equipped, WeaponsConfig.Starter)
	H.eq(#Weapons.ownedList(p.weapons), 1)
end)

H.test("clean sanitizes garbage and never equips what is not owned", function()
	for _, bad in { "x", 5, false, {}, { owned = 3, equipped = 9 } } do
		local d = Weapons.clean(bad)
		H.eq(d.equipped, WeaponsConfig.Starter)
		H.truthy(d.owned[WeaponsConfig.Starter])
	end
	local d =
		Weapons.clean({ owned = { Axe = true, Ghost = true, Bomb = "yes" }, equipped = "Bomb" })
	H.truthy(d.owned.Axe)
	H.eq(d.owned.Ghost, nil)
	H.eq(d.owned.Bomb, nil)
	H.eq(d.equipped, WeaponsConfig.Starter)
	H.eq(Weapons.clean({ owned = { Axe = true }, equipped = "Axe" }).equipped, "Axe")
	H.eq(Inventory.migrate({}).weapons.equipped, WeaponsConfig.Starter) -- old saves
end)

H.test("equip needs an owned weapon", function()
	local p = Inventory.default()
	local ok, why = Weapons.equip(p, "Axe")
	H.eq(ok, false)
	H.eq(why, "notowned")
	ok, why = Weapons.equip(p, "Ghost")
	H.eq(why, "unknown")
	ok, why = Weapons.equip(p, nil)
	H.eq(why, "unknown")
	H.eq(Weapons.grant(p, "Axe"), true)
	H.eq(Weapons.grant(p, "Axe"), false)
	H.eq(Weapons.grant(p, "Ghost"), false)
	ok = Weapons.equip(p, "Axe")
	H.eq(ok, true)
	H.eq(p.weapons.equipped, "Axe")
end)

H.test("ownedList follows the menu order", function()
	local p = Inventory.default()
	Weapons.grant(p, "Magnet")
	Weapons.grant(p, "Axe")
	H.eq(table.concat(Weapons.ownedList(p.weapons), ","), "Saw,Axe,Magnet")
end)

H.test("roll maps rarity and index", function()
	local odds = LobbyConfig.Gacha.odds
	H.eq(Weapons.roll(odds, fixed(0.0, 0.0)), "Saw") -- Common, first
	H.eq(Weapons.roll(odds, fixed(0.0, 0.99)), "Bomb") -- Common, last of Saw/Axe/Bomb
	H.eq(Weapons.roll(odds, fixed(0.7, 0.0)), "Rocket") -- Rare, first
	H.eq(Weapons.roll(odds, fixed(0.99, 0.99)), "Flame") -- Epic, last
end)

H.test("a pull can give a weapon (never on the first free pull)", function()
	local oldChance = LobbyConfig.Gacha.weaponChance
	LobbyConfig.Gacha.weaponChance = 40 -- weapons are off by default now
	local first = Inventory.default()
	local r = Gacha.pull(first, fixed(0.0, 0.99, 0)) -- weapon roll 0.0 would win, but it is the free pull
	H.eq(r.free, true)
	H.eq(r.weaponId, nil)
	H.truthy(r.carId ~= "")

	local p = Inventory.default()
	p.freePullUsed = true
	p.coins = 1000
	local w = Gacha.pull(p, fixed(0.0, 0.7, 0.0)) -- weapon, Rare, first = Rocket
	H.eq(w.weaponId, "Rocket")
	H.eq(w.carId, "")
	H.eq(w.isNew, true)
	H.eq(w.refund, 0)
	H.truthy(p.weapons.owned.Rocket)
	H.eq(p.coins, 1000 - LobbyConfig.Gacha.price)
	local dup = Gacha.pull(p, fixed(0.0, 0.7, 0.0))
	H.eq(dup.weaponId, "Rocket")
	H.eq(dup.isNew, false)
	H.eq(dup.refund, LobbyConfig.Gacha.duplicateRefund)
	LobbyConfig.Gacha.weaponChance = oldChance
end)
