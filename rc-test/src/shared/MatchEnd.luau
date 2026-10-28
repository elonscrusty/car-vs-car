--!strict
-- Smash match end screen data (plans/smash/MASTER-PLAN.md: 1st/2nd/3rd + coins + PLAY AGAIN,
-- which presses itself after 10 s). The server sends ReplicatedStorage.MatchResult to each player:
--   { places = { { name, smashes, userId? (nil = bot), carId? } } (best first, every kart),
--     coins = what this player earned, nextAt? = server time the next match starts }
-- MatchEnd.payload builds that (server), MatchEnd.read checks it (client: junk never errors).

local MatchEnd = {}

MatchEnd.AUTO = 10 -- seconds until PLAY AGAIN presses itself
MatchEnd.MAX_ROWS = 12 -- a match has at most 12 karts
MatchEnd.MAX_NAME = 20

export type Row = { name: string, smashes: number, userId: number?, carId: string? }
export type View = {
	place: number, -- this player's place (0 = not in the list)
	total: number, -- karts in the match
	top: { Row & { me: boolean } }, -- 1st, 2nd, 3rd (fewer if fewer karts)
	coins: number,
	smashes: number, -- this player's smashes
	nextAt: number?,
}

local function count(v: unknown, most: number): number
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v), 0, most)
end

local function words(v: unknown): string
	if type(v) ~= "string" then
		return "?"
	end
	local s = string.gsub(v, "[%c]", "")
	if #s > MatchEnd.MAX_NAME then
		s = string.sub(s, 1, MatchEnd.MAX_NAME)
	end
	return if s == "" then "?" else s
end

-- Server: the payload for one player (places best first).
function MatchEnd.payload(places: { Row }, coins: number, nextAt: number?): { [string]: any }
	local rows = {}
	for i, r in places do
		if i > MatchEnd.MAX_ROWS then
			break
		end
		table.insert(rows, { name = r.name, smashes = r.smashes, userId = r.userId, carId = r.carId })
	end
	return { places = rows, coins = coins, nextAt = nextAt }
end

-- Client: what the end screen shows for player `myId`. Anything odd in `data` is dropped, never
-- an error.
function MatchEnd.read(data: unknown, myId: number): View
	local view: View = { place = 0, total = 0, top = {}, coins = 0, smashes = 0, nextAt = nil }
	if type(data) ~= "table" then
		return view
	end
	local d = data :: { [string]: unknown }
	view.coins = count(d.coins, 1e9)
	if type(d.nextAt) == "number" and d.nextAt == d.nextAt then
		view.nextAt = d.nextAt :: number
	end
	local places = d.places
	if type(places) ~= "table" then
		return view
	end
	local n = 0
	for i = 1, MatchEnd.MAX_ROWS do
		local r = (places :: { unknown })[i]
		if type(r) ~= "table" then
			break
		end
		n = i
		local row = r :: { [string]: unknown }
		local uid = if type(row.userId) == "number" then row.userId :: number else nil
		local me = uid ~= nil and uid == myId
		local smashes = count(row.smashes, 9999)
		if me then
			view.place = i
			view.smashes = smashes
		end
		if i <= 3 then
			table.insert(view.top, {
				name = words(row.name),
				smashes = smashes,
				userId = uid,
				carId = if type(row.carId) == "string" then row.carId :: string else nil,
				me = me,
			})
		end
	end
	view.total = n
	return view
end

-- The big words: a win, a top 3, or NICE TRY! (never YOU LOST).
function MatchEnd.shout(place: number): string
	if place == 1 then
		return "YOU WON!"
	elseif place >= 2 and place <= 3 then
		return "TOP 3!"
	end
	return "NICE TRY!"
end

-- "3RD / 5"
function MatchEnd.placeWords(place: number, total: number): string
	if place < 1 then
		return ""
	end
	local tail = "TH"
	local t, h = place % 10, place % 100
	if h < 11 or h > 13 then
		tail = if t == 1 then "ST" elseif t == 2 then "ND" elseif t == 3 then "RD" else "TH"
	end
	return `{place}{tail} / {total}`
end

-- "1 SMASH" / "4 SMASHES"
function MatchEnd.smashWords(n: number): string
	return if n == 1 then "1 SMASH" else `{n} SMASHES`
end

-- Seconds left on the PLAY AGAIN count, from when the screen opened.
function MatchEnd.left(openedAt: number, now: number): number
	return math.max(0, math.ceil(MatchEnd.AUTO - (now - openedAt)))
end

return MatchEnd
