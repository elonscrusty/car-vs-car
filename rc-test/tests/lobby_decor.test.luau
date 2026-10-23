--!strict
-- Lobby decorations (LobbyDecor.luau): light for phones, nothing solid where people walk or
-- cars drive, nothing in the plots, and the life stays where it should.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local D = require("../src/shared/LobbyDecor")
local S = require("../src/shared/SpawnLobby")

local test, truthy = H.test, H.truthy

print("Lobby decorations")

local parts = D.parts()

-- flat footprint of a piece (turns of 90 degrees swap sides; other turns use the widest side)
local function flat(p: any): (number, number, number, number, number, number)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	if math.abs(p.rot.z) % 180 == 90 then
		sx, sy = sy, sx
	end
	local ry = math.abs(p.rot.y) % 180
	if ry == 90 then
		sx, sz = sz, sx
	elseif ry ~= 0 then
		local w = math.max(sx, sz) * 1.42
		sx, sz = w, w
	end
	if p.rot.x ~= 0 and math.abs(p.rot.x) % 180 ~= 0 then
		local w = math.max(sy, sz)
		sy, sz = w, w
	end
	return p.pos.x - sx / 2,
		p.pos.x + sx / 2,
		p.pos.y - sy / 2,
		p.pos.y + sy / 2,
		p.pos.z - sz / 2,
		p.pos.z + sz / 2
end

local function overlaps(p: any, b: any): boolean
	local x0, x1, _, _, z0, z1 = flat(p)
	return x1 > b.minX and x0 < b.maxX and z1 > b.minZ and z0 < b.maxZ
end

test("light enough for phones", function()
	truthy(#parts > 100 and #parts <= 330, `parts: {#parts}`)
	truthy(#D.life() <= 40, "flyers")
end)

test("road and walking lane stay clear below the bunting", function()
	local road = L.road()
	local lane = L.EDGE - 2.2 -- footpath things stand outside this
	for _, p in parts do
		local x0, x1, y0, _, z0, z1 = flat(p)
		local name = p.group .. "/" .. p.name
		if z1 > road.minZ and z0 < road.maxZ and x1 > -lane and x0 < lane then
			truthy(not p.collide, name .. " solid on the street")
			truthy(y0 >= 6 or p.pos.y < 0.2, name .. " in the way")
		end
	end
end)

test("nothing in the plots, on the pads or on the signs", function()
	local hw, hd = L.PLOT_D / 2, L.PLOT_W / 2
	for _, s in L.slots() do
		local plot =
			{ minX = s.plotX - hw, maxX = s.plotX + hw, minZ = s.plotZ - hd, maxZ = s.plotZ + hd }
		local pad = {
			minX = s.padX - L.PAD,
			maxX = s.padX + L.PAD,
			minZ = s.padZ - L.PAD,
			maxZ = s.padZ + L.PAD,
		}
		local sign =
			{ minX = s.signX - 1, maxX = s.signX + 1, minZ = s.signZ - 6, maxZ = s.signZ + 6 }
		for _, p in parts do
			local name = p.group .. "/" .. p.name
			truthy(not overlaps(p, plot), name .. " in plot " .. s.index)
			truthy(not overlaps(p, pad), name .. " on pad " .. s.index)
			truthy(not overlaps(p, sign), name .. " on sign " .. s.index)
		end
	end
end)

test("gap pieces leave room for the plots' gap steps", function()
	local road = L.road()
	for _, p in parts do
		local x0, x1, _, _, z0, _ = flat(p)
		if z0 > road.minZ and z0 < road.maxZ then
			truthy(x0 >= -(L.EDGE + 14) and x1 <= L.EDGE + 14, p.group .. " too far out")
		end
	end
end)

test("start line is past the waiting cars", function()
	local _, pz = L.parkSpot(1)
	for _, p in parts do
		if p.group == "StartLine" then
			local _, _, _, _, z0, _ = flat(p)
			truthy(z0 > pz + 1.5, "start line under the cars")
		end
	end
end)

test("RC corners sit on the grass beside the spawn lobby", function()
	local g = L.ground()
	local plaza = L.PLAZA
	for _, p in parts do
		if p.pos.z < L.road().minZ then
			local x0, x1, _, _, z0, z1 = flat(p)
			local name = p.group .. "/" .. p.name
			truthy(x0 > g.minX + 4 and x1 < g.maxX - 4 and z0 > g.minZ and z1 < plaza.maxZ, name)
			truthy(x1 < plaza.minX - 8 or x0 > plaza.maxX + 8, name .. " in the spawn lobby")
			truthy(math.abs(p.pos.x) > S.BOX.maxX, name .. " in the spawn lobby box")
		end
	end
end)

test("every Meshy swap has its block stand-in", function()
	local groups: { [string]: boolean } = {}
	for _, p in parts do
		groups[p.group] = true
	end
	for _, m in D.MESHES do
		truthy(groups[m.group] == true, m.group .. " has no stand-in")
	end
	for _, f in D.FACED do
		truthy(groups[f.group] == true, f.group .. " has no stand-in")
	end
end)

test("footpath props and gap flags face the road", function()
	truthy(#D.FACED >= 8 + 6 * 4, "faced props")
	for _, f in D.FACED do
		local toRoad = f.face.x * f.at.x < 0 and f.face.z == 0
		local toSpawn = f.face.z < 0 and f.at.z < L.FIRST_Z
		truthy(toRoad or toSpawn, f.group .. " faces away from the road")
	end
end)

test("butterflies stay low, birds fly high", function()
	for _, f in D.life() do
		if f.kind == "Butterfly" then
			truthy(f.y > 1.5 and f.y < 5, "butterfly height")
		else
			truthy(f.y >= 20, "bird height")
		end
	end
end)
