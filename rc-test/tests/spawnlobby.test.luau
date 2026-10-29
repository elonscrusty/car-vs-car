--!strict
-- Spawn lobby (SpawnLobby.luau): everything fits, the walk from the spawn to the street is open,
-- and it has the shop, the garage, a stand per player and the play pads.
local H = require("./harness")
local S = require("../src/shared/SpawnLobby")
local TrackData = require("../src/shared/TrackData")
local Cat = require("../src/shared/CarCatalog")
local Features = require("../src/shared/Features")

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

test(
	"a car stand for every plot, drift / race pads (Car VS Car: one SMASH! portal), shops and a garage",
	function()
		truthy(#S.STANDS >= #TrackData.order, "stands")
		-- (Car VS Car Smash: one SMASH! portal pad, and the crate shop in the race shop's spot)
		eq(#S.PADS, if Features.CVC then 1 else 2)
		local kinds: { [string]: boolean } = {}
		for _, pad in S.PADS do
			kinds[pad.kind] = true
		end
		for _, k in
			if S.SMASH then { "smash" } elseif Features.CVC then { "race" } else { "drift", "race" }
		do
			truthy(kinds[k], "pad for " .. k)
		end
		local groups: { [string]: boolean } = {}
		for _, p in S.allParts() do
			groups[p.group] = true
		end
		local want = {
			"Ground",
			"QueuePad1",
			"QueuePad" .. #S.PADS,
			"Arch",
			"garage/Lift",
		}
		-- (Smash: no statue or car stands, the portal is the hero, LOOK-BIBLE rule 9)
		for _, g in if S.SMASH then { "Portal1" } else { "Statue", "Stand8" } do
			table.insert(want, g)
		end
		for _, g in
			if Features.CVC
				then { "crates/Shell", "crates/Counter", "crates/Crate3" }
				else { "drift/Shell", "drift/Car1", "race/Counter", "race/Stand3" }
		do
			table.insert(want, g)
		end
		for _, g in want do
			truthy(groups[g], g)
		end
	end
)

test("lobby Meshy props each replace a real stand-in group", function()
	local groups: { [string]: boolean } = {}
	for _, p in S.parts() do
		groups[p.group] = true
	end
	for _, m in S.MESHES do
		truthy(groups[m.group], m.model .. " -> " .. m.group)
	end
end)

test("the buildings stay clear of the pads, the stands and each other", function()
	-- flat footprint of each building (its solid shell) and each pad
	local boxes: { { string | number } } = {}
	for _, p in S.allParts() do
		local g = p.group
		local slash = string.find(g, "/")
		if slash and p.collide then
			local key = string.sub(g, 1, slash - 1)
			local x0, x1, _, _, z0, z1 = flat(p)
			local b = boxes[key] :: any
			if not b then
				boxes[key] = { x0, x1, z0, z1 } :: any
			else
				b[1], b[2], b[3], b[4] =
					math.min(b[1], x0), math.max(b[2], x1), math.min(b[3], z0), math.max(b[4], z1)
			end
		end
	end
	local others: { [string]: { number } } = {}
	for i, pad in S.PADS do
		others["pad" .. i] = { pad.x - 6.3, pad.x + 6.3, S.PAD_Z - 5.3, S.PAD_Z + 5.3 }
	end
	others.stands =
		{ S.STANDS[1] - 2.4, S.STANDS[#S.STANDS] + 2.4, S.STAND_Z - 2.4, S.STAND_Z + 2.4 }
	local keys = {}
	for k, b in boxes :: any do
		table.insert(keys, k)
		others[k] = b
	end
	for _, k in keys do
		local a = (boxes :: any)[k]
		for name, o in others do
			if name ~= k then
				local hit = a[1] < o[2] and a[2] > o[1] and a[3] < o[4] and a[4] > o[3]
				truthy(not hit, k .. " overlaps " .. name)
			end
		end
	end
end)

test("each car shop has a name and a price for every car on show", function()
	local G = require("../src/shared/Garage")
	for kind, shop in G.SHOPS do
		truthy(#shop.cars >= #G.SHOP_STANDS, kind .. " has a car for every stand")
		eq(#shop.names, #shop.cars)
		eq(#shop.prices, #shop.cars)
		eq(shop.prices[1], 0) -- the starter is free
		-- on show: one car per stand, the free one first, and a rare one among them
		eq(#shop.display, #G.SHOP_STANDS)
		eq(shop.display[1], 1)
		local rare = false
		for _, at in shop.display do
			rare = rare or Cat.get(shop.ids[at]).rarity == "rare"
		end
		truthy(rare, kind .. " shows a rare car")
		for i = 2, #shop.prices do
			truthy(shop.prices[i] > shop.prices[i - 1], kind .. " prices go up")
		end
	end
end)

test("the walk out of every shop: no wall, no play pad, out through the front gap", function()
	local parts = S.allParts()
	for door = 1, #S.DOORS do
		local path = S.exitPath(door)
		local last = path[#path]
		truthy(
			math.abs(last[1]) < S.GAP and last[2] > S.BOX.maxZ,
			`door {door}: ends on the street`
		)
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local steps = math.ceil(math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2])))
			for k = 0, steps do
				local x = a[1] + (b[1] - a[1]) * k / steps
				local z = a[2] + (b[2] - a[2]) * k / steps
				-- a walker is about 1 stud wide each way
				for _, p in parts do
					local x0, x1, y0, y1, z0, z1 = flat(p)
					local solid = p.collide and p.name ~= "Floor" and y0 < 4 and y1 > 0.4
					local pad = string.sub(p.group, 1, 8) == "QueuePad" and p.name == "Rim"
					if
						(solid or pad)
						and x > x0 - 1
						and x < x1 + 1
						and z > z0 - 1
						and z < z1 + 1
					then
						truthy(false, `door {door}: {p.group}/{p.name} in the way at {x}, {z}`)
					end
				end
			end
		end
	end
end)
