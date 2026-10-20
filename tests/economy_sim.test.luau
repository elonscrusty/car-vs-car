--!strict
-- Economy simulation (pure, Lune only). Plays many fake players through 60 days using the REAL
-- configs and rules (Inventory, Progress, Quests, Daily, Spin, Gacha, Store) and asserts sanity.
-- All coin numbers are PRETEND placeholders. The printed numbers feed docs/economy-report.md.

local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local Daily = require("../src/shared/Daily")
local FeatureFlags = require("../src/shared/FeatureFlags")
local Gacha = require("../src/shared/Gacha")
local Inventory = require("../src/shared/Inventory")
local LobbyConfig = require("../src/shared/LobbyConfig")
local Progress = require("../src/shared/Progress")
local ProgressConfig = require("../src/shared/ProgressConfig")
local Quests = require("../src/shared/Quests")
local QuestsConfig = require("../src/shared/QuestsConfig")
local Spin = require("../src/shared/Spin")
local Store = require("../src/shared/Store")

print("Economy sim")

local DAY = QuestsConfig.Daily.dayLength
local DAYS = 60
local RUNS = 300
local NEVER = 999

-- Small deterministic rng (LCG) so the numbers in docs/economy-report.md can be reproduced.
local function makeRng(seed: number): () -> number
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

type Result = {
	firstPullDay: number, -- 1-based day of the first claw pull
	firstRare: number,
	firstEpic: number,
	firstLegendary: number,
	owned30: number,
	owned60: number,
	coins30: number,
	coins60: number,
	maxCoins: number,
	totalRefund: number,
	pulls: number,
	dupes: number,
	storeBuys: number,
}

local function countOwned(p: any): number
	local n = 0
	for _ in p.owned do
		n += 1
	end
	return n
end

