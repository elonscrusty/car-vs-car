--!strict
-- Economy check (polish pass): a new player's first 30 minutes. Server races every break
-- (ServerRace.BREAK) plus about RACE_SECONDS for the race itself; pay is ServerRace.payFor, the
-- picked plot's owner gets PAY_OWNER, the race gives stars (starsFor), the daily gift pays day 1
-- on join and one loop job pays after the first race. Weekend x2 is off. The buyer is greedy:
-- after each payout it buys the cheapest thing it can (Rewards.coinGoals), one at a time.
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local Profile = require("../src/shared/Profile")
local Rewards = require("../src/shared/Rewards")
local ServerRace = require("../src/shared/ServerRace")
local TileShop = require("../src/shared/TileShop")

local test, truthy = H.test, H.truthy

print("Economy")

local RACE_SECONDS = 140 -- call + grid + 3 laps + the result
local CYCLE = ServerRace.BREAK + RACE_SECONDS
local MINUTES = 30
local JOB = 30 -- the cheapest loop job (finish a server race)

type Player = { name: string, places: { number }, ownerIn: { [number]: boolean }, racers: number }

local function minutes(t: number): string
	return string.format("%4.1f", t / 60)
end

-- buy every cheapest thing you can afford now; returns what was bought
local function buyAll(d: any): { string }
	local got = {}
	while true do
		local g = Rewards.coinGoals(d)[1]
		if not (g and g.ready) then
			break
		end
		if g.kind == "car" then
			for _, list in CarCatalog.SHOP do
				for _, c in list do
					if c.name == g.name then
						assert(CarCatalog.buy(d, c.id))
					end
				end
			end
		else
			for _, t in TileShop.TILES do
				if t.name == g.name then
					assert(TileShop.buy(d, t.id))
				end
			end
		end
		table.insert(got, `{g.kind} {g.name} ({g.price})`)
	end
	return got
end

-- what each player can do and when (minutes); also prints the table
local function run(
	p: Player
): { buys: { { t: number, what: string } }, firsts: { [string]: number } }
	local d: any = Profile.new()
	local earned = 0 -- coins earned so far (for "could buy X if saved")
	local firsts: { [string]: number } = {}
	local buys = {}
	local function earn(t: number, n: number)
		d.coins += n
		earned += n
		local function first(key: string, price: number)
			if firsts[key] == nil and earned >= price then
				firsts[key] = t
			end
		end
		local cheapestTile = math.huge
		for _, tl in TileShop.TILES do
			if tl.tier == "coins" and TileShop.open(d, tl.id) then
				cheapestTile = math.min(cheapestTile, tl.price)
			end
		end
		first("first coin tile", cheapestTile)
		first("first race car", CarCatalog.SHOP.race[2].price)
		first("first drift car", CarCatalog.SHOP.drift[2].price)
		first("3rd car (2 bought)", CarCatalog.SHOP.race[2].price + CarCatalog.SHOP.race[3].price)
		first("first gumball", CarCatalog.GUMBALL_PRICE)
		for _, what in buyAll(d) do
			table.insert(buys, { t = t, what = what })
		end
	end
	earn(0, Profile.DAILY[1]) -- the daily gift on join
	local k = 0
	while true do
		k += 1
		local t = k * CYCLE
		if t > MINUTES * 60 then
			break
		end
		local place = p.places[(k - 1) % #p.places + 1]
		local pay = ServerRace.payFor(place, true)
		if p.ownerIn[k] then
			pay += ServerRace.PAY_OWNER
		end
		if k == 1 then
			pay += JOB
		end
		Profile.addRaceStars(d, ServerRace.starsFor(place, true, p.racers))
		earn(t, pay)
	end
	print(`  {p.name}: {earned} coins, {d.stars} stars in {MINUTES} min`)
	for _, b in buys do
		print(`    {minutes(b.t)} min  {b.what}`)
	end
	for _, key in
		{
			"first coin tile",
			"first race car",
			"first drift car",
			"3rd car (2 bought)",
			"first gumball",
		}
	do
		print(
			`    could first buy {key}: {if firsts[key]
				then minutes(firsts[key]) .. " min"
				else "not in 30 min"}`
		)
	end
	return { buys = buys, firsts = firsts }
end

local SOLO: Player = {
	name = "solo (wins every race, own plot)",
	places = { 1 },
	ownerIn = setmetatable({}, {
		__index = function()
			return true
		end,
	}) :: any,
	racers = 1,
}
local MID: Player = {
	name = "4 players, middle (2nd/3rd)",
	places = { 2, 3 },
	ownerIn = { [2] = true },
	racers = 4,
}
local LAST: Player = { name = "4 players, always last", places = { 4 }, ownerIn = {}, racers = 4 }

test("economy: nothing for free, first tile after race 1, first car by race 3", function()
	for _, p in { SOLO, MID, LAST } do
		local r = run(p)
		-- nothing before the first race (the daily gift alone buys nothing)
		for _, b in r.buys do
			truthy(b.t >= CYCLE, `{p.name}: bought {b.what} before any race`)
		end
		truthy(
			(r.firsts["first coin tile"] or math.huge) <= CYCLE,
			`{p.name}: no tile after race 1`
		)
		truthy((r.firsts["first race car"] or math.huge) <= 3 * CYCLE, `{p.name}: no car by race 3`)
	end
end)

test(
	"economy: something new every ~10 min (middle of 4), every ~15 min even when always last",
	function()
		for _, case in { { MID, 10, 3 }, { LAST, 15, 2 } } do
			local p, gapMin, atLeast = case[1] :: Player, case[2] :: number, case[3] :: number
			local r = run(p)
			local last = 0
			for _, b in r.buys do
				truthy(
					b.t - last <= gapMin * 60,
					`{p.name}: {minutes(b.t - last)} min with nothing new`
				)
				last = b.t
			end
			truthy(#r.buys >= atLeast, `{p.name}: only {#r.buys} things in 30 min`)
		end
	end
)
