--!strict
local H = require("./harness")
local RaceMaps = require("../src/shared/RaceMaps")
local ServerRace = require("../src/shared/ServerRace")

local test, eq, truthy = H.test, H.eq, H.truthy

-- a round test map: a ring of radius 200, road 40 wide, start line at the bottom
local function ring(): any
	local loop = {}
	local n = 160
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		table.insert(
			loop,
			{ x = math.sin(a) * 200, z = math.cos(a) * 200, tx = math.cos(a), tz = -math.sin(a) }
		)
	end
	local gates = {}
	for k = 0, 5 do
		local s = loop[k * (n // 6) + 1]
		table.insert(
			gates,
			{ x = s.x, y = 0, z = s.z, dx = s.tx, dz = s.tz, halfWidth = 20, depth = 3 }
		)
	end
	return {
		id = "ring",
		label = "RING",
		ROAD = 40,
		track = function(): any
			return {
				id = "race",
				label = "RING",
				originX = 0,
				mode = "loop",
				grip = 1,
				spawn = { x = 0, y = 2, z = 186, dx = 1, dz = 0 },
				gates = gates,
			}
		end,
		loop = function(): any
			return loop
		end,
		lineSample = function(): number
			return 1
		end,
	}
end

test("a good map has no problems, a broken one says what is wrong", function()
	eq(#RaceMaps.problems(ring()), 0)
	local bad = ring()
	bad.ROAD = 10
	truthy(#RaceMaps.problems(bad) > 0, "a too-narrow road should fail the grid check")
	-- every listed map must be race-ready
	for _, m in RaceMaps.list() do
		local p = RaceMaps.problems(m)
		eq(table.concat(p, "; "), "", m.id)
	end
end)

test("the map vote: most votes wins, a tie or no votes is random among the best", function()
	local ids = { "backyard", "kitchen" }
	eq(ServerRace.tally({ a = "kitchen", b = "kitchen", c = "backyard" }, ids, 0), "kitchen")
	eq(ServerRace.tally({ a = "kitchen", b = "backyard" }, ids, 0), "backyard")
	eq(ServerRace.tally({ a = "kitchen", b = "backyard" }, ids, 0.99), "kitchen")
	eq(ServerRace.tally({}, ids, 0.99), "kitchen")
	eq(ServerRace.tally({ a = "moon" }, ids, 0), "backyard") -- unknown ids don't count
	eq(ServerRace.tally({}, {}, 0.5), nil)
	truthy(ServerRace.VOTE < ServerRace.MAP_BREAK, "vote inside the wait")
end)

test("race maps sit after the street's plots as drive slots", function()
	local LobbyLayout = require("../src/shared/LobbyLayout")
	local n = #LobbyLayout.slots()
	eq(LobbyLayout.mapIndex(1), n + 1)
	eq(LobbyLayout.mapAt(n), nil) -- a plot, not a map
	eq(LobbyLayout.mapAt(LobbyLayout.mapIndex(#RaceMaps.NAMES + 1)), nil)
	for k, m in RaceMaps.list() do
		local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
		eq(t.map, m.id)
	end
end)

test("a map race ends by its own time limit", function()
	local e = { { name = "a", laps = 1 } }
	eq(ServerRace.over(e, ServerRace.MAP_TIME_LIMIT, nil, ServerRace.MAP_TIME_LIMIT), true)
	eq(ServerRace.over(e, ServerRace.MAP_TIME_LIMIT - 1, nil, ServerRace.MAP_TIME_LIMIT), false)
end)

test("the maps are live: a map exists", function()
	eq(RaceMaps.live(), #RaceMaps.NAMES > 0)
end)
