--!strict
-- Which cars the lobby shows (pure, unit tested): the car parked at each player's spot, the rarest
-- gumball car on the workshop stage and the three cars in the shop.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local RANK: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

local LobbyCars = {}

local function rankOf(id: string): number
	local f = BattleConfig.Fighters[id]
	return if f then RANK[f.rarity] or 0 else 0
end

-- The rarest car this player has (a free starter counts as owned). Ties go to catalog order.
function LobbyCars.bestOwned(owned: { [string]: boolean }): string
	local best: string? = nil
	for _, id in BattleConfig.Order do
		local f = BattleConfig.Fighters[id]
		if f and f.enabled and (not f.gumball or owned[id] == true) then
			if best == nil or rankOf(id) > rankOf(best) then
				best = id
			end
		end
	end
	return best or BattleConfig.Order[1]
end

-- The rarest car the gumball machine can drop (nil if it drops none).
function LobbyCars.rarestGumball(): string?
	local best: string? = nil
	for _, id in BattleConfig.Order do
		local f = BattleConfig.Fighters[id]
		if f and f.enabled and f.gumball and (best == nil or rankOf(id) > rankOf(best)) then
			best = id
		end
	end
	return best
end

-- The cars standing in the shop: the first three battle cars (Ram Truck, Cannon Van, Saw Buggy).
function LobbyCars.shopDisplay(): { string }
	local out: { string } = {}
	for _, id in BattleConfig.Order do
		local f = BattleConfig.Fighters[id]
		if f and f.enabled and #out < 3 then
			table.insert(out, id)
		end
	end
	return out
end

-- Is this pull worth telling everyone about? Epic and Legendary are.
function LobbyCars.isRarePull(carId: string): boolean
	return rankOf(carId) >= RANK.Epic
end

function LobbyCars.nameOf(carId: string): string
	local f = BattleConfig.Fighters[carId]
	return if f then f.name else carId
end

return LobbyCars
