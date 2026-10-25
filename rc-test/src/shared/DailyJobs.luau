--!strict
-- Carter's daily jobs: 3 small jobs a day (your track, the server race, collecting) that pay coins and
-- start over each day. Which 3 you get comes from the day and your user id, so only how far you
-- got is saved (Profile.Data.jobs). The server tells this module what happened ("lap",
-- "raceWin", ...) and it pays the coins when a job gets done. Pure tables, so Lune can test it.

export type Job = {
	id: string,
	text: string,
	event: string, -- what the server says happened (see Stars.server)
	goal: number,
	coins: number,
}
export type Save = { day: number, have: { number } }
export type Line = { text: string, have: number, goal: number, coins: number, done: boolean }

local DailyJobs = {}

DailyJobs.COUNT = 3

-- three lists, each day picks one job from each. Every job can be done by a new kid playing
-- alone (no "beat a friend", no drift-plot glow spots): build and drive your track, race,
-- collect. Saves keep progress by index (have[1..3]) for today only, so the lists can change.
-- `DailyJobs.EVENTS` lists the events the server sends (tests check every job uses one).
DailyJobs.POOLS = {
	{
		{ id = "laps", text = "Drive 3 laps on a track", event = "lap", goal = 3, coins = 30 },
		{ id = "laps8", text = "Drive 8 laps on a track", event = "lap", goal = 8, coins = 50 },
		{ id = "tiles", text = "Place 5 tiles", event = "tiles", goal = 5, coins = 30 },
	},
	{
		{ id = "race", text = "Finish a server race", event = "raceDone", goal = 1, coins = 30 },
		{ id = "top3", text = "Get top 3 in a race", event = "raceTop3", goal = 1, coins = 50 },
		{ id = "win", text = "Win a server race", event = "raceWin", goal = 1, coins = 50 },
	},
	{
		{ id = "car", text = "Buy a new car", event = "newCar", goal = 1, coins = 40 },
		{ id = "stars", text = "Earn 3 stars", event = "stars", goal = 3, coins = 40 },
		{ id = "tile", text = "Buy a new tile", event = "newTile", goal = 1, coins = 30 },
	},
} :: { { Job } }

-- every event a job may use, and who sends it (all can happen to a kid playing alone)
DailyJobs.EVENTS = {
	lap = "Stars.server: a lap on a race plot or built race track",
	tiles = "TrackBuild: road laid / tiles dropped or placed",
	raceDone = "ServerRaceRunner: finished a server race",
	raceTop3 = "ServerRaceRunner: 1st-3rd in a server race",
	raceWin = "ServerRaceRunner: won a server race",
	newCar = "CarShop: bought a car or won a new one from the gumball",
	stars = "ServerRaceRunner: race stars (n)",
	newTile = "CarShop: bought a tile or won a new one from the tile spin",
} :: { [string]: string }

function DailyJobs.new(day: number): Save
	return { day = day, have = { 0, 0, 0 } }
end

-- Today's 3 jobs for this player. Neighbours on the same day get different picks, and the same
-- player gets a new mix the next day.
function DailyJobs.list(day: number, userId: number): { Job }
	local seed = (math.floor(day) % 9973) * 31 + math.abs(math.floor(userId)) % 9973
	local out: { Job } = {}
	for i, pool in DailyJobs.POOLS do
		table.insert(out, pool[(seed + i * 7 + math.floor(seed / 3) * i) % #pool + 1])
	end
	return out
end

-- Bring the save to today: true when a new day started (new jobs to show).
function DailyJobs.today(d: { jobs: Save }, day: number): boolean
	if d.jobs.day == day then
		return false
	end
	d.jobs = DailyJobs.new(day)
	return true
end

-- Something happened (`event`, `n` times): counts towards today's jobs and pays the coins of
-- each one that just got done (times `boost`: 2 on weekends). Returns the jobs it finished.
function DailyJobs.add(
	d: { jobs: Save, coins: number },
	userId: number,
	day: number,
	event: string,
	n: number?,
	boost: number?
): { Job }
	DailyJobs.today(d, day)
	local done: { Job } = {}
	for i, job in DailyJobs.list(day, userId) do
		local had = d.jobs.have[i] or 0
		if job.event == event and had < job.goal then
			local now = math.min(had + (n or 1), job.goal)
			d.jobs.have[i] = now
			if now >= job.goal then
				d.coins += job.coins * (boost or 1)
				table.insert(done, job)
			end
		end
	end
	return done
end

-- What the panel shows.
function DailyJobs.lines(d: { jobs: Save }, userId: number, day: number): { Line }
	local out: { Line } = {}
	for i, job in DailyJobs.list(day, userId) do
		local have = if d.jobs.day == day then d.jobs.have[i] or 0 else 0
		table.insert(out, {
			text = job.text,
			have = have,
			goal = job.goal,
			coins = job.coins,
			done = have >= job.goal,
		})
	end
	return out
end

return DailyJobs
