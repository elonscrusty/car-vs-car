--!strict
-- Lobby leaderboards (Leaderboards.luau): the boards, scores, who is better, how it reads, the rows.
local H = require("./harness")
local Lb = require("../src/shared/Leaderboards")
local RaceMaps = require("../src/shared/RaceMaps")
local SpawnLobby = require("../src/shared/SpawnLobby")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Leaderboards")

local maps = {}
for _, m in RaceMaps.list() do
	table.insert(maps, { id = m.id, label = m.label })
end
local boards = Lb.boards(maps)
local trophies, lap = boards[1], boards[2]

test("a trophies board, then a lap board for every map, in their own stores", function()
	eq(#boards, 1 + #maps)
	eq(trophies.id, "trophies")
	truthy(not trophies.low)
	local seen: { [string]: boolean } = {}
	for i, b in boards do
		truthy(not seen[b.store], "store " .. b.store .. " is shared")
		seen[b.store] = true
		if i > 1 then
			truthy(b.low and b.id == "lap_" .. maps[i - 1].id)
		end
	end
end)

-- a board's footprint on the ground: the line from one end to the other (lobby-local x, z)
local function ends(b: Lb.Board): (number, number, number, number)
	local fx, fz = Lb.facing(b)
	local rx, rz = -fz, fx -- the board's own x
	local h = Lb.BOARD_W / 2
	return b.x - rx * h, b.z - rz * h, b.x + rx * h, b.z + rz * h
end

-- how far a point is from a board's footprint
local function away(b: Lb.Board, px: number, pz: number): number
	local ax, az, bx, bz = ends(b)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((ax + t * dx - px) ^ 2 + (az + t * dz - pz) ^ 2)
end

test("every board has a spot, clear of each other, the walk, the bushes and the lamps", function()
	for i, b in boards do
		truthy(Lb.placed(b, i), b.id .. " has no slot")
		local ax, az, bx, bz = ends(b)
		for _, e in { { ax, az }, { bx, bz } } do
			truthy(
				math.abs(e[1]) >= SpawnLobby.GAP or e[2] < SpawnLobby.PAD_Z,
				b.id .. " blocks the walk to the street"
			)
			truthy(
				e[1] >= SpawnLobby.BOX.minX + 1
					and e[1] <= SpawnLobby.BOX.maxX - 1
					and e[2] >= SpawnLobby.BOX.minZ + 1
					and e[2] <= SpawnLobby.BOX.maxZ,
				b.id .. " in the lobby"
			)
			for j = 1, i - 1 do
				truthy(away(boards[j], e[1], e[2]) >= 0.5, b.id .. " touches " .. boards[j].id)
			end
		end
		for _, bush in SpawnLobby.BUSHES do
			truthy(away(b, bush.x, bush.z) >= 2.5, b.id .. " on a bush")
		end
		for _, lamp in SpawnLobby.LAMPS do
			truthy(away(b, lamp.x, lamp.z) >= 1, b.id .. " on a lamp")
		end
		-- not in a shop, and back from where you walk up to one (the KITCHEN board at the crate
		-- shop's front corner filled the view there, Studio u14)
		for _, shop in SpawnLobby.BUILDINGS do
			truthy(
				math.abs(b.x - shop.x) > 8 + 1 or math.abs(b.z - shop.z) > 12 + Lb.BOARD_W / 2,
				b.id .. " in a shop"
			)
			local door = shop.x - 15 * math.sign(shop.x)
			truthy(away(b, door, shop.z) >= 20, b.id .. " by the " .. shop.kind .. " shop's door")
		end
		-- a front board stands in front of the play pads (z 23) and behind the arch (z 33.5)
		if b.yaw == 0 then
			truthy(
				b.z > SpawnLobby.PAD_Z + 3 and b.z < SpawnLobby.ARCH_Z - 2,
				b.id .. " at the front"
			)
		end
		-- its words face into the lobby
		local fx, fz = Lb.facing(b)
		truthy(
			fx * (0 - b.x) + fz * (SpawnLobby.SPAWN.z - b.z) > 0,
			b.id .. " faces the spawn side"
		)
	end
	truthy(
		Lb.BOARD_Y - Lb.BOARD_H / 2 >= 1.5 and Lb.BOARD_Y + Lb.BOARD_H / 2 <= SpawnLobby.BOX.maxY
	)
	local x, y, z = Lb.world(lap, 100)
	eq(x, lap.x)
	eq(y, Lb.BOARD_Y)
	eq(z, 100 + lap.z)
	eq(trophies.z, Lb.BOARD_Z)
	eq(select(2, Lb.facing(trophies)), -1)
end)

test("a lap is saved in whole milliseconds; a glitch lap or junk is no score", function()
	eq(Lb.score(lap, 12.3456), 12346)
	eq(Lb.score(lap, 0.5), nil)
	eq(Lb.score(lap, 9999), nil)
	eq(Lb.score(lap, "fast"), nil)
	eq(Lb.score(lap, 0 / 0), nil)
	eq(Lb.score(trophies, 42.9), 42)
	eq(Lb.score(trophies, 0), nil)
	eq(Lb.score(trophies, -5), nil)
	eq(Lb.score(trophies, 1e12), nil)
end)

test("better: more trophies, quicker lap; anything beats no score", function()
	truthy(Lb.better(trophies, 100, 101))
	truthy(not Lb.better(trophies, 100, 100))
	truthy(not Lb.better(trophies, 100, 99))
	truthy(Lb.better(lap, 12000, 11999))
	truthy(not Lb.better(lap, 12000, 12000))
	truthy(not Lb.better(lap, 12000, 13000))
	truthy(Lb.better(lap, nil, 99999))
	truthy(Lb.better(trophies, nil, 1))
end)

test("scores read plainly", function()
	eq(Lb.format(lap, 12346), "12.346")
	eq(Lb.format(lap, 5007), "5.007")
	eq(Lb.format(lap, 62345), "1:02.345")
	eq(Lb.format(trophies, 42), "42")
end)

local function names(rows: { Lb.Row }): string
	local out = {}
	for _, r in rows do
		table.insert(out, r.name .. ":" .. r.score)
	end
	return table.concat(out, " ")
end

test("merge: a new score goes in its place and the board stays cut", function()
	local rows: { Lb.Row } = {
		{ uid = 1, name = "A", score = 300 },
		{ uid = 2, name = "B", score = 200 },
		{ uid = 3, name = "C", score = 100 },
	}
	eq(names(Lb.merge(trophies, rows, 4, "D", 250, 3)), "A:300 D:250 B:200")
	eq(names(Lb.merge(trophies, rows, 4, "D", 50, 3)), "A:300 B:200 C:100")
	eq(names(Lb.merge(trophies, rows, 3, "C", 400, 3)), "C:400 A:300 B:200")
	-- a worse score from someone already there changes nothing
	eq(names(Lb.merge(trophies, rows, 2, "B", 150, 3)), "A:300 B:200 C:100")
	-- a tie keeps the earlier row first
	eq(names(Lb.merge(trophies, rows, 4, "D", 300, 4)), "A:300 D:300 B:200 C:100")
	eq(#rows, 3, "merge must not change its input")
end)

test("merge: laps sort quickest first", function()
	local rows: { Lb.Row } =
		{ { uid = 1, name = "A", score = 12000 }, { uid = 2, name = "B", score = 15000 } }
	eq(names(Lb.merge(lap, rows, 2, "B", 11000, 5)), "B:11000 A:12000")
	eq(names(Lb.merge(lap, rows, 1, "A", 13000, 5)), "A:12000 B:15000")
end)

test("writes wait their gap", function()
	truthy(Lb.due(nil, 5, 60))
	truthy(not Lb.due(10, 50, 60))
	truthy(Lb.due(10, 70, 60))
end)

test("the league badge: its league's words and colour; junk reads as Bronze", function()
	local League = require("../src/shared/League")
	for i, name in League.NAMES do
		local word, c = Lb.badge(i)
		eq(word, string.upper(name))
		eq(c, League.COLORS[i])
	end
	eq((Lb.badge(nil)), "BRONZE")
	eq((Lb.badge("gold")), "BRONZE")
	eq((Lb.badge(99)), "DIAMOND")
	eq((Lb.badge(0 / 0)), "BRONZE")
end)
