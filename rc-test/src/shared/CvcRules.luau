--!strict
-- Car VS Car rules on one save (carter 10-26, rc-game/cvc-plan.md): pick a starter, put cars on
-- stations, upgrade, level the plot, open and buy crates, a second of training, and a race's
-- pay. TrainingServer runs these for the Garage remote; being pure, Lune plays a new player's
-- first minutes through them (tests/cvc_flow.test.luau). Each returns whether it did anything,
-- so a "no" (not enough coins, not your car...) changes nothing.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end
local CarCatalog = sibling("CarCatalog")
local CarStats = sibling("CarStats")
local Crates = sibling("Crates")
local League = sibling("League")
local Profile = sibling("Profile")
local Training = sibling("Training")

type Data = Profile.Data

local CvcRules = {}

-- (stand-ins until Economy has them; Economy.luau takes these over)
CvcRules.COINS_PER_MIN = 3 -- each training car, a win's boost doubles it
CvcRules.WIN_BOOST_SECS = 600

function CvcRules.stats(id: string): Training.Stats
	return CarStats.stats(id)
end

-- COACH: a tap works once a minute. `at` = when it was last tapped (the plot's CoachAt, 0 =
-- never); returns the new CoachAt, or nil when it isn't ready (or `at` isn't a number).
function CvcRules.coach(at: unknown, now: number): number?
	if type(at) ~= "number" or at ~= at then
		return nil
	end
	return if Training.coachReady(at, now) then now else nil
end

-- The stations the plot level gives (new ones added empty; levels and cars kept).
function CvcRules.fitStations(data: Data)
	for i, kind in Training.stationsFor(data.plotLevel) do
		if data.stations[i] == nil then
			data.stations[i] = { kind = kind, level = 1, uid = "" }
		end
	end
end

-- The strength of the best car you own (what the league looks at).
function CvcRules.best(data: Data): number
	local top = 0
	for _, c in data.garage do
		top = math.max(top, Training.strength(c, CvcRules.stats(c.id)))
	end
	return top
end

-- First time in: the stations the plot level gives (an old or merged save can't keep extra
-- ones, a wrong kind, or one car on two stations), and a racer when there's a car. A save that
-- hasn't picked a starter yet (a new player, or an old save from the tycoon game) starts the
-- new-player steps from the top: the starter pick, the first race on a tap with easy bots, and
-- its crate.
function CvcRules.setUp(data: Data)
	if not data.picked then
		data.stage = Profile.STAGE.NEW
	end
	local kinds = Training.stationsFor(data.plotLevel)
	for i = #data.stations, #kinds + 1, -1 do
		table.remove(data.stations, i)
	end
	local used: { [string]: boolean } = {}
	for i, st in data.stations do
		st.kind = kinds[i]
		st.level = math.clamp(st.level, 1, Training.MAX_STATION_LEVEL)
		if st.uid ~= "" then
			if used[st.uid] or not Profile.findCar(data, st.uid) then
				st.uid = ""
			else
				used[st.uid] = true
			end
		end
	end
	CvcRules.fitStations(data)
	if data.racer ~= "" and not Profile.findCar(data, data.racer) then
		data.racer = ""
	end
	if data.racer == "" and data.garage[1] then
		data.racer = data.garage[1].uid
	end
end

-- The starter (once): it races and goes straight on the first station.
function CvcRules.pick(data: Data, id: unknown): boolean
	if data.picked or type(id) ~= "string" or not table.find(CarStats.STARTERS, id) then
		return false
	end
	local car = Profile.addCar(data, id)
	if not car then
		return false
	end
	data.picked = true
	data.racer = car.uid
	CvcRules.fitStations(data)
	if data.stations[1].uid == "" then
		data.stations[1].uid = car.uid
	end
	return true
end

-- Put one of your cars on station i ("" takes it off). A car is on one station at a time.
function CvcRules.station(data: Data, i: unknown, uid: unknown): boolean
	local st = if type(i) == "number" then data.stations[i] else nil
	if not st or type(uid) ~= "string" then
		return false
	end
	if uid ~= "" then
		if not Profile.findCar(data, uid) then
			return false
		end
		for _, other in data.stations do
			if other.uid == uid then
				other.uid = ""
			end
		end
	end
	st.uid = uid
	return true
end

function CvcRules.racer(data: Data, uid: unknown): boolean
	if type(uid) ~= "string" or not Profile.findCar(data, uid) then
		return false
	end
	data.racer = uid
	return true
end

