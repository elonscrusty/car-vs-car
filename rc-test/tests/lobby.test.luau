--!strict
-- Lobby layout (LobbyLayout.luau): one road, real RC-size plots on both sides facing it (the
-- plots are the tracks), a DRIVE pad in front of each, the spawn lobby at the top of the road.
local H = require("./harness")
local TrackData = require("../src/shared/TrackData")
local Kit = require("../src/shared/Plots/Kit")
local L = require("../src/shared/LobbyLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby")

local function inside(b: L.Box, x: number, z: number): boolean
	return x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ
end

test("8 plots, both sides of the road, kinds as in carter's picture", function()
	local slots = L.slots()
	eq(#slots, L.ROWS * 2)
	for i, s in slots do
		eq(s.index, i)
		eq(s.track, L.SLOT_TRACKS[i])
		eq(s.id, TrackData.order[s.track])
		truthy((s.plotX < 0) == (i % 2 == 1), "odd slots on the left")
	end
	for track in L.TRACKS do
		truthy(L.slotFor(track) ~= nil, "every lobby track has a slot")
	end
	eq(L.slotFor(2), 1) -- race is the first plot
	eq(L.slotFor(99), nil)
end)

test("plots are real RC size, fronts on the footpath edge, grass between", function()
	H.near(L.PLOT_W, Kit.WIDTH * TrackData.RC_SCALE)
	H.near(L.PLOT_D, Kit.DEPTH * TrackData.RC_SCALE)
	local slots = L.slots()
	for i, s in slots do
		H.near(math.abs(s.plotX) - L.PLOT_D / 2, L.EDGE)
		if i > 2 then
			H.near(s.plotZ - slots[i - 2].plotZ, L.PLOT_W + L.GAP)
		end
	end
end)

test("each lobby plot is its track: spawn and gates inside that plot, front to the road", function()
	for _, slot in L.slots() do
		local t = L.track(slot.index)
		eq(t.id, slot.id)
		local function onPlot(x: number, z: number): boolean
			return math.abs(x - slot.plotX) < L.PLOT_D / 2
				and math.abs(z - slot.plotZ) < L.PLOT_W / 2
		end
		local sx, _, sz = TrackData.toWorld(t, true, t.spawn.x, t.spawn.y, t.spawn.z)
		truthy(onPlot(sx, sz), "spawn on its plot")
		for _, g in t.gates do
			local gx, _, gz = TrackData.toWorld(t, true, g.x, g.y, g.z)
			truthy(onPlot(gx, gz), "gate on its plot")
		end
		-- the plot's front (local +z) points at the road
		local fx = TrackData.toWorld(t, true, 0, 0, Kit.DEPTH / 2)
		H.near(math.abs(fx), L.EDGE)
		local dx, dz = TrackData.dirToWorld(t, true, 0, 1)
		H.near(dx, if slot.plotX < 0 then 1 else -1)
		H.near(dz, 0)
		-- round trip
		local wx, wy, wz = TrackData.toWorld(t, true, 30, 4, -70)
		local lx, ly, lz = TrackData.toLocal(t, true, wx, wy, wz)
		H.near(lx, 30)
		H.near(ly, 4)
		H.near(lz, -70)
	end
end)

test("pads at the plot entrances, signs and exits on the footpath", function()
	local w = L.walks()
	for _, s in L.slots() do
		truthy(inside(w, s.padX, s.padZ) and math.abs(s.padX) > L.ROAD_W / 2, "pad on the footpath")
		H.near(s.padZ, s.plotZ) -- the plot's entrance gap is in the middle of its front
		truthy(inside(w, s.exitX, s.exitZ), "exit on the footpath")
		truthy(inside(w, s.signX, s.signZ), "sign on the footpath")
		truthy(math.abs(s.signZ - s.padZ) > L.PAD, "sign clear of the pad")
	end
end)

test("spawn in the spawn lobby, parked cars at the top of the road, away from pads", function()
	local x, _, z = L.spawn()
	truthy(inside(L.PLAZA, x, z), "spawn in the spawn lobby")
	eq(L.PLAZA.maxZ, L.road().minZ) -- the spawn lobby opens onto the road
	for n = 1, 8 do
		local px, pz = L.parkSpot(n)
		truthy(inside(L.PLAZA, px, pz) or inside(L.road(), px, pz), "parked car on hard ground")
		for _, s in L.slots() do
			truthy(not L.inReach(s, px, pz), "parked car on a pad")
		end
	end
	for _, b in { L.garage() } do
		truthy(inside(L.PLAZA, b.x, b.z), "building in the plaza")
		truthy(math.abs(b.x - x) > 20, "building clear of the spawn")
	end
end)

test("reach: on the pad yes, the next pad no", function()
	local slots = L.slots()
	local a = slots[1]
	truthy(L.inReach(a, a.padX, a.padZ))
	truthy(L.inReach(a, a.padX + 3, a.padZ + 3))
	truthy(not L.inReach(a, slots[2].padX, slots[2].padZ), "across the road")
	truthy(not L.inReach(a, slots[3].padX, slots[3].padZ), "next along")
end)

test("the grass covers every plot, the road and the spawn lobby", function()
	local g = L.ground()
	for _, s in L.slots() do
		truthy(math.abs(s.plotX) + L.PLOT_D / 2 < g.maxX)
		truthy(s.plotZ - L.PLOT_W / 2 > g.minZ)
	end
	local r = L.road()
	truthy(r.minZ > g.minZ and L.PLAZA.maxZ < g.maxZ and L.PLAZA.maxX < g.maxX)
	for _, t in L.trees() do
		truthy(inside(g, t.x, t.z), "tree on the grass")
		truthy(not inside(L.walks(), t.x, t.z), "tree off the footpath")
	end
end)

test("cones sit on the footpath beside each pad, never on it", function()
	local w = L.walks()
	eq(#L.cones(), #L.slots() * 2)
	for _, c in L.cones() do
		truthy(inside(w, c.x, c.z) and math.abs(c.x) > L.ROAD_W / 2, "cone on the footpath")
		for _, s in L.slots() do
			truthy(
				math.abs(c.z - s.padZ) > L.PAD / 2 or math.abs(c.x - s.padX) > L.PAD / 2,
				"cone off the pad"
			)
			truthy(
				math.abs(c.z - s.signZ) > 4.5 or math.abs(c.x - s.signX) > 1,
				"cone clear of the sign"
			)
		end
	end
end)

test("tyres close the lake end of the road, on the grass, past the last plots", function()
	local g, r = L.ground(), L.road()
	eq(L.LAKE_SIDE, 1)
	for _, t in L.tires() do
		truthy(inside(g, t.x, t.z) and math.abs(t.x) < L.EDGE, "tyres across the road end")
		truthy(t.z > r.maxZ - 3, "at the lake end")
		truthy(t.z > L.FIRST_Z + (L.ROWS - 1) * L.STEP + L.PLOT_W / 2, "past the last plots")
	end
end)

test("signs show the plot kind until someone drives that plot, then their name", function()
	eq(L.signText(nil, "Race"), "RACE")
	eq(L.signText("carter", "Race"), "carter")
	eq(L.signText("carter", "Race", true), "carter - OPEN")
end)

test("a plot can be driven when it is free and yours, nobody's, or opened to friends", function()
	eq(L.canDrive(nil, 1, false, false), true) -- nobody's
	eq(L.canDrive(1, 1, false, false), true) -- yours
	eq(L.canDrive(2, 1, false, false), false) -- someone else's, closed
	eq(L.canDrive(2, 1, true, false), true) -- someone else's, open
	eq(L.canDrive(1, 1, true, true), false) -- someone is on it
end)
