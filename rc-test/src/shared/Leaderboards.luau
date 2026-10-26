--!strict
-- The lobby leaderboards (carter's tycoon plan, 10-26): the best garage (coins a minute) and the
-- fastest lap on each race map, on three boards behind the dream-car stands. Pure (Lune tests it):
-- which boards there are, what score a value is, who is better, how a score reads, and how a board's
-- rows change when a new score comes in. The server module (Leaderboards) keeps the OrderedDataStores,
-- throttles the writes and draws the boards.

local Leaderboards = {}

Leaderboards.SHOWN = 5 -- rows on a board
Leaderboards.FETCH = 5 -- rows read from the store
Leaderboards.MIN_LAP_MS = 3000 -- a lap faster than this is a glitch, never saved
Leaderboards.MAX_LAP_MS = 600000
Leaderboards.MAX_COINS_MIN = 10000000

-- Lobby-local space (SpawnLobby: x across, +z toward the street): behind the back kerb (z = -35.5),
-- facing the street, centred on the stands. The board centre is BOARD_Y up.
Leaderboards.BOARD_Z = -37.5
Leaderboards.BOARD_Y = 8
Leaderboards.BOARD_W = 13
Leaderboards.BOARD_H = 7.5
Leaderboards.GAP = 16 -- between board centres

export type Board = {
	id: string, -- "coins" or "lap_<mapId>"
	store: string, -- OrderedDataStore name
	title: string,
	sub: string,
	low: boolean, -- true: the smaller score is better (lap times)
	x: number, -- lobby-local centre
}

export type Row = { uid: number, name: string, score: number }

-- The boards for these maps ({ id, label }): the garage board, then one lap board a map. Centred.
function Leaderboards.boards(maps: { { id: string, label: string } }): { Board }
	local list: { Board } = {
		{
			id = "coins",
			store = "RCBoard_coinsmin_v1",
			title = "BEST GARAGE",
			sub = "COINS A MINUTE",
			low = false,
			x = 0,
		},
	}
	for _, m in maps do
		table.insert(list, {
			id = "lap_" .. m.id,
			store = "RCBoard_lap_" .. m.id .. "_v1",
			title = m.label,
			sub = "FASTEST LAP",
			low = true,
			x = 0,
		})
	end
	for i, b in list do
		b.x = (i - (#list + 1) / 2) * Leaderboards.GAP
	end
	return list
end

-- The whole-number score for a value: coins a minute as they are, a lap in milliseconds. nil when
-- it can't be a real score (not a number, nothing, or a lap too quick or too slow to be true).
function Leaderboards.score(board: Board, value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if board.low then
		local ms = math.floor(value * 1000 + 0.5)
		if ms < Leaderboards.MIN_LAP_MS or ms > Leaderboards.MAX_LAP_MS then
			return nil
		end
		return ms
	end
	local n = math.floor(value)
	if n < 1 or n > Leaderboards.MAX_COINS_MIN then
		return nil
	end
	return n
end

-- Is `new` better than `old` (nil = no score yet) on this board?
function Leaderboards.better(board: Board, old: number?, new: number): boolean
	if old == nil then
		return true
	end
	if board.low then
		return new < old
	end
	return new > old
end

-- How a score reads: "1:02.345" / "12.345" for a lap, "420/min" for a garage.
function Leaderboards.format(board: Board, score: number): string
	if board.low then
		local ms = math.floor(score)
		local s = ms // 1000
		local minutes = s // 60
		if minutes > 0 then
			return string.format("%d:%02d.%03d", minutes, s % 60, ms % 1000)
		end
		return string.format("%d.%03d", s, ms % 1000)
	end
	return tostring(math.floor(score)) .. "/min"
end

-- The rows after `uid` posts `score`: their old row replaced (only when better), sorted best
-- first (ties: the earlier row keeps its place), cut to `limit`. Returns a new list.
function Leaderboards.merge(
	board: Board,
	rows: { Row },
	uid: number,
	name: string,
	score: number,
	limit: number
): { Row }
	local out: { Row } = {}
	local had: Row? = nil
	for _, r in rows do
		if r.uid == uid then
			had = r
		else
			table.insert(out, r)
		end
	end
	if had and not Leaderboards.better(board, had.score, score) then
		table.insert(out, had)
	else
		table.insert(out, { uid = uid, name = name, score = score })
	end
	-- stable sort: index breaks ties
	local order: { [Row]: number } = {}
	for i, r in out do
		order[r] = i
	end
	table.sort(out, function(a: Row, b: Row)
		if a.score ~= b.score then
			return Leaderboards.better(board, b.score, a.score)
		end
		return order[a] < order[b]
	end)
	while #out > limit do
		table.remove(out)
	end
	return out
end

-- Time for the next write? `last` = when this player's board was last written (nil = never).
function Leaderboards.due(last: number?, now: number, gap: number): boolean
	return last == nil or now - last >= gap
end

-- Where a board stands in the world: lobby-local (x, y, z) to world, for a lobby whose square's
-- middle is at world z = `originZ` and whose +z runs down the street (LobbyBuilder).
function Leaderboards.world(board: Board, originZ: number): (number, number, number)
	return board.x, Leaderboards.BOARD_Y, originZ + Leaderboards.BOARD_Z
end

return Leaderboards
