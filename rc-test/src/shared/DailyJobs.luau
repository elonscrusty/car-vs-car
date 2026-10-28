--!strict
-- Carter's daily jobs: 3 small jobs a day (your garage, the race, the shop) that pay coins and
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
-- alone (no "beat a friend", no drift-plot glow spots): collect your garage, race, shop
-- (the tycoon plan, carter 10-26). Saves keep progress by index (have[1..3]) for today only, so the lists can change.
-- `DailyJobs.EVENTS` lists the events the server sends (tests check every job uses one).
DailyJobs.POOLS = {
	{
		{
			id = "collect2",
			text = "Collect your garage 2 times",
			event = "collect",
			goal = 2,
			coins = 30,
		},
		{
			id = "collect4",
			text = "Collect your garage 4 times",
			event = "collect",
			goal = 4,
			coins = 50,
		},
		{ id = "races2", text = "Finish 2 races", event = "raceDone", goal = 2, coins = 40 },
	},
	{
		{ id = "race", text = "Finish a server race", event = "raceDone", goal = 1, coins = 30 },
		{ id = "top3", text = "Get top 3 in a race", event = "raceTop3", goal = 1, coins = 50 },
		{ id = "win", text = "Win a server race", event = "raceWin", goal = 1, coins = 50 },
	},
	{
		{ id = "car", text = "Buy a new car", event = "newCar", goal = 1, coins = 40 },
		{ id = "spin", text = "Spin the gumball", event = "spin", goal = 1, coins = 30 },
		{ id = "races3", text = "Finish 3 races", event = "raceDone", goal = 3, coins = 50 },
	},
} :: { { Job } }

-- Car VS Car's jobs (carter's pick 45, 10-26: "win 1 race, train 5 min"): train, race, crates.
-- Stars.server swaps them in with DailyJobs.useCvc while Features.CVC is on.
DailyJobs.CVC_POOLS = {
	{
		{
			id = "train5",
			text = "Train your cars for 5 min",
			event = "train",
			goal = 5,
			coins = 30,
		},
		{
			id = "train8",
			text = "Train your cars for 8 min",
			event = "train",
			goal = 8,
			coins = 50,
		},
		{ id = "coach3", text = "Tap COACH 3 times", event = "coach", goal = 3, coins = 30 },
	},
	{
		{ id = "win", text = "Win 1 race", event = "raceWin", goal = 1, coins = 50 },
		{ id = "top3", text = "Get top 3 in a race", event = "raceTop3", goal = 1, coins = 50 },
		-- (a race you don't get to the end of doesn't count: the words say so, critic REPORT-1)
		{
			id = "race2",
			text = "Cross the finish line in 2 races",
			event = "raceDone",
			goal = 2,
			coins = 40,
		},
	},
	{
		{ id = "crate", text = "Open a crate", event = "crate", goal = 1, coins = 40 },
		{ id = "upgrade", text = "Upgrade your plot", event = "upgrade", goal = 1, coins = 40 },
		{
			id = "races3",
			text = "Cross the finish line in 3 races",
			event = "raceDone",
			goal = 3,
			coins = 50,
		},
	},
} :: { { Job } }
-- Car VS Car SMASH's jobs (FINISH-JOBS SAVES row: "Smash 10 karts", "open a crate", "play 3
-- matches"): smash, play, crates. Each list has one more job so the days aren't all the same.
DailyJobs.SMASH_POOLS = {
	{
		{ id = "smash10", text = "Smash 10 karts", event = "smash", goal = 10, coins = 50 },
		{ id = "smash6", text = "Smash 6 karts", event = "smash", goal = 6, coins = 30 },
	},
	{
		{ id = "match3", text = "Play 3 matches", event = "matchDone", goal = 3, coins = 40 },
		{ id = "mtop3", text = "Get top 3 in a match", event = "matchTop3", goal = 1, coins = 50 },
	},
	{
		{ id = "crate", text = "Open a crate", event = "crate", goal = 1, coins = 40 },
		{ id = "match5", text = "Play 5 matches", event = "matchDone", goal = 5, coins = 50 },
	},
} :: { { Job } }
DailyJobs.TYCOON_POOLS = DailyJobs.POOLS

-- Which jobs today's lists come from (true = Car VS Car's).
function DailyJobs.useCvc(on: boolean)
	DailyJobs.POOLS = if on then DailyJobs.CVC_POOLS else DailyJobs.TYCOON_POOLS
end

-- The smash game's jobs (call after useCvc; phase 5 of plans/smash turns it on).
function DailyJobs.useSmash()
	DailyJobs.POOLS = DailyJobs.SMASH_POOLS
end

-- every event a job may use, and who sends it (all can happen to a kid playing alone)
DailyJobs.EVENTS = {
	train = "TrainingServer: a minute with a car training",
	coach = "TrainingServer: tapped COACH",
	crate = "TrainingServer: opened or bought a crate",
	upgrade = "TrainingServer: upgraded a station or the plot",
	collect = "TycoonServer: collected the garage's coins",
	spin = "CarShop: spun the gumball",
	raceDone = "ServerRaceRunner: finished a server race",
	raceTop3 = "ServerRaceRunner: 1st-3rd in a server race",
	raceWin = "ServerRaceRunner: won a server race",
	newCar = "CarShop: bought a car or won a new one from the gumball",
	smash = "MatchRunner: smashed a kart (once per smash)",
	matchDone = "MatchRunner: played a match to the end",
	matchTop3 = "MatchRunner: 1st-3rd in a match",
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
