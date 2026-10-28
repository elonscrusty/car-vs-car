--!strict
-- Car VS Car leagues (carter 10-26): Bronze, Silver, Gold, Diamond. You move up by your best
-- car's strength AND your top-3 finishes (trophies: a kid who rarely wins still climbs; audit
-- C3), and never move down. A higher league pays bigger prizes. All leagues
-- race at once, each in its own race. (Numbers are first guesses; Economy tunes them.)

local League = {}

League.NAMES = { "Bronze", "Silver", "Gold", "Diamond" }
League.COLORS = {
	{ 205, 127, 50 },
	{ 192, 200, 210 },
	{ 255, 200, 40 },
	{ 90, 220, 255 },
}
-- what each league needs: best car strength (speed + turning + boost, 0..300) and top-3
-- finishes. Tuned on the economy sim (tests/cvc_economy.test.luau): a normal kid reaches Silver
-- in 25-40 min of play and Diamond in about 2 weeks of 20 min a day.
League.NEED = {
	{ strength = 0, top3 = 0 },
	{ strength = 140, top3 = 11 },
	{ strength = 215, top3 = 24 },
	{ strength = 250, top3 = 48 },
}
League.PLACE_PAY = { 100, 70, 50 } -- top 3 (Bronze); 4th and on get FINISH_PAY
League.FINISH_PAY = 20
-- raced but didn't finish (critic run 1: losing paid 0, so a lost kid got nothing for a race)
League.TRY_PAY = 10
League.PAY_MULT = { 1, 1.5, 2.2, 3 }

-- The strongest a car in league `l` can be (just under the next league's strength; nil = top
-- league, no limit). Friends race together in the lower league, with stronger cars held to this.
function League.top(l: number): number?
	local n = League.clamp(l)
	if n >= #League.NAMES then
		return nil
	end
	return League.NEED[n + 1].strength
end

function League.clamp(n: any): number
	if type(n) ~= "number" or n ~= n then
		return 1
	end
	return math.clamp(math.floor(n), 1, #League.NAMES)
end

-- The league after a race or some training: up when both needs are met, never down.
function League.next(strength: number, top3: number, now: number): number
	local best = League.clamp(now)
	for i = best + 1, #League.NAMES do
		local need = League.NEED[i]
		if strength >= need.strength and top3 >= need.top3 then
			best = i
		end
	end
	return best
end

-- Coins for a place in a league race (0 = didn't finish: the small try pay).
function League.prize(league: number, place: number): number
	local base = if place <= 0 then League.TRY_PAY else League.PLACE_PAY[place] or League.FINISH_PAY
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
