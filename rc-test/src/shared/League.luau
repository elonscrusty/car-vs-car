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

-- ===== Car VS Car SMASH (plans/smash/MASTER-PLAN.md): leagues by smashes and place =====
-- Every match gives trophies: a few for the place, one per smash (up to SMASH_TROPHY_CAP, so
-- farming one match can't skip a league). The league only needs trophies now (no training, so
-- no car strength). First guesses for a normal kid (~5 trophies a 3-min match, about 1.5 a
-- minute; tests/smash_save): Silver ~35 min, Gold ~1.5 h, Diamond about day 12 at 20 min a day, the
-- same pace as the racing game's sim (Silver 34 min, Gold 85 min, Diamond day 10.6).
League.SMASH_NEED = { 0, 55, 140, 400 }
League.PLACE_TROPHIES = { 3, 2, 1 } -- 1st, 2nd, 3rd; 4th and on get 0
League.SMASH_TROPHY_CAP = 5
-- match coins: League.PLACE_PAY for the top 3, MATCH_PAY for 4th and on, plus SMASH_PAY a
-- smash; all times the league's PAY_MULT (first guesses, Economy tunes them)
League.MATCH_PAY = 25
League.SMASH_PAY = 5
League.MAX_SMASHES = 99 -- one match can't report more than this (a broken count can't pay a lot)

local function count(n: any, most: number): number
	if type(n) ~= "number" or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, most)
end

-- Trophies for one match: place 1.. (0 = left before the end: nothing).
function League.matchTrophies(place: number, smashes: number): number
	local p = count(place, 99)
	if p <= 0 then
		return 0
	end
	return (League.PLACE_TROPHIES[p] or 0)
		+ math.min(count(smashes, League.MAX_SMASHES), League.SMASH_TROPHY_CAP)
end

-- Coins for one match in league `league` (place 0 = left before the end: nothing).
function League.matchPay(league: number, place: number, smashes: number): number
	local p = count(place, 99)
	if p <= 0 then
		return 0
	end
	local base = (League.PLACE_PAY[p] or League.MATCH_PAY)
		+ League.SMASH_PAY * count(smashes, League.MAX_SMASHES)
	return math.floor(base * League.PAY_MULT[League.clamp(league)])
end

-- The league for this many trophies: up when the need is met, never down.
function League.byTrophies(trophies: number, now: number): number
	local best = League.clamp(now)
	local t = count(trophies, math.huge)
	for i = best + 1, #League.NAMES do
		if t >= League.SMASH_NEED[i] then
			best = i
		end
	end
	return best
end

export type MatchSave = {
	coins: number,
	trophies: number,
	league: number,
	smashes: number,
	matches: number,
	matchWins: number,
}
export type MatchResult = { coins: number, trophies: number, from: number, to: number }

-- One match is over for this player (the server's MatchRunner calls it with the server's own
-- place and smash count, never the client's): pays the coins, adds trophies and totals, moves
-- the league up. Pay uses the league the match was played in. `to > from` = league-up moment.
function League.matchDone(d: MatchSave, place: number, smashes: number): MatchResult
	local p = count(place, 99)
	local s = count(smashes, League.MAX_SMASHES)
	local from = League.clamp(d.league)
	local coins = League.matchPay(from, p, s)
	local trophies = League.matchTrophies(p, s)
	d.coins = math.min(d.coins + coins, 1e12) -- (Profile.MAX_COINS)
	d.trophies += trophies
	d.smashes += s
	if p > 0 then
		d.matches += 1
		if p == 1 then
			d.matchWins += 1
		end
	end
	d.league = League.byTrophies(d.trophies, from)
	return { coins = coins, trophies = trophies, from = from, to = d.league }
end

function League.name(n: number): string
	return League.NAMES[League.clamp(n)]
end

-- The league-up ceremony (vault "Reward Moments and Celebrations": each step up adds layers, it
-- doesn't just get louder; the top layers are kept for the top league). Silver: tint, beam,
-- rays, confetti. Gold adds a flash and fireworks over your car. Diamond adds a shake, more
-- fireworks and TOP LEAGUE!. `hold` = seconds before AWESOME! shows (buttons come last).
export type Ceremony = {
	to: number,
	name: string, -- "GOLD LEAGUE"
	pay: string, -- "Races pay 2.2x coins!"
	color: { number },
	confetti: number, -- extra confetti bits on top of the screen's own
	flash: boolean,
	fireworks: number, -- bursts over your car after the screen
	shake: boolean,
	top: boolean,
	hold: number,
}

League.CEREMONY = {
	[2] = { confetti = 10, flash = false, fireworks = 0, shake = false, hold = 0.9 },
	[3] = { confetti = 22, flash = true, fireworks = 3, shake = false, hold = 1.1 },
	[4] = { confetti = 36, flash = true, fireworks = 6, shake = true, hold = 1.3 },
}

-- "Races pay 1.5x coins!" (the real reward of a new league)
function League.payWords(n: number): string
	return `Races pay {string.format("%g", League.PAY_MULT[League.clamp(n)])}x coins!`
end

-- The ceremony for going from league `from` to `to` (a jump of two shows the higher one), or nil
-- when it isn't a step up.
function League.ceremony(from: number, to: number): Ceremony?
	local a, b = League.clamp(from), League.clamp(to)
	local layers = League.CEREMONY[b]
	if b <= a or not layers then
		return nil
	end
	return {
		to = b,
		name = `{string.upper(League.name(b))} LEAGUE`,
		pay = League.payWords(b),
		color = League.COLORS[b],
		confetti = layers.confetti,
		flash = layers.flash,
		fireworks = layers.fireworks,
		shake = layers.shake,
		top = b == #League.NAMES,
		hold = layers.hold,
	}
end

return League
