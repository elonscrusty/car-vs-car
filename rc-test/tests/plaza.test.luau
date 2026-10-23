--!strict
-- Lobby plaza (Plaza.luau): paving, lamps, planters and the building spots fit together.
local H = require("./harness")
local L = require("../src/shared/LobbyLayout")
local P = require("../src/shared/Plaza")

local test, truthy = H.test, H.truthy

print("Plaza")

type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
local function inside(b: Box, x: number, z: number, pad: number?): boolean
	local m = pad or 0
	return x >= b.minX - m and x <= b.maxX + m and z >= b.minZ - m and z <= b.maxZ + m
end
local function overlap(a: Box, b: Box): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

test("the plaza is exactly the lobby's PLAZA box, starting where the road ends", function()
	H.near(P.WIDTH, L.PLAZA.maxX - L.PLAZA.minX)
	H.near(P.DEPTH, L.PLAZA.maxZ - L.PLAZA.minZ)
	H.near(L.road().maxZ, L.PLAZA.minZ)
	truthy(P.MOUTH >= L.road().maxX - L.road().minX, "the road fits through the open mouth")
end)

test("every building spot is on the paving and they never overlap", function()
	for i, s in P.spots do
		local b = s.box
		for _, c in
			{ { b.minX, b.minZ }, { b.maxX, b.minZ }, { b.minX, b.maxZ }, { b.maxX, b.maxZ } }
		do
			truthy(P.onPaving(c[1], c[2]), s.name .. " corner on the paving")
		end
		for j = i + 1, #P.spots do
			truthy(not overlap(b, P.spots[j].box), s.name .. " overlaps " .. P.spots[j].name)
		end
	end
end)

test("the middle lane in from the road stays open", function()
	local lane = { minX = -P.MOUTH / 2, maxX = P.MOUTH / 2, minZ = 0, maxZ = 30 }
	for _, s in P.spots do
		truthy(not overlap(s.box, lane), s.name .. " in the lane")
	end
	for _, l in P.lamps do
		truthy(
			not inside(lane, l[1], l[2], -0.5) or math.abs(l[1]) >= P.MOUTH / 2 - 0.5,
			"lamp in the lane"
		)
	end
end)

test("lamps and planters are on the paving, clear of buildings, spawn and trees", function()
	local sx, _, sz = L.spawn()
	local things = {}
	for _, l in P.lamps do
		table.insert(things, { l[1], l[2], 1 })
	end
	for _, p in P.planters do
		table.insert(things, { p[1], p[2], math.max(p[3], p[4]) / 2 })
	end
	for _, t in things do
		local x, z, r = t[1], t[2], t[3]
		truthy(P.onPaving(x, z), "on the paving")
		for _, s in P.spots do
			truthy(not inside(s.box, x, z, r + 1), "clear of " .. s.name)
		end
		truthy(math.abs(x - sx) > 8 or math.abs(z + L.PLAZA.minZ - sz) > 8, "clear of the spawn")
		for _, tree in L.trees() do
			local dx, dz = tree.x - x, tree.z - (z + L.PLAZA.minZ)
			truthy(dx * dx + dz * dz > 4 * 4, "clear of a tree")
		end
	end
end)

test("the garage spot matches the lobby's garage", function()
	local g = L.garage()
	local s = P.spot("Garage")
	truthy(s ~= nil)
	local b = (s :: any).box
	truthy(inside(b, g.x, g.z - L.PLAZA.minZ), "garage middle in its spot")
end)

test(
	"decor sits on the paving, out of the lane, buildings, spawn, parked cars and trees",
	function()
		local sx, _, sz = L.spawn()
		local lane = { minX = -P.MOUTH / 2, maxX = P.MOUTH / 2, minZ = 0, maxZ = 30 }
		for i, d in P.decor do
			local where = d.name .. " #" .. i
			truthy(
				P.onPaving(d.x - d.r, d.z) and P.onPaving(d.x + d.r, d.z),
				where .. " on the paving"
			)
			truthy(not inside(lane, d.x, d.z, d.r), where .. " in the lane")
			for _, s in P.spots do
				truthy(not inside(s.box, d.x, d.z, d.r + 1), where .. " in " .. s.name)
			end
			local wz = d.z + L.PLAZA.minZ
			truthy(math.abs(d.x - sx) > 8 or math.abs(wz - sz) > 8, where .. " on the spawn")
			for n = 1, 8 do
				local px, pz = L.parkSpot(n)
				truthy(
					math.abs(d.x - px) > d.r + 2 or math.abs(wz - pz) > d.r + 2,
					where .. " on a parked car"
				)
			end
			for _, tree in L.trees() do
				local dx, dz = tree.x - d.x, tree.z - wz
				truthy(dx * dx + dz * dz > (d.r + 3) ^ 2, where .. " in a tree")
			end
			for _, l in P.lamps do
				local dx, dz = l[1] - d.x, l[2] - d.z
				truthy(dx * dx + dz * dz > (d.r + 1.5) ^ 2, where .. " on a lamp")
			end
			for j, e in P.decor do
				if j > i then
					local dx, dz = e.x - d.x, e.z - d.z
					truthy(dx * dx + dz * dz > (d.r + e.r) ^ 2, where .. " on " .. e.name)
				end
			end
		end
	end
)
