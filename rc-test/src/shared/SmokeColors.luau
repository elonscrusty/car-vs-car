--!strict
-- Tyre smoke colours (looks only, no change to how the car drives). White is free; the rest open
-- up as the player's star count reaches each one's price. Pure data, so Lune can test it.

export type SmokeColor = { name: string, rgb: { number }, stars: number }

local SmokeColors = {}

SmokeColors.LIST = {
	{ name = "WHITE", rgb = { 235, 235, 235 }, stars = 0 },
	{ name = "RED", rgb = { 235, 60, 50 }, stars = 3 },
	{ name = "BLUE", rgb = { 60, 130, 245 }, stars = 6 },
	{ name = "GREEN", rgb = { 70, 220, 90 }, stars = 10 },
	{ name = "YELLOW", rgb = { 255, 215, 50 }, stars = 15 },
	{ name = "PINK", rgb = { 255, 110, 200 }, stars = 20 },
	{ name = "PURPLE", rgb = { 150, 80, 240 }, stars = 30 },
	{ name = "BLACK", rgb = { 35, 35, 40 }, stars = 40 },
} :: { SmokeColor }

function SmokeColors.isOpen(index: number, stars: number, all: boolean?): boolean
	local c = SmokeColors.LIST[index]
	return c ~= nil and (all == true or stars >= c.stars)
end

-- The next open colour after `index` (wraps round to white, which is always open).
function SmokeColors.nextOpen(index: number, stars: number, all: boolean?): number
	local n = #SmokeColors.LIST
	for step = 1, n do
		local i = (index - 1 + step) % n + 1
		if SmokeColors.isOpen(i, stars, all) then
			return i
		end
	end
	return 1
end

-- The cheapest colour still locked, or nil when all are open.
function SmokeColors.nextLocked(stars: number): SmokeColor?
	for _, c in SmokeColors.LIST do
		if stars < c.stars then
			return c
		end
	end
	return nil
end

return SmokeColors
