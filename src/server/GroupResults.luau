--!strict
-- What a many-car match tells the lobby about each human when it ends (audit #24, #28, #32).
-- GroupMatch calls `set(player, result)` just before the player's onFinished; the lobby service
-- reads it once with `take(player)` (nil for the 1v1 modes, so old paths keep working).
-- Fields are optional per mode:
--   soccer: goals, ownGoals, touches        race: place, placeOf        tag: place, survivedSeconds, tags
--   coinsBonus = EXTRA coins on top of the normal win/lose reward (never negative).
-- No Roblox calls here, so it is unit tested.

local GroupResults = {}

export type Result = {
	mode: string,
	won: boolean,
	place: number?, -- 1 = best (race, tag)
	placeOf: number?, -- cars in the match
	goals: number?,
	ownGoals: number?,
	touches: number?,
	survivedSeconds: number?,
	tags: number?, -- tag: cars this player tagged
	kos: number?, -- fight: cars this player knocked out
	coinsBonus: number,
}

local pending: { [any]: Result } = setmetatable({}, { __mode = "k" }) :: any

function GroupResults.set(player: any, result: Result)
	pending[player] = result
end

-- Returns the result once and forgets it.
function GroupResults.take(player: any): Result?
	local r = pending[player]
	pending[player] = nil
	return r
end

-- Attribute names put on the Player (so the end screen can show "2nd of 6", "Goals: 2").
GroupResults.attributeNames = {
	"MatchPlace",
	"MatchPlaceOf",
	"MatchGoals",
	"MatchOwnGoals",
	"MatchTags",
	"MatchKos",
	"MatchSurvived",
	"MatchCoinsBonus",
	"MatchOut",
}

-- name -> value for the Player attributes of a result (only the fields that exist).
function GroupResults.attributes(r: Result): { [string]: number }
	local out: { [string]: number } = {}
	if r.place then
		out.MatchPlace = r.place
	end
	if r.placeOf then
		out.MatchPlaceOf = r.placeOf
	end
	if r.goals then
		out.MatchGoals = r.goals
	end
	if r.ownGoals then
		out.MatchOwnGoals = r.ownGoals
	end
	if r.tags then
		out.MatchTags = r.tags
	end
	if r.kos then
		out.MatchKos = r.kos
	end
	if r.survivedSeconds then
		out.MatchSurvived = math.floor(r.survivedSeconds + 0.5)
	end
	out.MatchCoinsBonus = math.max(0, r.coinsBonus)
	return out
end

return GroupResults
