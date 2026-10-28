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
	plotTop: { [string]: { Record } }, -- plot kind -> my plot's board: each player's best, top 3
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
	tiles: { [string]: number }, -- old tile shop ids -> copies owned (kept so old saves load)
	raceStars: number, -- stars won in server races (on top of the medal stars in starsFrom)
	trackKind: string, -- what my built plot is: "race" (laps) or "drift" (drift score)
	stage: number, -- how far into the game I am (Profile.STAGE): new players see one thing at a time
	-- the tycoon (Tycoon): my plot is my garage
	pile: number, -- coins waiting in my plot (tap to collect)
	lastSeen: number, -- os.time of the last save: coins keep piling while I'm away
	boostUntil: number, -- os.time a race win's double income ends
	plotLevel: number, -- 0..Training.MAX_PLOT_LEVEL: more stations (and tycoon parking slots)
	parked: { string }, -- car ids parked in my garage (each makes coins)
	-- Car VS Car (rc-game/cvc-plan.md): cars train on my plot's stations
	garage: { GarageCar }, -- every car I own, duplicates too; each keeps its own training
	racer: string, -- uid of the car I race ("" = none yet)
	stations: { Station }, -- my plot's stations, in Training.stationsFor order
	garageLevel: number, -- more garage spots
	league: number, -- 1..4 (League.NAMES), never goes down
	trophies: number,
	raceWins: number,
	crates: number, -- free crates not opened yet
	picked: boolean, -- chose the starter car
	nextUid: number, -- for the next car's uid
	friendsPaid: { [string]: number }, -- friend's user id -> the day we last got the friend coins
	-- Car VS Car SMASH (plans/smash/MASTER-PLAN.md): totals over every match
	smashes: number, -- karts I smashed
	matches: number, -- matches played to the end
	matchWins: number, -- matches won (1st)
}
-- One owned car: its CarCatalog id and the points trained on top of its base bars (Training).
export type GarageCar = { uid: string, id: string, speed: number, turn: number, boost: number }
export type Station = { kind: string, level: number, uid: string } -- uid "" = empty
-- One placed tile: column, row (from 1), old track-builder piece id, quarter turns 0..3.
export type Tile = { c: number, r: number, piece: string, rot: number }
export type Track = { tiles: { Tile } }
-- My score against one other player: wins = I beat their record, losses = they beat mine.
export type Rival = { name: string, wins: number, losses: number, at: number }
export type Lock = { job: string, at: number }

export type Stored = { data: Data, lock: Lock? }
export type LoadStep = { kind: "blocked" | "readOnly" | "write", data: Data?, record: Stored? }
export type SaveStep = { kind: "lost" | "skip" | "write", record: Stored? }

local Profile = {}

