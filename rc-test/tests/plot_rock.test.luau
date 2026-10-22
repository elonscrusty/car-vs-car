--!strict
-- Tests for the rock plot only (Plots/Rock.luau). The shared rules are in plots.test.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local LapTimer = require("../src/shared/LapTimer")
local Plot = require("../src/shared/Plots/Rock")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot: rock")

local path = Plot.path()

-- Slope (rise over run) of each trail piece.
local function slopes(): { number }
	local out = {}
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		out[i] = (Plot.height(Plot.uOf(i + 1)) - Plot.height(Plot.uOf(i))) / len
	end
	return out
end

test("rock plot loads, slow one-way crawl", function()
	eq(Plot.id, "rock")
	eq(Plot.mode, "oneway")
	eq(#path, (Plot.LAST_U - 1) * 10 + 1)
end)

test("the whole trail and its walls stay inside the track area", function()
	local edge = Plot.HALF_WIDTH + 1.5
	for i, s in path do
		for _, side in { -1, 1 } do
			local x, z = s.x - s.tz * edge * side, s.z + s.tx * edge * side
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

test("it only climbs, never too steep, with two steep climbs to show off", function()
	local steepRuns, inSteep = 0, false
	for i, s in slopes() do
		truthy(s >= -1e-9, `piece {i} goes downhill`)
		truthy(s <= 0.6, `piece {i} is too steep to crawl ({s})`)
		local steep = s > 0.4
		if steep and not inSteep then
			steepRuns += 1
		end
		inSteep = steep
	end
	eq(steepRuns, 2, "steep climbs")
	eq(Plot.height(1), 0)
	truthy(Plot.height(Plot.LAST_U) >= 60, "the flag should be up high")
end)

test("everything on the trail is on the trail, and small ones can be crawled over", function()
	local count: { [string]: number } = {}
	local left, right = 0, 0
	for _, f in Plot.features do
		count[f.kind] = (count[f.kind] or 0) + 1
		truthy(f.u > Plot.START_U and f.u < Plot.FINISH_U, `{f.kind} at {f.u} is off the course`)
		truthy(math.abs(f.side) <= 0.8, `{f.kind} at {f.u} sits in the wall`)
		if f.kind == "rock" then
			if f.lift <= Plot.MAX_LIFT then
				if f.side < 0 then
					left += 1
				elseif f.side > 0 then
					right += 1
				end
			end
		else
			truthy(f.lift <= Plot.MAX_LIFT, `{f.kind} at {f.u} is too tall to crawl`)
		end
	end
	truthy((count.rock or 0) >= 25, "too few rocks")
	truthy((count.log or 0) >= 2, "logs")
	truthy((count.ledge or 0) >= 3, "ledges")
	truthy((count.ramp or 0) >= 2, "ramps")
	-- offset rocks: both sides get lifted, about as often
	truthy(left >= 8 and right >= 8, "crawl rocks should sit on both sides")
end)

test("big rocks hug the edges, leaving room to drive past", function()
	for _, f in Plot.features do
		if f.kind == "rock" and f.lift > Plot.MAX_LIFT then
			local gap = Plot.HALF_WIDTH * (1 + math.abs(f.side)) - f.r
			truthy(gap > 12, `big rock at {f.u} blocks the trail`)
		end
	end
end)

test("gates sit on the trail in order, a run goes start -> checkpoints -> finish", function()
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
