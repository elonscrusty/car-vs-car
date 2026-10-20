--!strict
local Harness = require("./harness")
local LobbyLayout = require("../LobbyLayout")

local test, near, truthy, eq = Harness.test, Harness.near, Harness.truthy, Harness.eq

print("LobbyLayout")

test("eight garage bays, four on each side", function()
	eq(#LobbyLayout.bays, 8)
	local left = 0
	for _, b in LobbyLayout.bays do
		if b.face == 1 then
			left += 1
		end
	end
	eq(left, 4)
end)

test("garages are named A1-A4 and B1-B4", function()
	eq(LobbyLayout.bayName(1), "A1")
	eq(LobbyLayout.bayName(4), "A4")
	eq(LobbyLayout.bayName(5), "B1")
	eq(LobbyLayout.bayName(8), "B4")
end)

test("garages are built into the side walls, in line along the wall", function()
	local room = LobbyLayout.room
	for _, b in LobbyLayout.bays do
		-- The opening (front of the garage) sits on the wall line; the room is behind it.
		near(math.abs(b.x) - LobbyLayout.bay.w / 2, room.halfW, 1e-9)
		truthy(math.abs(b.z) + LobbyLayout.bay.d / 2 <= room.halfL)
	end
	for i = 1, 3 do
		near(LobbyLayout.bays[i + 1].z - LobbyLayout.bays[i].z, LobbyLayout.bay.d, 1e-9)
	end
end)

test("four pads", function()
	eq(#LobbyLayout.pads, 4)
end)

test("everything is inside the room", function()
	for name, r in LobbyLayout.footprints() do
		truthy(LobbyLayout.insideRoom(r), name .. " outside room")
	end
end)

test("no footprints overlap (so spawn is not on a pad)", function()
	local list = {}
	for name, r in LobbyLayout.footprints() do
		table.insert(list, { name = name, r = r })
	end
	for i = 1, #list do
		for j = i + 1, #list do
			truthy(
				not LobbyLayout.overlaps(list[i].r, list[j].r),
				list[i].name .. " overlaps " .. list[j].name
			)
		end
	end
end)

test("spawn faces the stage", function()
	local dx, dz = LobbyLayout.spawnFacing()
	near(dx, 0, 1e-9)
	near(dz, -1, 1e-9)
end)

test("showcase platform is smaller than its footprint", function()
	truthy(LobbyLayout.showcase.radius * 2 <= LobbyLayout.showcase.footprint)
end)

test("garages are big, open-fronted and with the store and paint booth past them", function()
	local bay = LobbyLayout.bay
	truthy(bay.d >= 40 and bay.w >= 30)
	truthy(bay.gap >= 10 and bay.gap < bay.d) -- a wide walk-in gap in the low front wall
	truthy(bay.wallHeight <= 2) -- low enough to hop over anywhere
	local lastEnd = LobbyLayout.bays[#LobbyLayout.bays].z + bay.d / 2
	for _, booth in { LobbyLayout.store, LobbyLayout.paint } do
		truthy(booth.z >= lastEnd, "booth sits past the last garage")
	end
end)

test("the gumball machine stands against the back wall in the right corner", function()
	local g = LobbyLayout.gacha
	local room = LobbyLayout.room
	truthy(g.x > 0, "right side")
	near(g.z - g.d / 2, -room.halfL + 1, 1.01) -- touching the back wall (a stud for the wall panel)
	truthy(LobbyLayout.insideRoom(LobbyLayout.footprints().gacha))
end)
