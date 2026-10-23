--!strict
-- Track tile looks (TileLooks.luau): each tile's looks stay on its own square, nothing is solid,
-- nothing tall stands on the road or curbs, and each tile stays inside the phone budget.
local H = require("./harness")
local T = require("../src/shared/TileLooks")

local test, truthy = H.test, H.truthy

print("Tile looks")

local CELL = T.CELL
local EDGE = T.ROAD / 2 + T.CURB

-- the size in tile space (a quarter roll about z swaps x and y; a yaw makes the footprint round)
local function dims(p: any): (number, number, number)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	if math.abs(p.rot.z) == 90 then
		sx, sy = sy, sx
	end
	if p.rot.y % 180 ~= 0 then
		local m = math.max(sx, sz)
		sx, sz = m, m
	end
	return sx, sy, sz
end

local function nearRoad(id: string, x: number, z: number, r: number): boolean
	for _, p in T.centre(id, CELL) do
		if math.sqrt((p[1] - x) ^ 2 + (p[2] - z) ^ 2) < r then
			return true
		end
	end
	return false
end

for _, id in T.IDS do
	test(id .. ": on its own square, nothing solid, inside the budget", function()
		local parts = T.parts(id, CELL)
		truthy(#parts > 0 and #parts <= T.MAX_PARTS, tostring(#parts))
		for _, p in parts do
			truthy(not p.collide, p.name .. " solid")
			truthy(p.group == "TileLooks", p.name)
			local sx, _, sz = dims(p)
			truthy(math.abs(p.pos.x) + sx / 2 <= CELL / 2 + 0.5, p.name .. " x")
			truthy(math.abs(p.pos.z) + sz / 2 <= CELL / 2 + 0.5, p.name .. " z")
		end
	end)

	test(id .. ": on the road only paint, anything taller beside it", function()
		for _, p in T.parts(id, CELL) do
			local sx, sy, sz = dims(p)
			local top = p.pos.y + sy / 2
			-- skins draw TrackTiles' own (invisible) cones, barrels, bumps and island
			local skin = string.sub(p.name, 1, 4) == "Skin"
				or (id == "split" and (string.sub(p.name, 1, 5) == "Split" or p.name == "Bush"))
			if top > T.ROAD_TOP + 0.2 and p.pos.y < 9 and not skin then
				-- low and tall: must stand clear of the road and curbs (overhead beams may cross)
				local r = math.min(sx, sz) / 2
				truthy(not nearRoad(id, p.pos.x, p.pos.z, EDGE + r), p.name .. " on the road")
			end
		end
	end)
end

local Kit = require("../src/shared/Plots/Kit")

test("empty cells: every kind on its square, low, nothing solid", function()
	local seen = {}
	for c = 1, 5 do
		for r = 1, 6 do
			local parts = T.emptyParts(c, r, CELL)
			seen[(c * 7 + r * 13) % T.EMPTY_KINDS] = true
			truthy(#parts <= 12, tostring(#parts))
			for _, p in parts do
				truthy(not p.collide, p.name)
				truthy(math.abs(p.pos.x) + p.size.x / 2 <= CELL / 2, p.name .. " x")
				truthy(math.abs(p.pos.z) + p.size.z / 2 <= CELL / 2, p.name .. " z")
				truthy(p.pos.y + p.size.y / 2 <= 6, p.name .. " low")
			end
		end
	end
	for k = 0, T.EMPTY_KINDS - 1 do
		truthy(seen[k], "kind " .. k)
	end
end)

test("surround: in the strips round a 5x5 grid, nothing on a 5x6 grid's road", function()
	local a = Kit.AREA
	local function grid(rows: number): (number, number, number, number)
		local midZ = (a.minZ + a.maxZ) / 2
		return -2.5 * CELL, 2.5 * CELL, midZ - rows / 2 * CELL, midZ + rows / 2 * CELL
	end
	for _, rows in { 5, 6 } do
		local x0, x1, z0, z1 = grid(rows)
		local parts = T.surroundParts(x0, x1, z0, z1, a)
		truthy(#parts <= 80, tostring(#parts))
		for _, p in parts do
			truthy(not p.collide, p.name)
			local px0, px1 = p.pos.x - p.size.x / 2, p.pos.x + p.size.x / 2
			local pz0, pz1 = p.pos.z - p.size.z / 2, p.pos.z + p.size.z / 2
			truthy(
				px0 >= a.minX and px1 <= a.maxX and pz0 >= a.minZ and pz1 <= a.maxZ,
				p.name .. " area"
			)
			local inGrid = px1 > x0 and px0 < x1 and pz1 > z0 and pz0 < z1
			truthy(not inGrid, p.name .. " on the grid")
		end
	end
end)
