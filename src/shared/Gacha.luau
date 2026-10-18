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

type Profile = {
	coins: number,
	freePullUsed: boolean,
	owned: { [string]: boolean },
	daily: { freePulls: number }?, -- daily gift tries
}
export type OddsRow = { rarity: string, percent: number, cars: { string } }
-- A claw win is always a car (a duplicate pays coins back).
export type PullResult = {
	carId: string,
	isNew: boolean,
	refund: number,
	free: boolean,
}

local Gacha = {}

local RARITY_ORDER = CarConfig.Rarities

-- The odds the player sees AND the server rolls with. Rarities with no cars are left out and the
-- rest are re-scaled to 100 (1 decimal), so the shown numbers are always the real ones.
function Gacha.oddsTable(): { OddsRow }
	local rows: { OddsRow } = {}
	local total = 0
	for _, rarity in RARITY_ORDER do
		local cars = {}
		for _, id in CarConfig.Order do
			if LobbyConfig.Rarity[id] == rarity then
				table.insert(cars, id)
			end
		end
		local raw = LobbyConfig.Gacha.odds[rarity] or 0
		if #cars > 0 and raw > 0 then
			total += raw
			table.insert(rows, { rarity = rarity, percent = raw, cars = cars })
		end
	end
	local used = 0
	for i, row in rows do
		if i == #rows then
			row.percent = math.floor((100 - used) * 10 + 0.5) / 10
		else
			row.percent = math.floor(row.percent / total * 1000 + 0.5) / 10
			used += row.percent
		end
	end
	return rows
end

-- Coins back when the prize is a car you already own (more for rarer cars).
function Gacha.refundFor(carId: string): number
	local rarity = LobbyConfig.Rarity[carId]
	local byRarity = LobbyConfig.Gacha.duplicateRefunds :: { [string]: number }
	return (rarity and byRarity[rarity]) or LobbyConfig.Gacha.duplicateRefund
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
	local gift = not free and hasGift(p)
	if free then
		p.freePullUsed = true
	elseif gift then
		local daily = p.daily
		if daily then
			daily.freePulls -= 1
		end
		free = true
	else
		Inventory.addCoins(p, -LobbyConfig.Gacha.price)
	end

	-- Roll rarity from the same table the player is shown.
	local rows = Gacha.oddsTable()
	local total = 0
	for _, row in rows do
		total += row.percent
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
		refund = Gacha.refundFor(carId)
		Inventory.addCoins(p, refund)
	end
	return { carId = carId, isNew = isNew, refund = refund, free = free }
end

return Gacha
