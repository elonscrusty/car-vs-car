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
}
export type Lock = { job: string, at: number }

local Profile = {}

Profile.VERSION = 3 -- 2: likes, liked, visited. 3: bolts
Profile.MAX_OWNERS = 500 -- keeps the save small; stars from more owners than this stop counting
Profile.LOCK_TIMEOUT = 300 -- a server that hasn't saved for this long is gone: its lock is stale
Profile.MODES = { "race", "drift", "rock" }
Profile.MAX_LIST = 500 -- liked / visited entries kept
Profile.VISIT_COINS = 20 -- the visitor's gift (once per plot owner per day)
Profile.HOST_COINS = 10 -- the owner's share of it
Profile.BOLTS = 5 -- gold bolts hidden on the rock climb, each on top of a hard climb

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
	local stars = 0
	for _, modes in d.starsFrom do
		for _, m in modes do
			stars += m
		end
	end
	d.stars = stars
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

-- The day number for once-a-day gifts.
function Profile.day(now: number): number
	return math.floor(now / 86400)
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
-- The caller gives the owner Profile.HOST_COINS.
function Profile.visit(d: Data, selfId: number, ownerId: number, day: number): boolean
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
	d.coins += Profile.VISIT_COINS
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
