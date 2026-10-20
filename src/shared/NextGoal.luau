--!strict
-- The one "what should I do next?" line for the lobby (pure, unit tested).
-- Closest car the player does not own (and how many coins are missing), or a mode they have not
-- played yet. Text only: the client decides where to show it. Numbers: LobbyConfig.NextGoal.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local CarConfig = sibling("CarConfig")
local LobbyConfig = sibling("LobbyConfig")
local ModesConfig = sibling("ModesConfig")
local Store = sibling("Store")

export type Input = {
	matches: number,
	coins: number,
	owned: { [string]: boolean },
	modesPlayed: { [string]: boolean },
}
export type Goal = { text: string, kind: string, carId: string?, mode: string?, missing: number? }

local NextGoal = {}

-- "CAR TAG" -> "Car Tag".
local function titleCase(s: string): string
	local out = string.gsub(string.lower(s), "(%a)(%a*)", function(first: string, rest: string)
		return string.upper(first) .. rest
	end)
	return out
end

-- The cheapest car not owned yet: id and coins still missing (nil when the player owns them all).
function NextGoal.closestCar(owned: { [string]: boolean }, coins: number): (string?, number)
	local bestId: string? = nil
	local bestPrice = math.huge
	for _, id in CarConfig.Order do
		if not owned[id] then
			local price = Store.price(id)
			if price < bestPrice then
				bestPrice = price
				bestId = id
			end
		end
	end
	if bestId == nil then
		return nil, 0
	end
	return bestId, math.max(0, bestPrice - coins)
end

-- `cfg` = LobbyConfig.NextGoal, `order` = the mode rotation (ModesConfig.Order); both overridable.
function NextGoal.compute(p: Input, cfg: any?, order: { string }?): Goal
	local c = cfg or LobbyConfig.NextGoal
	local modes = order or ModesConfig.Order
	if p.matches <= 0 then
		return { text = "Tap PLAY or step on a pad", kind = "firstMatch" }
	end
	local carId, missing = NextGoal.closestCar(p.owned, p.coins)
	local carName = if carId then CarConfig.Cars[carId].name else ""
	local unplayed: string? = nil
	for _, mode in modes do
		if not p.modesPlayed[mode] then
			unplayed = mode
			break
		end
	end

	local function carGoal(): Goal
		local text = if missing <= 0
			then `Next: {carName} - you can buy it now!`
			else `Next: {carName} - {missing} coins away`
		return { text = text, kind = "car", carId = carId, missing = missing }
	end
	local function modeGoal(mode: string): Goal
		local label = titleCase(ModesConfig.Names[mode] or mode)
		return { text = `Try {label} (not played yet)`, kind = "mode", mode = mode }
	end

	if carId ~= nil and missing <= c.nearCoins then
		return carGoal()
	end
	if unplayed ~= nil then
		return modeGoal(unplayed)
	end
	if carId ~= nil then
		return carGoal()
	end
	return { text = "You own every car!", kind = "done" }
end

return NextGoal
