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

test("pads don't touch each other or the room", function()
	local P = T.PAD
	for i, a in T.GRID do
		truthy(a.z - P.d / 2 > T.ROOM.z1, "pad " .. i .. " in front of the room")
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
	eq(b, "LV 3")
	a, b = T.padWords(nil, 4)
	eq(a, "LOCKED")
	eq(b, "PLOT LV 3")
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
			truthy(z >= B.z - B.len / 2 and z <= B.z + B.len / 2, "on the belt")
		end
	end
	truthy(b[1] > a[1], "moves toward the road")
end)

test("car tags: one per pad, never over the next pad, the car or each other", function()
	local A = T.TAG
	-- the highest a station car gets (top of its hop) plus the car itself
	local top = 0
	for _, kind in { "treadmill", "ramp", "track" } do
		for k = 0, 600 do
			local _, y = T.ride(kind, k * 0.01)
			top = math.max(top, y)
		end
	end
	top += 3.6 * T.CAR
	for i = 1, #T.GRID do
		local x, y, z = T.tagSpot(i)
		local g = T.GRID[i]
		truthy(math.abs(x - g.x) + A.w / 2 <= T.PAD.w / 2, "tag " .. i .. " within its pad's width")
		truthy(math.abs(z - g.z) <= T.PAD.d / 2, "tag " .. i .. " over its pad")
		truthy(y - A.h / 2 > top, "tag " .. i .. " above the car's whole run")
		for j = i + 1, #T.GRID do
			local x2, _, z2 = T.tagSpot(j)
			truthy(
				math.abs(x - x2) >= A.w or math.abs(z - z2) >= T.PAD.d,
				"tags " .. i .. " and " .. j .. " apart"
			)
		end
	end
	-- and under the room's signs (Studio 29: a tag stuck on NAME'S GARAGE)
	local tagTop = T.TAG.y + A.h / 2
	for _, p in T.pieces(8, 8, 12) do
		if p.name == "RoomSign" or p.name == "ShelfSign" then
			truthy(p.pos.y - p.size.y / 2 > tagTop, p.name .. " above the tags")
		end
	end
	-- stand tags: narrower than the gap between stands side by side
	for a = 1, #T.STANDS do
		for b = a + 1, #T.STANDS do
			local p, q = T.STANDS[a], T.STANDS[b]
			if p.z == q.z then
				truthy(
					math.abs(p.x - q.x) > T.STAND_TAG.w,
					"stand tags " .. a .. " and " .. b .. " apart"
				)
			end
		end
	end
end)
