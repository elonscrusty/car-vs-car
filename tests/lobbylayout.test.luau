--!strict
local H = require("./harness")
local LobbyLayout = require("../src/shared/LobbyLayout")
local eq, near, truthy = H.eq, H.near, H.truthy

print("LobbyLayout")

H.test("four pads on the ring, none touching", function()
	local pads = LobbyLayout.pads()
	eq(#pads, 4)
	for i = 1, #pads do
		near(
			math.sqrt((pads[i].x - LobbyLayout.ring.x) ^ 2 + (pads[i].z - LobbyLayout.ring.z) ^ 2),
			LobbyLayout.padDist,
			1e-6
		)
		for j = i + 1, #pads do
			local d = math.sqrt((pads[i].x - pads[j].x) ^ 2 + (pads[i].z - pads[j].z) ^ 2)
			truthy(d > LobbyLayout.padRadius * 2 + 2, "pads too close")
		end
	end
end)

H.test("padAt finds the pad you stand on", function()
	for i, p in LobbyLayout.pads() do
		eq(LobbyLayout.padAt(p.x, p.z), i)
		eq(LobbyLayout.padAt(p.x + LobbyLayout.padRadius - 0.5, p.z), i)
	end
	eq(LobbyLayout.padAt(LobbyLayout.ring.x, LobbyLayout.ring.z), nil)
	eq(LobbyLayout.padAt(0, 60), nil)
end)

H.test("return spots are not on a pad and stay on the ring", function()
	for k = 1, 16 do
		local s = LobbyLayout.returnSpot(k)
		eq(LobbyLayout.padAt(s.x, s.z, 1), nil)
		truthy(LobbyLayout.onPlaza(s.x, s.z))
	end
end)

H.test("the sheet is 220 x 180 and nothing is outside the plaza", function()
	eq(LobbyLayout.size.x, 220)
	eq(LobbyLayout.size.z, 180)
	eq(LobbyLayout.size.height, 32)
	for name, r in LobbyLayout.footprints() do
		if name ~= "archLeft" and name ~= "archRight" then
			truthy(LobbyLayout.onPlaza(r.x, r.z), name .. " centre outside plaza")
		end
	end
	local sp = LobbyLayout.spawn
	truthy(LobbyLayout.onPlaza(sp.x, sp.z))
end)

H.test("no two footprints overlap", function()
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

H.test("overlap test works", function()
	truthy(
		LobbyLayout.overlaps(
			{ x = 0, z = 0, w = 4, d = 4, yawDeg = 0 },
			{ x = 3, z = 0, w = 4, d = 4, yawDeg = 0 }
		)
	)
	truthy(
		not LobbyLayout.overlaps(
			{ x = 0, z = 0, w = 4, d = 4, yawDeg = 0 },
			{ x = 5, z = 0, w = 4, d = 4, yawDeg = 0 }
		)
	)
	truthy(
		not LobbyLayout.overlaps(
			{ x = 0, z = 0, w = 4, d = 4, yawDeg = 45 },
			{ x = 5, z = 0, w = 4, d = 4, yawDeg = 0 }
		)
	)
end)

H.test("spawn is clear of paths blockers and looks at the ring", function()
	local sp = LobbyLayout.spawn
	for _, b in LobbyLayout.blockers() do
		truthy(
			not LobbyLayout.overlaps(
				{ x = sp.x, z = sp.z, w = sp.size, d = sp.size, yawDeg = 0 },
				b
			),
			"spawn in a blocker"
		)
	end
	near(LobbyLayout.spawnYaw(), math.pi, 0.01) -- ring is straight ahead (-z)
end)

H.test("16 parking spots, one car each, clear of the front path and the ring", function()
	local spots = LobbyLayout.parking()
	eq(#spots, 16)
	for _, s in spots do
		truthy(
			math.abs(s.x) - LobbyLayout.parkingSize.w / 2 > 7 + 2,
			"spot too near the front path"
		)
		truthy(LobbyLayout.onPlaza(s.x, s.z))
		truthy(
			math.sqrt((s.x - LobbyLayout.ring.x) ^ 2 + (s.z - LobbyLayout.ring.z) ^ 2)
				> LobbyLayout.ring.radius + 6
		)
	end
end)

H.test("tire wall leaves the three entrances open", function()
	local st = LobbyLayout.tireWall()
	truthy(#st > 60)
	for _, s in st do
		truthy(not (s.z == LobbyLayout.plaza.frontZ and math.abs(s.x) < 9))
		truthy(not (math.abs(s.x) == LobbyLayout.plaza.halfX and s.z > -29 and s.z < 5))
	end
end)

H.test("garage mouths and the plaza edge are blocked", function()
	truthy(#LobbyLayout.blockers() >= 7)
end)

H.test("scenery is on grass and always the same", function()
	local a, b = LobbyLayout.scenery(), LobbyLayout.scenery()
	eq(#a, #b)
	truthy(#a > 150)
	for _, s in a do
		truthy(
			not (
					math.abs(s.x) < LobbyLayout.plaza.halfX
					and s.z < LobbyLayout.plaza.frontZ
					and s.z > LobbyLayout.plaza.backZ
				)
		)
	end
end)

H.test("boards stand beside the workshop", function()
	local w = LobbyLayout.workshop
	truthy(math.abs(LobbyLayout.boards.weekly.x) > w.w / 2)
	eq(LobbyLayout.boards.weekly.x, -LobbyLayout.boards.wins.x)
end)
