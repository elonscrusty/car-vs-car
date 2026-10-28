--!strict
-- Car VS Car plot (PlotTraining.luau): the garage room, the station pads and the tiny cars'
-- runs all fit inside the plot, behind the front wall.
local H = require("./harness")
local T = require("../src/shared/PlotTraining")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot training")

local function box(p: any): (number, number, number, number)
	local sx, sz = p.size.x, p.size.z
	if p.shape == "Cylinder" then
		sx, sz = p.size.y, p.size.z
	end
	local yaw = math.rad(p.rot.y)
	local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	local wx, wz = sx * c + sz * s, sx * s + sz * c
	return p.pos.x - wx / 2, p.pos.x + wx / 2, p.pos.z - wz / 2, p.pos.z + wz / 2
end

test("the room and the pads fit the plot behind the front wall at every level", function()
	for level = 0, 8 do
		for _, p in T.pieces(level, level, level * 2) do
			local x0, x1, z0, z1 = box(p)
			local name = level .. " " .. p.group .. "/" .. p.name
			truthy(x0 >= -39.4 and x1 <= 39.4, name .. " inside the side walls")
			truthy(z0 >= -54.4 and z1 <= 36.6, name .. " between the back wall and the front wall")
		end
	end
	for _, m in T.meshes() do
		truthy(math.abs(m.at.x) + math.max(m.fit.x, m.fit.z) / 2 <= 39.4, m.model .. " in (x)")
		truthy(m.at.z - m.fit.z / 2 >= -54.4, m.model .. " in (z)")
	end
end)

