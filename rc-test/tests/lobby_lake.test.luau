--!strict
-- Things to do at the lobby lake (LobbyLake.luau): fishing spots, raft, boats, beaches, ducks.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local W = require("../src/shared/LobbyWater")
local K = require("../src/shared/LobbyLake")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Lobby lake")

local pieces, spots = K.build()

local function named(name: string): { K.Piece }
	local out = {}
	for _, p in pieces do
		if p.name == name then
			table.insert(out, p)
		end
	end
	return out
end

test("light for phones: a couple of hundred plain parts", function()
	truthy(#pieces < 300, `{#pieces} parts`)
	for _, p in pieces do
		truthy(p.sx > 0 and p.sy > 0 and p.sz > 0, p.name .. " flat")
	end
end)

test("everything is past the street end, on the lake's land", function()
	local g = L.ground()
	local land = W.landBox()
	for _, p in pieces do
		-- reach along x and z (exact for square-on pieces, a circle round the rest)
		local r = math.max(p.sx, p.sz) / 2
		local rx, rz = r, r
		if p.ry % 180 == 0 then
			rx, rz = p.sx / 2, p.sz / 2
		end
		truthy(p.z - rz > g.maxZ, p.name .. " pokes into the lobby")
		truthy(
			p.x - rx > land.minX and p.x + rx < land.maxX and p.z + rz < land.maxZ,
			p.name .. " off the land"
		)
	end
end)

test("seats: fishing stools, deck chairs under the umbrellas, the lifeguard chair", function()
	local seats = 0
	for _, p in pieces do
		if p.seat then
			seats += 1
		end
	end
	eq(#named("FishSeat"), 4)
	eq(#named("ChairSeat"), 8)
	eq(#named("GuardSeat"), 1)
	eq(seats, 13)
end)

test("each fishing line hangs from its rod tip down to a float on the water", function()
	local lines, floats = named("FishLine"), named("FishFloat")
	eq(#lines, 4)
	eq(#floats, 4)
	for i, l in lines do
		local bottom = l.y - l.sy / 2
		truthy(math.abs(bottom - W.WATER_TOP) < 0.01, "line reaches the water")
		local f = floats[i]
		truthy(math.abs(f.x - l.x) < 0.01 and math.abs(f.z - l.z) < 0.01, "float under the line")
		truthy(not l.collide and not f.collide, "you walk through lines and floats")
	end
	-- the line hangs past the dock end, over water
	for _, e in W.dockEnds() do
		local past = 0
		for _, l in lines do
			if math.abs(l.x - e.x) < 4 and (l.z - e.z) * e.dz > 1 then
				past += 1
			end
		end
		eq(past, 2, "two lines off each dock end")
	end
end)

test("the beaches stay inside the first underwater step, so you walk up onto them", function()
	local l = W.lakeBox()
	local first = W.STEPS[1][2] - W.SAND -- how far the first step reaches past the waterline
	for _, p in pieces do
		if p.name == "Beach" or p.name == "BeachBump" then
			local r = if p.name == "Beach" then p.sz / 2 else p.sx * 0.71
			truthy(p.z + r - l.minZ < first, p.name .. " reaches past the first step")
			truthy(math.abs(p.y + p.sy / 2 - W.SAND_TOP) < 0.01, "beach top = sand top")
		end
	end
end)

test("the beaches keep clear of the docks", function()
	for _, e in W.dockEnds() do
		for _, p in named("Beach") do
			truthy(math.abs(p.x - e.x) > p.sx / 2 + 6, "beach under a dock")
		end
	end
end)

test("the raft sits on the water with steps up from the lake floor", function()
	local planks = named("RaftPlank")
	eq(#planks, 5)
	for _, p in planks do
		truthy(math.abs(p.y + p.sy / 2 - W.DECK_TOP) < 0.01, "deck height")
	end
	local steps = named("RaftStep")
	eq(#steps, 2)
	for _, s in steps do
		truthy(
			s.y + s.sy / 2 > W.BED_TOP and s.y + s.sy / 2 < W.DECK_TOP,
			"step between floor and deck"
		)
	end
end)

test("every Meshy spot has blocks standing in for it until the mesh is imported", function()
	local known =
		{ Sailboat = 2, Canoe = 1, Duck = 4, Campfire = 1, BaitShack = 1, BeachUmbrella = 4 }
	local seen: { [string]: number } = {}
	for _, s in spots do
		truthy(known[s.mesh] ~= nil, "unknown mesh " .. s.mesh)
		seen[s.mesh] = (seen[s.mesh] or 0) + 1
		truthy(s.height > 0, s.id .. " height")
		local blocks = 0
		for _, p in pieces do
			if p.group == s.id then
				blocks += 1
				truthy(not p.seat, "a seat must not vanish with the mesh")
			end
		end
		truthy(blocks > 0, s.id .. " has no blocks")
	end
	for mesh, n in known do
		eq(seen[mesh], n, mesh)
	end
end)

test("the campfire glows: flames walk-through, one hidden light", function()
	for _, f in named("Flame") do
		truthy(f.neon and not f.collide, "flame")
	end
	local light = named("FireLight")
	eq(#light, 1)
	truthy(light[1].hidden and light[1].light and light[1].group == nil, "light stays when meshed")
end)

test("same lake every run", function()
	local again = K.build()
	eq(#again, #pieces)
	for i, p in again do
		truthy(
			p.name == pieces[i].name and p.x == pieces[i].x and p.z == pieces[i].z,
			"piece " .. i
		)
	end
end)

local motions = K.motions()

test("two sailboats and four ducks move on screen, each a Meshy spot", function()
	local kinds: { [string]: number } = {}
	for _, mo in motions do
		kinds[mo.kind] = (kinds[mo.kind] or 0) + 1
		local found = false
		for _, s in spots do
			found = found or s.id == mo.id
		end
		truthy(found, mo.id .. " has no spot")
	end
	eq(kinds.sail, 2)
	eq(kinds.duck, 4)
end)

test("ducks start on their spot at time 0 and paddle the way they face", function()
	for _, mo in motions do
		if mo.kind == "duck" and mo.lag == 0 then
			local x, _, z, ry = K.pose(mo, 0)
			truthy(math.abs(x - mo.x) < 0.01 and math.abs(z - mo.z) < 0.01, "mother on her spot")
			truthy(math.abs(((ry - mo.ry + 180) % 360) - 180) < 5, "facing her way")
			local x2, _, z2 = K.pose(mo, 0.5)
			local f = math.rad(mo.ry)
			truthy((x2 - x) * math.sin(f) + (z2 - z) * math.cos(f) > 0, "moves forward")
		end
	end
end)

test("ducks and sailboats stay out in open water, clear of the raft and each other", function()
	local l = W.lakeBox()
	local inset = W.SHALLOW
	local raftX, raftZ = 0, 0
	for _, p in named("RaftFrame") do
		raftX, raftZ = p.x, p.z
	end
	for t = 0, 120, 0.5 do
		local spots: { { number } } = {}
		for _, mo in motions do
			local x, _, z = K.pose(mo, t)
			truthy(x > l.minX + inset and x < l.maxX - inset, mo.id .. " too near the shore (x)")
			truthy(z > l.minZ + inset and z < l.maxZ - inset, mo.id .. " too near the shore (z)")
			truthy(math.max(math.abs(x - raftX), math.abs(z - raftZ)) > 18, mo.id .. " at the raft")
			if mo.kind == "sail" then
				table.insert(spots, { x, z })
			end
		end
		for _, mo in motions do
			if mo.kind == "duck" then
				local x, _, z = K.pose(mo, t)
				for _, s in spots do
					truthy(math.abs(x - s[1]) + math.abs(z - s[2]) > 12, "duck under a sailboat")
				end
			end
		end
	end
end)

test("ducklings keep their place behind their mother", function()
	local ducks = {}
	for _, mo in motions do
		if mo.kind == "duck" then
			table.insert(ducks, mo)
		end
	end
	for t = 0, 60, 5 do
		for i = 2, #ducks do
			local ax, _, az = K.pose(ducks[i - 1], t)
			local bx, _, bz = K.pose(ducks[i], t)
			local d = math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
			truthy(d > 1 and d < 4, `duck {i} is {d} from the one ahead`)
		end
	end
end)

test("glints flash on open water", function()
	local l = W.lakeBox()
	for i = 1, K.SPARKLES do
		for t = 0, 10, 0.37 do
			local x, z, b = K.sparkle(i, t)
			truthy(x > l.minX and x < l.maxX and z > l.minZ and z < l.maxZ, "on the lake")
			truthy(b >= 0 and b <= 1, "brightness")
		end
	end
end)
