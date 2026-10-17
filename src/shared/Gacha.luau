--!strict
-- Gacha rules (pure). The server passes a Random-backed rng; tests pass a fake.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local Inventory = sibling("Inventory")
local LobbyConfig = sibling("LobbyConfig")
local Weapons = sibling("Weapons")

type Profile = {
	coins: number,
	freePullUsed: boolean,
	owned: { [string]: boolean },
	daily: { freePulls: number }?, -- daily gift tries
	weapons: Weapons.WeaponData?, -- old test profiles have none (cars only)
}
export type OddsRow = { rarity: string, percent: number, cars: { string } }
-- A claw win is a car (carId set) or a weapon (weaponId set, carId is "").
export type PullResult = {
	carId: string,
	weaponId: string?,
	isNew: boolean,
	refund: number,
	free: boolean,
}

local Gacha = {}

local RARITY_ORDER = { "Common", "Rare", "Epic" }

function Gacha.oddsTable(): { OddsRow }
	local rows: { OddsRow } = {}
	for _, rarity in RARITY_ORDER do
		local cars = {}
		for _, id in CarConfig.Order do
			if LobbyConfig.Rarity[id] == rarity then
				table.insert(cars, id)
			end
		end
		table.insert(
			rows,
			{ rarity = rarity, percent = LobbyConfig.Gacha.odds[rarity] or 0, cars = cars }
		)
	end
	return rows
end

local function isFree(p: Profile): boolean
	return LobbyConfig.Gacha.firstPullFree and not p.freePullUsed
end

local function hasGift(p: Profile): boolean
	return p.daily ~= nil and p.daily.freePulls > 0
end

function Gacha.canBuy(p: Profile): (boolean, string?)
	if isFree(p) or hasGift(p) or p.coins >= LobbyConfig.Gacha.price then
		return true, nil
	end
	return false, "coins"
end

-- Mutates p. Errors if the player can't afford it (callers check canBuy first).
function Gacha.pull(p: Profile, rng: () -> number): PullResult
	local ok = Gacha.canBuy(p)
	if not ok then
		error("cannot afford gacha pull")
	end
	local free = isFree(p)
	local firstPull = free -- the very first (free) pull always gives a car
	local gift = not free and hasGift(p)
	if free then
		p.freePullUsed = true
	elseif gift then
		(p.daily :: any).freePulls -= 1
		free = true
	else
		Inventory.addCoins(p, -LobbyConfig.Gacha.price)
	end

	-- Some pulls give a weapon instead of a car.
	if
		not firstPull
		and p.weapons ~= nil
		and rng() * 100 < (LobbyConfig.Gacha.weaponChance or 0)
	then
		local weaponId = Weapons.roll(LobbyConfig.Gacha.odds, rng)
		local isNew = Weapons.grant(p :: any, weaponId)
		local refund = 0
		if not isNew then
			refund = LobbyConfig.Gacha.duplicateRefund
			Inventory.addCoins(p :: any, refund)
		end
		return { carId = "", weaponId = weaponId, isNew = isNew, refund = refund, free = free }
	end

	-- Roll rarity, skipping rarities that have no cars.
	local rows = {}
	local total = 0
	for _, row in Gacha.oddsTable() do
		if #row.cars > 0 and row.percent > 0 then
			table.insert(rows, row)
			total += row.percent
		end
	end
	local roll = rng() * total
	local chosen = rows[#rows]
	local acc = 0
	for _, row in rows do
		acc += row.percent
		if roll < acc then
			chosen = row
			break
		end
	end
	local index = math.clamp(math.floor(rng() * #chosen.cars) + 1, 1, #chosen.cars)
	local carId = chosen.cars[index]

	local isNew = Inventory.grantCar(p, carId)
	local refund = 0
	if not isNew then
		refund = LobbyConfig.Gacha.duplicateRefund
		Inventory.addCoins(p, refund)
	end
	return { carId = carId, isNew = isNew, refund = refund, free = free }
end

return Gacha
