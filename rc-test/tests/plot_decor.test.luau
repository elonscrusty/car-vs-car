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
			if m.group == "Arch" then
				-- the gate model: you walk through it, and it is never solid
				truthy(not m.collide, "gate " .. m.model .. " not solid")
				continue
			end
			local inLane = m.at.x + m.fit.x / 2 > lane.minX
				and m.at.x - m.fit.x / 2 < lane.maxX
				and m.at.z + m.fit.z / 2 > lane.minZ
				and m.at.z - m.fit.z / 2 < lane.maxZ
			truthy(not inLane, "mesh " .. m.model)
		end
	end)

	test(kind .. ": Car VS Car: no bunting ropes to the smaller gate", function()
		local gate = false
		for _, m in P.meshes(kind) do
			if m.group == "Arch" then
				gate = true
			end
		end
		for _, p in if gate then P.parts(kind) else {} do
			truthy(p.name ~= "Rope" and p.name ~= "Pennant", "no bunting to a gate that moved")
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

	test(kind .. ": Smash: no chequered flags or checker strips (no racing)", function()
		for _, p in P.parts(kind) do
			truthy(p.name ~= "Check" and p.name ~= "Checker", `{p.group}/{p.name}`)
		end
	end)

	test(
		kind .. ": Smash: the gate is plain garage posts (navy, no Neon, no race gate model)",
		function()
			for _, p in P.parts(kind) do
				-- (the rock plot keeps its log gate: wood, not a race start)
				if
					kind ~= "rock"
					and p.group == "Arch"
					and (p.name == "Pillar" or p.name == "Beam")
				then
					eq(table.concat(p.color, ","), "35,45,80", p.name)
				end
				if
					(p.group == "Arch" or p.group == "Bunting")
					and (p.name == "Lantern" or p.name == "Glow")
				then
					truthy(p.material ~= "Neon", `{p.group}/{p.name} glows`)
				end
			end
			for _, m in P.meshes(kind) do
				truthy(m.model ~= "PlotGate" and m.model ~= "DriftGate", m.model)
			end
		end
	)

	test(kind .. ": light on phones (under 66 parts)", function()
		truthy(#P.parts(kind) < 66, tostring(#P.parts(kind)))
	end)
end
