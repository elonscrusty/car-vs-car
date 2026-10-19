--!strict
-- Round and match scoring for the 1v1 auto-battle (pure, unit tested).
-- Sides are "a" and "b". A drawn round still uses up one of the rounds.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

export type Side = "a" | "b"
export type Outcome = "a" | "b" | "draw"
export type Series = {
	round: number, -- the round being played (1..rounds); stays at the last one when over
	winsA: number,
	winsB: number,
	results: { Outcome }, -- one per finished round
	over: boolean,
	winner: Outcome?, -- "a" | "b" | "draw" once over
	forfeit: Side?, -- the side that left, if the match ended by leaving
}

local BattleSeries = {}

function BattleSeries.new(): Series
	return {
		round = 1,
		winsA = 0,
		winsB = 0,
		results = {},
		over = false,
		winner = nil,
		forfeit = nil,
	}
end

-- Who won one fight. HP values are what is left; timedOut = the clock ran out.
-- Both at zero in the same update = draw. Zero HP loses. On timeout the higher HP percent wins.
function BattleSeries.roundOutcome(
	hpA: number,
	maxA: number,
	hpB: number,
	maxB: number,
	timedOut: boolean
): Outcome?
	local deadA, deadB = hpA <= 0, hpB <= 0
	if deadA and deadB then
		return "draw"
	elseif deadA then
		return "b"
	elseif deadB then
		return "a"
	end
	if not timedOut then
		return nil -- the fight goes on
	end
	local pctA = hpA / math.max(maxA, 1)
	local pctB = hpB / math.max(maxB, 1)
	if math.abs(pctA - pctB) < 1e-6 then
		return "draw"
	end
	return if pctA > pctB then "a" else "b"
end

-- Adds one finished round. Does nothing once the match is over (so a late event cannot score twice).
function BattleSeries.record(s: Series, outcome: Outcome): boolean
	if s.over then
		return false
	end
	table.insert(s.results, outcome)
	if outcome == "a" then
		s.winsA += 1
	elseif outcome == "b" then
		s.winsB += 1
	end
	local needed = BattleConfig.Series.winsNeeded
	local rounds = BattleConfig.Series.rounds
	if s.winsA >= needed then
		s.over, s.winner = true, "a"
	elseif s.winsB >= needed then
		s.over, s.winner = true, "b"
	elseif #s.results >= rounds then
		s.over = true
		s.winner = if s.winsA > s.winsB then "a" elseif s.winsB > s.winsA then "b" else "draw"
	else
		s.round = #s.results + 1
	end
	return true
end

-- The side `leaver` left: the other side wins the match. Only counts once.
function BattleSeries.forfeit(s: Series, leaver: Side): boolean
	if s.over then
		return false
	end
	s.over = true
	s.forfeit = leaver
	s.winner = if leaver == "a" then "b" else "a"
	return true
end

function BattleSeries.other(side: Side): Side
	return if side == "a" then "b" else "a"
end

-- The finished match seen from one side: "win" | "loss" | "draw".
function BattleSeries.resultFor(s: Series, side: Side): string?
	if not s.over or s.winner == nil then
		return nil
	end
	if s.winner == "draw" then
		return "draw"
	end
	return if s.winner == side then "win" else "loss"
end

return BattleSeries
