--!strict
-- Upgrades garage (Garage.luau): fits its plaza box, door lane stays open, nothing floats or sinks.
local H = require("./harness")
local G = require("../src/shared/Garage")

local test, truthy = H.test, H.truthy

print("Garage")

-- flat footprint of a piece (rotations here are only 0 / 90 / 180 degrees)
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

test("every piece is real and named", function()
	local parts = G.parts()
	truthy(#parts > 50, "enough pieces")
	for _, p in parts do
		truthy(p.size.x > 0 and p.size.y > 0 and p.size.z > 0, p.name .. " size")
		truthy(p.shape == "Block" or p.shape == "Cylinder", p.name .. " shape")
		truthy(#p.color == 3, p.name .. " colour")
	end
end)

test("everything fits in the garage box and stands on the ground", function()
	local b = G.BOX
	for _, p in G.parts() do
		local x0, x1, y0, y1, z0, z1 = flat(p)
		truthy(x0 >= b.minX - 1e-6 and x1 <= b.maxX + 1e-6, p.group .. "/" .. p.name .. " x")
		truthy(z0 >= b.minZ - 1e-6 and z1 <= b.maxZ + 1e-6, p.group .. "/" .. p.name .. " z")
		truthy(y0 >= -1e-6 and y1 <= b.maxY + 1e-6, p.group .. "/" .. p.name .. " y")
	end
end)

test("the walk-in lane from the open front is clear", function()
	local l = G.LANE
	for _, p in G.parts() do
		if p.collide and p.name ~= "Floor" then
			local x0, x1, y0, _, z0, z1 = flat(p)
			local hits = x1 > l.minX and x0 < l.maxX and z1 > l.minZ and z0 < l.maxZ and y0 < 6
			truthy(not hits, p.group .. "/" .. p.name .. " blocks the door")
		end
	end
end)

test(
	"there is a lift with a car, a bench, a tool board, a chest, tires, a gas pump, trophies and an upgrade pad",
	function()
		local groups: { [string]: boolean } = {}
		for _, p in G.parts() do
			groups[p.group] = true
		end
		for _, g in
			{
				"Shell",
				"Lift",
				"Workbench",
				"ToolBoard",
				"ToolChest",
				"TiresIn",
				"TiresOut1",
				"GasPump",
				"TrophyShelf",
				"UpgradePad",
			}
		do
			truthy(groups[g], g)
		end
	end
)

test(
	"each Meshy prop has a home: its stand-in group, a spot in the box, real kept names",
	function()
		local names: { [string]: { [string]: boolean } } = {}
		for _, p in G.parts() do
			names[p.group] = names[p.group] or {}
			names[p.group][p.name] = true
		end
		local b = G.BOX
		for _, m in G.MESHES do
			truthy(names[m.group], m.model .. " group " .. m.group)
			truthy(m.long == "x" or m.long == "z", m.model .. " long")
			local hx, hz = m.fit.x / 2, m.fit.z / 2
			if m.long == "z" then
				hx, hz = m.fit.z / 2, m.fit.x / 2
			end
			truthy(m.at.x - hx >= b.minX and m.at.x + hx <= b.maxX, m.model .. " x")
			truthy(m.at.z - hz >= b.minZ and m.at.z + hz <= b.maxZ, m.model .. " z")
			truthy(m.at.y + m.fit.y <= b.maxY, m.model .. " y")
			for _, k in m.keep do
				truthy(names[m.group][k], m.model .. " keeps " .. k)
			end
		end
	end
)
