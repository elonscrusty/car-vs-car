--!nocheck
-- Car VS Car, the whole loop on the real server scripts (Lead's FINISH-JOBS row LOOPTEST): a new
-- kid joins a pretend server running Main, Stars and CarShop (tests/fakeroblox.luau), picks a
-- starter, trains with COACH, races in the real ServerRaceRunner (a pretend screen drives the car
-- round the gates), opens crates, buys a car, upgrades, and races again: 3 full loops. Then the
-- kid leaves and joins a second server: everything comes back, and the daily gift isn't given
-- twice. Every thread error (red in Studio) and every warn fails the test.
local H = require("./harness")
local Fake = require("./fakeroblox")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car: 3 full loops on the real server scripts")

local KID = 101
local BEAT = 0.1 -- Heartbeat step, pretend seconds

-- a server with the game's three server Scripts running, as Roblox starts them
local function boot(store: Fake.Store, jobId: string)
	local S = Fake.server(store, { jobId = jobId })
	S.run("Main")
	S.run("Stars")
	S.run("CarShop")
	return S
end

-- The kid's screen in a race: puts the car on the grid spot the server sent ("drive"), then after
-- the 3-2-1 drives it round the gates at `speed` (big units/s; a real car tops ~95).
local function pilot(S, player)
	local TrackData = S.require("Shared.TrackData")
	local LobbyLayout = S.require("Shared.LobbyLayout")
	local ServerRace = S.require("Shared.ServerRace")
	local me = { speed = 90, seen = 0, on = false, placed = false, goAt = 0, i = 1, slot = 0 }
	S.game:GetService("RunService").Heartbeat:Connect(function(dt)
		local drives = S.got(player, "RCControl", "drive")
		if #drives > me.seen then
			me.seen = #drives
			me.on, me.placed, me.i = true, false, 1
			me.slot = drives[#drives][3]
			me.goAt = S.now() + ServerRace.GO_DELAY + 0.6
		end
		local car = S.workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and car.PrimaryPart
		if not (me.on and body and S.workspace:GetAttribute("RaceSlot") == me.slot) then
			return
		end
		local t = LobbyLayout.track(me.slot)
		if not me.placed then
			me.placed = true
			local g = drives[#drives][4]
			if type(g) == "table" then
				local wx, wy, wz = TrackData.toWorld(t, true, g.x, g.y, g.z)
				body.CFrame = roblox.CFrame.new(wx, wy, wz)
			end
		end
		if S.now() < me.goAt then
			return
		end
		local pos = body.Position
		local x, y, z = TrackData.toLocal(t, true, pos.X, pos.Y, pos.Z)
		local step = me.speed * dt
		while step > 0 do
			local g = t.gates[(me.i - 1) % #t.gates + 1]
			local d = math.sqrt((g.x - x) ^ 2 + (g.z - z) ^ 2)
			if d <= step then
				x, y, z = g.x, g.y, g.z
				step -= d
				me.i += 1
			else
				x += (g.x - x) / d * step
				z += (g.z - z) / d * step
				step = 0
			end
		end
		local wx, wy, wz = TrackData.toWorld(t, true, x, y, z)
		body.CFrame = roblox.CFrame.new(wx, wy, wz)
	end)
	return me
end

-- every error and warn so far, as one message ("" = none)
local function trouble(S): string
	local out = {}
	for _, e in S.errors do
		table.insert(out, "ERROR " .. e)
	end
	for _, w in S.warns do
		table.insert(out, "WARN " .. w)
	end
	return table.concat(out, "\n")
end

local function carIds(data): string
	local ids = {}
	for _, c in data.garage do
		table.insert(ids, c.id)
	end
	return table.concat(ids, ",")
end

local function totalBars(data): number
	local n = 0
	for _, c in data.garage do
		n += c.speed + c.turn + c.boost
	end
	return n
end

local store = Fake.store()
local S = boot(store, "server-A")
local PlayerData = S.require("PlayerData")
local Crates = S.require("Shared.Crates")
local Training = S.require("Shared.Training")
local CvcRules = S.require("Shared.CvcRules")
local Profile = S.require("Shared.Profile")
local kid = S.join(KID)
local driver = pilot(S, kid)
S.advance(5, BEAT)
local data = PlayerData.get(kid)

-- one race, start to end: JOIN, wait for the start, drive, wait for the result
local function race(): { any }?
	local before = #S.got(kid, "Garage", "race")
	S.send(kid, "ServerRace", "join")
	local waited = 0
	while #S.got(kid, "Garage", "race") == before and waited < 400 do
		S.advance(1, BEAT)
		waited += 1
		-- COACH whenever it's ready, as a kid on the plot does between races
		S.send(kid, "Garage", "coach")
	end
	-- the result card, then back on the plot
	S.advance(12, BEAT)
	local got = S.got(kid, "Garage", "race")
	return got[before + 1]
end

-- trains (and taps COACH once a minute) for `secs`
local function train(secs: number)
	for _ = 1, secs do
		S.send(kid, "Garage", "coach")
		S.advance(1, BEAT)
	end
end

-- the cheapest useful spend, the way the sim's normal kid shops: a crate, else a station level
local function shop(): string?
	local price = Crates.price("basic") :: number
	if data.coins >= price then
		local had = #data.garage
		S.send(kid, "Garage", "buy", "basic")
		S.advance(0.5, BEAT)
		return if #data.garage == had + 1 then "crate" else nil
	end
	for i, st in data.stations do
		local cost = Training.upgradeCost(st.level)
		if st.uid ~= "" and cost and data.coins >= cost then
			local lvl = st.level
			S.send(kid, "Garage", "upgrade", i)
			S.advance(0.5, BEAT)
			return if st.level == lvl + 1 then "upgrade" else nil
		end
	end
	local plotCost = Training.plotCost(data.plotLevel)
	if plotCost and data.coins >= plotCost then
		local lvl = data.plotLevel
		S.send(kid, "Garage", "level")
		S.advance(0.5, BEAT)
		if data.plotLevel ~= lvl + 1 then
			return nil
		end
		-- the new station comes empty: the screen opens the garage and the kid puts a car on it
		local busy = {}
		for _, st in data.stations do
			busy[st.uid] = true
		end
		for i, st in data.stations do
			for _, c in data.garage do
				if st.uid == "" and not busy[c.uid] then
					S.send(kid, "Garage", "station", i, c.uid)
					S.advance(0.5, BEAT)
					busy[c.uid] = true
					break
				end
			end
		end
		return "level"
	end
	return nil
end

-- races with the strongest car (the garage's "use this car")
local function pickBest()
	local best, top = nil, -1
	for _, c in data.garage do
		local s = Training.strength(c, CvcRules.stats(c.id))
		if s > top then
			best, top = c, s
		end
	end
	if best and best.uid ~= data.racer then
		S.send(kid, "Garage", "racer", best.uid)
		S.advance(0.5, BEAT)
	end
end

local log = {}
local spends = {}
local places = {}

test("join: a new kid gets a save, a plot, the garage lists and no errors", function()
	truthy(data, "PlayerData has the kid")
	eq(data.stage, Profile.STAGE.NEW, "stage")
	truthy(#S.got(kid, "Garage", "cars") >= 1, "the garage lists were sent")
	truthy(#S.got(kid, "RCControl", "own") >= 1, "the kid got a plot")
	eq(trouble(S), "", "errors or warns")
end)

test("pick a starter: it races and trains on the first station", function()
	S.send(kid, "Garage", "pick", "race_bolt")
	S.advance(1, BEAT)
	eq(data.picked, true, "picked")
	eq(#data.garage, 1, "cars")
	eq(data.stations[1].uid, data.garage[1].uid, "on station 1")
	eq(data.racer, data.garage[1].uid, "racer")
	eq(kid:GetAttribute("RacerCar"), "race_bolt", "RacerCar")
	local bars = totalBars(data)
	train(30)
	truthy(totalBars(data) > bars, "the starter trained")
	eq(trouble(S), "", "errors or warns")
end)

-- a fast kid, a so-so one, a slow one (a win, a middle place, last or out of time)
local SPEEDS = { 90, 70, 30 }
for loop = 1, 3 do
	test(`loop {loop}: race, coins, a crate or a buy, train`, function()
		local coins0, cars0, bars0 = data.coins, #data.garage, totalBars(data)
		driver.speed = SPEEDS[loop]
		pickBest()
		local r = race()
		truthy(r, "a race result came back within 400 s")
		local place, coins = r[3], r[4]
		table.insert(places, place)
		truthy(type(place) == "number" and place >= 0, `a place (got {place})`)
		truthy(coins > 0, "paid (a kid who drove gets something)")
		truthy(data.coins >= coins0 + coins, "the coins are in the save")
		-- back on the plot: not stuck in the race
		eq(kid:GetAttribute("RaceGroup"), nil, "RaceGroup cleared")
		eq(kid:GetAttribute("RacePlace"), nil, "RacePlace cleared")
		eq(S.workspace:GetAttribute("RaceSlot"), 0, "the race is over")
		if loop == 1 then
			eq(data.stage, Profile.STAGE.RACED, "first race: stage RACED")
			eq(data.crates, 1, "first race: a free crate")
		end
		-- open every free crate (the first race's, the daily gift's)
		local opened = 0
		while data.crates > 0 and opened < 3 do
			local had = #data.garage
			S.send(kid, "Garage", "open")
			S.advance(1, BEAT)
			eq(#data.garage, had + 1, "a crate gives a car")
			opened += 1
		end
		if loop == 1 then
			eq(data.stage, Profile.STAGE.SHOPPED, "first crate: stage SHOPPED")
			eq(#S.got(kid, "StarsEvent", "daily"), 1, "the daily gift came once, after the crate")
			eq(opened, 2, "the race's crate and the daily gift's crate")
		end
		-- every car that came went onto a station while there was room
		local onStation = 0
		for _, st in data.stations do
			if st.uid ~= "" then
				onStation += 1
			end
		end
		eq(onStation, math.min(#data.stations, #data.garage), "cars on stations")
		-- train until the next race comes round, spending when there's enough
		for _ = 1, 4 do
			train(30)
			local did = shop()
			if did then
				table.insert(spends, did)
			end
		end
		truthy(totalBars(data) > bars0, "cars trained")
		truthy(#data.garage >= cars0, "no car lost")
		table.insert(
			log,
			`loop {loop}: place {place}, +{coins} coins, {#data.garage} cars, {data.coins} coins left, league {data.league}`
		)
		eq(trouble(S), "", "errors or warns")
	end)
end

test("3 loops: a car was bought with coins and the kid never got stuck", function()
	eq(#places, 3, "3 races")
	eq(places[1], 1, "the fast kid won")
	truthy(places[3] ~= 1, "the slow kid didn't win")
	truthy(table.find(spends, "crate"), "bought a crate: " .. table.concat(spends, ","))
	for _, line in log do
		print("       " .. line)
	end
end)

-- what the save should hold after leaving
local want = {
	coins = data.coins,
	cars = carIds(data),
	crates = data.crates,
	league = data.league,
	trophies = data.trophies,
	plotLevel = data.plotLevel,
	dailyDay = data.dailyDay,
	stage = data.stage,
	racer = data.racer,
	stations = #data.stations,
}

test("leave and rejoin on another server: everything comes back, no 2nd daily gift", function()
	S.leave(kid)
	S.advance(5, BEAT)
	-- what the leave-save wrote: exactly the kid's numbers, the lock let go
	local saved = serde.decode("json", store["RCPlayerData_v1/p_" .. KID])
	eq(saved.lock, nil, "the lock was let go")
	eq(saved.data.coins, want.coins, "saved coins")
	eq(carIds(saved.data), want.cars, "saved cars")
	eq(trouble(S), "", "server A errors or warns")
	local S2 = boot(store, "server-B")
	local kid2 = S2.join(KID)
	S2.advance(5, BEAT)
	local PD2 = S2.require("PlayerData")
	local d2 = PD2.get(kid2)
	truthy(d2, "loaded")
	-- (5 s of training on server B already earned a coin or two)
	truthy(
		d2.coins >= want.coins and d2.coins <= want.coins + 5,
		`coins {d2.coins} vs {want.coins}`
	)
	eq(carIds(d2), want.cars, "cars")
	eq(d2.crates, want.crates, "crates")
	eq(d2.league, want.league, "league")
	eq(d2.trophies, want.trophies, "trophies")
	eq(d2.plotLevel, want.plotLevel, "plot level")
	eq(d2.dailyDay, want.dailyDay, "daily day")
	eq(d2.stage, want.stage, "stage")
	eq(d2.racer, want.racer, "racer")
	eq(#d2.stations, want.stations, "stations")
	eq(#S2.got(kid2, "StarsEvent", "daily"), 0, "no second daily gift the same day")
	eq(trouble(S2), "", "server B errors or warns")
end)
