--!strict
-- Car VS Car earning speed (audit C3, MASTER-PROMPT §9 NOW #2, §10 "Economy sim"): a normal kid
-- (tests/cvc_sim.luau) plays 20 min a day for 3 weeks, on several seeds, through the real rules.
-- The bars: first crate by 3 min, 2nd crate by 12 min, the first league-up (Silver) in 25-40 min,
-- Diamond in about 2 weeks, and never a long stretch with nothing new (audit B9: ~8 min).
-- If a number here fails, retune the game's numbers, not the bar.
local H = require("./harness")
local Sim = require("./cvc_sim")
local League = require("../src/shared/League")

local test, truthy = H.test, H.truthy

print("Car VS Car economy sim")

local SEEDS, DAYS = 7, 21
local runs: { Sim.Result } = {}
for seed = 1, SEEDS do
	table.insert(runs, Sim.run(DAYS, seed * 7919))
end

-- the middle run's number (nil = never)
local function median(pick: (Sim.Result) -> number?): number
	local list = {}
	for _, r in runs do
		table.insert(list, pick(r) or math.huge)
	end
	table.sort(list)
	return list[math.floor((#list + 1) / 2)]
end
local function worst(pick: (Sim.Result) -> number?): number
	local most = 0
	for _, r in runs do
		most = math.max(most, pick(r) or math.huge)
	end
	return most
end
local function f(n: number): string
	return string.format("%.1f", n)
end

local day = Sim.SESSION_MIN
local silver = median(function(r)
	return r.leagues[2]
end)
local diamond = median(function(r)
	return r.leagues[#League.NAMES]
end)
print(
	`       {SEEDS} kids, {DAYS} days of {day} min: Silver {f(silver)} min, Gold {f(
		median(function(r)
			return r.leagues[3]
		end)
	)} min, Diamond {f(diamond)} min (day {f(diamond / day)})`
)

test("economy: first crate by 3 min, a 2nd by 12 min", function()
	local first = worst(function(r)
		return r.crates[1]
	end)
	local second = worst(function(r)
		return r.crates[2]
	end)
	-- the first race's crate, then the daily gift's (kids buy station levels before a crate)
	truthy(first <= 3, `first crate at {f(first)} min`)
	truthy(second <= 12, `2nd crate at {f(second)} min`)
end)

test("economy: Silver (the first league-up) in 25-40 min", function()
	truthy(silver >= 25 and silver <= 40, `Silver at {f(silver)} min`)
	-- no kid gets it in the first session
	local soonest = math.huge
	for _, r in runs do
		soonest = math.min(soonest, r.leagues[2] or math.huge)
	end
	truthy(soonest > day, `a kid got Silver at {f(soonest)} min`)
end)

test("economy: Diamond in about 2 weeks", function()
	local days = diamond / day
	truthy(days >= 10 and days <= 18, `Diamond on day {f(days)}`)
end)

test("economy: leagues count top 3, so a kid who rarely wins still climbs", function()
	for _, r in runs do
		truthy(r.wins < r.races / 4, `{r.wins} wins in {r.races} races`)
		truthy(r.data.league >= 3, `league {r.data.league} after {DAYS} days`)
	end
end)

test("economy: never long with nothing new in the first session (B9)", function()
	local early = worst(function(r)
		return Sim.longestWait(r, 3, 12)
	end)
	local session = median(function(r)
		return Sim.longestWait(r, 3, day)
	end)
	truthy(early <= 4, `waited {f(early)} min between 3 and 12 min`)
	truthy(session <= 7, `waited {f(session)} min in the first session`)
end)
