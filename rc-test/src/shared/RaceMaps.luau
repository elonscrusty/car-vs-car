--!strict
-- The big race maps (carter's tycoon plan, 10-26: Backyard and Kitchen; tiny cars, giant world).
-- Each map is a module in Shared/Maps (rc-game/tycoon/race-map-api.md): its track like a plot's
-- (TrackData.Track, map-local big units, placed by rcX/rcZ/rcAngle), its road's centre line and
-- the sample at the start line, so the race lines the grid up behind the line. Pure (Lune tests
-- it); the parts are the map builder's.

local function load(name: string): any
	if script then
		return require((script :: any).Parent.Maps[name])
	end
	local luneRequire: any = require
	return luneRequire("./Maps/" .. name)
end

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local ServerRace = sibling("ServerRace")

local RaceMaps = {}

-- The maps in vote order (module names in Shared/Maps). The map builder adds them here.
RaceMaps.NAMES = { "Backyard", "Kitchen" } :: { string }

-- Does the server race run on the maps? A map exists. Then the wait between races is
-- ServerRace.MAP_BREAK.
function RaceMaps.live(): boolean
	return #RaceMaps.NAMES > 0
end

function RaceMaps.list(): { any }
	local out = {}
	for _, name in RaceMaps.NAMES do
		table.insert(out, load(name))
	end
	return out
end

function RaceMaps.get(id: string): any?
	for _, m in RaceMaps.list() do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- What is wrong with a map for racing ({} = ready): a loop track with a start line and gates, a
-- closed centre line, and every grid spot on the road (map.ROAD = road width, big units).
function RaceMaps.problems(map: any): { string }
	local out = {}
	local ok, t = pcall(map.track)
	if not ok or type(t) ~= "table" then
		return { "track() failed: " .. tostring(t) }
	end
	if t.mode ~= "loop" then
		table.insert(out, "mode is not loop")
	end
	if #t.gates < 4 then
		table.insert(out, "fewer than 4 gates (start line + 3)")
	end
	local loop = map.loop()
	if #loop < 8 then
		table.insert(out, "centre line too short")
		return out
	end
	local a, b = loop[1], loop[#loop]
	if math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) > 20 then
		table.insert(out, "centre line is not closed")
	end
	local road = map.ROAD or 30
	for k = 1, ServerRace.MAX do
		local g = ServerRace.gridOn(map, k, t.spawn.y)
		local best = math.huge
		for i, p in loop do
			local q = loop[i % #loop + 1]
			local ex, ez = q.x - p.x, q.z - p.z
			local len2 = ex * ex + ez * ez
			local u = if len2 > 0
				then math.clamp(((g.x - p.x) * ex + (g.z - p.z) * ez) / len2, 0, 1)
				else 0
			best = math.min(best, math.sqrt((g.x - p.x - ex * u) ^ 2 + (g.z - p.z - ez * u) ^ 2))
		end
		if best > road / 2 - 3 then
			table.insert(out, `grid spot {k} is off the road`)
		end
	end
	return out
end

return RaceMaps
