--!strict
-- The plot as your garage (PlotGarage.luau): the loop the parked cars drive, the coin pile,
-- the LEVEL UP sign and the level looks all fit inside the plot, behind the front wall.
local H = require("./harness")
local G = require("../src/shared/PlotGarage")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot garage")

test("spots on the loop: 3 at the start, one more a level, 8 at the top", function()
	eq(G.slots(0), 3)
	eq(G.slots(1), 4)
	eq(G.slots(5), 8)
	eq(G.slots(9), 8)
end)

test("a car goes round the loop smoothly, facing the way it drives", function()
	local n = 400
	local step = G.length() / n
	local px, pz = G.at(0)
	for i = 1, n do
		local x, z, yaw = G.at(i / n)
		local dx, dz = x - px, z - pz
		local d = math.sqrt(dx * dx + dz * dz)
		truthy(math.abs(d - step) < 0.05, "no jumps at " .. i)
		-- facing: Roblox yaw 0 looks toward -z
		local fx, fz = -math.sin(yaw), -math.cos(yaw)
		truthy(fx * dx + fz * dz > 0.9 * d, "faces forward at " .. i)
		px, pz = x, z
	end
end)

local function box(p: any): (number, number, number, number, number)
	local sx, sz = p.size.x, p.size.z
	if p.shape == "Cylinder" then
		sx, sz = p.size.y, p.size.z
	end
	local yaw = math.rad(p.rot.y)
	local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	local wx, wz = sx * c + sz * s, sx * s + sz * c
	return p.pos.x - wx / 2,
		p.pos.x + wx / 2,
		p.pos.z - wz / 2,
		p.pos.z + wz / 2,
		p.pos.y + p.size.y / 2
end

test("the yard fits the plot behind the front wall at every level", function()
	for level = 0, G.MAX_LEVEL do
		for _, p in G.pieces(level) do
			local x0, x1, z0, z1 = box(p)
			local name = level .. " " .. p.group .. "/" .. p.name
			truthy(x0 >= -39.4 and x1 <= 39.4, name .. " inside the side walls")
			truthy(z0 >= -54.4 and z1 <= 36.6, name .. " between the back wall and the front wall")
		end
		for _, m in G.meshes(level) do
			truthy(math.abs(m.at.x) + math.max(m.fit.x, m.fit.z) / 2 <= 39.4, m.model .. " in (x)")
			truthy(
				m.at.z - m.fit.z / 2 >= -54.4 and m.at.z + m.fit.z / 2 <= 36.6,
				m.model .. " in (z)"
			)
		end
	end
end)

test("you can walk anywhere in the yard: only the sign posts are solid", function()
	for _, p in G.pieces(G.MAX_LEVEL) do
		if p.collide then
			eq(p.name, "SignPost")
		end
	end
end)

test("the pile and the sign sit off the road", function()
	local L = G.LOOP
	local frontEdge = L.z + L.halfL + L.road / 2 + 0.8
	truthy(G.PILE.z - G.PILE.r - 1.2 > frontEdge, "pile clear of the loop")
	truthy(G.SIGN.z > frontEdge, "sign clear of the loop")
end)

test("the coin pile grows with the coins, then stops", function()
	eq(G.pileCoins(0), 0)
	truthy(G.pileCoins(1) > 0, "one coin shows")
	local last = 0
	for _, c in { 1, 5, 20, 100, 500, 2000, 10000 } do
		local n = G.pileCoins(c)
		truthy(n >= last, "never shrinks as coins grow")
		last = n
	end
	eq(G.pileCoins(1e12), G.PILE_MAX)
end)

test("more looks each level", function()
	local last = 0
	for level = 0, G.MAX_LEVEL do
		local n = #G.pieces(level) + #G.meshes(level)
		truthy(n > last, "level " .. level .. " adds something")
		last = n
	end
end)

test("gate sign: whose garage it is", function()
	eq(G.signText("Mia"), "MIA'S GARAGE")
	eq(G.signText("James"), "JAMES' GARAGE")
	eq(G.signText(nil), "GARAGE")
	eq(G.signText(""), "GARAGE")
end)

test("level sign says what you get, then MAX", function()
	eq(select(1, G.levelWords(0, 500)), "LEVEL UP: +1 CAR")
	eq(select(2, G.levelWords(0, 500)), "500 COINS")
	eq(select(2, G.levelWords(5, nil)), "MAX")
end)

test("a car's +N matches its coins a minute", function()
	eq(G.popCoins(2), 1)
	eq(G.popCoins(6), 3)
	eq(G.popCoins(15), 8)
	eq(G.popCoins(40), 20)
	eq(G.popCoins(0), 1)
end)

test("income board stands in the front left corner, clear of the gate and the road wall", function()
	for _, p in G.boardPieces() do
		truthy(
			p.pos.x - p.size.x / 2 >= -39.4 and p.pos.x + p.size.x / 2 <= -1,
			p.name .. " left of the gate"
		)
		truthy(
			p.pos.z - p.size.z / 2 >= 37.5 and p.pos.z + p.size.z / 2 <= 54.4,
			p.name .. " in front"
		)
	end
end)

test("income board words", function()
	eq(select(1, G.incomeWords(12, 3, false)), "+12 COINS / MIN")
	eq(select(2, G.incomeWords(12, 3, false)), "FROM 3 CARS")
	eq(select(2, G.incomeWords(2, 1, false)), "FROM 1 CAR")
	eq(select(2, G.incomeWords(24, 3, true)), "2X BOOST!")
end)

test("plot cars can move at a set rate: every frame at 60, every other at 30", function()
	local acc, due = G.stepDue(0, 1 / 60, 60)
	truthy(due, "60 moves every frame")
	local moves = 0
	acc = 0
	for _ = 1, 60 do
		acc, due = G.stepDue(acc, 1 / 60, 30)
		if due then
			moves += 1
		end
	end
	truthy(moves >= 29 and moves <= 31, `30 Hz moved {moves} times in a second`)
end)
