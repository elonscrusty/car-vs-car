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
	coins: number, -- phase 3
}
export type Lock = { job: string, at: number }

local Profile = {}

Profile.VERSION = 1
Profile.MAX_OWNERS = 500 -- keeps the save small; stars from more owners than this stop counting
Profile.LOCK_TIMEOUT = 300 -- a server that hasn't saved for this long is gone: its lock is stale
Profile.MODES = { "race", "drift", "rock" }

function Profile.new(): Data
	return { version = Profile.VERSION, stars = 0, starsFrom = {}, plotRecords = {}, coins = 0 }
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
