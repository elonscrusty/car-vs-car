--!strict
-- Lobby layout (LobbyLayout.luau): small plots on a street, a DRIVE pad in front of each.
local H = require("./harness")
local TrackData = require("../src/shared/TrackData")
local Kit = require("../src/shared/Plots/Kit")
local L = require("../src/shared/LobbyLayout")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby")

test("one slot per plot, same order as the plot keys", function()
	local slots = L.slots()
	eq(#slots, #TrackData.order)
	for i, s in slots do
		eq(s.index, i)
		eq(s.id, TrackData.order[i])
	end
end)

test("small plots are garden size, side by side with grass between, fronts on one line", function()
	H.near(L.PLOT_W, Kit.WIDTH * L.MINI)
	truthy(L.PLOT_W <= 40 and L.PLOT_D <= 50, "small plot")
	local slots = L.slots()
	for i, s in slots do
		H.near(s.plotZ + L.PLOT_D / 2, L.FRONT_Z)
		if i > 1 then
			H.near(s.plotX - slots[i - 1].plotX, L.PLOT_W + L.GAP)
		end
	end
end)

test("the small plots sit far from the real driving plots", function()
	for _, id in TrackData.order do
		local t = TrackData.get(id)
		local _, rz = TrackData.origin(t, true)
		local _, bz = TrackData.origin(t, false)
		local g = L.ground()
		local half = Kit.DEPTH / 2
		truthy(g.maxZ < rz - half * TrackData.RC_SCALE, "clear of the RC plots")
		truthy(g.minZ > bz + half, "clear of the big plots")
	end
end)

test("pads, exits and the spawn are on the street; exits and spawn can't start a drive", function()
	local st = L.street()
	local function onStreet(x: number, z: number): boolean
		return x > st.minX and x < st.maxX and z > st.minZ and z < st.maxZ
	end
	for _, s in L.slots() do
		truthy(onStreet(s.padX, s.padZ), "pad on the street")
		truthy(onStreet(s.exitX, s.exitZ), "exit on the street")
		truthy(onStreet(s.signX, s.signZ), "sign on the street")
		truthy(not L.inReach(s, s.exitX, s.exitZ), "stepping off must not start driving again")
		truthy(math.abs(s.signX - s.padX) > L.PAD, "sign clear of the pad")
	end
	local x, _, z = L.spawn()
	truthy(onStreet(x, z), "spawn on the street")
	for _, s in L.slots() do
		truthy(not L.inReach(s, x, z), "spawn too close to a pad")
	end
	for n = 1, 8 do
		local px, pz = L.parkSpot(n)
		truthy(onStreet(px, pz), "parked car on the street")
		for _, s in L.slots() do
			truthy(not L.inReach(s, px, pz), "parked car on a pad")
		end
	end
end)

test("reach: on the pad yes, the next pad no", function()
	local slots = L.slots()
	local a, b = slots[1], slots[2]
	truthy(L.inReach(a, a.padX, a.padZ))
	truthy(L.inReach(a, a.padX + 3, a.padZ + 3))
	truthy(not L.inReach(a, b.padX, b.padZ))
end)

test("the grass covers every small plot and the whole street", function()
	local g, st = L.ground(), L.street()
	for _, s in L.slots() do
		truthy(s.plotX - L.PLOT_W / 2 > g.minX and s.plotX + L.PLOT_W / 2 < g.maxX)
		truthy(s.plotZ - L.PLOT_D / 2 > g.minZ)
	end
	truthy(g.maxZ > st.maxZ)
end)

test("copy car: real plot spot -> same spot on the small plot, off the plot -> nothing", function()
	local s = L.slots()[2]
	local x, y, z = L.toMini(s, 0, 0, 0)
	H.near(x :: number, s.plotX)
	H.near(y, 0)
	H.near(z, s.plotZ)
	-- the front-right corner of the real plot lands on the small plot's front-right corner
	x, y, z = L.toMini(s, Kit.WIDTH / 2, 10, Kit.DEPTH / 2)
	H.near(x :: number, s.plotX + L.PLOT_W / 2)
	H.near(y, 10 * L.MINI)
	H.near(z, L.FRONT_Z)
	x = L.toMini(s, Kit.WIDTH, 0, 0)
	eq(x, nil)
	x = L.toMini(s, 0, 0, -Kit.DEPTH)
	eq(x, nil)
end)
