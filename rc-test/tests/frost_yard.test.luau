--!strict
-- Frosty Yard, the second arena (shared/FrostYard): the ice patches sit on open flat ground away from
-- everything that matters; the re-colour only names parts ArenaBuilder / ArenaHorizon really make; the
-- look never repeats more than MAX_RUN rounds; the props stay outside the wall; the ice is the only
-- part that plays differently (a Grip below the sand's).
local fs = require("@lune/fs")
local H = require("./harness")
local F = require("../src/shared/FrostYard")
local A = require("../src/shared/ArenaData")
local Barrels = require("../src/shared/Barrels")
local RollBarrels = require("../src/shared/RollBarrels")
local FirePits = require("../src/shared/FirePits")
local BreakCrates = require("../src/shared/BreakCrates")
local Crane = require("../src/shared/Crane")
local Wrenches = require("../src/shared/Wrenches")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Frosty Yard")

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

test("ice patches are open, flat and off the sand", function()
	eq(#F.ICE, 5)
	for i, p in F.ICE do
		local x, y, r = p[1], p[2], p[3]
		truthy(A.clear(x, y, 3), `ice {i} middle is not open`)
		eq(A.groundAt({ x, y }), 0, `ice {i} middle is not flat`)
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			for _, f in { 0.5, 1 } do
				local q = { x + math.cos(a) * r * f, y + math.sin(a) * r * f }
				truthy(A.clear(q[1], q[2], 3), `ice {i} reaches a wall or cover`)
				eq(A.groundAt(q :: any), 0, `ice {i} reaches a hill or ramp`)
				truthy(not A.inside(A.SAND, q :: any), `ice {i} reaches the sand`)
			end
		end
	end
end)

test("ice keeps clear of starts, boxes, hazards, crates and wrenches", function()
	local sets: { { any } } = {
		{ "start", A.START, 12 },
		{ "box", A.BOXES, 6 },
		{ "keg", Barrels.SPOTS, 10 },
		{ "drum", RollBarrels.SPOTS, 10 },
		{ "pit", FirePits.SPOTS, 12 },
		{ "crate", BreakCrates.SPOTS, 8 },
		{ "crane", { Crane.SPOT }, 14 },
		{ "wrench", Wrenches.SPOTS, 8 },
	}
	for _, s in sets do
		for i, p in F.ICE do
			for j, q in s[2] do
				local d = dist({ p[1], p[2] }, q) - p[3]
				truthy(d >= s[3], `ice {i} is {math.floor(d)} from {s[1]} {j} (need {s[3]})`)
			end
		end
	end
end)

test("ice patches do not touch each other", function()
	for i = 1, #F.ICE do
		for j = i + 1, #F.ICE do
			local a, b = F.ICE[i], F.ICE[j]
			truthy(dist({ a[1], a[2] }, { b[1], b[2] }) - a[3] - b[3] >= 8, `ice {i} and {j} touch`)
		end
	end
end)

test("ice grips less than sand but still steers", function()
	truthy(F.ICE_GRIP < 0.85, "ice must grip less than the sand")
	truthy(F.ICE_GRIP >= 0.2, "ice must still steer")
end)

test("pines, cabin and snowmen stand outside the wall", function()
	local pines = F.pines()
	truthy(#pines >= 20, "too few pines")
	for i, p in pines do
		truthy(p[1] < 0 or p[1] > A.PIC or p[2] < 0 or p[2] > A.PIC, `pine {i} is inside the wall`)
		truthy(p[3] >= 0.8 and p[3] <= 1.4, `pine {i} size`)
	end
	truthy(F.CABIN.y < -20, "the cabin must be past the north wall")
	for i, p in F.SNOWMEN do
		truthy(
			p[1] < 0 or p[1] > A.PIC or p[2] < 0 or p[2] > A.PIC,
			`snowman {i} is inside the wall`
		)
	end
end)

test("the look never repeats more than MAX_RUN rounds", function()
	for _, roll in { 0, 0.3, 0.49, 0.5, 0.9, 1 } do
		local last: string? = nil
		local run = 0
		for round = 1, 20 do
			-- a stubborn roll: always asks for the same look
			local pick = F.next(last, run, roll)
			run = if pick == last then run + 1 else 1
			last = pick
			truthy(run <= F.MAX_RUN, `roll {roll}: {run} in a row at round {round}`)
		end
	end
	eq(F.next(nil, 0, 0.1), F.YARD)
	eq(F.next(nil, 0, 0.9), F.FROST)
end)

test("every re-colour rule names a part the arena really builds", function()
	local builder = fs.readFile("src/server/ArenaBuilder.luau")
	local horizon = fs.readFile("src/shared/ArenaHorizon.luau")
	local data = fs.readFile("src/shared/ArenaData.luau")
	for name, rule in F.RECOLOR do
		local found = string.find(builder, `"{name}"`, 1, true) ~= nil
			or string.find(horizon, `"{name}"`, 1, true) ~= nil
			or string.find(data, `name = "{name}"`, 1, true) ~= nil
		truthy(found, `nothing builds a part called {name}`)
		truthy(rule.a > 0 and rule.a <= 1, `{name} mix`)
		for _, c in rule.c do
			truthy(c >= 0 and c <= 255, `{name} colour`)
		end
	end
end)

test("nothing in the frost look glows", function()
	-- the sky only shifts colours; bright snow stays under the bloom threshold's reach
	for _, c in { F.sky.ambient, F.sky.outdoorAmbient, F.sky.colorShiftTop, F.sky.tint } do
		for _, v in c do
			truthy(v >= 0 and v <= 255, "sky colour")
		end
	end
	truthy(F.sky.saturation <= 0.15, "frost sky must stay calm")
end)

return nil
