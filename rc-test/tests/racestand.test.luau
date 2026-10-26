--!strict
-- Car VS Car driver stand: spots on each map's stand, the camera over the shoulder, the zoom.
local H = require("./harness")
local RaceStand = require("../src/shared/RaceStand")
local RaceMaps = require("../src/shared/RaceMaps")
local LobbyLayout = require("../src/shared/LobbyLayout")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Race stand")

test("stand: 8 spots side by side on every map, facing the track", function()
	for k, m in RaceMaps.list() do
		local t = LobbyLayout.track(LobbyLayout.mapIndex(k))
		local a, b = RaceStand.spot(t, 1), RaceStand.spot(t, 8)
		truthy(a ~= nil and b ~= nil, m.id .. " has a stand")
		local s1, s8 = a :: RaceStand.Spot, b :: RaceStand.Spot
		truthy(math.abs(s1.y - s8.y) < 1e-6 and s1.y > 5, "on the deck top")
		local gap = math.sqrt((s1.x - s8.x) ^ 2 + (s1.z - s8.z) ^ 2)
		truthy(gap > 20, m.id .. ": spots spread along the stand")
		-- facing the track: the start spot is ahead, not behind
		local sx, _, sz = TrackData.toWorld(t, true, t.spawn.x, 0, t.spawn.z)
		truthy((sx - s1.x) * s1.dx + (sz - s1.z) * s1.dz > 0, m.id .. ": faces the track")
		-- out-of-range numbers stay on the stand
		eq((RaceStand.spot(t, 99) :: RaceStand.Spot).x, s8.x)
	end
	eq(RaceStand.spot({ map = nil }, 1), nil)
end)

test("stand: the camera is above and behind the spot, a near car fills the view more", function()
	local s = { x = 0, y = 20, z = 0, dx = 0, dz = -1 }
	local x, y, z = RaceStand.camAt(s)
	truthy(y > s.y and z > 0, "up and back from the track")
	truthy(x > 0, "over the right shoulder")
	truthy(RaceStand.fov(20) > RaceStand.fov(200))
	eq(RaceStand.fov(0.01), RaceStand.FOV_MAX)
	eq(RaceStand.fov(1e6), RaceStand.FOV_MIN)
end)
