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
	for _, track in L.TRACKS do
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

test("trees stand in the grass gaps, clear of the plots and the flag beds", function()
	local trees = L.trees()
	eq(#trees, (L.ROWS - 1) * 2 * #L.TREE_X)
	truthy(L.GAP >= 30, "room between plots")
	for _, t in trees do
		for _, s in L.slots() do
			local plot = {
				minX = s.plotX - L.PLOT_D / 2,
				maxX = s.plotX + L.PLOT_D / 2,
				minZ = s.plotZ - L.PLOT_W / 2 - 4,
				maxZ = s.plotZ + L.PLOT_W / 2 + 4,
			}
			truthy(not inside(plot, t.x, t.z), "tree off a plot (and its wall)")
		end
		truthy(math.abs(t.x) > L.EDGE + 25, "behind the flag and flower bed")
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
	eq(L.signText("carter", "Race", true), "carter - CLOSED")
	eq(L.signText("carter", "Race", false), "carter")
	eq(L.signText("", "Race"), "RACE")
	-- every empty plot on the street names its kind, and the drift plots say DRIFT
	for _, s in L.slots() do
		local text = L.signText(nil, s.label)
		truthy(#text > 0, "no blank sign")
		if s.id == "drift" then
			eq(text, "DRIFT")
		end
	end
end)

test("a plot with its own track drives that track, the others keep their kind's", function()
	L.custom[2] = { mode = "loop", spawn = { x = 1, y = 2, z = 3, dx = 0, dz = -1 }, gates = {} }
	local own, other = L.track(2), L.track(8)
	eq(own.spawn.x, 1)
	eq(#own.gates, 0)
	eq(own.id, L.slots()[2].id)
	eq(other.spawn.x, TrackData.get(L.slots()[8].id).spawn.x)
	L.custom[2] = nil
	eq(L.track(2).spawn.x, TrackData.get(L.slots()[2].id).spawn.x)
end)

test("a plot can be driven when it is free and yours, nobody's, or opened to friends", function()
	eq(L.canDrive(nil, 1, false, false), true) -- nobody's
	eq(L.canDrive(1, 1, false, false), true) -- yours
	eq(L.canDrive(2, 1, false, false), false) -- someone else's, closed
	eq(L.canDrive(2, 1, true, false), true) -- someone else's, open
	eq(L.canDrive(1, 1, true, true), false) -- someone is on it
end)

test("claim order: race plots first (you build on them), every plot once", function()
	local order = L.claimOrder()
	local slots = L.slots()
	eq(#order, #slots)
	local seen = {}
	local pastRace = false
	for _, i in order do
		truthy(not seen[i], "slot twice")
		seen[i] = true
		if slots[i].id ~= "race" then
			pastRace = true
		else
			truthy(not pastRace, "a race plot after a non-race one")
		end
	end
	eq(slots[order[1]].id, "race")
end)

test("a pad's DRIVE button: DRIVE when you may, BUSY, or whose it is and LOCKED", function()
	local ok, text = L.padButton(0, "", 0, false, 7)
	eq(ok, true)
	eq(text, "DRIVE") -- nobody's plot
	ok, text = L.padButton(7, "me", 0, false, 7)
	eq(text, "DRIVE") -- mine
	ok, text = L.padButton(9, "mia", 0, true, 7)
	eq(text, "DRIVE") -- open to friends
	ok, text = L.padButton(9, "mia", 0, false, 7)
	eq(ok, false)
	eq(text, "MIA - LOCKED")
	ok, text = L.padButton(9, "superlongname_2014", 0, false, 7)
	eq(text, "SUPERLONGN - LOCKED") -- cut to fit one line
	ok, text = L.padButton(9, "mia", 9, true, 7)
	eq(ok, false)
	eq(text, "BUSY")
	-- a visitor on my own plot: I can still drive it (the owner comes first)
	ok, text = L.padButton(7, "me", 9, true, 7)
	eq(ok, true)
	eq(text, "DRIVE")
	ok, text = L.padButton(7, "me", 7, false, 7)
	eq(ok, true) -- my own drive still going
end)

test("star boards: the pad sees the whole board clear of the gate posts, both sides", function()
	local PlotDecor = require("../src/shared/PlotDecor")
	local post = PlotDecor.GATE + 0.8 -- the arch posts: this far along the road from the plot middle
	for _, s in L.slots() do
		local side = if s.padX < 0 then -1 else 1
		local c, face = L.board(s)
		-- the board's two ends: across its facing
		local fx, fz = face.x - c.x, face.z - c.z
		local len = math.sqrt(fx * fx + fz * fz)
		local ax, az = -fz / len, fx / len
		local ends = {
			{ x = c.x, z = c.z },
			{ x = c.x + ax * L.BOARD_W / 2, z = c.z + az * L.BOARD_W / 2 },
			{ x = c.x - ax * L.BOARD_W / 2, z = c.z - az * L.BOARD_W / 2 },
		}
		for _, e in ends do
			-- in front of the plot, not over the middle of the road
			truthy(side * e.x < L.EDGE, `slot {s.index}: board end inside the plot`)
			truthy(side * e.x > 2, `slot {s.index}: board over the middle of the road`)
			-- from the pad to this end: never through a post (with a little room)
			for k = 0, 100 do
				local t = k / 100
				local x = s.padX + (e.x - s.padX) * t
				local z = s.padZ + (e.z - s.padZ) * t
				local inPost = side * x > L.EDGE - 1.2
					and side * x < L.EDGE + 1.2
					and math.abs(math.abs(z - s.plotZ) - post) < 1.2
				truthy(not inPost, `slot {s.index}: a gate post hides the board from the pad`)
			end
		end
		-- the pad faces it: in front (down the road), about 15-25 studs away
		local d = math.sqrt((c.x - s.padX) ^ 2 + (c.z - s.padZ) ^ 2)
		truthy(d > 12 and d < 26, `slot {s.index}: board {d} studs from the pad`)
		-- clear of the lamps
		for _, lamp in L.lamps() do
			truthy(
				math.abs(lamp.z - c.z) > L.BOARD_W / 2 + 1 or lamp.x * side < 0,
				"lamp in the board"
			)
		end
	end
end)
