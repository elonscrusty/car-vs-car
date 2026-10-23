--!strict
-- Plot decor (PlotDecor.luau): fits on the plot's frame and front area, never on the track,
-- leaves the walk to the stand open, and the gap steps stay clear of the other lobby bits.
local H = require("./harness")
local P = require("../src/shared/PlotDecor")
local L = require("../src/shared/LobbyLayout")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Plot decor")

-- flat footprint of a piece (box around it, rotations up to 90 degrees about one axis)
local function box(p: any): (number, number, number, number, number, number)
	local sx, sy, sz = p.size.x, p.size.y, p.size.z
	local rz, ry = math.abs(p.rot.z) % 180, math.abs(p.rot.y) % 180
	if rz == 90 then
		sx, sy = sy, sx
	elseif rz ~= 0 then
		local r = math.rad(rz)
		sx, sy =
			sx * math.abs(math.cos(r)) + sy * math.abs(math.sin(r)),
			sx * math.abs(math.sin(r)) + sy * math.abs(math.cos(r))
	end
	if ry == 90 then
		sx, sz = sz, sx
	elseif ry ~= 0 then
		local m = math.max(sx, sz)
		sx, sz = m, m
	end
	if math.abs(p.rot.x) > 0 then
		sy += sz * math.sin(math.rad(math.abs(p.rot.x)))
	end
	return p.pos.x - sx / 2,
		p.pos.x + sx / 2,
		p.pos.y - sy / 2,
		p.pos.y + sy / 2,
		p.pos.z - sz / 2,
		p.pos.z + sz / 2
end

for _, kind in { "race", "drift", "rock" } do
	test(kind .. ": every piece fits in the plot box", function()
		local b = P.BOX
		for _, p in P.parts(kind) do
			local x0, x1, y0, y1, z0, z1 = box(p)
			local name = p.group .. "/" .. p.name
			truthy(x0 >= b.minX and x1 <= b.maxX, name .. " x")
			truthy(z0 >= b.minZ and z1 <= b.maxZ, name .. " z")
			truthy(y0 >= -0.3 and y1 <= b.maxY, name .. " y")
		end
	end)

	test(kind .. ": nothing on the track (only on the walls or in the front area)", function()
		local W, D = P.HALF_W, P.HALF_D
		for _, p in P.parts(kind) do
			local x0, x1, _, _, z0, z1 = box(p)
			local onWall = x0 >= W - 1 or x1 <= -W + 1 or z1 <= -D + 1 or z0 >= D - 1
			local front = z0 >= P.FRONT_Z + 0.3
			truthy(onWall or front, p.group .. "/" .. p.name)
		end
		for _, m in P.meshes(kind) do
			truthy(m.at.z - m.fit.z / 2 >= P.FRONT_Z + 0.3, "mesh " .. m.model)
		end
	end)

	test(kind .. ": the walk from the gate to the stand steps is open", function()
		local lane = P.LANE
		for _, p in P.parts(kind) do
			local x0, x1, y0, _, z0, z1 = box(p)
			local hit = p.collide
				and y0 < 5
				and x1 > lane.minX
				and x0 < lane.maxX
				and z1 > lane.minZ
				and z0 < lane.maxZ
			truthy(not hit, p.group .. "/" .. p.name)
		end
		for _, m in P.meshes(kind) do
			local inLane = m.at.x + m.fit.x / 2 > lane.minX
				and m.at.x - m.fit.x / 2 < lane.maxX
				and m.at.z + m.fit.z / 2 > lane.minZ
				and m.at.z - m.fit.z / 2 < lane.maxZ
			truthy(not inLane, "mesh " .. m.model)
		end
	end)

	test(kind .. ": a name board on the arch, high over the gate", function()
		local n = 0
		for _, p in P.parts(kind) do
			if p.name == "NameBoard" then
				n += 1
				truthy(p.pos.y - p.size.y / 2 > 8, "above heads")
				truthy(p.pos.z > P.HALF_D, "on the road side")
			end
		end
		eq(n, 1)
	end)

	test(kind .. ": light on phones (under 60 parts)", function()
		truthy(#P.parts(kind) < 60, tostring(#P.parts(kind)))
	end)
end

test("gap steps sit in the gaps, clear of the gap's flag, flowers and tree", function()
	local half = L.STEP / 2
	local pieces = P.gapSteps()
	eq(#pieces, (L.ROWS - 1) * 2 * #P.STEPS)
	for _, p in pieces do
		local x0, x1, _, _, z0, z1 = box(p)
		local ax0, ax1 = math.min(math.abs(x0), math.abs(x1)), math.max(math.abs(x0), math.abs(x1))
		truthy(ax0 > L.EDGE + 16, "past the flower bed")
		truthy(ax1 < L.EDGE + L.PLOT_D - 8, "before the tree")
		-- between two plots' side walls (plot middle +- PLOT_W / 2)
		local row = math.floor((p.pos.z - L.FIRST_Z) / L.STEP)
		local mid = L.FIRST_Z + (row + 0.5) * L.STEP
		truthy(z0 > mid - half + L.PLOT_W / 2 - 4.75 + 0.5, "clear of the near wall")
		truthy(z1 < mid + half - L.PLOT_W / 2 + 4.75 - 0.5, "clear of the far wall")
	end
end)
