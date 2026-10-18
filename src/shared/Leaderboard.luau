--!strict
-- Leaderboard rules (pure, unit tested): which number goes on which board, when to send a new
-- score, and how the top rows turn into board text. Server/Leaderboards.luau does the DataStore calls.

export type Entry = { key: any, value: any } -- one OrderedDataStore row
export type Row = { rank: number, userId: number, score: number }
export type Kind = "wins" | "streak"

local Leaderboard = {}

-- Board order, OrderedDataStore name and title. Changing a store name starts a new empty board.
Leaderboard.Boards = {
	{ kind = "wins" :: Kind, store = "TopWins_v1", title = "MOST WINS" },
	{ kind = "streak" :: Kind, store = "BestStreak_v1", title = "BEST WIN STREAK" },
}

-- The score a player has on a board. `profile` needs `wins` and `progress.bestStreak`.
function Leaderboard.scoreFor(kind: Kind, profile: any): number
	local v = if kind == "wins" then profile.wins else profile.progress.bestStreak
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, 1e9)
end

-- Send only a better score, and not more often than `minGap` seconds (DataStore budget).
-- `lastScore`/`lastAt` are what this server sent before (nil = never).
function Leaderboard.shouldSubmit(
	score: number,
	lastScore: number?,
	lastAt: number?,
	now: number,
	minGap: number
): boolean
	if score <= 0 then
		return false
	end
	if lastScore ~= nil and score <= lastScore then
		return false
	end
	if lastAt ~= nil and now - lastAt < minGap then
		return false
	end
	return true
end

-- Raw sorted pages (best first) -> clean rows with ranks 1... Skips bad keys and scores < 1.
function Leaderboard.rows(entries: any, limit: number): { Row }
	local out: { Row } = {}
	if type(entries) ~= "table" then
		return out
	end
	for _, e in entries do
		if #out >= limit then
			break
		end
		local id = if type(e) == "table" then tonumber(e.key) else nil
		local score = if type(e) == "table" and type(e.value) == "number" then e.value else 0
		if id ~= nil and id > 0 and score >= 1 then
			table.insert(
				out,
				{ rank = #out + 1, userId = math.floor(id), score = math.floor(score) }
			)
		end
	end
	return out
end

local MAX_NAME = 16

-- One line of board text: "1. Name   12". `nameOf` may return nil (shown as "Player").
function Leaderboard.line(row: Row, name: string?): string
	local n = if name and name ~= "" then name else "Player"
	if #n > MAX_NAME then
		n = string.sub(n, 1, MAX_NAME)
	end
	return `{row.rank}. {n}   {row.score}`
end

return Leaderboard
