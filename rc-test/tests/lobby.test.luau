--!strict
-- Lobby layout (LobbyLayout.luau): one road, small plots on both sides facing it, a DRIVE pad in
-- front of each, the plaza at the road's end.
local H = require("./harness")
local TrackData = require("../src/shared/TrackData")
local Kit = require("../src/shared/Plots/Kit")
local L = require("../src/shared/LobbyLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby")

local function inside(b: L.Box, x: number, z: number): boolean
	return x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ
end

test("8 slots, both sides of the road, cycling drift / race / rock", function()
	local slots = L.slots()
	eq(#slots, L.ROWS * 2)
	for i, s in slots do
		eq(s.index, i)
		eq(s.track, L.TRACKS[(i - 1) % #L.TRACKS + 1])
		eq(s.id, TrackData.order[s.track])
		truthy((s.plotX < 0) == (i % 2 == 1), "odd slots on the left")
	end
	for track in L.TRACKS do
		truthy(L.slotFor(track) ~= nil, "every lobby track has a slot")
	end
	eq(L.slotFor(1), 1)
	eq(L.slotFor(99), nil)
end)

test("small plots are garden size, fronts on the footpath edge, grass between", function()
	truthy(L.PLOT_W <= 40 and L.PLOT_D <= 50, "small plot")
	local slots = L.slots()
	for i, s in slots do
		H.near(math.abs(s.plotX) - L.PLOT_D / 2, L.EDGE)
		if i > 2 then
			H.near(s.plotZ - slots[i - 2].plotZ, L.PLOT_W + L.GAP)
		end
	end
end)

test("the lobby sits far from the real driving plots", function()
	local g = L.ground()
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		local _, rz = TrackData.origin(t, true)
		local _, bz = TrackData.origin(t, false)
		truthy(g.maxZ < rz - Kit.DEPTH / 2 * TrackData.RC_SCALE, "clear of the RC plots")
		truthy(g.minZ > bz + Kit.DEPTH / 2, "clear of the big plots")
	end
end)

test("pads, exits and signs are on the footpaths or road; exits can't start a drive", function()
	local w = L.walks()
	for _, s in L.slots() do
		truthy(inside(w, s.padX, s.padZ), "pad on the footpath")
		truthy(inside(L.road(), s.exitX, s.exitZ), "exit on the road")
		truthy((s.exitX > 0) == (s.padX > 0), "exit on the pad's side of the road")
		truthy(inside(w, s.signX, s.signZ), "sign on the footpath")
		truthy(not L.inReach(s, s.exitX, s.exitZ), "stepping off must not start driving again")
		truthy(math.abs(s.signZ - s.padZ) > L.PAD, "sign clear of the pad")
	end
end)

test("spawn and parked cars are in the plaza, away from pads and buildings", function()
	local x, _, z = L.spawn()
	truthy(inside(L.PLAZA, x, z), "spawn in the plaza")
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

test("the grass covers every small plot, the road and the plaza", function()
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

test("copy car: real plot spot -> same spot on the turned small plot", function()
	local left, right = L.slots()[1], L.slots()[2]
	local x, y, z = L.toMini(left, 0, 0, 0)
	H.near(x :: number, left.plotX)
	H.near(y, 0)
	H.near(z, left.plotZ)
	-- the real plot's front (+z) is the road side of the small plot
	x, _, z = L.toMini(left, 0, 0, 100)
	H.near(x :: number, left.plotX + 10)
	H.near(z, left.plotZ)
	x, _, z = L.toMini(right, 0, 0, 100)
	H.near(x :: number, right.plotX - 10)
	H.near(z, right.plotZ)
	-- the real plot's +x: along the road, mirrored on the two sides
	x, y, z = L.toMini(left, 40, 10, 0)
	H.near(x :: number, left.plotX)
	H.near(y, 10 * L.MINI)
	H.near(z, left.plotZ - 4)
	x, _, z = L.toMini(right, 40, 0, 0)
	H.near(z, right.plotZ + 4)
	-- at the real wall the copy car stays inside the small plot's wall
	x, _, z = L.toMini(left, Kit.WIDTH / 2, 0, Kit.DEPTH / 2)
	H.near(x :: number, left.plotX + L.PLOT_D / 2 - L.MINI_CAR_EDGE)
	H.near(z, left.plotZ - (L.PLOT_W / 2 - L.MINI_CAR_EDGE))
	eq((L.toMini(left, Kit.WIDTH, 0, 0)), nil)
	eq((L.toMini(left, 0, 0, -Kit.DEPTH)), nil)
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

test("tyres close the far end of the road, on the grass, clear of the first plots", function()
	local g, r = L.ground(), L.road()
	for _, t in L.tires() do
		truthy(inside(g, t.x, t.z) and math.abs(t.x) < L.EDGE, "tyres across the road end")
		truthy(t.z < r.minZ + 3, "at the far end")
		truthy(t.z < L.FIRST_Z - L.PLOT_W / 2, "before the first plots")
	end
end)

test("signs are blank until someone drives that plot, then show their name", function()
	eq(L.signText(nil), "")
	eq(L.signText("carter"), "carter")
end)
