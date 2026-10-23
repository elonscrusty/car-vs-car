--!strict
-- Tests for the rock plot only (Plots/Rock.luau). The shared rules are in plots.test.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local LapTimer = require("../src/shared/LapTimer")
local Plot = require("../src/shared/Plots/Rock")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot: rock")

local path = Plot.path()

-- Slope (rise over run) of each trail piece, and how much the trail turns there (radians).
local function pieces(): ({ number }, { number })
	local slope, turn = {}, {}
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		slope[i] = (Plot.height(Plot.uOf(i + 1)) - Plot.height(Plot.uOf(i))) / len
		turn[i] = math.abs(math.atan2(a.tx * b.tz - a.tz * b.tx, a.tx * b.tx + a.tz * b.tz))
	end
	return slope, turn
end

test("rock plot loads, slow one-way crawl", function()
	eq(Plot.id, "rock")
	eq(Plot.mode, "oneway")
	eq(#path, (Plot.LAST_U - 1) * 10 + 1)
end)

test("the whole trail stays inside the track area", function()
	for i, s in path do
		for _, side in { -1, 1 } do
			local x, z = s.x - s.tz * Plot.HALF_WIDTH * side, s.z + s.tx * Plot.HALF_WIDTH * side
			truthy(Kit.inArea(x, z), `trail piece {i} pokes out at {x}, {z}`)
		end
	end
end)

test("the rows don't touch each other", function()
	local best = math.huge
	for i = 1, #path do
		for j = i + 25, #path do
			local dx, dz = path[i].x - path[j].x, path[i].z - path[j].z
			best = math.min(best, math.sqrt(dx * dx + dz * dz))
		end
	end
	truthy(best > Plot.ROAD + 6, `rows only {best} apart`)
end)

test("it only climbs, gently on bends, steep only on the straight rock face", function()
	local slope, turn = pieces()
	local steepest = 0
	for i, s in slope do
		local onFace = Plot.uOf(i) >= 23 and Plot.uOf(i + 1) <= 24
		truthy(s >= -0.05, `piece {i} goes downhill ({s})`)
		truthy(s <= (if onFace then 0.42 else 0.32), `piece {i} is too steep to crawl ({s})`)
		if turn[i] > 0.01 then
			truthy(s <= 0.2, `piece {i} climbs ({s}) round a bend ({turn[i]})`)
		end
		steepest = math.max(steepest, s)
	end
	truthy(steepest > 0.35, "the rock face should be steep enough to show off")
	truthy(Plot.height(Plot.LAST_U) >= 95, "the flag should be up high")
end)

test("the ground sits above the plot floor everywhere (no flicker with it)", function()
	local g, _, _, nx, nz = Plot.grid()
	for i = 1, nx do
		for j = 1, nz do
			truthy(g[i][j] >= 1, `ground corner {i},{j} is at {g[i][j]}`)
		end
	end
end)

test("the ground reaches the outer walls and the front wall (no trench to fall into)", function()
	local _, x0, z0, nx, nz, dx, dz = Plot.grid()
	truthy(x0 <= -Kit.WIDTH / 2 + 2 and x0 + (nx - 1) * dx >= Kit.WIDTH / 2 - 2, "sides")
	truthy(z0 <= -Kit.DEPTH / 2 + 2, "back")
	truthy(z0 + (nz - 1) * dz >= Kit.FRONT_Z - 2, "front")
	truthy(dx <= Plot.CELL and dz <= Plot.CELL, "cells")
	truthy(Plot.RIM >= 8, "the rim round the back and sides is too low to stop the car")
end)

test("each row leans back into the hill, so a car that wanders rolls away from the edge", function()
	for _, u in { 3, 8.5, 13.5, 18.5, 23.5 } do
		local _, fz = Plot.spot(u, 0)
		local _, _, _, tx = Plot.at(u)
		-- the side of the trail nearer the stand (+z) is the front edge
		local frontSide = if tx > 0 then 1 else -1
		local ax, az = Plot.spot(u, frontSide)
		local bx, bz = Plot.spot(u, -frontSide)
		truthy(az > fz and bz < fz, `row at {u}: front side is not toward the stand`)
		local drop = Plot.groundAt(ax, az) - Plot.groundAt(bx, bz)
		truthy(drop > 2, `row at {u} doesn't lean back into the hill ({drop})`)
		truthy(drop < 4, `row at {u} leans too much ({drop})`)
	end
end)

test("the domes sit on the hill side of the trail, away from the front edge", function()
	for _, d in Plot.domes do
		local _, cz = Plot.at(d.u)
		truthy(d.z < cz, `dome at {d.u} is on the front-edge side`)
	end
end)

test("each row sits higher than the one in front of it", function()
	-- row middles (u) front to back: mounds, creek, low shelf, high shelf, slab
	local rows = { 3, 8.5, 13.5, 18.5, 23 }
	for k = 2, #rows do
		truthy(Plot.height(rows[k]) > Plot.height(rows[k - 1]), `row {k} is not above row {k - 1}`)
	end
end)

test("from the stand you can see the car almost all the way", function()
	local seen = 0
	for i, s in path do
		if Plot.canSee(s.x, s.z, Plot.height(Plot.uOf(i))) then
			seen += 1
		end
	end
	local share = seen / #path
	truthy(share >= 0.95, `only {math.floor(share * 100)}% of the trail can be seen`)
end)

test("rocks, logs and ledges sit on the trail and can be crawled over", function()
	local count: { [string]: number } = {}
	local left, right, big = 0, 0, 0
	for _, f in Plot.features do
		count[f.kind] = (count[f.kind] or 0) + 1
		truthy(f.u > Plot.START_U and f.u < Plot.FINISH_U, `{f.kind} at {f.u} is off the course`)
		truthy(math.abs(f.side) <= 0.8, `{f.kind} at {f.u} is off the trail`)
		truthy(f.lift <= Plot.MAX_LIFT, `{f.kind} at {f.u} is too tall to crawl`)
		if f.kind == "rock" then
			if f.r >= 6 then
				big += 1
			elseif f.side < 0 then
				left += 1
			elseif f.side > 0 then
				right += 1
			end
		end
	end
	truthy((count.rock or 0) >= 25, "too few rocks")
	truthy((count.log or 0) >= 2, "logs")
	truthy((count.ledge or 0) >= 2, "ledges")
	truthy(left >= 8 and right >= 8, "crawl rocks should sit on both sides")
	truthy(big >= 1, "a big boulder near the stand")
end)

test("the big boulders are in the row nearest the stand", function()
	for _, f in Plot.features do
		if f.kind == "rock" and f.r >= 6 then
			local _, z = Plot.spot(f.u, f.side)
			truthy(Kit.STAND.z - z < 80, `big boulder at {f.u} is far from the stand`)
		end
	end
end)

test(
	"big rock domes: taller than a wheel, round enough to crawl over, nothing buried in them",
	function()
		truthy(#Plot.domes >= 5, "too few domes")
		for _, d in Plot.domes do
			truthy(d.h >= 4, `dome at {d.u} is small`)
			-- steepest side of the dome is about 0.86 * h / r
			truthy(0.86 * d.h / d.r <= 0.42, `dome at {d.u} is too steep`)
			truthy(math.abs(d.side) <= 0.5, `dome at {d.u} is off the trail`)
			for _, t in Plot.TURNS do
				truthy(math.abs(d.u - t) > 0.6, `dome at {d.u} sits in a turn`)
			end
			for _, f in Plot.features do
				local x, z = Plot.spot(f.u, f.side)
				local q = ((x - d.x) ^ 2 + (z - d.z) ^ 2) / d.r ^ 2
				truthy(d.h * math.exp(-q) < 0.3, `{f.kind} at {f.u} is buried in the dome at {d.u}`)
			end
		end
	end
)

test("the creek dips the trail, and the log bridge over it can be crawled onto", function()
	local c = Plot.CREEK
	local x, z, h = Plot.at(c.u)
	truthy(h - Plot.groundAt(x, z) >= 4, "the creek is too shallow")
	truthy(c.lift <= Plot.MAX_LIFT, "the bridge is too tall to climb on")
	truthy(c.depth * math.pi / (2 * c.half) <= 0.5, "the creek banks are too steep")
	for _, f in Plot.features do
		truthy(math.abs(f.u - c.u) * 60 > c.half + f.r, `{f.kind} at {f.u} is in the creek`)
	end
end)

test("rock steps: small steps up, on a straight, nothing else on them", function()
	local st = Plot.STEPS
	local blocks = Plot.stepBlocks()
	eq(#blocks, st.n)
	for _, b in blocks do
		local rise = b.top - Plot.height(b.u0)
		truthy(rise >= 1 and rise <= Plot.MAX_LIFT, `step at {b.u0} rises {rise}`)
	end
	local _, _, _, ax, az = Plot.at(st.from)
	local _, _, _, bx, bz = Plot.at(st.to)
	truthy(ax * bx + az * bz > 0.98, "the steps should be on a straight")
	for _, f in Plot.features do
		truthy(f.u < st.from - 0.2 or f.u > st.to + 0.2, `{f.kind} at {f.u} sits on the steps`)
	end
	for _, d in Plot.domes do
		truthy(d.u < st.from - 0.4 or d.u > st.to + 0.4, `dome at {d.u} sits on the steps`)
	end
end)

test("the steep slab is clear of rocks", function()
	for _, f in Plot.features do
		truthy(f.u < 22, `{f.kind} at {f.u} sits on the slab`)
	end
end)

test("gates sit on the trail in order, a run goes start -> every turn -> finish", function()
	eq(#Plot.gates, 2 + #Plot.TURNS)
	local timer = LapTimer.new(Plot.gates, Plot.mode)
	local s = Plot.spawn
	eq(LapTimer.update(timer, 0, s.x, s.y, s.z), nil)
	local results = {}
	for i, g in Plot.gates do
		results[i] = LapTimer.update(timer, i, g.x, g.y + 2.5, g.z)
	end
	eq(results[1], "start")
	eq(results[#results], "finish")
	for i = 2, #Plot.gates do
		truthy(Plot.gates[i].y >= Plot.gates[i - 1].y, "gates should climb")
	end
end)
