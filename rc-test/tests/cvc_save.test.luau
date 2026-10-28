--!strict
-- Car VS Car go-live save check (FINISH-JOBS STATS row): a kid who played for real leaves, the
-- save goes through the same steps PlayerData runs inside UpdateAsync (take the lock, autosave,
-- leave save), is stored the way a DataStore stores it (JSON), and is loaded back on another
-- server. Coins, cars (with their training), plot and station levels, league, daily streak and
-- crates all come back the same, also after a server crash and after the join set-up.
local H = require("./harness")
local serde = require("@lune/serde")
local CvcRules = require("../src/shared/CvcRules")
local CarStats = require("../src/shared/CarStats")
local Crates = require("../src/shared/Crates")
local Profile = require("../src/shared/Profile")
local Training = require("../src/shared/Training")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car: save and rejoin")

local function rng(n: number): Crates.Rng
	return {
		NextNumber = function(_: any): number
			return n
		end,
	} :: any
end

-- What the DataStore hands back: the value after a trip through JSON.
local function stored(record: any): any
	return serde.decode("json", serde.encode("json", record))
end

-- Every value in `a` is in `b` too (tables compared all the way down).
local function same(a: any, b: any, path: string)
	if type(a) ~= "table" then
		truthy(a == b, `{path}: {tostring(a)} came back as {tostring(b)}`)
		return
	end
	truthy(type(b) == "table", `{path} is gone`)
	if type(b) ~= "table" then
		return
	end
	for k, v in a do
		same(v, b[k], `{path}.{tostring(k)}`)
	end
	for k in b do
		truthy(a[k] ~= nil, `{path}.{tostring(k)} appeared`)
	end
end

