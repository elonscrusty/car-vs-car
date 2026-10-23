--!strict
-- Spawn lobby (SpawnLobby.luau): everything fits, the walk from the spawn to the street is open,
-- and it has the shop, the garage, a stand per player and the play pads.
local H = require("./harness")
local S = require("../src/shared/SpawnLobby")
local TrackData = require("../src/shared/TrackData")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Spawn lobby")

-- flat footprint of a piece (rotations here are multiples of 90 degrees, or small details)
local function flat(p: any): (number, number, number, number, number, number)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	if math.abs(p.rot.z) % 180 == 90 then
		sx, sy = sy, sx
	end
	if math.abs(p.rot.y) % 180 == 90 then
		sx, sz = sz, sx
	end
	return p.pos.x - sx / 2,
		p.pos.x + sx / 2,
		p.pos.y - sy / 2,
		p.pos.y + sy / 2,
		p.pos.z - sz / 2,
		p.pos.z + sz / 2
end

test("every piece fits in the lobby box", function()
	local b = S.BOX
	for _, p in S.allParts() do
		local x0, x1, y0, y1, z0, z1 = flat(p)
		local name = p.group .. "/" .. p.name
		truthy(x0 >= b.minX - 0.5 and x1 <= b.maxX + 0.5, name .. " x")
		truthy(z0 >= b.minZ - 0.5 and z1 <= b.maxZ + 0.5, name .. " z")
		truthy(y0 >= -0.5 and y1 <= b.maxY, name .. " y")
	end
end)

test("nothing solid between the spawn and the street", function()
	local lane = { minX = -6, maxX = 6, minZ = S.SPAWN.z - 2, maxZ = S.DEPTH / 2 + 1 }
	for _, p in S.allParts() do
		if p.collide and p.name ~= "Floor" then
			local x0, x1, y0, _, z0, z1 = flat(p)
			local hits = x1 > lane.minX
				and x0 < lane.maxX
				and z1 > lane.minZ
				and z0 < lane.maxZ
				and y0 < 6
			truthy(not hits, p.group .. "/" .. p.name .. " blocks the walk")
		end
	end
end)

test("a car stand for every plot, a play pad per plot kind, a shop and a garage", function()
	truthy(#S.STANDS >= #TrackData.order, "stands")
	eq(#S.PADS, 3)
	local kinds: { [string]: boolean } = {}
	for _, pad in S.PADS do
		kinds[pad.kind] = true
	end
	for _, k in { "drift", "race", "rock" } do
		truthy(kinds[k], "pad for " .. k)
	end
	local groups: { [string]: boolean } = {}
	for _, p in S.allParts() do
		groups[p.group] = true
	end
	for _, g in
		{
			"Ground",
			"Statue",
			"QueuePad1",
			"QueuePad3",
			"Stand8",
			"Arch",
			"shop/Shell",
			"shop/Cars",
			"garage/Lift",
		}
	do
		truthy(groups[g], g)
	end
end)

test("lobby Meshy props each replace a real stand-in group", function()
	local groups: { [string]: boolean } = {}
	for _, p in S.parts() do
		groups[p.group] = true
	end
	for _, m in S.MESHES do
		truthy(groups[m.group], m.model .. " -> " .. m.group)
	end
end)
