--!strict
local H = require("./harness")
local GuidePath = require("../src/shared/GuidePath")
local Config = require("../src/shared/TutorialConfig")
local Layout = require("../src/shared/LobbyLayout")
local Props = require("../src/shared/LobbyProps")

print("GuidePath")

-- Every solid thing a walker must not touch (the ring itself is walkable).
local function solids(): { GuidePath.Rect }
	local list: { GuidePath.Rect } = {}
	for name, r in Layout.footprints() do
		if name ~= "ring" then
			table.insert(list, r)
		end
	end
	for _, r in Props.footprints() do
		table.insert(list, r)
	end
	return list
end

-- Walks a route in small steps and returns what it hits: "" when it is clean.
local function hits(route: { GuidePath.Point }, openPad: number?): string
	local rects = solids()
	local pads = Layout.pads()
	local padR = Layout.padRadius + Layout.padSlack
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local steps = math.max(1, math.ceil(len / 0.5))
		for k = 0, steps do
			local t = k / steps
			local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
			-- a route may start inside something (the player stood there) but never cross it later
			if not (i == 2 and k == 0) then
				for n, r in rects do
					if GuidePath.insideRect(r, x, z, 0.5) then
						return `solid {n} at {x}, {z}`
					end
				end
				for k2, p in pads do
					if k2 ~= openPad and (p.x - x) ^ 2 + (p.z - z) ^ 2 < padR * padR then
						return `pad {k2} at {x}, {z}`
					end
				end
			end
		end
	end
	return ""
end

local function straight(a: GuidePath.Point, b: GuidePath.Point): number
	return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
end

