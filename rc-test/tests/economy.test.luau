--!strict
-- Economy check (tycoon plan, carter 10-26): a new player's first 30 minutes. A map race every
-- ServerRace.MAP_BREAK plus about RACE_SECONDS for the race; pay is ServerRace.payFor and a
-- win doubles the garage for Tycoon.BOOST_SECS. The garage makes Tycoon.income from the parked
-- cars; the player collects after each race and buys the cheapest new car (it parks if there's
-- room) or, with every shop car owned, the next garage level. Weekend x2, daily gift and jobs
-- are left out (they only make it faster).
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local Profile = require("../src/shared/Profile")
local Rewards = require("../src/shared/Rewards")
local ServerRace = require("../src/shared/ServerRace")
local Tycoon = require("../src/shared/Tycoon")

local test, truthy = H.test, H.truthy

print("Economy")

local RACE_SECONDS = 150 -- vote call + grid + laps + the result (maps cap at 180)
local CYCLE = ServerRace.MAP_BREAK + RACE_SECONDS
local MINUTES = 30

type Player = { name: string, places: { number }, racers: number }

local function minutes(t: number): string
	return string.format("%4.1f", t / 60)
end

local function owns(d: any): (string) -> boolean
	return function(id: string): boolean
		return CarCatalog.owns(d, id)
	end
end

-- buy the next goal while it's affordable; returns what was bought
local function buyAll(d: any): { string }
	local got = {}
	while true do
		local g = Rewards.next(d)
		if not (g and g.ready) then
			break
		end
		if g.kind == "car" then
			for _, list in CarCatalog.SHOP do
				for _, c in list do
					if c.name == g.name then
						assert(CarCatalog.buy(d, c.id))
						-- park it, or swap it in for the worst parked car
						if not Tycoon.park(d.parked, d.plotLevel, c.id, true, owns(d)) then
							table.sort(d.parked, function(a, b)
								return Tycoon.perMin(a) > Tycoon.perMin(b)
							end)
							if Tycoon.perMin(c.id) > Tycoon.perMin(d.parked[#d.parked]) then
								table.remove(d.parked)
								Tycoon.park(d.parked, d.plotLevel, c.id, true, owns(d))
							end
						end
					end
				end
			end
		elseif g.kind == "level" then
			d.coins -= g.price
			d.plotLevel += 1
		else
			error(`unexpected goal kind {g.kind}`)
		end
		table.insert(got, `{g.kind} {g.name} ({g.price})`)
	end
	return got
end

local function run(p: Player): { buys: { { t: number, what: string } }, firstCar: number? }
	local d: any = Profile.new()
	d.parked = Tycoon.firstParked(0, owns(d))
	local buys = {}
	local firstCar: number? = nil
	local t = 0
	for k = 1, math.floor(MINUTES * 60 / CYCLE) do
		-- the garage fills through the wait and the race (boost from a win counts for its time)
		local boosted = math.min(CYCLE, math.max(0, d.boostUntil - t))
		local base = Tycoon.income(d.parked, 0, 0)
		d.pile = Tycoon.accrue(d.pile, base, CYCLE) + base * (Tycoon.WIN_BOOST - 1) * boosted / 60
		t += CYCLE
		local place = p.places[(k - 1) % #p.places + 1]
		d.coins += ServerRace.payFor(place, true)
		if place == 1 then
			d.boostUntil = t + Tycoon.BOOST_SECS
		end
		d.coins += math.floor(d.pile)
		d.pile -= math.floor(d.pile)
		for _, what in buyAll(d) do
			table.insert(buys, { t = t, what = what })
			if firstCar == nil and string.sub(what, 1, 3) == "car" then
				firstCar = t
			end
		end
	end
	print(`  {p.name}: income {Tycoon.income(d.parked, 0, 0)}/min after {MINUTES} min`)
	for _, b in buys do
		print(`    {minutes(b.t)} min  {b.what}`)
	end
	return { buys = buys, firstCar = firstCar }
end

local SOLO: Player = { name = "solo (wins every race)", places = { 1 }, racers = 1 }
local MID: Player = { name = "4 players, middle (2nd/3rd)", places = { 2, 3 }, racers = 4 }
local LAST: Player = { name = "4 players, always last", places = { 4 }, racers = 4 }

test("economy: the first new car comes by race 2 (race 3 when always last)", function()
	for _, case in { { SOLO, 2 }, { MID, 2 }, { LAST, 3 } } do
		local p, races = case[1] :: Player, case[2] :: number
		local r = run(p)
		truthy((r.firstCar or math.huge) <= races * CYCLE, `{p.name}: no car by race {races}`)
	end
end)

test(
	"economy: something new every ~10 min (middle of 4), every ~15 min when always last",
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
