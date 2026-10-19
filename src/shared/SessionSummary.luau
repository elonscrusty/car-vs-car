--!strict
-- What a player did since joining this server (pure, unit tested). Kept in memory only, never
-- saved. The lobby sends it when the client asks for a "summary" card.

export type Data = { matches: number, coins: number, goals: number, wins: number }

local SessionSummary = {}

function SessionSummary.new(): Data
	return { matches = 0, coins = 0, goals = 0, wins = 0 }
end

local function count(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, 1e9)
end

-- One finished match. coinsEarned / goals may be nil.
function SessionSummary.record(s: Data, won: boolean, coinsEarned: any, goals: any)
	s.matches += 1
	s.coins += count(coinsEarned)
	s.goals += count(goals)
	if won then
		s.wins += 1
	end
end

-- The table sent to the client.
function SessionSummary.view(s: Data, nextGoal: string?): { [string]: any }
	return {
		matches = s.matches,
		coinsEarned = s.coins,
		goals = s.goals,
		wins = s.wins,
		nextGoal = nextGoal or "",
	}
end

return SessionSummary