test("carter's room props keep the room's own floor, rug, rails and sign", function()
	-- (Garage.useMeshes clears every part of the group that isn't in `keep`)
	for _, m in T.meshes() do
		local keep: { [string]: boolean } = {}
		for _, name in m.keep do
			keep[name] = true
		end
		for _, p in T.pieces(8, 10, 20) do
			if p.group == m.group then
				truthy(keep[p.name], m.model .. " keeps " .. p.name)
			end
		end
	end
end)

test("nothing on the plot is solid (walk anywhere)", function()
	for _, p in T.pieces(8, 10, 20) do
		eq(p.collide, false)
	end
end)

test("pads don't touch each other or the garage floor in the middle", function()
	local P = T.PAD
	local R = T.ROOM
	for i, a in T.GRID do
		local clear = a.x + P.w / 2 < R.x0 or a.x - P.w / 2 > R.x1 or a.z + P.d / 2 < R.z0
		truthy(clear, "pad " .. i .. " off the garage floor")
		for j, b in T.GRID do
			if i < j then
				local apart = math.abs(a.x - b.x) >= P.w + 1 or math.abs(a.z - b.z) >= P.d + 1
				truthy(apart, "pads " .. i .. " and " .. j .. " apart")
			end
		end
	end
end)

test("one pad open at the start, one more a level", function()
	eq(T.open(0), 1)
	eq(T.open(4), 5)
	eq(T.open(8), 9)
end)

test("car stands: 3 at the start, one more a garage level, 10 at most", function()
	eq(T.stands(0), 3)
	eq(T.stands(2), 5)
	eq(T.stands(50), 10)
end)

test("more trophies, more cups (up to the shelf's room)", function()
	local function cups(n: number): number
		local c = 0
		for _, p in T.pieces(0, 0, n) do
			if p.name == "TrophyCup" then
				c += 1
			end
		end
		return c
	end
	eq(cups(0), 0)
	eq(cups(3), 3)
	eq(cups(99), T.MAX_TROPHIES)
end)

test("reads the Stations attribute", function()
	local pads = T.parse("treadmill:1:race_bolt;ramp:2:;track:x:")
	eq(#pads, 3)
	eq(pads[1].kind, "treadmill")
	eq(pads[1].car, "race_bolt")
	eq(pads[2].level, 2)
	eq(pads[2].car, "")
	eq(pads[3].level, 1)
	eq(#T.parse(nil), 0)
	eq(#T.parse(""), 0)
	eq(#T.parse("junk:1:a"), 0)
end)

test("pad signs: the station and its level, or which plot level opens it", function()
	local a, b = T.padWords({ kind = "ramp", level = 3, car = "" }, 2)
	eq(a, "RAMP")
	eq(b, "LV 3  +BOOST")
	eq(select(2, T.padWords({ kind = "track", level = 1, car = "" }, 3)), "LV 1  +TURN")
	a, b = T.padWords(nil, 4)
	eq(a, "?")
	eq(b, "LV 3")
end)

test("the tiny cars stay on their pad and never jump", function()
	local P = T.PAD
	for _, kind in { "treadmill", "ramp", "track" } do
		local px, _, pz = T.ride(kind, 0)
		for k = 1, 1200 do
			local x, y, z = T.ride(kind, k * 0.01)
			truthy(
				math.abs(x) + 1.5 <= P.w / 2 and math.abs(z) + 1.5 <= P.d / 2,
				kind .. " on the pad"
			)
			truthy(y >= 0.3 and y < 5, kind .. " height")
			local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
			truthy(d < 0.6, kind .. " no jump at " .. k)
			px, pz = x, z
		end
	end
end)

test("pad i is station i", function()
	eq(T.kindAt(1), "treadmill")
	eq(T.kindAt(2), "ramp")
	eq(T.kindAt(3), "track")
end)

test("COACH speeds the stations up for its 10 seconds only", function()
	eq(T.coaching(0, 1000), false)
	eq(T.coaching(nil, 1000), false)
	eq(T.coaching(995, 1000), true)
	eq(T.coaching(985, 1000), false)
	truthy(T.COACH_SPEED > 1, "faster")
end)

test("the treadmill belt's slats stay on the belt and scroll back", function()
	local B = T.BELT
	local a = T.slats(0)
	local b = T.slats(0.05)
	eq(#a, B.slats)
	for _, t in { 0, 0.3, 1.7, 99.9 } do
		for _, z in T.slats(t) do
			truthy(z >= (B.z - B.len / 2) * T.K and z <= (B.z + B.len / 2) * T.K, "on the belt")
		end
	end
	truthy(b[1] > a[1], "moves toward the road")
end)

test("station cars: their name and number on the pad's sign, no tag", function()
	local a, b = T.carWords({ kind = "treadmill", level = 2, car = "race_bolt" }, "Bolt", 27)
	eq(a, "TREADMILL  LV 2")
	eq(b, "BOLT  SPD 27")
	eq(select(2, T.carWords({ kind = "track", level = 1, car = "" }, "Bolt", 9)), "BOLT  TURN 9")
	-- stand tags: narrower than the gap between stands side by side
	for i = 1, #T.STANDS do
		for j = i + 1, #T.STANDS do
			local p, q = T.STANDS[i], T.STANDS[j]
			if p.z == q.z then
				truthy(
					math.abs(p.x - q.x) > T.STAND_TAG.w,
					"stand tags " .. i .. " and " .. j .. " apart"
				)
			end
		end
	end
end)

-- where a plot-local point lands on a 16:9 screen from the stand camera: -1..1 across and up
local function onScreen(px: number, py: number, pz: number, aspect: number): (number, number)
	local C = T.STAND_CAM
	local e, l = C.eye, C.look
	local fx, fy, fz = l.x - e.x, l.y - e.y, l.z - e.z
	local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
	fx, fy, fz = fx / fl, fy / fl, fz / fl
	-- right = forward x up, then up = right x forward
	local rx, ry, rz = -fz, 0, fx
	local rl = math.sqrt(rx * rx + rz * rz)
	rx, rz = rx / rl, rz / rl
	local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	local dx, dy, dz = px - e.x, py - e.y, pz - e.z
	local depth = dx * fx + dy * fy + dz * fz
	local t = math.tan(math.rad(C.fov / 2))
	local across = (dx * rx + dy * ry + dz * rz) / depth / (t * aspect)
	local up = (dx * ux + dy * uy + dz * uz) / depth / t
	return across, up
end

test("the plot camera sees every pad corner and the scoreboard on a phone", function()
	local P = T.PAD
	local B = T.BOARD
	local points = {}
	for _, g in T.GRID do
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(points, { g.x + sx * P.w / 2, 0, g.z + sz * P.d / 2 })
			end
		end
	end
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			table.insert(points, { B.x + sx * B.w / 2, B.y + sy * B.h / 2, B.z })
		end
	end
	for _, aspect in { 16 / 9, 2.16 } do -- a phone on its side, and a long one
		for _, p in points do
			local a, u = onScreen(p[1], p[2], p[3], aspect)
			truthy(
				math.abs(a) <= 0.97 and math.abs(u) <= 0.97,
				`({p[1]}, {p[2]}, {p[3]}) on screen`
			)
		end
	end
end)

test("the gate's name board is under the front pads, not over them", function()
	local D = require("../src/shared/PlotDecor")
	for _, kind in { "race", "drift" } do
		for _, m in D.meshes(kind) do
			if m.group == "Arch" then
				local top = m.fit.y
				local _, gate = onScreen(m.at.x, top, m.at.z, 16 / 9)
				-- the nearest pad corner on the screen (the lowest)
				local low = math.huge
				for _, g in T.GRID do
					local _, u = onScreen(g.x, 0, g.z + T.PAD.d / 2, 16 / 9)
					low = math.min(low, u)
				end
				truthy(gate < low, m.model .. " under the pads")
			end
		end
	end
end)

test("locked pads have no little sign (their words are painted big on the pad)", function()
	for _, p in T.pieces(1, 0, 0) do
		if p.name == "PadSign" or p.name == "PadSignFoot" then
			local i = tonumber(string.sub(p.group, 4)) :: number
			truthy(i <= T.open(1), "sign only on open pads, not " .. p.group)
		end
	end
end)

test("LOCKED words fit the pad top once turned to read from the gate", function()
	local P = T.PAD
	for _, line in T.PAINT do
		-- turned 90: its width runs along the pad's x, its height along z
		truthy(line.w <= P.w * 0.95, "fits across")
		local zc = (line.at - 0.5) * P.d
		truthy(math.abs(zc) + line.h / 2 <= P.d / 2, "fits deep")
	end
	truthy(T.PAINT[1].at > T.PAINT[2].at, "LOCKED on the far line, PLOT LV under it")
end)