H.test("the way from the spawn to the gumball machine is short and clean", function()
	local sp = Layout.spawn
	local route, found = GuidePath.toGumball(sp.x, sp.z)
	H.truthy(found)
	H.truthy(#route >= 2)
	H.near(route[1].x, sp.x)
	H.near(route[1].z, sp.z)
	local last = route[#route]
	H.near(last.x, Config.gumballStop.x)
	H.near(last.z, Config.gumballStop.z)
	H.eq(hits(route), "")
	local d = straight({ x = sp.x, z = sp.z }, Config.gumballStop)
	H.truthy(GuidePath.length(route) <= d * 1.25, "not much longer than the straight line")
	H.truthy(GuidePath.length(route) >= d - 1e-6)
end)

H.test("the way to a pad ends in the middle of it and avoids the other pads", function()
	local sp = Layout.spawn
	local pad, route, found = GuidePath.toNearestPad(sp.x, sp.z)
	H.truthy(found)
	H.truthy(pad >= 1 and pad <= 4)
	local p = Layout.pads()[pad]
	local last = route[#route]
	H.near(last.x, p.x)
	H.near(last.z, p.z)
	H.eq(hits(route, pad), "")
	-- a pad on the near side of the ring (it is closer to the spawn than the far ones)
	H.truthy(p.z > Layout.ring.z)
end)

H.test("a way to every pad from the spawn and from the gumball machine", function()
	for _, from in
		{
			{ x = Layout.spawn.x, z = Layout.spawn.z },
			{ x = Config.gumballStop.x, z = Config.gumballStop.z },
		}
	do
		for k, p in Layout.pads() do
			local route, found = GuidePath.route(from.x, from.z, p.x, p.z, k)
			H.truthy(found, `pad {k}`)
			H.near(route[#route].x, p.x)
			H.near(route[#route].z, p.z)
			H.eq(hits(route, k), "", `pad {k}`)
		end
	end
end)

H.test("ways from all over the lobby reach the gumball machine cleanly", function()
	local tried = 0
	for x = -80, 80, 10 do
		for z = -62, 54, 8 do
			if GuidePath.free(x, z, nil) then
				tried += 1
				local route, found = GuidePath.toGumball(x, z)
				local last = route[#route]
				H.near(last.x, Config.gumballStop.x)
				H.near(last.z, Config.gumballStop.z)
				for _, pt in route do
					H.truthy(pt.x == pt.x and pt.z == pt.z, "no NaN")
				end
				if found then
					H.eq(hits(route), "", `from {x}, {z}`)
				else
					-- only the pockets behind and between the garages (shut in by their walls)
					H.truthy(z <= -50, `{x}, {z} is shut in but is not behind a garage`)
				end
			end
		end
	end
	H.truthy(tried > 60, "the sample covers the lobby")
end)

H.test("a player standing inside something still gets a route out", function()
	-- inside the first bench, inside a car-show stand, and on a pad
	local bench = Props.benches()[1]
	local stand = Layout.parking()[1]
	local pad = Layout.pads()[1]
	for _, p in
		{
			{ x = bench.x, z = bench.z },
			{ x = stand.x, z = stand.z },
			{ x = pad.x, z = pad.z },
		}
	do
		local route, found = GuidePath.toGumball(p.x, p.z)
		H.truthy(found)
		H.truthy(#route >= 2)
		local last = route[#route]
		H.near(last.x, Config.gumballStop.x)
		H.near(last.z, Config.gumballStop.z)
	end
end)

H.test("the gumball stop, the spawn and every pad middle are open ground", function()
	H.truthy(GuidePath.free(Config.gumballStop.x, Config.gumballStop.z, nil))
	H.truthy(GuidePath.free(Layout.spawn.x, Layout.spawn.z, nil))
	for k, p in Layout.pads() do
		H.eq(GuidePath.free(p.x, p.z, nil), false, "a closed pad blocks routes")
		H.truthy(GuidePath.free(p.x, p.z, k), "its own pad is open for its route")
	end
	-- a bench is solid, the middle of the front path is not
	local bench = Props.benches()[1]
	H.eq(GuidePath.free(bench.x, bench.z, nil), false)
	H.truthy(GuidePath.free(0, 50, nil))
	-- outside the plaza is closed
	H.eq(GuidePath.free(150, 0, nil), false)
end)

H.test("length, and a route with no distance", function()
	H.eq(GuidePath.length({ { x = 0, z = 0 }, { x = 3, z = 4 }, { x = 3, z = 10 } }), 11)
	H.eq(GuidePath.length({ { x = 1, z = 1 } }), 0)
	local route, found = GuidePath.route(0, 42, 0, 42, nil)
	H.truthy(found)
	H.eq(#route, 2)
	H.eq(GuidePath.length(route), 0)
end)

H.test("a pocket shut in by the walls gives the straight line and says so", function()
	-- the corner behind the customize garage cannot be walked out of
	local route, found = GuidePath.toGumball(-80, -62)
	H.eq(found, false)
	H.eq(#route, 2)
end)

H.test("marks are evenly spaced along the route and point along it", function()
	local route: { GuidePath.Point } = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = -10 } }
	local marks = GuidePath.marks(route, 4, 1)
	-- distances 1, 5, 9 | 13, 17 (the corner is at 10)
	H.eq(#marks, 5)
	H.near(marks[1].x, 1)
	H.near(marks[1].dx, 1)
	H.near(marks[1].dz, 0)
	H.near(marks[3].x, 9)
	H.near(marks[4].x, 10)
	H.near(marks[4].z, -3)
	H.near(marks[4].dx, 0)
	H.near(marks[4].dz, -1)
	H.near(marks[5].z, -7)
	for _, m in marks do
		H.near(math.sqrt(m.dx * m.dx + m.dz * m.dz), 1, 1e-9)
	end
	H.eq(#GuidePath.marks({ { x = 0, z = 0 } }, 4, 0), 0)
	-- sliding the offset moves every mark forward by the same amount
	local moved = GuidePath.marks(route, 4, 2.5)
	H.near(moved[1].x, 2.5)
end)

H.test("the way to the gumball machine only goes toward the back", function()
	local sp = Layout.spawn
	local route = GuidePath.toGumball(sp.x, sp.z)
	for i = 2, #route do
		H.truthy(route[i].z <= route[i - 1].z + 1e-6, "no backtracking")
	end
end)
