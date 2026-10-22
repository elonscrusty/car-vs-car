--!strict
-- Lobby street layout (LobbyLayout.luau).
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

test("every stand sits on the same front line, behind the street", function()
	for _, s in L.slots() do
		truthy(s.standZ < L.FRONT_Z, "stand inside the plot")
		truthy(L.FRONT_Z - s.standZ < 15, "stand near the entrance")
		eq(s.standZ, L.slots()[1].standZ)
		H.near(s.standY, Kit.STAND_H * TrackData.RC_SCALE)
	end
end)

test("exit spots and the spawn are on the street, the spawn is far from every stand", function()
	local st = L.street()
	local function onStreet(x: number, z: number): boolean
		return x > st.minX and x < st.maxX and z > st.minZ and z < st.maxZ
	end
	for _, s in L.slots() do
		truthy(onStreet(s.exitX, s.exitZ), "exit on the street")
		truthy(not L.inReach(s, s.exitX, s.exitZ), "stepping off must not start driving again")
	end
	local x, _, z = L.spawn()
	truthy(onStreet(x, z), "spawn on the street")
	for _, s in L.slots() do
		truthy(not L.inReach(s, x, z), "spawn too close to a stand")
	end
	for n = 1, 8 do
		local px, pz = L.parkSpot(n)
		truthy(onStreet(px, pz), "parked car on the street")
	end
end)

test("reach: on the stand yes, one plot over no", function()
	local slots = L.slots()
	local a, b = slots[1], slots[2]
	truthy(L.inReach(a, a.standX, a.standZ))
	truthy(L.inReach(a, a.standX + 6, a.standZ + 6))
	truthy(not L.inReach(a, b.standX, b.standZ))
end)

test("the grass covers every plot and the whole street", function()
	local g, st = L.ground(), L.street()
	local half = Kit.WIDTH / 2 * TrackData.RC_SCALE
	for _, s in L.slots() do
		truthy(s.exitX - half > g.minX and s.exitX + half < g.maxX)
	end
	truthy(g.minZ < TrackData.RC_Z - Kit.DEPTH / 2 * TrackData.RC_SCALE)
	truthy(g.maxZ > st.maxZ)
end)