Profile.VERSION = 17 -- 2: likes, liked, visited. 3: bolts. 4: wins, streak, rivals. 5: daily gift.
-- 6: daily jobs. 7: looks, lookOff. 8: cars, equipped. 9: track. 10: tiles (owned).
-- 11: raceStars. 12: trackKind. 13: plotTop. 14: stage. 15: pile, lastSeen, boostUntil,
-- plotLevel, parked (the tycoon). 16: garage, racer, stations, garageLevel, league, trophies,
-- raceWins, crates, picked, nextUid, friendsPaid (Car VS Car). 17: smashes, matches, matchWins
-- (Car VS Car SMASH)
Profile.TOP = 3 -- rows on a plot's board
-- How far into the game a player is. Only goes up. The screen shows more at each one
-- (JoinStage): new = just your car and GO; lapped = coins and BUILD; raced = the shop;
-- shopped (first car bought) = everything (gift, jobs, looks, top 3, 2X).
Profile.STAGE = { NEW = 0, LAPPED = 1, RACED = 2, SHOPPED = 3 }
Profile.MAX_PLOT_LEVEL = 8 -- (Training.MAX_PLOT_LEVEL; was Tycoon's 5, which cut Car VS Car plots 6-8 back to 5 on rejoin)
Profile.MAX_PARKED = 8 -- (Tycoon.slots at the top level)
Profile.BASE_SLOTS = 3 -- (Tycoon.BASE_SLOTS) parked cars past slots(plotLevel) are dropped
Profile.MAX_COINS = 1e12 -- a broken number can't blow the save up; real play never gets near
Profile.FIRST_LAP_COINS = 20 -- the first lap ever pays this (the first coins a new player sees)
Profile.MAX_OWNERS = 500 -- keeps the save small; stars from more owners than this stop counting
Profile.LOCK_TIMEOUT = 300 -- a server that hasn't saved for this long is gone: its lock is stale
Profile.MODES = { "race", "drift", "rock" }
Profile.MAX_LIST = 500 -- liked / visited entries kept
Profile.VISIT_COINS = 20 -- the visitor's gift (once per plot owner per day)
Profile.HOST_COINS = 10 -- the owner's share of it
-- bring a friend (Car VS Car): both get this, once per friend per day (Economy may tune it)
Profile.FRIEND_COINS = 100
Profile.FRIENDS_PER_DAY = 5
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
Profile.MAX_GARAGE = 200 -- cars kept (duplicates count)
Profile.MAX_STATIONS = 9 -- (#Training.STATIONS)
Profile.MAX_LEVEL = 50 -- garage / station levels
Profile.LEAGUES = 4 -- (#League.NAMES)
Profile.BAR_MAX = 100 -- (Training.MAX_BAR) trained points per bar can't pass this
-- Car VS Car SMASH has no training (CHANGE-LIST §2). While the training game still runs this
-- stays true and saves keep stations, plot level, track and per-car training. Phase 3 (training
-- removed) sets it false: every load then drops them (Profile.dropTraining). Cars and coins stay.
-- When it flips, also bump VERSION (old servers then open the new saves read-only) and make
-- sure nothing adds to `pile` after the load any more (TycoonServer's offline coins go with it).
Profile.KEEP_TRAINING = true

function Profile.new(): Data
	return {
		version = Profile.VERSION,
		stars = 0,
		starsFrom = {},
		plotRecords = {},
		plotTop = {},
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
		trackKind = "race",
		stage = 0,
		pile = 0,
		lastSeen = 0,
		boostUntil = 0,
		plotLevel = 0,
		parked = {},
		garage = {},
		racer = "",
		stations = {},
		garageLevel = 0,
		league = 1,
		trophies = 0,
		raceWins = 0,
		crates = 0,
		picked = false,
		nextUid = 1,
		friendsPaid = {},
		smashes = 0,
		matches = 0,
		matchWins = 0,
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

local function sameTrack(a: Track?, b: Track?): boolean
	local at, bt = if a then a.tiles else {}, if b then b.tiles else {}
	if #at ~= #bt then
		return false
	end
	local key = function(t: Tile): string
		return `{t.c},{t.r},{t.piece},{t.rot}`
	end
	local seen: { [string]: boolean } = {}
	for _, t in at do
		seen[key(t)] = true
	end
	for _, t in bt do
		if not seen[key(t)] then
			return false
		end
	end
	return true
end

-- Save a new track (`tiles` nil = back to the starter circle). The caller then PlayerData.touch.
-- A changed track clears my plot's records: old times on another road don't compare. Returns
-- whether the track changed.
function Profile.setTrack(d: Data, tiles: { Tile }?): boolean
	local new = if tiles then Profile.cleanTrack(tiles) else nil
	if sameTrack(d.track, new) then
		d.track = new
		return false
	end
	d.track = new
	d.plotRecords = {}
	d.plotTop = {}
	return true
end

-- What my plot is ("race" or "drift"); anything else is refused. Returns whether it changed.
-- A change clears my plot's records (a lap time and a drift score don't compare).
function Profile.setTrackKind(d: Data, kind: string): boolean
	if (kind ~= "race" and kind ~= "drift") or d.trackKind == kind then
		return false
	end
	d.trackKind = kind
	d.plotRecords = {}
	d.plotTop = {}
	return true
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
	-- the boards: up to TOP good rows per kind, one per player; old saves start from the record
	local function goodRecord(r: any): boolean
		return type(r) == "table"
			and goodNumber(r.value)
			and r.value > 0
			and type(r.name) == "string"
			and goodNumber(r.userId)
	end
	if type(raw.plotTop) == "table" then
		for mode, list in raw.plotTop do
			if isMode(mode) and type(list) == "table" then
				local clean: { Record } = {}
				local seen: { [number]: boolean } = {}
				for _, r in list do
					if #clean < Profile.TOP and goodRecord(r) and not seen[r.userId] then
						seen[r.userId] = true
						table.insert(
							clean,
							{ value = r.value, name = string.sub(r.name, 1, 40), userId = r.userId }
						)
					end
				end
				if #clean > 0 then
					d.plotTop[mode] = clean
				end
			end
		end
	end
	for mode, r in d.plotRecords do
		if d.plotTop[mode] == nil then
			d.plotTop[mode] = { { value = r.value, name = r.name, userId = r.userId } }
		end
	end
	if raw.trackKind == "race" or raw.trackKind == "drift" then
		d.trackKind = raw.trackKind
	end
	if goodNumber(raw.raceStars) then
		d.raceStars = math.clamp(math.floor(raw.raceStars), 0, Profile.MAX_RACE_STARS)
	end
	if goodNumber(raw.coins) then
		d.coins = math.clamp(math.floor(raw.coins), 0, Profile.MAX_COINS)
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
	if type(raw.friendsPaid) == "table" then
		for friend, day in raw.friendsPaid do
			if
				type(friend) == "string"
				and goodNumber(day)
				and count(d.friendsPaid) < Profile.MAX_LIST
			then
				d.friendsPaid[friend] = math.floor(day)
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
	if goodNumber(raw.pile) then
		d.pile = math.clamp(raw.pile, 0, Profile.MAX_COINS)
	end
	for _, k in { "lastSeen", "boostUntil" } do
		local v = raw[k]
		if goodNumber(v) then
			(d :: any)[k] = math.max(math.floor(v), 0)
		end
	end
	if goodNumber(raw.plotLevel) then
		d.plotLevel = math.clamp(math.floor(raw.plotLevel), 0, Profile.MAX_PLOT_LEVEL)
	end
	if type(raw.parked) == "table" then
		for _, id in raw.parked do
			if
				type(id) == "string"
				and #id <= 40
				and #d.parked < math.min(Profile.MAX_PARKED, Profile.BASE_SLOTS + d.plotLevel)
				and not table.find(d.parked, id)
			then
				table.insert(d.parked, id)
			end
		end
	end
	Profile.migrateGarage(d, raw)
	if not Profile.KEEP_TRAINING then
		Profile.dropTraining(d)
	end
	if goodNumber(raw.stage) then
		d.stage = math.clamp(math.floor(raw.stage), 0, Profile.STAGE.SHOPPED)
	elseif d.coins > 0 or d.stars > 0 or next(d.cars) ~= nil then
		-- a save from before stages that has played: they've seen it all already
		d.stage = Profile.STAGE.SHOPPED
	end
	return d
end

local function cleanCar(c: any): GarageCar?
	if type(c) ~= "table" or type(c.uid) ~= "string" or type(c.id) ~= "string" then
		return nil
	end
	if #c.uid == 0 or #c.uid > 20 or #c.id == 0 or #c.id > 40 then
		return nil
	end
	local out: any = { uid = c.uid, id = c.id }
	for _, b in { "speed", "turn", "boost" } do
		out[b] = if goodNumber(c[b]) then math.clamp(c[b], 0, Profile.BAR_MAX) else 0
	end
	return out
end

-- A new car in the garage (untrained); returns it, or nil when the garage is full.
function Profile.addCar(d: Data, id: string): GarageCar?
	if #d.garage >= Profile.MAX_GARAGE then
		return nil
	end
	local car = { uid = tostring(d.nextUid), id = id, speed = 0, turn = 0, boost = 0 }
	d.nextUid += 1
	table.insert(d.garage, car)
	return car
end

function Profile.findCar(d: Data, uid: string): GarageCar?
	for _, c in d.garage do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- (Car VS Car) the v16 fields; a save from before them gets one untrained car for each car id it
-- owned, so nobody loses a car. Old fields stay as they were.
function Profile.migrateGarage(d: Data, raw: any)
	local seen: { [string]: boolean } = {}
	if type(raw.garage) == "table" then
		for _, c in raw.garage do
			local car = cleanCar(c)
			if car and not seen[car.uid] and #d.garage < Profile.MAX_GARAGE then
				seen[car.uid] = true
				table.insert(d.garage, car)
			end
		end
	end
	if goodNumber(raw.nextUid) then
		d.nextUid = math.max(math.floor(raw.nextUid), 1)
	end
	-- never hand out a uid that's already used
	for uid in seen do
		local n = tonumber(uid)
		if n and n >= d.nextUid then
			d.nextUid = math.floor(n) + 1
		end
	end
	if type(raw.garage) ~= "table" then
		local ids = {}
		for id, yes in d.cars do
			if yes then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			Profile.addCar(d, id)
		end
	end
	if type(raw.racer) == "string" and Profile.findCar(d, raw.racer) then
		d.racer = raw.racer
	end
	if type(raw.stations) == "table" then
		for _, s in raw.stations do
			if #d.stations >= Profile.MAX_STATIONS then
				break
			end
			if type(s) == "table" and type(s.kind) == "string" and #s.kind <= 20 then
				local uid = if type(s.uid) == "string" and Profile.findCar(d, s.uid)
					then s.uid
					else ""
				local level = if goodNumber(s.level)
					then math.clamp(math.floor(s.level), 1, Profile.MAX_LEVEL)
					else 1
				table.insert(d.stations, { kind = s.kind, level = level, uid = uid })
			end
		end
	end
	if goodNumber(raw.garageLevel) then
		d.garageLevel = math.clamp(math.floor(raw.garageLevel), 0, Profile.MAX_LEVEL)
	end
	if goodNumber(raw.league) then
		d.league = math.clamp(math.floor(raw.league), 1, Profile.LEAGUES)
	end
	for _, k in { "trophies", "raceWins", "crates", "smashes", "matches", "matchWins" } do
		local v = raw[k]
		if goodNumber(v) then
			(d :: any)[k] = math.clamp(math.floor(v), 0, Profile.MAX_COINS)
		end
	end
	d.picked = raw.picked == true
end

-- (Car VS Car SMASH) take the training game out of a save: stations, plot level, the tycoon's
-- parked row, the built track with its records, and each car's trained points go. Every car (by
-- uid, and in `cars`) and every coin stays: coins still waiting in the plot's pile move into
-- coins (rounded up, so nobody loses part of one). Safe to run again.
function Profile.dropTraining(d: Data)
	d.coins = math.clamp(d.coins + math.ceil(d.pile), 0, Profile.MAX_COINS)
	d.pile = 0
	d.stations = {}
	d.plotLevel = 0
	d.parked = {}
	d.track = nil
	d.trackKind = "race"
	d.plotRecords = {}
	d.plotTop = {}
	for _, c in d.garage do
		c.speed, c.turn, c.boost = 0, 0, 0
	end
end

-- Move up to stage n (never down). True when it moved.
function Profile.raiseStage(d: Data, n: number): boolean
	if not goodNumber(n) or n <= d.stage then
		return false
	end
	d.stage = math.min(math.floor(n), Profile.STAGE.SHOPPED)
	return true
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

-- Bring a friend (Car VS Car): `friendId` is a Roblox friend of `d`'s player and they're in the
-- same server. True (and `d`'s coins) once per friend per day, for up to FRIENDS_PER_DAY friends a
-- day; the caller does the same for the friend's save, so both get paid. Older days are dropped.
function Profile.friendBonus(
	d: Data,
	selfId: number,
	friendId: number,
	day: number,
	mult: number?
): boolean
	local key = tostring(friendId)
	if friendId == selfId or d.friendsPaid[key] == day then
		return false
	end
	local today = 0
	for k, v in d.friendsPaid do
		if v < day then
			d.friendsPaid[k] = nil
		elseif v == day then
			today += 1
		end
	end
	if today >= Profile.FRIENDS_PER_DAY or count(d.friendsPaid) >= Profile.MAX_LIST then
		return false
	end
	d.friendsPaid[key] = day
	d.coins = math.min(d.coins + Profile.FRIEND_COINS * (mult or 1), Profile.MAX_COINS)
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
-- What a server may do with the save it found (`old` is the whole stored value, lock and all):
-- "fresh" = nothing there yet, start a new one; "load" = read it and keep saving; "readOnly" =
-- play with it but never write it back. readOnly when the save is junk (writing would put a blank
-- one over it) or from a NEWER game version (an old server still running after an update would
-- drop the fields it doesn't know).
function Profile.loadPlan(old: any): "fresh" | "load" | "readOnly"
	if old == nil then
		return "fresh"
	end
	if type(old) ~= "table" or type(old.data) ~= "table" then
		return if type(old) == "table" and old.data == nil then "fresh" else "readOnly"
	end
	local v = old.data.version
	if type(v) == "number" and v > Profile.VERSION then
		return "readOnly"
	end
	return "load"
end

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

-- One step of taking the save on join (runs inside UpdateAsync, so it may run more than once).
-- "blocked" = another live server holds it (write nothing; wait and try again);
-- "readOnly" = junk or newer: `data` is a copy to play with, nothing is written;
-- "write" = `record` is the new stored value (data + our lock), `data` is the player's data.
function Profile.loadStep(old: any, job: string, now: number, force: boolean?): LoadStep
	if type(old) == "table" and not Profile.canTake(old.lock, job, now, force) then
		return { kind = "blocked" }
	end
	local plan = Profile.loadPlan(old)
	local data = Profile.migrate(if plan ~= "fresh" then (old :: any).data else nil)
	if plan == "readOnly" then
		return { kind = "readOnly", data = data }
	end
	return { kind = "write", data = data, record = { data = data, lock = { job = job, at = now } } }
end

-- One step of saving (also inside UpdateAsync). "lost" = another server took the lock: write
-- nothing, stop saving. "skip" = write nothing now (a late autosave after the leave save let go
-- of the lock must not take it back). "write" = `record` is the new stored value.
function Profile.saveStep(
	old: any,
	job: string,
	data: Data,
	letGo: boolean,
	gone: boolean,
	now: number
): SaveStep
	if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= job then
		return { kind = "lost" }
	end
	if gone and not letGo then
		return { kind = "skip" }
	end
	return {
		kind = "write",
		record = { data = data, lock = if letGo then nil else { job = job, at = now } },
	}
end

-- A visit that played unsaved (the DataStore was down at join) finally reaches the real save.
-- `stored` is the migrated real save (a fresh copy: this changes and returns it), `session` what
-- the visit ended up with, `base` what the visit started from (Profile.new()). Only what the
-- visit EARNED is added: coin and count gains, new cars, new bests. Nothing in `stored` is ever
-- lowered or replaced by a blank, so a late save can't wipe what was there.
function Profile.mergeVisit(stored: Data, session: Data, base: Data): Data
	local function gain(a: number, b: number): number
		return math.max(a - b, 0)
	end
	local out: any = stored
	local ses: any = session
	out.coins = math.clamp(stored.coins + gain(session.coins, base.coins), 0, Profile.MAX_COINS)
	out.pile = math.clamp(stored.pile + gain(session.pile, base.pile), 0, Profile.MAX_COINS)
	for _, k in { "likes", "winPoints", "raceStars" } do
		out[k] = out[k] + gain(ses[k], (base :: any)[k])
	end
	out.raceStars = math.min(out.raceStars, Profile.MAX_RACE_STARS)
	for _, k in { "bestStreak", "lastSeen", "boostUntil", "plotLevel", "stage" } do
		out[k] = math.max(out[k], ses[k])
	end
	out.plotLevel = math.min(out.plotLevel, Profile.MAX_PLOT_LEVEL)
	out.stage = math.min(out.stage, Profile.STAGE.SHOPPED)
	-- sets: anything the visit has is added
	for _, k in { "liked", "bolts", "looks", "lookOff", "cars" } do
		for id, yes in ses[k] do
			if out[k][id] == nil and count(out[k]) < Profile.MAX_CARS then
				out[k][id] = yes
			end
		end
	end
	for owner, day in session.visited do
		out.visited[owner] = math.max(out.visited[owner] or 0, day)
	end
	for friend, day in session.friendsPaid do
		if out.friendsPaid[friend] ~= nil or count(out.friendsPaid) < Profile.MAX_LIST then
			out.friendsPaid[friend] = math.max(out.friendsPaid[friend] or 0, day)
		end
	end
	for owner, modes in session.starsFrom do
		local mine = out.starsFrom[owner]
		if mine == nil and count(out.starsFrom) < Profile.MAX_OWNERS then
			mine = {}
			out.starsFrom[owner] = mine
		end
		if mine then
			for mode, medal in modes do
				mine[mode] = math.max(mine[mode] or 0, medal)
			end
		end
	end
	local stars = 0
	for _, modes in out.starsFrom do
		for _, m in modes do
			stars += m
		end
	end
	out.stars = stars + out.raceStars
	-- tiles bought this visit come on top of the copies already owned
	for id, n in session.tiles do
		out.tiles[id] = math.min((out.tiles[id] or 0) + n, 99)
	end
	-- the stored value wins; the visit only fills what is missing
	for mode, r in session.plotRecords do
		if out.plotRecords[mode] == nil then
			out.plotRecords[mode] = r
		end
	end
	for mode, list in session.plotTop do
		if out.plotTop[mode] == nil then
			out.plotTop[mode] = list
		end
	end
	for id, r in session.rivals do
		if out.rivals[id] == nil and count(out.rivals) < Profile.MAX_RIVALS then
			out.rivals[id] = r
		end
	end
	for mode, id in session.equipped do
		if out.equipped[mode] == nil then
			out.equipped[mode] = id
		end
	end
	if out.track == nil then
		out.track = session.track
	end
	-- the daily gift: whichever was taken on the later day (the same day = already taken there)
	if session.dailyDay > stored.dailyDay then
		out.dailyDay = session.dailyDay
		out.dayStreak = session.dayStreak
	end
	if session.jobs.day > stored.jobs.day then
		out.jobs = { day = session.jobs.day, have = table.clone(session.jobs.have) }
	elseif session.jobs.day == stored.jobs.day then
		for i = 1, 3 do
			out.jobs.have[i] = math.max(out.jobs.have[i] or 0, session.jobs.have[i] or 0)
		end
	end
	-- the garage: theirs stays; cars bought this visit move in while there is room (a player who
	-- never had a garage gets the one the visit set up)
	local room = Profile.BASE_SLOTS + out.plotLevel
	local fresh = #stored.parked == 0
	for _, id in session.parked do
		if
			#out.parked < math.min(room, Profile.MAX_PARKED)
			and not table.find(out.parked, id)
			and (fresh or session.cars[id])
		then
			table.insert(out.parked, id)
		end
	end
	-- (Car VS Car) the garage: theirs stays, cars the visit got move in (by uid), training only
	-- goes up; counts add what the visit earned; the league never goes down
	out.nextUid = math.max(out.nextUid, session.nextUid)
	for _, c in session.garage do
		local mine = Profile.findCar(out, c.uid)
		if mine and mine.id ~= c.id then
			-- the same uid handed out twice (the visit didn't know the real save): a new one
			mine = nil
			c = table.clone(c)
			c.uid = tostring(out.nextUid)
			out.nextUid += 1
		end
		if mine == nil then
			if #out.garage < Profile.MAX_GARAGE then
				table.insert(out.garage, table.clone(c))
			end
		else
			mine.speed = math.max(mine.speed, c.speed)
			mine.turn = math.max(mine.turn, c.turn)
			mine.boost = math.max(mine.boost, c.boost)
		end
	end
	for _, k in { "trophies", "raceWins", "crates", "smashes", "matches", "matchWins" } do
		out[k] = math.clamp(out[k] + gain(ses[k], (base :: any)[k]), 0, Profile.MAX_COINS)
	end
	for _, k in { "garageLevel", "league" } do
		out[k] = math.max(out[k], ses[k])
	end
	out.picked = out.picked or session.picked
	if out.racer == "" then
		out.racer = session.racer
	end
	if #out.stations == 0 then
		for _, st in session.stations do
			table.insert(out.stations, table.clone(st))
		end
	else
		-- station levels bought this visit stay (a level only goes up); the visit's extra
		-- stations (a plot level it bought) come too
		for i, st in session.stations do
			local mine = out.stations[i]
			if mine then
				mine.level = math.max(mine.level, st.level)
			elseif #out.stations < Profile.MAX_STATIONS then
				local c = table.clone(st)
				if c.uid ~= "" and not Profile.findCar(out, c.uid) then
					c.uid = ""
				end
				table.insert(out.stations, c)
			end
		end
	end
	return out
end

return Profile
