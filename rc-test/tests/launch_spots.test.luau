--!nocheck
-- Where rockets and mines leave the click-on weapon parts: a Rockets shot names the rack tube it left
-- from, a dropped mine names the dropper's spoon. Looks only (the shot and the mine still start
-- where they always did).
local H = require("./harness")
local Flight = require("../src/server/weapons/Flight")
local Mine = require("../src/server/weapons/Mine")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

local function v(x, y, z)
	return vector.create(x, y, z)
end

local LEN = 5.5 * TrackData.RC_SCALE
local ORIGIN, AHEAD = v(0, 0, 0), v(0, 0, -1)

print("Launch spots")

test("launch: rockets leave from the rack tubes, on the roof, ahead of the middle", function()
	for n = 1, 6 do
		local p = Flight.tubeSpot(ORIGIN, AHEAD, n, LEN)
		truthy(p ~= nil, "tube " .. n .. " has a spot")
		truthy(p.z < 0 and p.z > -LEN, "tube " .. n .. " ahead of the middle, inside a kart length")
		truthy(p.y > 0 and p.y < LEN, "tube " .. n .. " above the roof line")
		truthy(math.abs(p.x) < 0.15 * LEN, "tube " .. n .. " inside the kart's width")
	end
end)

test("launch: the tubes fire left, right, ... and go round again", function()
	local a, b = Flight.tubeSpot(ORIGIN, AHEAD, 1, LEN), Flight.tubeSpot(ORIGIN, AHEAD, 2, LEN)
	truthy(a.x * b.x < 0, "the first two tubes are on opposite sides")
	local seen = {}
	for n = 1, 6 do
		seen[string.format(
			"%.4f,%.4f",
			Flight.tubeSpot(ORIGIN, AHEAD, n, LEN).x,
			Flight.tubeSpot(ORIGIN, AHEAD, n, LEN).y
		)] =
			true
	end
	local count = 0
	for _ in seen do
		count += 1
	end
	eq(count, 6, "six different tubes")
	eq(Flight.tubeSpot(ORIGIN, AHEAD, 7, LEN).x, a.x, "tube 7 is tube 1 again")
end)

test("launch: the tubes turn with the kart", function()
	local east = Flight.tubeSpot(ORIGIN, v(1, 0, 0), 3, LEN)
	truthy(east.x > 0 and math.abs(east.z) < 0.15 * LEN, "a kart facing +x fires ahead along +x")
end)

test("launch: the mine leaves the dropper's spoon, up on the roof toward the tail", function()
	local p = Mine.spoonSpot({ Position = ORIGIN, LookVector = AHEAD })
	truthy(p ~= nil, "the dropper has a spoon")
	truthy(p.z > 0 and p.z < LEN, "behind the middle, inside a kart length")
	truthy(p.y > 0 and p.y < LEN, "above the roof line")
end)