-- One more level on station i, for coins.
function CvcRules.upgrade(data: Data, i: unknown): boolean
	local st = if type(i) == "number" then data.stations[i] else nil
	local cost = st and Training.upgradeCost(st.level)
	if not (st and cost) or st.level >= Training.MAX_STATION_LEVEL or data.coins < cost then
		return false
	end
	data.coins -= cost
	st.level += 1
	return true
end

-- One more plot level (one more station), for coins.
function CvcRules.levelUp(data: Data): boolean
	local cost = Training.plotCost(data.plotLevel)
	if not cost or data.plotLevel >= Training.MAX_PLOT_LEVEL or data.coins < cost then
		return false
	end
	data.coins -= cost
	data.plotLevel += 1
	CvcRules.fitStations(data)
	return true
end

-- Opens a free crate (from your first race): the new car's id, or nil.
function CvcRules.open(data: Data, rng: Crates.Rng): string?
	if data.crates <= 0 then
		return nil
	end
	local id = Crates.roll("free", rng)
	if type(id) ~= "string" or not CarCatalog.get(id) or not Profile.addCar(data, id) then
		return nil
	end
	data.crates -= 1
	return id
end

-- Buys a crate from the crate shop for coins and opens it: the new car's id, or nil.
-- (No Robux crates until carter gives prices. The screen showed the odds first.)
function CvcRules.buy(data: Data, kind: unknown, rng: Crates.Rng): string?
	local price = Crates.price(kind)
	if type(kind) ~= "string" or not table.find(Crates.SHOP, kind) or not price then
		return nil
	end
	if data.coins < price or #data.garage >= Profile.MAX_GARAGE then
		return nil
	end
	local id = Crates.roll(kind, rng)
	if type(id) ~= "string" or not CarCatalog.get(id) or not Profile.addCar(data, id) then
		return nil
	end
	data.coins -= price
	return id
end

-- The daily gift (carter's picks 36 and 46): the login streak's coins (Profile.daily) and a free
-- crate every day. Once a day; 0 coins and no crate when today's is already taken.
function CvcRules.daily(data: Data, day: number, mult: number?): (number, number, boolean)
	local coins, streak = Profile.daily(data, day, mult)
	if coins <= 0 then
		return 0, streak, false
	end
	data.crates = math.min(data.crates + 1, Profile.MAX_COINS)
	return coins, streak, true
end

export type RaceResult = { coins: number, trophy: boolean, league: number, firstCrate: boolean }

-- A race is over (place 0 = didn't finish): coins by league and place, a trophy for the top 3,
-- a win's boost, and the first race ever gives a crate. The league can only go up. (The caller
-- moves the save's stage on to RACED when firstCrate is true: the server tells its screens.)
-- `tried` false = didn't finish and never got past a gate (JOIN then walk off): no try pay.
function CvcRules.raceDone(data: Data, place: number, now: number, tried: boolean?): RaceResult
	local coins = if place <= 0 and tried == false then 0 else League.prize(data.league, place)
	data.coins = math.min(data.coins + coins, Profile.MAX_COINS)
	local trophy = League.trophy(place)
	if trophy then
		data.trophies += 1
	end
	if place == 1 then
		data.raceWins += 1
		data.boostUntil = now + CvcRules.WIN_BOOST_SECS
	end
	local first = data.stage < Profile.STAGE.RACED
	if first then
		data.crates += 1
	end
	data.league = League.next(CvcRules.best(data), data.raceWins, data.league)
	return { coins = coins, trophy = trophy, league = data.league, firstCrate = first }
end

-- `dt` seconds of training on every station with a car, and the coins it earns. `bits` is the
-- part of a coin left over last time; returns the new leftover and the cars that trained.
function CvcRules.tick(
	data: Data,
	dt: number,
	coach: boolean,
	now: number,
	bits: number
): (number, { Profile.GarageCar })
	local trainedCars = {}
	local training = 0
	for _, st in data.stations do
		local car = st.uid ~= "" and Profile.findCar(data, st.uid)
		if car then
			local stats = CvcRules.stats(car.id)
			if not Training.full(car, stats) then
				local after = Training.gain(car, st.kind, st.level, dt, coach, stats)
				car.speed, car.turn, car.boost = after.speed, after.turn, after.boost
				table.insert(trainedCars, car)
			end
			training += 1
		end
	end
	local boost = if data.boostUntil > now then 2 else 1
	bits += training * CvcRules.COINS_PER_MIN * boost * dt / 60
	local whole = math.floor(bits)
	if whole > 0 then
		data.coins = math.min(data.coins + whole, Profile.MAX_COINS)
	end
	data.league = League.next(CvcRules.best(data), data.raceWins, data.league)
	return bits - whole, trainedCars
end

return CvcRules
