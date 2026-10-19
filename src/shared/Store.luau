--!strict
-- Store rules (pure): what a car costs and whether a profile may buy it.
-- The server calls canBuy then buy; the client only shows prices (same functions, display only).

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

type Profile = { coins: number, owned: { [string]: boolean } }

local Store = {}

-- Price in coins, by the car's rarity (LobbyConfig.Rarity), so new cars price themselves.
function Store.price(carId: string): number
	local rarity = LobbyConfig.Rarity[carId]
	local prices = LobbyConfig.Store.prices :: { [string]: number }
	return (rarity and prices[rarity]) or LobbyConfig.Store.defaultPrice
end

-- reason: "unknown" (bad car id), "owned", or "coins".
function Store.canBuy(p: Profile, carId: any): (boolean, string?)
	if type(carId) ~= "string" or not CarConfig.isLive(carId) then
		return false, "unknown"
	end
	if p.owned[carId] then
		return false, "owned"
	end
	if p.coins < Store.price(carId) then
		return false, "coins"
	end
	return true, nil
end

-- Mutates p. Returns false (and changes nothing) if canBuy says no.
function Store.buy(p: Profile, carId: any): boolean
	local ok = Store.canBuy(p, carId)
	if not ok then
		return false
	end
	Inventory.addCoins(p, -Store.price(carId))
	return Inventory.grantCar(p, carId)
end

return Store
