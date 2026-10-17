--!strict
local Harness = require("./harness")
local LobbyLayout = require("../src/shared/LobbyLayout")

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

test("spawn faces the middle of the pads", function()
	local dx, dz = LobbyLayout.spawnFacing()
	near(dx, 0, 1e-9)
	near(dz, -1, 1e-9)
end)

test("showcase platform is smaller than its footprint", function()
	truthy(LobbyLayout.showcase.radius * 2 <= LobbyLayout.showcase.footprint)
end)
