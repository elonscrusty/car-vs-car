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

local BattleConfig = sibling("BattleConfig")
local CarConfig = sibling("CarConfig")
local Inventory = sibling("Inventory")
local LobbyConfig = sibling("LobbyConfig")

type Profile = {
	coins: number,
	freePullUsed: boolean,
	owned: { [string]: boolean },
	daily: { freePulls: number }?, -- daily gift tries
	progress: { gachaPity: number }?, -- pulls since the last Epic or better (profile.progress)
}
export type OddsRow = { rarity: string, percent: number, cars: { string } }
-- A claw win is always a car (a duplicate pays coins back).
export type PullResult = {
	carId: string,
	isNew: boolean,
	refund: number,
	free: boolean,
	pity: number, -- pulls since the last Epic or better, after this pull
	pityForced: boolean, -- this pull was the guaranteed Epic-or-better one
}

local Gacha = {}

local RARITY_ORDER = CarConfig.Rarities

-- What the machine hands out: the old garage cars, or (auto-battle mode) the gumball fighters.
-- The server switches this once at start; one config row per fighter is all a new car needs.
local poolIds: () -> { string } = function()
	return CarConfig.Order
end
local poolRarity: (string) -> string? = function(id)
	return LobbyConfig.Rarity[id]
end

function Gacha.useCars()
	poolIds = function()
		return CarConfig.Order
	end
	poolRarity = function(id)
		return LobbyConfig.Rarity[id]
	end
end

function Gacha.useFighters()
	poolIds = function()
		local ids = {}
		for _, id in BattleConfig.Order do
			local f = BattleConfig.Fighters[id]
			if f and f.gumball and f.enabled then
				table.insert(ids, id)
			end
		end
		return ids
	end
	poolRarity = function(id)
		local f = BattleConfig.Fighters[id]
		return if f then f.rarity else nil
	end
end

-- The odds the player sees AND the server rolls with. Rarities with no cars are left out and the
-- rest are re-scaled to 100 (1 decimal), so the shown numbers are always the real ones.
function Gacha.oddsTable(): { OddsRow }
	local rows: { OddsRow } = {}
	local total = 0
	for _, rarity in RARITY_ORDER do
		local cars = {}
		for _, id in poolIds() do
			if poolRarity(id) == rarity then
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

-- Rarities that count for the pity guarantee (the configured minimum and everything above it).
local function pityRarities(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local at = table.find(RARITY_ORDER, LobbyConfig.Gacha.pityMinRarity)
	if at == nil then
		return out
	end
	for i = at, #RARITY_ORDER do
		out[RARITY_ORDER[i]] = true
	end
	return out
end

local function pityOf(p: Profile): number
	local d = p.progress
	return if d and type(d.gachaPity) == "number" then d.gachaPity else 0
end

-- Pity bar for the UI: `count` pulls since the last Epic or better, guaranteed at `every`.
function Gacha.pityView(p: Profile): { count: number, every: number, left: number }
	local every = LobbyConfig.Gacha.pityEvery
	local count = math.clamp(pityOf(p), 0, every)
	return { count = count, every = every, left = math.max(0, every - count) }
end

export type OddsCar = { id: string, owned: boolean }
export type OddsViewRow = {
	rarity: string,
	percent: number,
	cars: { OddsCar },
	refund: number, -- coins back for a duplicate of this rarity
}

-- The odds list for the claw screen: the real odds, each car marked owned or not, and the
-- duplicate refund per rarity ("Duplicate = 25 coins back").
function Gacha.oddsView(p: { owned: { [string]: boolean } }): { OddsViewRow }
	local out: { OddsViewRow } = {}
	for _, row in Gacha.oddsTable() do
		local cars: { OddsCar } = {}
		for _, id in row.cars do
			table.insert(cars, { id = id, owned = p.owned[id] == true })
		end
		local byRarity = LobbyConfig.Gacha.duplicateRefunds :: { [string]: number }
		table.insert(out, {
			rarity = row.rarity,
			percent = row.percent,
			cars = cars,
			refund = byRarity[row.rarity] or LobbyConfig.Gacha.duplicateRefund,
		})
	end
	return out
end

-- Coins back when the prize is a car you already own (more for rarer cars).
function Gacha.refundFor(carId: string): number
	local rarity = poolRarity(carId)
	local byRarity = LobbyConfig.Gacha.duplicateRefunds :: { [string]: number }
	return (rarity and byRarity[rarity]) or LobbyConfig.Gacha.duplicateRefund
end

local function isFree(p: Profile): boolean
	return LobbyConfig.Gacha.firstPullFree and not p.freePullUsed
end

local function hasGift(p: Profile): boolean
	return p.daily ~= nil and p.daily.freePulls > 0
end

-- True while the machine still holds a car this player does not own.
function Gacha.hasNewCar(p: Profile): boolean
	for _, id in poolIds() do
		if not p.owned[id] then
			return true
		end
	end
	return false
end

function Gacha.canBuy(p: Profile): (boolean, string?)
	-- a pull that could only hand out a duplicate is never sold (duplicates give nothing)
	if not Gacha.hasNewCar(p) then
		return false, "complete"
	end
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

	-- Roll rarity from the same table the player is shown. When the pity counter is full the roll
	-- only uses the Epic-or-better rows (same relative odds).
	local rows = Gacha.oddsTable()
	local pity = pityOf(p)
	local forced = false
	if pity + 1 >= LobbyConfig.Gacha.pityEvery then
		local good = pityRarities()
		local goodRows: { OddsRow } = {}
		for _, row in rows do
			if good[row.rarity] then
				table.insert(goodRows, row)
			end
		end
		if #goodRows > 0 then
			rows = goodRows
			forced = true
		end
	end
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

	-- Epic or better (forced or lucky) resets the counter; anything else counts up.
	local gotGood = pityRarities()[poolRarity(carId) or ""] == true
	pity = if gotGood then 0 else pity + 1
	if p.progress then
		p.progress.gachaPity = pity
	end

	local isNew = Inventory.grantCar(p, carId)
	if BattleConfig.Fighters[carId] and not p.owned[carId] then
		p.owned[carId] = true
		isNew = true
	end
	local refund = 0
	if not isNew then
		refund = Gacha.refundFor(carId)
		Inventory.addCoins(p, refund)
	end
	return {
		carId = carId,
		isNew = isNew,
		refund = refund,
		free = free,
		pity = pity,
		pityForced = forced and gotGood,
	}
end

return Gacha
