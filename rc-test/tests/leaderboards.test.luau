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
local coins, lap = boards[1], boards[2]

test("a garage board, then a lap board for every map, in their own stores", function()
	eq(#boards, 1 + #maps)
	eq(coins.id, "coins")
	truthy(not coins.low)
	local seen: { [string]: boolean } = {}
	for i, b in boards do
		truthy(not seen[b.store], "store " .. b.store .. " is shared")
		seen[b.store] = true
		if i > 1 then
			truthy(b.low and b.id == "lap_" .. maps[i - 1].id)
		end
	end
end)

test("the boards sit in a row, centred, clear of each other, behind the stands", function()
	for i, b in boards do
		if i > 1 then
			truthy(b.x - boards[i - 1].x >= Lb.BOARD_W + 1, "boards touch")
		end
	end
	eq(boards[1].x + boards[#boards].x, 0)
	local edge = math.max(math.abs(boards[1].x), math.abs(boards[#boards].x)) + Lb.BOARD_W / 2
	truthy(edge <= SpawnLobby.BOX.maxX - 20, "board runs into the side shops")
	-- behind the back kerb (z -35.5), inside the lobby box
	truthy(Lb.BOARD_Z < -35.5 and Lb.BOARD_Z - 0.5 >= SpawnLobby.BOX.minZ)
	-- above the dream cars on the stands, under the box top
	truthy(Lb.BOARD_Y - Lb.BOARD_H / 2 > 4 and Lb.BOARD_Y + Lb.BOARD_H / 2 <= SpawnLobby.BOX.maxY)
	local x, y, z = Lb.world(lap, 100)
	eq(x, lap.x)
	eq(y, Lb.BOARD_Y)
	eq(z, 100 + Lb.BOARD_Z)
end)

test("a lap is saved in whole milliseconds; a glitch lap or junk is no score", function()
	eq(Lb.score(lap, 12.3456), 12346)
	eq(Lb.score(lap, 0.5), nil)
	eq(Lb.score(lap, 9999), nil)
	eq(Lb.score(lap, "fast"), nil)
	eq(Lb.score(lap, 0 / 0), nil)
	eq(Lb.score(coins, 420.9), 420)
	eq(Lb.score(coins, 0), nil)
	eq(Lb.score(coins, -5), nil)
	eq(Lb.score(coins, 1e12), nil)
end)

test("better: bigger garage, quicker lap; anything beats no score", function()
	truthy(Lb.better(coins, 100, 101))
	truthy(not Lb.better(coins, 100, 100))
	truthy(not Lb.better(coins, 100, 99))
	truthy(Lb.better(lap, 12000, 11999))
	truthy(not Lb.better(lap, 12000, 12000))
	truthy(not Lb.better(lap, 12000, 13000))
	truthy(Lb.better(lap, nil, 99999))
	truthy(Lb.better(coins, nil, 1))
end)

test("scores read plainly", function()
	eq(Lb.format(lap, 12346), "12.346")
	eq(Lb.format(lap, 5007), "5.007")
	eq(Lb.format(lap, 62345), "1:02.345")
	eq(Lb.format(coins, 420), "420/min")
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
	eq(names(Lb.merge(coins, rows, 4, "D", 250, 3)), "A:300 D:250 B:200")
	eq(names(Lb.merge(coins, rows, 4, "D", 50, 3)), "A:300 B:200 C:100")
	eq(names(Lb.merge(coins, rows, 3, "C", 400, 3)), "C:400 A:300 B:200")
	-- a worse score from someone already there changes nothing
	eq(names(Lb.merge(coins, rows, 2, "B", 150, 3)), "A:300 B:200 C:100")
	-- a tie keeps the earlier row first
	eq(names(Lb.merge(coins, rows, 4, "D", 300, 4)), "A:300 D:300 B:200 C:100")
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
