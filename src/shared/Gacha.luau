--!strict
-- Gacha rules (pure). The server passes a Random-backed rng; tests pass a fake.

local CarConfig = require("./CarConfig")
local Inventory = require("./Inventory")
local LobbyConfig = require("./LobbyConfig")

export type OddsRow = { rarity: string, percent: number, cars: { string } }
export type PullResult = { carId: string, isNew: boolean, refund: number, free: boolean }

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

local function isFree(p: Inventory.Profile): boolean
	return LobbyConfig.Gacha.firstPullFree and not p.freePullUsed
end

function Gacha.canBuy(p: Inventory.Profile): (boolean, string?)
	if isFree(p) or p.coins >= LobbyConfig.Gacha.price then
		return true, nil
	end
	return false, "coins"
end

-- Mutates p. Errors if the player can't afford it (callers check canBuy first).
function Gacha.pull(p: Inventory.Profile, rng: () -> number): PullResult
	local ok = Gacha.canBuy(p)
	if not ok then
		error("cannot afford gacha pull")
	end
	local free = isFree(p)
	if free then
		p.freePullUsed = true
	else
		Inventory.addCoins(p, -LobbyConfig.Gacha.price)
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
