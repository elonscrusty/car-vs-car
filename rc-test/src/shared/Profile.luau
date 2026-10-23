--!strict
-- One player's save (carter's stars loop, phase 1). Pure tables, so Lune can test it; the server's
-- PlayerData does the DataStore part. Stars only come from OTHER people's plots, once per medal
-- per plot owner per kind of plot: bronze then gold on Mia's race = 1 + 2 = 3 stars, never more.

export type Record = { value: number, name: string, userId: number }
export type Data = {
	version: number,
	stars: number,
	-- plot owner's user id (as text, DataStore keys must be text) -> plot kind -> best medal 1..3
	starsFrom: { [string]: { [string]: number } },
	plotRecords: { [string]: Record }, -- plot kind -> the best run anyone made on MY plot
	coins: number,
	likes: number, -- likes my plot got
	liked: { [string]: boolean }, -- plot owners I liked (once each, ever)
	visited: { [string]: number }, -- plot owner -> the day I last got their visit gift
	bolts: { [string]: boolean }, -- gold bolts found on the rock climb ("1".."5")
	winPoints: number, -- one per record beaten (ranks go up by winning)
	streak: number, -- records beaten in a row; someone beating one of mine ends it
	bestStreak: number,
	rivals: { [string]: Rival }, -- other player's user id -> my score against them
	dailyDay: number, -- the day the daily gift was last taken (0 = never)
	dayStreak: number, -- days in a row the daily gift was taken
	jobs: { day: number, have: { number } }, -- daily jobs: the day, and how far each job got
	looks: { [string]: boolean }, -- plot looks bought in the plot shop (PlotShop ids)
	lookOff: { [string]: boolean }, -- plot looks I have but turned off
	cars: { [string]: boolean }, -- CarCatalog ids bought or won (starters are everyone's anyway)
	equipped: { [string]: string }, -- mode -> the car id driven in that mode
	track: Track?, -- my built track (nil = the starter circle); the grid size comes from stars
	tiles: { [string]: number }, -- TileShop ids -> copies owned (free tiles are everyone's anyway)
	raceStars: number, -- stars won in server races (on top of the medal stars in starsFrom)
}
-- One placed tile: column, row (from 1), TrackTiles piece id, quarter turns 0..3.
export type Tile = { c: number, r: number, piece: string, rot: number }
export type Track = { tiles: { Tile } }
-- My score against one other player: wins = I beat their record, losses = they beat mine.
export type Rival = { name: string, wins: number, losses: number, at: number }
export type Lock = { job: string, at: number }

local Profile = {}

Profile.VERSION = 11 -- 2: likes, liked, visited. 3: bolts. 4: wins, streak, rivals. 5: daily gift.
-- 6: daily jobs. 7: looks, lookOff. 8: cars, equipped. 9: track. 10: tiles (owned).
-- 11: raceStars
Profile.MAX_OWNERS = 500 -- keeps the save small; stars from more owners than this stop counting
Profile.LOCK_TIMEOUT = 300 -- a server that hasn't saved for this long is gone: its lock is stale
Profile.MODES = { "race", "drift", "rock" }
Profile.MAX_LIST = 500 -- liked / visited entries kept
Profile.VISIT_COINS = 20 -- the visitor's gift (once per plot owner per day)
Profile.HOST_COINS = 10 -- the owner's share of it
Profile.BOLTS = 5 -- gold bolts hidden on the rock climb, each on top of a hard climb
Profile.WIN_COINS = 30 -- beating someone else's record (first guess)
Profile.MAX_RIVALS = 50 -- the least recent rival goes when full
-- The daily gift by days in a row (day 1, day 2, ...); from day 7 on it stays at the last one.
-- Miss a day and it starts again at day 1. (Guess amounts, like the visit gift.)
Profile.DAILY = { 10, 15, 20, 30, 40, 50, 75 }
Profile.MAX_LOOKS = 32 -- look ids kept (the shop has fewer)
Profile.MAX_CARS = 200 -- car ids kept (far more cars than exist)
Profile.MAX_GRID = 16 -- tiles outside 1..MAX_GRID columns / rows are dropped
Profile.MAX_TILES = Profile.MAX_GRID * Profile.MAX_GRID
Profile.MAX_TILE_IDS = 64 -- owned tile ids kept (far more than exist)

function Profile.new(): Data
	return {
		version = Profile.VERSION,
		stars = 0,
		starsFrom = {},
		plotRecords = {},
		coins = 0,
		likes = 0,
		liked = {},
		visited = {},
		bolts = {},
		winPoints = 0,
		streak = 0,
		bestStreak = 0,
		rivals = {},
		dailyDay = 0,
		dayStreak = 0,
		jobs = { day = -1, have = { 0, 0, 0 } },
		looks = {},
		lookOff = {},
		cars = {},
		equipped = {},
		tiles = {},
		raceStars = 0,
	}
end

local function count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function isMode(m: any): boolean
	return type(m) == "string" and table.find(Profile.MODES, m) ~= nil
end

local function goodNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Any saved value (old, broken or missing) -> a clean save. Stars are counted again from
-- starsFrom, so the two can never disagree.
-- A clean copy of a tile list (from a save or the build code): bad tiles dropped, one tile per
-- cell (the last one wins). nil when the list isn't a list. The caller checks the grid size and
-- that the pieces are owned; this only keeps the save sane.
function Profile.cleanTrack(raw: any): Track?
	if type(raw) ~= "table" then
		return nil
	end
	local byCell: { [number]: Tile } = {}
	local order: { number } = {}
	for _, t in raw do
		if
			type(t) == "table"
			and goodNumber(t.c)
			and goodNumber(t.r)
			and goodNumber(t.rot)
			and type(t.piece) == "string"
			and #t.piece > 0
			and #t.piece <= 32
		then
			local c, r = math.floor(t.c), math.floor(t.r)
			if c >= 1 and c <= Profile.MAX_GRID and r >= 1 and r <= Profile.MAX_GRID then
				local key = (r - 1) * Profile.MAX_GRID + c
				if not byCell[key] then
					table.insert(order, key)
				end
				byCell[key] = { c = c, r = r, piece = t.piece, rot = math.floor(t.rot) % 4 }
			end
		end
		if #order >= Profile.MAX_TILES then
			break
		end
	end
	local tiles: { Tile } = {}
	for _, key in order do
		table.insert(tiles, byCell[key])
	end
	return { tiles = tiles }
end

-- My saved track (nil = the starter circle).
function Profile.getTrack(d: Data): Track?
	return d.track
end

-- Save a new track (`tiles` nil = back to the starter circle). The caller then PlayerData.touch.
function Profile.setTrack(d: Data, tiles: { Tile }?)
	d.track = if tiles then Profile.cleanTrack(tiles) else nil
end

function Profile.migrate(raw: any): Data
	local d = Profile.new()
	if type(raw) ~= "table" then
		return d
	end
	if type(raw.starsFrom) == "table" then
		for owner, modes in raw.starsFrom do
			if type(owner) == "string" and type(modes) == "table" then
				local clean: { [string]: number } = {}
				for mode, medal in modes do
					if isMode(mode) and goodNumber(medal) then
						local m = math.clamp(math.floor(medal), 0, 3)
						if m > 0 then
							clean[mode] = m
						end
					end
				end
				if next(clean) and count(d.starsFrom) < Profile.MAX_OWNERS then
					d.starsFrom[owner] = clean
				end
			end
		end
	end
	if type(raw.plotRecords) == "table" then
		for mode, r in raw.plotRecords do
			if
				isMode(mode)
				and type(r) == "table"
				and goodNumber(r.value)
				and r.value > 0
				and type(r.name) == "string"
				and goodNumber(r.userId)
			then
				d.plotRecords[mode] =
					{ value = r.value, name = string.sub(r.name, 1, 40), userId = r.userId }
			end
		end
	end
	if goodNumber(raw.raceStars) then
		d.raceStars = math.clamp(math.floor(raw.raceStars), 0, Profile.MAX_RACE_STARS)
	end
	if goodNumber(raw.coins) then
		d.coins = math.max(math.floor(raw.coins), 0)
	end
	if goodNumber(raw.likes) then
		d.likes = math.max(math.floor(raw.likes), 0)
	end
	if type(raw.liked) == "table" then
		for owner, yes in raw.liked do
			if type(owner) == "string" and yes == true and count(d.liked) < Profile.MAX_LIST then
				d.liked[owner] = true
			end
		end
	end
	if type(raw.visited) == "table" then
		for owner, day in raw.visited do
			if
				type(owner) == "string"
				and goodNumber(day)
				and count(d.visited) < Profile.MAX_LIST
			then
				d.visited[owner] = math.floor(day)
			end
		end
	end
	if type(raw.bolts) == "table" then
		for id, yes in raw.bolts do
			local n = tonumber(id)
			if yes == true and n and n == math.floor(n) and n >= 1 and n <= Profile.BOLTS then
				d.bolts[tostring(n)] = true
			end
		end
	end
	for _, k in { "winPoints", "streak", "bestStreak" } do
		if goodNumber(raw[k]) then
			(d :: any)[k] = math.max(math.floor(raw[k]), 0)
		end
	end
	d.bestStreak = math.max(d.bestStreak, d.streak)
	if type(raw.rivals) == "table" then
		for id, r in raw.rivals do
			if
				type(id) == "string"
				and type(r) == "table"
				and type(r.name) == "string"
				and goodNumber(r.wins)
				and goodNumber(r.losses)
				and count(d.rivals) < Profile.MAX_RIVALS
			then
				d.rivals[id] = {
					name = string.sub(r.name, 1, 40),
					wins = math.max(math.floor(r.wins), 0),
					losses = math.max(math.floor(r.losses), 0),
					at = if goodNumber(r.at) then r.at else 0,
				}
			end
		end
	end
	if goodNumber(raw.dailyDay) and goodNumber(raw.dayStreak) then
		d.dailyDay = math.max(math.floor(raw.dailyDay), 0)
		d.dayStreak = math.clamp(math.floor(raw.dayStreak), 0, 100000)
	end
	if
		type(raw.jobs) == "table"
		and goodNumber(raw.jobs.day)
		and type(raw.jobs.have) == "table"
	then
		d.jobs.day = math.floor(raw.jobs.day)
		for i = 1, 3 do
			local v = raw.jobs.have[i]
			if goodNumber(v) and v > 0 then
				d.jobs.have[i] = math.min(math.floor(v), 999)
			end
		end
	end
	for _, k in { "looks", "lookOff" } do
		local raw2 = raw[k]
		if type(raw2) == "table" then
			local set = (d :: any)[k]
			for id, yes in raw2 do
				if type(id) == "string" and yes == true and count(set) < Profile.MAX_LOOKS then
					set[string.sub(id, 1, 20)] = true
				end
			end
		end
	end
	if type(raw.cars) == "table" then
		for id, yes in raw.cars do
			if
				type(id) == "string"
				and #id <= 40
				and yes == true
				and count(d.cars) < Profile.MAX_CARS
			then
				d.cars[id] = true
			end
		end
	end
	if type(raw.tiles) == "table" then
		for id, n in raw.tiles do
			-- true (one copy) is fine too
			local copies = if n == true then 1 elseif goodNumber(n) then math.floor(n) else 0
			if
				type(id) == "string"
				and #id <= 40
				and copies > 0
				and count(d.tiles) < Profile.MAX_TILE_IDS
			then
				d.tiles[id] = math.min(copies, 99)
			end
		end
	end
	if type(raw.equipped) == "table" then
		for mode, id in raw.equipped do
			if isMode(mode) and type(id) == "string" and #id <= 40 then
				d.equipped[mode] = id
			end
		end
	end
	if type(raw.track) == "table" then
		d.track = Profile.cleanTrack(raw.track.tiles)
	end
	local stars = 0
	for _, modes in d.starsFrom do
		for _, m in modes do
			stars += m
		end
	end
	d.stars = stars + d.raceStars
	return d
end

-- A run on `ownerId`'s plot won `medal` (0..3) on a `mode` plot: how many new stars? (0 when
-- it's your own plot, no medal, or no better than before)
function Profile.award(
	d: Data,
	selfId: number,
	ownerId: number,
	mode: string,
	medal: number
): number
	if ownerId == selfId or medal <= 0 or not isMode(mode) then
		return 0
	end
	local key = tostring(ownerId)
	local modes = d.starsFrom[key]
	if modes == nil then
		if count(d.starsFrom) >= Profile.MAX_OWNERS then
			return 0
		end
		modes = {}
		d.starsFrom[key] = modes
	end
	local had = modes[mode] or 0
	local m = math.clamp(math.floor(medal), 0, 3)
	if m <= had then
		return 0
	end
	modes[mode] = m
	d.stars += m - had
	return m - had
end

-- Stars won in a server race (ServerRace.starsFor). Unlike medal stars these keep adding up:
-- racing is how you climb (bigger grid, tiles open), even with no friends' plots around.
Profile.MAX_RACE_STARS = 100000
function Profile.addRaceStars(d: Data, n: number): number
	local add = math.clamp(math.floor(n), 0, Profile.MAX_RACE_STARS - d.raceStars)
	d.raceStars += add
	d.stars += add
	return add
end

-- The day number for once-a-day gifts.
function Profile.day(now: number): number
	return math.floor(now / 86400)
end

-- Saturday or Sunday (UTC): every coin gift is doubled.
function Profile.weekend(now: number): boolean
	local wday = (Profile.day(now) + 4) % 7 -- day 0 (1 Jan 1970) was a Thursday: 0 = Sunday
	return wday == 0 or wday == 6
end

-- How many times the coin gifts pay right now (2 on weekends).
function Profile.boost(now: number): number
	return if Profile.weekend(now) then 2 else 1
end

-- The daily gift for `day`: (coins, days in a row) the first time each day, (0, streak) after.
-- `mult` = Profile.boost.
function Profile.daily(d: Data, day: number, mult: number?): (number, number)
	if d.dailyDay == day then
		return 0, d.dayStreak
	end
	d.dayStreak = if d.dailyDay == day - 1 then d.dayStreak + 1 else 1
	d.dailyDay = day
	local coins = Profile.DAILY[math.min(d.dayStreak, #Profile.DAILY)] * (mult or 1)
	d.coins += coins
	return coins, d.dayStreak
end

-- `d` likes `ownerId`'s plot: true the first time only (never your own plot).
function Profile.like(d: Data, selfId: number, ownerId: number): boolean
	local key = tostring(ownerId)
	if ownerId == selfId or d.liked[key] then
		return false
	end
	if count(d.liked) >= Profile.MAX_LIST then
		-- full: forget one old like to make room (it can't be liked twice in one session anyway)
		local first = next(d.liked)
		if first then
			d.liked[first] = nil
		end
	end
	d.liked[key] = true
	return true
end

-- `d` drove `ownerId`'s plot today: true (and the visitor's coins) the first time each day.
-- The caller gives the owner Profile.HOST_COINS (both times `mult`, Profile.boost).
function Profile.visit(
	d: Data,
	selfId: number,
	ownerId: number,
	day: number,
	mult: number?
): boolean
	local key = tostring(ownerId)
	if ownerId == selfId or d.visited[key] == day then
		return false
	end
	if d.visited[key] == nil and count(d.visited) >= Profile.MAX_LIST then
		-- full: drop the oldest visit day
		local oldKey, oldDay = nil, math.huge
		for k, v in d.visited do
			if v < oldDay then
				oldKey, oldDay = k, v
			end
		end
		if oldKey then
			d.visited[oldKey] = nil
		end
	end
	d.visited[key] = day
	d.coins += Profile.VISIT_COINS * (mult or 1)
	return true
end

-- Found gold bolt `id` (1..BOLTS): true the first time.
function Profile.findBolt(d: Data, id: number): boolean
	if id ~= math.floor(id) or id < 1 or id > Profile.BOLTS then
		return false
	end
	local key = tostring(id)
	if d.bolts[key] then
		return false
	end
	d.bolts[key] = true
	return true
end

function Profile.boltList(d: Data): { number }
	local out = {}
	for key in d.bolts do
		table.insert(out, tonumber(key) :: number)
	end
	table.sort(out)
	return out
end

local function rival(d: Data, otherId: number, name: string, now: number): Rival
	local key = tostring(otherId)
	local r = d.rivals[key]
	if r == nil then
		if count(d.rivals) >= Profile.MAX_RIVALS then
			-- full: the one played longest ago goes
			local oldKey, oldAt = nil, math.huge
			for k, v in d.rivals do
				if v.at < oldAt then
					oldKey, oldAt = k, v.at
				end
			end
			if oldKey then
				d.rivals[oldKey] = nil
			end
		end
		r = { name = name, wins = 0, losses = 0, at = now }
		d.rivals[key] = r
	end
	r.name = string.sub(name, 1, 40)
	r.at = now
	return r
end

-- I beat `otherId`'s record: a win against them, a win point, the streak goes up and coins.
-- (Beating your own record is not a win.) Returns false when it doesn't count.
function Profile.win(d: Data, selfId: number, otherId: number, name: string, now: number): boolean
	if otherId == selfId then
		return false
	end
	local r = rival(d, otherId, name, now)
	r.wins += 1
	d.winPoints += 1
	d.streak += 1
	d.bestStreak = math.max(d.bestStreak, d.streak)
	d.coins += Profile.WIN_COINS * Profile.boost(now) -- double on weekends
	return true
end

-- `otherId` beat my record: a loss against them and my streak ends. Nothing else is taken.
function Profile.lose(d: Data, selfId: number, otherId: number, name: string, now: number)
	if otherId == selfId then
		return
	end
	local r = rival(d, otherId, name, now)
	r.losses += 1
	d.streak = 0
end

-- My rivals, most recent first (for the list on screen).
function Profile.rivalList(
	d: Data,
	max: number
): { { id: string, name: string, wins: number, losses: number } }
	local out = {}
	for id, r in d.rivals do
		table.insert(out, { id = id, name = r.name, wins = r.wins, losses = r.losses, at = r.at })
	end
	table.sort(out, function(a, b)
		return a.at > b.at
	end)
	local list = {}
	for i = 1, math.min(max, #out) do
		local r = out[i]
		list[i] = { id = r.id, name = r.name, wins = r.wins, losses = r.losses }
	end
	return list
end

-- May this server (job) take the save? Free, ours already, or the other server stopped saving.
-- `force` = we waited and the other server still holds it: take it anyway (that server sees the
-- new lock on its next save and stops saving, so the two never write over each other).
-- A Studio test server ("studio-...") always takes a lock left by an older Studio test: Stop
-- shuts the test down before its last save can let go, and there's only one Studio per tester.
function Profile.canTake(lock: any, job: string, now: number, force: boolean?): boolean
	if force or type(lock) ~= "table" or type(lock.job) ~= "string" then
		return true
	end
	if lock.job == job then
		return true
	end
	if string.sub(job, 1, 7) == "studio-" and string.sub(lock.job, 1, 7) == "studio-" then
		return true
	end
	return type(lock.at) ~= "number" or now - lock.at > Profile.LOCK_TIMEOUT
end

return Profile
