--!strict
-- Car VS Car leagues (carter 10-26): Bronze, Silver, Gold, Diamond. You move up by your best
-- car's strength AND wins, and never move down. A higher league pays bigger prizes. All leagues
-- race at once, each in its own race. (Numbers are first guesses; Economy tunes them.)

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Economy = sibling("Economy")

local League = {}

League.NAMES = { "Bronze", "Silver", "Gold", "Diamond" }
League.COLORS = {
	{ 205, 127, 50 },
	{ 192, 200, 210 },
	{ 255, 200, 40 },
	{ 90, 220, 255 },
}
-- what each league needs: best car strength (speed + turning + boost, 0..300) and race wins
League.NEED = Economy.LEAGUE_NEED
League.PLACE_PAY = Economy.PLACE_PAY -- top 3 (Bronze); 4th and on get FINISH_PAY
League.FINISH_PAY = Economy.FINISH_PAY
League.PAY_MULT = Economy.PAY_MULT

function League.clamp(n: any): number
	if type(n) ~= "number" or n ~= n then
		return 1
	end
	return math.clamp(math.floor(n), 1, #League.NAMES)
end

-- The league after a race or some training: up when both needs are met, never down.
function League.next(strength: number, wins: number, now: number): number
	local best = League.clamp(now)
	for i = best + 1, #League.NAMES do
		local need = League.NEED[i]
		if strength >= need.strength and wins >= need.wins then
			best = i
		end
	end
	return best
end

-- Coins for a place in a league race (0 = didn't finish).
function League.prize(league: number, place: number): number
	if place <= 0 then
		return 0
	end
	local base = League.PLACE_PAY[place] or League.FINISH_PAY
	return math.floor(base * League.PAY_MULT[League.clamp(league)])
end

-- Top 3 get a trophy.
function League.trophy(place: number): boolean
	return place >= 1 and place <= 3
end

function League.name(n: number): string
	return League.NAMES[League.clamp(n)]
end

return League