-- A kid with a bit of everything: a trained starter, crate cars, upgraded stations, the plot at
-- its top level, races, Gold, a 3-day daily streak and a crate not opened yet.
local DAY = 20000
local function played(): Profile.Data
	local d = Profile.new()
	CvcRules.setUp(d)
	assert(CvcRules.pick(d, CarStats.STARTERS[2]), "pick")
	local now = DAY * 86400
	CvcRules.raceDone(d, 1, now) -- the first race: its crate
	Profile.raiseStage(d, Profile.STAGE.RACED) -- (the server does this after race 1)
	assert(CvcRules.open(d, rng(0.3)), "open the free crate")
	for day = DAY - 2, DAY do
		CvcRules.daily(d, day)
	end
	d.coins = 50000
	while CvcRules.levelUp(d) do
	end
	assert(CvcRules.upgrade(d, 1) and CvcRules.upgrade(d, 1) and CvcRules.upgrade(d, 2))
	assert(CvcRules.buy(d, Crates.SHOP[1], rng(0.7)), "buy a crate")
	local bits = 0
	for _ = 1, 155 do
		now += 1
		bits = CvcRules.tick(d, 1, false, now, bits)
	end
	for _ = 1, 12 do
		CvcRules.raceDone(d, 2, now)
	end
	d.garageLevel = 2
	d.league = 3 -- Gold (a few minutes of play can't get there; the save is what this checks)
	return d
end

test("save + rejoin: everything a kid earned comes back the same", function()
	local d = played()
	-- the kid really has what this test is about
	eq(d.plotLevel, Training.MAX_PLOT_LEVEL)
	truthy(#d.garage >= 3, "3 cars")
	local part = false
	for _, c in d.garage do
		part = part or (c.speed > 0 and c.speed % 1 ~= 0)
	end
	truthy(part, "training part-way (not whole numbers)")
	eq(Profile.MAX_PLOT_LEVEL, Training.MAX_PLOT_LEVEL) -- a full plot is never cut on load
	truthy(d.league >= 2, "past Bronze")
	eq(d.dayStreak, 3)
	eq(d.crates, 3) -- the 3 daily crates, not opened
	truthy(d.stations[1].level >= 3)
	-- server A: join (take the lock), play, autosave, leave
	local join = Profile.loadStep(nil, "A", 100, false)
	eq(join.kind, "write")
	local record: any = stored(join.record)
	local auto = Profile.saveStep(record, "A", d, false, false, 200)
	eq(auto.kind, "write")
	record = stored(auto.record)
	local leave = Profile.saveStep(record, "A", d, true, true, 300)
	eq(leave.kind, "write")
	record = stored(leave.record)
	eq(record.lock, nil) -- let go: the next server takes it at once
	-- server B: rejoin
	local back = Profile.loadStep(record, "B", 310, false)
	eq(back.kind, "write")
	local got = back.data :: Profile.Data
	same(d, got, "save")
	eq(got.coins, d.coins)
	eq(#got.garage, #d.garage)
	eq(got.plotLevel, d.plotLevel)
	eq(got.garageLevel, 2)
	eq(got.stations[1].level, d.stations[1].level)
	eq(got.league, d.league)
	eq(got.dayStreak, 3)
	eq(got.dailyDay, DAY)
	eq(got.crates, 3)
	eq(got.racer, d.racer)
	-- the join set-up (TrainingServer) keeps it all too
	local before = table.clone(got.stations)
	CvcRules.setUp(got)
	eq(#got.stations, #before)
	for i, st in before do
		eq(got.stations[i].uid, st.uid)
		eq(got.stations[i].level, st.level)
	end
	eq(got.plotLevel, Training.MAX_PLOT_LEVEL)
	-- tomorrow's daily gift carries the streak on
	local _, streak = CvcRules.daily(got, DAY + 1)
	eq(streak, 4)
	eq(got.crates, 4)
end)

test("save + rejoin: a crashed server's last autosave comes back", function()
	local d = played()
	local record: any = stored(Profile.loadStep(nil, "A", 100, false).record)
	record = stored(Profile.saveStep(record, "A", d, false, false, 200).record)
	-- A crashed: no leave save, its lock stays. B waits, then takes the stale lock.
	eq(Profile.loadStep(record, "B", 210, false).kind, "blocked")
	local back = Profile.loadStep(record, "B", 210 + Profile.LOCK_TIMEOUT, false)
	eq(back.kind, "write")
	same(d, back.data, "save")
	-- and A, still running somehow, can't write over B's save any more
	local late = Profile.saveStep(stored(back.record), "A", d, false, false, 900)
	eq(late.kind, "lost")
end)

test("save + rejoin: a second save in a row changes nothing", function()
	local d = played()
	local once = Profile.migrate(stored(d))
	local twice = Profile.migrate(stored(once))
	same(once, twice, "save")
end)

test("a visit that played unsaved (DataStore down) keeps its station levels and plot level", function()
	local real = played()
	local base = Profile.new()
	local visit = Profile.migrate(stored(real))
	visit.stations[2].level += 2
	local merged = Profile.mergeVisit(Profile.migrate(stored(real)), visit, base)
	eq(merged.stations[2].level, real.stations[2].level + 2)
	eq(merged.stations[1].level, real.stations[1].level)
	eq(merged.plotLevel, Training.MAX_PLOT_LEVEL)
	eq(#merged.stations, #real.stations)
end)

-- Go-live: nothing that only a tester should reach works in the live game. Test hooks (plot or
-- workspace attributes read by the server, the screens gallery) only run inside IsStudio(), and
-- no server remote has a cheat, give or test action.
test("go-live: test hooks are Studio only, no cheat remotes", function()
	local fs = require("@lune/fs")
	local hooks = { "TestLooks", "TestStars", "ServerRaceSoon" }
	local bad = { "cheat", "givecoins", "setcoins", "addcoins", "debug", "godmode", "qa" }
	for _, dir in { "src/server", "src/shared", "src/client" } do
		for _, name in fs.readDir(dir) do
			local path = `{dir}/{name}`
			if fs.isFile(path) and string.find(name, "%.luau$") then
				local src = fs.readFile(path)
				local lines = string.split(src, "\n")
				for i, line in lines do
					local code = string.gsub(line, "%-%-.*$", "") -- comments don't count
					for _, hook in hooks do
						if string.find(code, `"{hook}"`, 1, true) and string.find(code, "GetAttribute") then
							-- the read sits inside an IsStudio() check a few lines up
							local gated = false
							for j = math.max(1, i - 8), i do
								gated = gated or string.find(lines[j], "IsStudio()", 1, true) ~= nil
							end
							truthy(gated, `{path}:{i} reads {hook} outside Studio`)
						end
					end
					for _, word in bad do
						truthy(
							not string.find(string.lower(code), `"{word}`, 1, true),
							`{path}:{i} has a "{word}" action`
						)
					end
				end
			end
		end
	end
	-- the screens gallery stops at once outside Studio
	local gallery = fs.readFile("src/client/UiGallery.client.luau")
	truthy(string.find(gallery, "if not RunService:IsStudio() then\n\treturn\nend", 1, true) ~= nil)
end)
