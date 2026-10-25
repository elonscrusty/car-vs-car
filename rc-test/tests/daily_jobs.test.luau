--!strict
-- Carter's daily jobs: 3 a day (drift, race, a bigger one), paid once, new each day.
local H = require("./harness")
local DailyJobs = require("../src/shared/DailyJobs")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy

print("DailyJobs")

test("3 jobs a day: one drift, one race, one bigger one", function()
	for day = 20000, 20010 do
		for _, uid in { 1, 77, 123456789, -1 } do
			local list = DailyJobs.list(day, uid)
			eq(#list, 3)
			for i, job in list do
				truthy(table.find(DailyJobs.POOLS[i], job) ~= nil, `{day} {uid} {i}`)
			end
		end
	end
end)

test("the mix changes from day to day", function()
	local seen: { [string]: boolean } = {}
	for day = 20000, 20006 do
		local key = ""
		for _, job in DailyJobs.list(day, 42) do
			key ..= job.id .. ","
		end
		seen[key] = true
	end
	local n = 0
	for _ in seen do
		n += 1
	end
	truthy(n >= 3, `only {n} different mixes in a week`)
end)

test("a job pays its coins once, when it gets done", function()
	local d = Profile.new()
	local day = 20000
	local list = DailyJobs.list(day, 5)
	local j = list[1]
	for k = 1, j.goal - 1 do
		eq(#DailyJobs.add(d, 5, day, j.event), 0, `step {k}`)
	end
	eq(d.coins, 0)
	local done = DailyJobs.add(d, 5, day, j.event)
	eq(#done, 1)
	eq(d.coins, j.coins)
	eq(#DailyJobs.add(d, 5, day, j.event), 0)
	eq(d.coins, j.coins)
	local lines = DailyJobs.lines(d, 5, day)
	eq(lines[1].done, true)
	eq(lines[1].have, j.goal)
	eq(lines[2].done, false)
end)

test("other events don't count; a new day starts over", function()
	local d = Profile.new()
	local day = 20000
	eq(#DailyJobs.add(d, 5, day, "nope"), 0)
	for _, l in DailyJobs.lines(d, 5, day) do
		eq(l.have, 0)
	end
	local j = DailyJobs.list(day, 5)[2]
	DailyJobs.add(d, 5, day, j.event)
	eq(d.jobs.have[2], 1)
	eq(DailyJobs.today(d, day), false)
	eq(DailyJobs.today(d, day + 1), true)
	eq(d.jobs.have[2], 0)
end)

test("save: jobs load back, junk and old saves are safe", function()
	local d = Profile.new()
	local day = 20000
	DailyJobs.add(d, 5, day, DailyJobs.list(day, 5)[3].event)
	local back = Profile.migrate(d)
	eq(back.jobs.day, day)
	eq(back.jobs.have[3], d.jobs.have[3])
	local old = Profile.migrate({ coins = 10 })
	eq(old.jobs.day, -1)
	eq(DailyJobs.today(old, day), true)
	local junk = Profile.migrate({ jobs = { day = "x", have = { 1 } } })
	eq(junk.jobs.day, -1)
	local bad = Profile.migrate({ jobs = { day = day, have = { 0 / 0, -4, 1e9 } } })
	eq(bad.jobs.have[1], 0)
	eq(bad.jobs.have[2], 0)
	eq(bad.jobs.have[3], 999)
end)

test("no rock jobs (rocks are gone)", function()
	for _, pool in DailyJobs.POOLS do
		for _, job in pool do
			truthy(not string.find(string.lower(job.text), "climb"), job.id)
			truthy(not string.find(job.event, "flag") and job.event ~= "climb", job.id)
		end
	end
end)