local function simulate(
	seed: number,
	matchesPerDay: number,
	winRate: number,
	useStore: boolean
): Result
	local rng = makeRng(seed)
	local p = Inventory.default()
	local r: Result = {
		firstPullDay = NEVER,
		firstRare = NEVER,
		firstEpic = NEVER,
		firstLegendary = NEVER,
		owned30 = 0,
		owned60 = 0,
		coins30 = 0,
		coins60 = 0,
		maxCoins = 0,
		totalRefund = 0,
		pulls = 0,
		dupes = 0,
		storeBuys = 0,
	}
	local function noteCar(carId: string, day: number)
		local rarity = LobbyConfig.Rarity[carId]
		if rarity == "Rare" and r.firstRare == NEVER then
			r.firstRare = day
		elseif rarity == "Epic" and r.firstEpic == NEVER then
			r.firstEpic = day
		elseif rarity == "Legendary" and r.firstLegendary == NEVER then
			r.firstLegendary = day
		end
	end
	local function claimQuests(now: number)
		local i = 1
		while i <= #p.quests do
			if Quests.isDone(p.quests[i]) then
				Quests.claim(p, i, now, function(n)
					Inventory.addCoins(p, n)
				end)
				i = 1
			else
				i += 1
			end
		end
	end
	local function pullAll(day: number, onlyFree: boolean)
		while Gacha.canBuy(p :: any) do
			if onlyFree and p.freePullUsed and p.daily.freePulls <= 0 then
				break
			end
			local res = Gacha.pull(p :: any, rng)
			r.pulls += 1
			if r.firstPullDay == NEVER then
				r.firstPullDay = day
			end
			if res.isNew then
				noteCar(res.carId, day)
			else
				r.dupes += 1
				r.totalRefund += res.refund
			end
		end
	end
	for day = 1, DAYS do
		local now = (day + 100) * DAY + 3600
		Quests.ensure(p, now)
		Daily.claim(p.daily, now)
		if FeatureFlags.enabled("dailySpin") then
			Spin.spin(p.spin, now, rng, function(n)
				Inventory.addCoins(p, n)
			end, function(n)
				Spin.addFreePulls(p.daily, n)
			end)
		end
		for _ = 1, matchesPerDay do
			local owned = Inventory.ownedList(p)
			local carId = owned[math.floor(rng() * #owned) + 1]
			local won = rng() < winRate
			local res = Progress.applyMatchResult(p, carId, won, ProgressConfig)
			local earned = if won
				then LobbyConfig.Rewards.winCoins
				else LobbyConfig.Rewards.loseCoins
			Quests.onMatchEnd(p, { won = won, carId = carId, opponentIsBot = rng() < 0.5 })
			Inventory.addCoins(p, earned + res.coinsBonus)
			if won then
				p.wins += 1
			end
			p.matches += 1
			claimQuests(now)
		end
		if useStore then
			-- Saves for the cheapest unowned car; only free/gift claw tries are used.
			local cheapest: string? = nil
			for _, id in CarConfig.Order do
				if
					not p.owned[id] and (cheapest == nil or Store.price(id) < Store.price(cheapest))
				then
					cheapest = id
				end
			end
			if cheapest and p.freePullUsed and Store.buy(p, cheapest) then
				r.storeBuys += 1
				noteCar(cheapest, day)
			end
			pullAll(day, true)
		else
			pullAll(day, false) -- claw whenever affordable
		end
		r.maxCoins = math.max(r.maxCoins, p.coins)
		if day == 30 then
			r.owned30, r.coins30 = countOwned(p), p.coins
		elseif day == 60 then
			r.owned60, r.coins60 = countOwned(p), p.coins
		end
	end
	return r
end

local function median(xs: { number }): number
	local c = table.clone(xs)
	table.sort(c)
	return c[math.ceil(#c / 2)]
end

local function fraction(xs: { number }, pred: (number) -> boolean): number
	local n = 0
	for _, x in xs do
		if pred(x) then
			n += 1
		end
	end
	return n / #xs
end

local function run(matches: number, winRate: number, useStore: boolean): { Result }
	local out: { Result } = {}
	for seed = 1, RUNS do
		table.insert(out, simulate(seed * 7919, matches, winRate, useStore))
	end
	return out
end

local function col(rs: { Result }, key: string): { number }
	local out: { number } = {}
	for _, r in rs do
		table.insert(out, (r :: any)[key])
	end
	return out
end

local function report(name: string, rs: { Result })
	print(
		`  [{name}] median first day: pull {median(col(rs, "firstPullDay"))}, Rare {median(
			col(rs, "firstRare")
		)}, Epic {median(col(rs, "firstEpic"))}, Legendary {median(col(rs, "firstLegendary"))} ({NEVER} = never in {DAYS}d)`
	)
	print(
		`  [{name}] owned d30 {median(col(rs, "owned30"))} d60 {median(col(rs, "owned60"))}; coins d30 {median(
			col(rs, "coins30")
		)} d60 {median(col(rs, "coins60"))}; peak {median(col(rs, "maxCoins"))}`
	)
	print(
		`  [{name}] pulls {median(col(rs, "pulls"))}, dupes {median(col(rs, "dupes"))}, refund coins {median(
			col(rs, "totalRefund")
		)}, store buys {median(col(rs, "storeBuys"))}`
	)
end

local casual = run(4, 0.5, false)
print(
	`  [casual] share with a Legendary after day 14: {fraction(
		col(casual, "firstLegendary"),
		function(d)
			return d > 14
		end
	)}; never by day 60: {fraction(col(casual, "firstLegendary"), function(d)
		return d > 60
	end)}`
)
local dailyOnly = run(0, 0.5, false)
local storer = run(4, 0.5, true)
report("casual 4/day 50%", casual)
report("daily-only", dailyOnly)
report("casual+store", storer)

H.test("a new player can pull the claw in the first session (day 1)", function()
	H.truthy(LobbyConfig.Gacha.firstPullFree)
	H.eq(
		fraction(col(casual, "firstPullDay"), function(d)
			return d == 1
		end),
		1
	)
	H.eq(median(col(dailyOnly, "firstPullDay")), 1)
end)

H.test("a Rare comes early and a Legendary is not guaranteed before day 14", function()
	H.truthy(median(col(casual, "firstRare")) <= 14, "median Rare by day 14")
	H.truthy(fraction(col(casual, "firstLegendary"), function(d)
		return d > 14
	end) > 0.1, "some casual players should still be chasing a Legendary at day 14")
end)

H.test("a Legendary is reachable by day 60 for most casual players", function()
	H.truthy(fraction(col(casual, "firstLegendary"), function(d)
		return d <= 60
	end) >= 0.75, "at least 75% own a Legendary by day 60")
end)

H.test("no unbounded coin inflation", function()
	-- A pull that could only give a duplicate is never sold, so a player who owns every car keeps
	-- their coins (no sink yet): the pile is checked while they still collect, and by income after.
	H.truthy(median(col(casual, "coins30")) < 1500, "casual coin pile stays small while collecting")
	-- Without a sink, a finished collection piles coins up at the income rate (documented in
	-- docs/economy-report.md); it must stay inside what the configs can pay per day.
	local maxPerDay = 4 * (LobbyConfig.Rewards.winCoins + ProgressConfig.StreakBonusMax) + 3 * 80
	H.truthy(median(col(storer, "coins60")) < DAYS * maxPerDay)
	H.truthy(LobbyConfig.Rewards.winCoins + ProgressConfig.StreakBonusMax <= 200)
end)

H.test("daily-only player still progresses, slower than casual", function()
	H.truthy(median(col(dailyOnly, "owned60")) > 1, "daily-only owns something new")
	-- Compared at day 30: the Epic pity guarantee lets a daily-only player catch up by day 60.
	H.truthy(median(col(dailyOnly, "owned30")) < median(col(casual, "owned30")))
end)

H.test("duplicates give nothing back (carter), so there is no refund loop", function()
	for _, amount in LobbyConfig.Gacha.duplicateRefunds do
		H.eq(amount, 0)
	end
	H.eq(LobbyConfig.Gacha.duplicateRefund, 0)
	H.eq(median(col(casual, "totalRefund")), 0)
end)

H.test("store prices are ordered and reachable", function()
	local prices = LobbyConfig.Store.prices
	H.truthy(
		prices.Common < prices.Rare and prices.Rare < prices.Epic and prices.Epic < prices.Legendary
	)
	local perDay = 4 * (0.5 * LobbyConfig.Rewards.winCoins + 0.5 * LobbyConfig.Rewards.loseCoins)
	H.truthy(prices.Common / perDay <= 2, "a Common car is about 2 days of play")
	H.truthy(prices.Legendary / perDay <= 20, "a Legendary car is within 20 days of saving")
end)
