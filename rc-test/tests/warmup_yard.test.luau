--!strict
-- Car VS Car Smash's warm-up yard (WarmupYard.luau): everything sits inside its walls and apart,
-- it's far from the lobby and the arena, it drives like a map, and the clock words read right.
local H = require("./harness")
local Y = require("../src/shared/WarmupYard")
local TrackData = require("../src/shared/TrackData")
local LobbyLayout = require("../src/shared/LobbyLayout")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Warm-up yard")

local function within(p: any, margin: number): boolean
	return math.abs(p.x) <= Y.W / 2 - margin and math.abs(p.z) <= Y.D / 2 - margin
end

test("yard: spawns, boxes and dummies all inside the walls, and apart", function()
	local all = {}
	eq(#Y.spawns, 8)
	for _, s in Y.spawns do
		truthy(within(s, 10), "spawn by a wall")
		table.insert(all, s)
	end
	for _, b in Y.boxSpots do
		truthy(within(b, 12), "box by a wall")
		table.insert(all, b)
	end
	for _, d in Y.DUMMIES do
		-- a circling dummy's loop (CIRCLE_R) stays inside the walls
		truthy(within(d.at, if d.mode == "circle" then Y.CIRCLE_R + 6 else 12), "dummy by a wall")
		truthy(d.mode == "still" or d.mode == "circle", d.mode)
		table.insert(all, d.at)
	end
	for _, d in Y.DUMMIES do
		if d.mode == "circle" then
			for _, b in Y.boxSpots do
				local r = math.sqrt((b.x - d.at.x) ^ 2 + (b.z - d.at.z) ^ 2)
				truthy(math.abs(r - Y.CIRCLE_R) >= 6, "a box on the dummy's loop")
			end
			-- nor a spawn or a still dummy (the circling one would drive through it; the floor
			-- paint marks the loop)
			for _, p in Y.spawns do
				local r = math.sqrt((p.x - d.at.x) ^ 2 + (p.z - d.at.z) ^ 2)
				truthy(math.abs(r - Y.CIRCLE_R) >= 6, "a spawn on the dummy's loop")
			end
			for _, o in Y.DUMMIES do
				if o.mode == "still" then
					local r = math.sqrt((o.at.x - d.at.x) ^ 2 + (o.at.z - d.at.z) ^ 2)
					truthy(math.abs(r - Y.CIRCLE_R) >= 6, "a still dummy on the dummy's loop")
				end
			end
		end
	end
	for i, a in all do
		for j = i + 1, #all do
			local b = all[j]
			local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			truthy(gap >= 14, `spots {i} and {j} only {gap} apart`)
		end
	end
end)

test("yard: its own drive slot after the arena, far from the lobby and the arena", function()
	local i = LobbyLayout.yardIndex()
	eq(LobbyLayout.mapAt(i), Y)
	local t = LobbyLayout.track(i)
	eq(t.map, "yard")
	eq(t.mode, "arena") -- no lights, no laps
	local w = Y.world(Y.spawns[1])
	truthy(w.z <= -1500, "too close to the lobby")
	truthy(math.abs(w.z - -3000) > 200, "too close to the arena")
	truthy(Y.inside(w))
	truthy(not Y.inside({ x = 0, y = 0, z = 1000 }))
	local x, _, z = TrackData.toWorld(Y.track(), true, Y.W, 0, 0)
	truthy(not Y.inside({ x = x, y = 0, z = z }))
end)

test("yard: parts are low-poly (SmoothPlastic or Neon only) and the walls close it", function()
	local walls = 0
	for _, p in Y.parts() do
		truthy(p.material == "SmoothPlastic" or p.material == "Neon", p.material)
		if p.group == "Walls" and (p.name == "Side" or p.name == "End") then
			walls += 1
		end
	end
	eq(walls, 4)
end)

test("yard: the clock reads NEXT MATCH IN m:ss, GET READY! at 0, WARM UP! with no round", function()
	eq(Y.clock(102), "NEXT MATCH IN 1:42")
	eq(Y.clock(101.2), "NEXT MATCH IN 1:42")
	eq(Y.clock(9), "NEXT MATCH IN 0:09")
	eq(Y.clock(0.2), "GET READY!")
	eq(Y.clock(-3), "GET READY!")
	eq(Y.clock(nil), "WARM UP!")
	eq(Y.clock(0 / 0), "WARM UP!")
end)

test("yard: who goes there (queued, not playing, the round a while off)", function()
	local S = Y
	local now = 1000
	-- a round is going: wait in the yard
	truthy(S.wants(true, false, now + 100, nil, now))
	-- nothing going, the next round soon: wait by the portal
	truthy(not S.wants(true, false, nil, now + 5, now))
	truthy(S.wants(true, false, nil, now + S.MIN_WAIT + 1, now))
	-- not queued, or already playing
	truthy(not S.wants(false, false, now + 100, nil, now))
	truthy(not S.wants(true, true, now + 100, nil, now))
	-- a round that's over (ROUND OVER break) with the next one far off
	truthy(S.wants(true, false, now - 3, now + 30, now))
end)

test("yard: dressed like the arena, and nothing solid on a spawn, box or dummy spot", function()
	local names: { [string]: number } = {}
	for _, p in Y.parts() do
		names[p.name] = (names[p.name] or 0) + 1
	end
	for _, n in { "Cover", "CoverEnd", "Crate", "Barrel", "GrassPatch", "Stripe" } do
		truthy((names[n] or 0) > 0, "no " .. n)
	end
	local spots = {}
	for _, s in Y.spawns do
		table.insert(spots, s)
	end
	for _, b in Y.boxSpots do
		table.insert(spots, b)
	end
	for _, d in Y.DUMMIES do
		if d.mode == "still" then -- (a circling one is on its loop, checked below)
			table.insert(spots, d.at)
		end
	end
	for _, p in Y.parts() do
		if p.collide and p.group ~= "Ground" and p.group ~= "Walls" and p.group ~= "Board" then
			-- the piece's widest half-extent on the floor, turned any way
			local half = math.sqrt(p.size.x ^ 2 + p.size.z ^ 2) / 2
			if p.shape == "Cylinder" and p.rot.z == 90 then
				half = math.max(p.size.y, p.size.z) / 2 -- an upright stick
			end
			for _, s in spots do
				local gap = math.sqrt((p.pos.x - s.x) ^ 2 + (p.pos.z - s.z) ^ 2) - half
				truthy(gap >= 8, `{p.name} at {p.pos.x},{p.pos.z} is {gap} from a spot`)
			end
			-- and off a circling dummy's loop
			for _, d in Y.DUMMIES do
				if d.mode == "circle" then
					local r = math.sqrt((p.pos.x - d.at.x) ^ 2 + (p.pos.z - d.at.z) ^ 2)
					truthy(
						math.abs(r - Y.CIRCLE_R) >= half + 4,
						`{p.name} at {p.pos.x},{p.pos.z} is on the dummy's loop`
					)
				end
			end
		end
	end
end)

test("yard: sits in a valley (round hills on every side, the lake open), looks only", function()
	local names: { [string]: number } = {}
	for _, p in Y.parts() do
		if p.group == "World" then
			names[p.name] = (names[p.name] or 0) + 1
			eq(p.collide, false)
		end
	end
	for _, n in { "FarGrass", "Lake", "Shore" } do
		truthy((names[n] or 0) > 0, "no " .. n)
	end
	local domes, trees = Y.valley()
	truthy(#domes >= 30, "too few hills")
	truthy(#trees >= 6, "too few trees on the hills")
	local hx, hz = Y.W / 2 + 90, Y.D / 2 + 90 -- the yard's own grass
	local sides = { n = 0, s = 0, e = 0, w = 0 }
	for _, d in domes do
		-- no hill on the yard's grass, and none in the lake (z past the grass, |x| < 280)
		local inGrass = math.abs(d.x) - d.w / 2 < hx and math.abs(d.z) - d.d / 2 < hz
		truthy(not inGrass, `hill at {d.x},{d.z} is on the yard's grass`)
		truthy(
			not (d.z - d.d / 2 < hz + 220 and d.z + d.d / 2 > hz and math.abs(d.x) < 200),
			`hill at {d.x},{d.z} is in the lake`
		)
		if d.x > hx then
			sides.e += 1
		elseif d.x < -hx then
			sides.w += 1
		elseif d.z > hz then
			sides.n += 1
		else
			sides.s += 1
		end
	end
	for k, c in sides do
		truthy(c > 0, `no hills on the {k} side`)
	end
	for _, t in trees do
		truthy(
			math.abs(t.x) > Y.W / 2 + 20 or math.abs(t.z) > Y.D / 2 + 20,
			"a hill tree in the yard"
		)
	end
end)
