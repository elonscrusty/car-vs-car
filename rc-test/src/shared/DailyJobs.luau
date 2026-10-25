--!strict
-- Carter's daily jobs: 3 small jobs a day (one drift, one race, one bigger one) that pay coins and
-- start over each day. Which 3 you get comes from the day and your user id, so only how far you
-- got is saved (Profile.Data.jobs). The server tells this module what happened ("touch", "lap",
-- "flag3", ...) and it pays the coins when a job gets done. Pure tables, so Lune can test it.

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

-- one list per kind of plot; each day picks one job from each
DailyJobs.POOLS = {
	{
		{
			id = "touch",
			text = "Drift through 3 glow spots",
			event = "touch",
			goal = 3,
			coins = 30,
		},
		{ id = "slides", text = "Do 5 drifts of 500+", event = "slide500", goal = 5, coins = 40 },
		{
			id = "bigslide",
			text = "Score 1500 in one drift",
			event = "slide1500",
			goal = 1,
			coins = 40,
		},
	},
	{
		{ id = "laps", text = "Drive 3 race laps", event = "lap", goal = 3, coins = 30 },
		{ id = "beat", text = "Beat 1 friend's best time", event = "beat", goal = 1, coins = 50 },
		{
			id = "medal",
			text = "Win a medal on a friend's plot",
			event = "medal",
			goal = 1,
			coins = 40,
		},
	},
	-- (was rocks; carter dropped them 2026-10-23): a bigger race or drift job
	{
		{ id = "laps8", text = "Drive 8 race laps", event = "lap", goal = 8, coins = 60 },
		{
			id = "slides12",
			text = "Do 12 drifts of 500+",
			event = "slide500",
			goal = 12,
			coins = 60,
		},
		{ id = "medal2", text = "Win 2 medals", event = "medal", goal = 2, coins = 70 },
	},
} :: { { Job } }

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
