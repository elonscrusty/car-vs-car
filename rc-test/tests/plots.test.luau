--!strict
-- Rules every plot must follow (shared by all four plots).
local H = require("./harness")
local TrackData = require("../src/shared/TrackData")
local Kit = require("../src/shared/Plots/Kit")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plots")

test("curve directions are unit length, open paths end on the last point", function()
	local pts = { { x = 0, z = 0 }, { x = 50, z = -10 }, { x = 90, z = -80 } }
	for _, ring in { Kit.loop(pts, 6), Kit.path(pts, 6) } do
		for _, s in ring do
			truthy(math.abs(s.tx * s.tx + s.tz * s.tz - 1) < 1e-6)
		end
	end
	local path = Kit.path(pts, 6)
	eq(path[#path].x, 90)
	eq(path[#path].z, -80)
end)

for _, id in TrackData.order do
	local p = TrackData.plot(id)
	local t = TrackData.get(id)

	test(id .. ": has the plot fields", function()
		eq(p.id, id)
		truthy(type(p.label) == "string" and #p.label > 0, "label")
		truthy(p.mode == "free" or p.mode == "loop" or p.mode == "oneway", "mode")
		truthy(p.grip > 0 and p.grip <= 2, "grip")
		truthy(type(p.build) == "function", "build")
		if p.mode ~= "free" then
			truthy(#p.gates >= 2, "a timed plot needs gates")
		end
	end)

	test(id .. ": car starts inside the track area, facing a real direction", function()
		local s = p.spawn
		truthy(Kit.inArea(s.x, s.z), `spawn {s.x}, {s.z} is outside the area`)
		truthy(math.abs(s.dx * s.dx + s.dz * s.dz - 1) < 1e-3, "direction is not unit length")
	end)

	test(id .. ": gates sit inside the track area", function()
		for i, g in p.gates do
			truthy(Kit.inArea(g.x, g.z), `gate {i} is outside the area`)
		end
	end)

	if p.mode ~= "free" then
		test(id .. ": the spawn doesn't trip the timer, the start gate does", function()
			local timer = LapTimer.new(t.gates, t.mode)
			eq(LapTimer.update(timer, 0, t.spawn.x, t.spawn.y, t.spawn.z), nil)
			local g = t.gates[1]
			eq(LapTimer.update(timer, 1, g.x, g.y, g.z), "start")
		end)
	end
end

test("player stands in the front area, plots don't touch at RC size", function()
	local spot = TrackData.standSpot(TrackData.get("race"))
	truthy(spot.z > Kit.FRONT_Z, "stand spot is on the track side")
	local a = TrackData.origin(TrackData.get("drift"), true)
	local b = TrackData.origin(TrackData.get("race"), true)
	truthy(math.abs(b - a) > Kit.WIDTH * TrackData.RC_SCALE + 10)
end)

test("world and local spots round-trip at both sizes", function()
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		for _, rc in { false, true } do
			local wx, wy, wz = TrackData.toWorld(t, rc, 12, 3, -40)
			local lx, ly, lz = TrackData.toLocal(t, rc, wx, wy, wz)
			truthy(
				math.abs(lx - 12) < 1e-6 and math.abs(ly - 3) < 1e-6 and math.abs(lz + 40) < 1e-6
			)
		end
	end
end)
