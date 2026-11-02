--!strict
-- Each bot kart in a round gets its own paint so they are easy to tell apart (carter 10-30 picked
-- "Candy Bright"). Look-only: the server names the paint on the model, every screen paints it.

local BotPaints = {}

BotPaints.LIST = {
	{ 255, 59, 59 }, -- red
	{ 255, 138, 31 }, -- orange
	{ 255, 210, 31 }, -- yellow
	{ 95, 224, 58 }, -- lime
	{ 34, 211, 238 }, -- cyan
	{ 47, 107, 255 }, -- blue
	{ 166, 75, 255 }, -- purple
	{ 255, 95, 176 }, -- pink
}

-- The paint for the n-th bot of a round (1, 2, 3...); it wraps if a round ever has more bots
-- than paints.
function BotPaints.forBot(n: number): { number }
	return BotPaints.LIST[(math.max(n, 1) - 1) % #BotPaints.LIST + 1]
end

return BotPaints
