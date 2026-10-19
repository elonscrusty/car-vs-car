--!strict
-- Leaderboard rules (pure, unit tested): which number goes on which board, when to send a new
-- score, and how the top rows turn into board text. Server/Leaderboards.luau does the DataStore calls.

export type Entry = { key: any, value: any } -- one OrderedDataStore row
export type Row = { rank: number, userId: number, score: number }
export type Kind = "wins" | "streak" | "weekly" | "smashes"

local Leaderboard = {}

-- Board order, OrderedDataStore name and title. Changing a store name starts a new empty board.
Leaderboard.Boards = {
	{ kind = "wins" :: Kind, store = "TopWins_v1", title = "MOST WINS" },
	{ kind = "streak" :: Kind, store = "BestStreak_v1", title = "BEST WIN STREAK" },
}

-- Weekly wins board. Its OrderedDataStore name carries the week number, so each week starts empty
-- and old weeks just stop being read. Weeks run Monday 00:00 UTC to Sunday 23:59 UTC.
Leaderboard.Weekly =
	{ kind = "weekly" :: Kind, store = "TopWinsWeekly_v1", title = "WINS THIS WEEK" }
-- Smashes (knock-outs) this week. Same weekly reset as the wins board.
Leaderboard.Smashes =
	{ kind = "smashes" :: Kind, store = "TopSmashesWeekly_v1", title = "SMASHES THIS WEEK" }
Leaderboard.WEEK_SECONDS = 604800
local MONDAY_OFFSET = 345600 -- 1970-01-01 was a Thursday; the first Monday is 4 days later

-- Whole weeks since the first Monday of 1970 (UTC). Bad or negative time gives 0.
function Leaderboard.weekIndex(unixSeconds: number): number
	if type(unixSeconds) ~= "number" or unixSeconds ~= unixSeconds then
		return 0
	end
	return math.max(0, math.floor((unixSeconds - MONDAY_OFFSET) / Leaderboard.WEEK_SECONDS))
end

-- "TopWinsWeekly_v1_w2900" for week 2900.
function Leaderboard.weeklyStore(week: number): string
	return `{Leaderboard.Weekly.store}_w{math.max(0, math.floor(week))}`
end

-- "TopSmashesWeekly_v1_w2900" for week 2900.
function Leaderboard.smashesStore(week: number): string
	return `{Leaderboard.Smashes.store}_w{math.max(0, math.floor(week))}`
end

-- New stored weekly score after `add` more wins (junk old values count as 0).
function Leaderboard.addWins(old: any, add: number): number
	local base = if type(old) == "number" and old == old and old >= 0 then math.floor(old) else 0
	return math.min(base + math.max(0, math.floor(add)), 1e9)
end

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
