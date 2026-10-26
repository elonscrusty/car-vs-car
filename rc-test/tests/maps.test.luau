--!strict
-- The big race maps (Shared/Maps: Backyard, Kitchen): race-ready, the road fits, nothing solid
-- on a road, shortcuts and the secret still count the lap, about 45 s a lap.
local H = require("./harness")
local RaceMaps = require("../src/shared/RaceMaps")
local Maps = require("../src/shared/Maps")
local MapKit = require("../src/shared/Maps/MapKit")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Race maps")

-- things you drive under or through: their own legs / walls are checked by hand in Studio
local OVER = {
	dogHouse = true, -- the secret drives through it
	table = true, -- the shortcut drives under it
	chair = true, -- and through the pushed-in chair's legs
	picnicTable = true,
	stove = true, -- part of the counter (the tunnel is inside)
	sink = true,
	cabinetDoor = true,
}

local maps = RaceMaps.list()

test("both maps are in the vote list, with a name and an icon", function()
	eq(#maps, 2)
	local seen = {}
	for _, m in maps do
		truthy(not seen[m.id], "two maps with id " .. m.id)
		seen[m.id] = true
		local info = Maps.get(m.id)
		truthy(info ~= nil, "no vote card info for " .. m.id)
		truthy(info and info.icon ~= "", "no icon for " .. m.id)
	end
end)

local function roads(m: any): { { MapKit.Sample } }
	local out = { m.loop() }
	for i = 1, #m.def.paths do
		table.insert(out, m.path(i))
	end
	return out
end

local function closestApproach(ring: { any }, step: number): number
	local best = math.huge
	local n = #ring
	for i = 1, n do
		for j = i + 1, n do
			local gap = math.min(j - i, n - (j - i))
			if gap > step then
				best = math.min(
					best,
					math.sqrt((ring[i].x - ring[j].x) ^ 2 + (ring[i].z - ring[j].z) ^ 2)
				)
			end
		end
	end
	return best
end

-- one lap's worth of spots along a run of samples
local function drive(
	timer: any,
	now: number,
	ring: { MapKit.Sample },
	from: number,
	to: number
): (number, { string })
	local events = {}
	local n = #ring
	local i = from
	while true do
		local a, b = ring[i], ring[(i % n) + 1]
		for t = 0, 0.9, 0.1 do
			now += 0.01
			local e = LapTimer.update(timer, now, a.x + (b.x - a.x) * t, 0, a.z + (b.z - a.z) * t)
			if e then
				table.insert(events, e)
			end
		end
		if i == to then
			break
		end
		i = (i % n) + 1
	end
	return now, events
end

for _, m in maps do
	local def: MapKit.Def = m.def
	local loop = m.loop()

	test(m.id .. ": race-ready (track, gates, grid on the road)", function()
		local problems = RaceMaps.problems(m)
		eq(#problems, 0, table.concat(problems, "; "))
		truthy(#m.gates >= 6, "want 6+ lap checks for the race order")
	end)

	test(m.id .. ": a lap is about 45 s (2600 to 3400 long)", function()
		local len = MapKit.length(loop, true)
		truthy(len >= 2600 and len <= 3400, `lap is {len} long`)
	end)

	test(m.id .. ": the road doesn't touch itself", function()
		local gap = closestApproach(loop, 20)
		truthy(gap > def.road + 12, `two bits of road are {gap} apart`)
	end)

	test(m.id .. ": every road and its curbs stay on the floor, off the walls", function()
		for k, ring in roads(m) do
			local w = if k == 1 then def.road else def.paths[k - 1].width
			local edge = w / 2 + MapKit.CURB_WIDTH + 6
			for i, s in ring do
				for _, side in { -1, 1 } do
					local x, z = s.x - s.tz * edge * side, s.z + s.tx * edge * side
					truthy(
						x > def.minX and x < def.maxX and z > def.minZ and z < def.maxZ,
						`road {k} sample {i} pokes out at {x}, {z}`
					)
				end
			end
		end
	end)

	test(m.id .. ": one lap round the main road = start, every check, a lap", function()
		local timer = LapTimer.new(m.gates, m.mode)
		local line = m.lineSample()
		local n = #loop
		local function idx(k: number): number
			return (k - 1) % n + 1
		end
		local now, events = drive(timer, 0, loop, idx(line - 4), idx(line + 3))
		local _, more = drive(timer, now, loop, idx(line + 4), idx(line + 3))
		for _, e in more do
			table.insert(events, e)
		end
		eq(table.concat(events, ","), "start," .. string.rep("checkpoint,", #m.gates - 1) .. "lap")
	end)

	for p, path in def.paths do
		test(m.id .. ": the " .. path.kind .. " starts and ends on the main road", function()
			local ring = m.path(p)
			for _, s in { ring[1], ring[#ring] } do
				local d = MapKit.distTo(loop, s.x, s.z)
				truthy(d < def.road / 2, `{path.kind} end is {d} off the road`)
			end
		end)

		test(m.id .. ": a lap through the " .. path.kind .. " still counts", function()
			local ring = m.path(p)
			local _, enter = MapKit.nearest(loop, ring[1])
			local _, leave = MapKit.nearest(loop, ring[#ring])
			local timer = LapTimer.new(m.gates, m.mode)
			local line = m.lineSample()
			local n = #loop
			local events = {}
			local function add(list: { string })
				for _, e in list do
					table.insert(events, e)
				end
			end
			local now, e1 = drive(timer, 0, loop, (line - 4 - 1) % n + 1, enter)
			add(e1)
			-- along the side road, then on round the main road past the line
			local e2 = {}
			for i = 1, #ring - 1 do
				local a, b = ring[i], ring[i + 1]
				for t = 0, 0.9, 0.1 do
					now += 0.01
					local e =
						LapTimer.update(timer, now, a.x + (b.x - a.x) * t, 0, a.z + (b.z - a.z) * t)
					if e then
						table.insert(e2, e)
					end
				end
			end
			add(e2)
			local _, e3 = drive(timer, now, loop, leave, (line + 3 - 1) % n + 1)
			add(e3)
			truthy(table.find(events, "lap") ~= nil, `no lap: {table.concat(events, ",")}`)
		end)

		test(m.id .. ": the " .. path.kind .. " is shorter than the main road it skips", function()
			local ring = m.path(p)
			local _, enter = MapKit.nearest(loop, ring[1])
			local _, leave = MapKit.nearest(loop, ring[#ring])
			local skipped = {}
			local i = enter
			while i ~= leave do
				table.insert(skipped, loop[i])
				i = (i % #loop) + 1
			end
			table.insert(skipped, loop[leave])
			local short, long = MapKit.length(ring, false), MapKit.length(skipped, false)
			truthy(short < long * 0.95, `{path.kind} {short} vs main {long}`)
		end)
	end

	test(m.id .. ": nothing solid on any road", function()
		for _, e in def.props do
			if e.solid and not OVER[e.kind] and e.h > 2 then
				local hw, hd = (e.w or e.h * 0.6) / 2, (e.d or e.h * 0.6) / 2
				local c, s = math.cos(e.yaw), math.sin(e.yaw)
				for k, ring in roads(m) do
					local w = if k == 1 then def.road else def.paths[k - 1].width
					for _, q in
						{
							{ 0, 0 },
							{ -hw, -hd },
							{ hw, -hd },
							{ -hw, hd },
							{ hw, hd },
							{ 0, hd },
							{ 0, -hd },
							{ hw, 0 },
							{ -hw, 0 },
						}
					do
						local x, z = e.x + q[1] * c + q[2] * s, e.z - q[1] * s + q[2] * c
						local d = MapKit.distTo(ring, x, z)
						truthy(
							d > w / 2 + MapKit.CURB_WIDTH + 2,
							`{e.kind} at {e.x}, {e.z} is {d} from road {k}`
						)
					end
				end
			end
		end
	end)

	test(
		m.id .. ": pads and jumps sit on their road, jumps clear of the lap checks and the grid",
		function()
			for _, pad in def.pads do
				truthy(MapKit.PADS[pad.kind] ~= nil, "unknown pad " .. pad.kind)
				local d = MapKit.distTo(m.ring(pad.path), pad.at.x, pad.at.z)
				truthy(d < 20, `{pad.kind} pad is {d} off its road`)
			end
			local line = m.gates[1]
			for _, j in def.jumps do
				local d = MapKit.distTo(m.ring(j.path), j.at.x, j.at.z)
				truthy(d < 20, `jump is {d} off its road`)
				for _, g in m.gates do
					local gd = math.sqrt((g.x - j.at.x) ^ 2 + (g.z - j.at.z) ^ 2)
					truthy(
						gd > (j.len or MapKit.JUMP_LEN) / 2 + MapKit.GATE_DEPTH + 10,
						`jump at {j.at.x}, {j.at.z} is {gd} from a lap check`
					)
				end
				local ld = math.sqrt((line.x - j.at.x) ^ 2 + (line.z - j.at.z) ^ 2)
				truthy(ld > 200, "jump too near the start grid")
			end
		end
	)

	test(m.id .. ": props stand on the floor, inside the walls", function()
		for _, e in def.props do
			if e.kind ~= "tree" then -- the giant trees stand past the fence on purpose
				truthy(
					e.x > def.minX and e.x < def.maxX and e.z > def.minZ and e.z < def.maxZ,
					`{e.kind} at {e.x}, {e.z}`
				)
			end
		end
	end)

	test(m.id .. ": has a shortcut and a secret", function()
		local kinds = {}
		for _, p in def.paths do
			kinds[p.kind] = true
		end
		truthy(kinds.shortcut and kinds.secret, "want one shortcut and one secret")
		truthy(#def.jumps >= 1, "no jump")
		local boost = false
		for _, p in def.pads do
			boost = boost or p.kind == "boost"
		end
		truthy(boost, "no boost pad")
	end)

	test(m.id .. ": things lining the road stay off every road", function()
		local spots = MapKit.edgeSpots(m, 34, def.road / 2 + MapKit.CURB_WIDTH + 10, 5)
		truthy(#spots > 80, `only {#spots} spots by the road`)
		local toys = MapKit.edgeSpots(m, 130, MapKit.TOY_OFF, MapKit.TOY_CLEAR)
		truthy(#toys > 8, `only {#toys} toy spots`)
		for _, e in toys do
			for k, ring in roads(m) do
				local w = if k == 1 then def.road else def.paths[k - 1].width
				local d = MapKit.distTo(ring, e.x, e.z)
				-- a 44 x 22 brick reaches 25 from its middle
				truthy(
					d - 25 > w / 2 + MapKit.CURB_WIDTH,
					`toy at {e.x}, {e.z} is {d} from road {k}`
				)
			end
		end
	end)

	test(m.id .. ": every jump sits on a straight bit (you hit the ridge square)", function()
		for _, j in def.jumps do
			local ring = m.ring(j.path)
			local s0 = MapKit.nearest(ring, j.at)
			-- the run up behind the ridge, the landing slope ahead of it
			local back, ahead = (j.len or MapKit.JUMP_LEN) / 2 + 10, MapKit.JUMP_DOWN + 10
			for _, s in ring do
				local along = (s.x - s0.x) * s0.tx + (s.z - s0.z) * s0.tz
				local across = math.abs((s.x - s0.x) * -s0.tz + (s.z - s0.z) * s0.tx)
				if along >= -back and along <= ahead and across < def.road then
					local dot = s.tx * s0.tx + s.tz * s0.tz
					truthy(
						dot > 0.99,
						`road bends {math.deg(math.acos(math.min(dot, 1)))} deg on the jump at {j.at.x}, {j.at.z}`
					)
				end
			end
		end
	end)

	test(m.id .. ": a drive-through prop is turned to its side road", function()
		for _, e in def.props do
			if e.kind == "dogHouse" then
				local d = MapKit.distTo(m.path(2), e.x, e.z)
				truthy(d < 5, `dog house is {d} off the secret road`)
				local yaw = MapKit.pathYaw(m, e.x, e.z)
				local s = MapKit.nearest(m.path(2), { x = e.x, z = e.z })
				truthy(
					math.abs(math.sin(yaw) - s.tx) < 0.01 and math.abs(math.cos(yaw) - s.tz) < 0.01,
					"not turned to the road"
				)
			end
		end
	end)

	test(
		m.id .. ": jumps keep their shape through the squeeze, low enough for full speed",
		function()
			for _, j in def.jumps do
				truthy((j.h or MapKit.JUMP_H) <= 11, "jump too tall")
				truthy((j.len or MapKit.JUMP_LEN) >= 80, "jump too short (steep)")
			end
			local d = MapKit.scale({
				id = "x",
				label = "X",
				theme = "yard",
				road = 36,
				minX = -1,
				maxX = 1,
				minZ = -1,
				maxZ = 1,
				main = {},
				line = { x = 0, z = 0 },
				gates = {},
				paths = {},
				pads = {},
				props = {},
				lines = {},
				jumps = { { path = 0, at = { x = 10, z = 0 }, h = 5, len = 99 } },
				rcX = 0,
				rcZ = 0,
				rcAngle = 0,
			}, 0.5)
			eq(d.jumps[1].h, 5)
			eq(d.jumps[1].len, 99)
			eq(d.jumps[1].at.x, 5)
		end
	)

	test(m.id .. ": sits far from the lobby", function()
		local t = m.track()
		truthy(math.abs(t.rcX) >= 2000, "too close to the street")
	end)
end

-- Studio 10-26: a helper used above its `local function` line is nil there, and the whole map
-- failed to build (cars fell through the void). Lune can't run the builder, so read it.
test("the map builder never calls a helper before it is made", function()
	local fs = require("@lune/fs")
	local lines = string.split(fs.readFile("src/server/RaceMapBuilder.luau"), "\n")
	local made: { [string]: number } = {}
	for n, l in lines do
		local name = string.match(l, "^local function ([%w_]+)")
		if name and not made[name] then
			made[name] = n
		end
	end
	for name, at in made do
		for n = 1, at - 1 do
			local code = string.gsub(lines[n], "%-%-.*$", "")
			truthy(
				not string.find(code, "%f[%w_]" .. name .. "%s*%("),
				`{name} is called on line {n} but made on line {at}`
			)
		end
	end
end)

-- Car VS Car: the driver stand (racers stand on it, side by side, with their remotes)
for _, m in maps do
	test(m.id .. ": the driver stand is inside the walls, off every road, with 8 spots", function()
		local def = m.def
		local st = def.stand
		truthy(st ~= nil, "no stand")
		-- the stand and its stairs (they run off the left end)
		local x0, x1 = st.x - st.w / 2 - MapKit.STAND_STAIRS, st.x + st.w / 2
		local z0, z1 = st.z - st.d / 2, st.z + st.d / 2
		truthy(
			x0 > def.minX and x1 < def.maxX and z0 > def.minZ and z1 < def.maxZ,
			"stand is outside the walls"
		)
		local rings = { m.loop() }
		local widths = { def.road }
		for i, p in def.paths do
			table.insert(rings, m.path(i))
			table.insert(widths, p.width)
		end
		for r, ring in rings do
			local clear = widths[r] / 2 + MapKit.CURB_WIDTH + 4
			for _, s in ring do
				local dx = math.max(x0 - s.x, 0, s.x - x1)
				local dz = math.max(z0 - s.z, 0, s.z - z1)
				truthy(math.sqrt(dx * dx + dz * dz) > clear, `stand is on a road at {s.x}, {s.z}`)
			end
		end
		for _, p in def.props do
			if p.solid and p.h > 2 then
				local w, d = (p.w or 0) / 2, (p.d or 0) / 2
				local hit = p.x + w > x0 and p.x - w < x1 and p.z + d > z0 and p.z - d < z1
				truthy(not hit, `stand is on top of the {p.kind}`)
			end
		end
		local spots = m.standSpots()
		eq(#spots, 8)
		for _, sp in spots do
			truthy(sp.x > x0 and sp.x < x1 and sp.y == st.h, "spot is off the stand")
		end
	end)

	test(m.id .. ": the driver stand looks onto the front straight, close by", function()
		local st = m.def.stand
		local line = m.loop()[m.lineSample()]
		-- the track is in front (-z) of the stand, and the start isn't far along it
		truthy(line.z < st.z - st.d / 2, "the start line is behind the stand")
		truthy(
			math.abs(line.x - st.x) < 300 and st.z - line.z < 150,
			"the stand is far from the start"
		)
	end)
end

-- The stand camera (RaceStand: above and behind your spot) must see the road right in front of
-- the stand: an offline render showed the deck itself hiding the front straight (10-26).
local RaceStand = require("../src/shared/RaceStand")
for _, m in maps do
	test(m.id .. ": from the stand camera the deck never hides the road in front", function()
		local st = m.def.stand
		local big = 1 / 0.25 -- RC studs to big units
		local x0, x1 = st.x - st.w / 2, st.x + st.w / 2
		local z0, z1 = st.z - st.d / 2, st.z + st.d / 2
		local y0, y1 = st.h - 4, st.h
		local spots = m.standSpots()
		for _, k in { 1, 4, 8 } do
			local sp = spots[k]
			local c = {
				sp.x + RaceStand.CAM_SIDE * big,
				sp.y + RaceStand.CAM_UP * big,
				sp.z + RaceStand.CAM_BACK * big,
			}
			truthy(c[3] < m.def.maxZ - 8, `spot {k}: the camera is out past the fence`)
			for _, s in m.loop() do
				if math.abs(s.x - st.x) < 300 and math.abs(s.z - st.z) < 200 then
					-- does the line from the camera to the road cross the deck slab?
					local e = { s.x, 0.5, s.z }
					local lo, hi = 0, 1
					for i, r in { { x0, x1 }, { y0, y1 }, { z0, z1 } } do
						local d = e[i] - c[i]
						if math.abs(d) < 1e-9 then
							if c[i] < r[1] or c[i] > r[2] then
								lo = 2
							end
						else
							local t1, t2 = (r[1] - c[i]) / d, (r[2] - c[i]) / d
							lo = math.max(lo, math.min(t1, t2))
							hi = math.min(hi, math.max(t1, t2))
						end
					end
					truthy(
						lo > hi,
						`spot {k}: the deck hides the road at {math.floor(s.x)}, {math.floor(s.z)}`
					)
				end
			end
		end
	end)
end
