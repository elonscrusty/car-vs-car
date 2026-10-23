--!strict
local H = require("./harness")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("LapTimer")

local function gate(x: number, z: number): LapTimer.Gate
	return { x = x, y = 0, z = z, dx = 0, dz = -1, halfWidth = 10, depth = 3 }
end

test("loop: lap counts only after every gate in order", function()
	local s = LapTimer.new({ gate(0, 0), gate(0, -50), gate(0, -100) }, "loop")
	eq(LapTimer.update(s, 0, 0, 0, 20), nil)
	eq(LapTimer.update(s, 1, 0, 0, 0), "start")
	-- skipping gate 2 does nothing
	eq(LapTimer.update(s, 2, 0, 0, -100), nil)
	eq(LapTimer.update(s, 3, 0, 0, -50), "checkpoint")
	eq(LapTimer.update(s, 4, 0, 0, -100), "checkpoint")
	eq(LapTimer.update(s, 11, 0, 0, 0), "lap")
	near(s.last :: number, 10)
	eq(s.laps, 1)
	-- second lap is faster: best updates
	LapTimer.update(s, 12, 0, 0, -50)
	LapTimer.update(s, 13, 0, 0, -100)
	eq(LapTimer.update(s, 17, 0, 0, 0), "lap")
	near(s.best :: number, 6)
	near(s.last :: number, 6)
end)

test("oneway: last gate stops the clock, best is kept after a reset", function()
	local s = LapTimer.new({ gate(0, 0), gate(0, -80) }, "oneway")
	eq(LapTimer.update(s, 5, 0, 0, 0), "start")
	eq(LapTimer.update(s, 25, 0, 0, -80), "finish")
	truthy(s.finished)
	near(s.last :: number, 20)
	LapTimer.reset(s)
	eq(s.finished, false)
	near(s.best :: number, 20)
	eq(LapTimer.update(s, 30, 0, 0, -80), nil)
end)

test("gate shape: width, depth and height", function()
	local s = LapTimer.new({ gate(0, 0), gate(0, -50) }, "oneway")
	eq(LapTimer.update(s, 1, 11, 0, 0), nil)
	eq(LapTimer.update(s, 1, 0, 0, 4), nil)
	eq(LapTimer.update(s, 1, 0, 30, 0), nil)
	eq(LapTimer.update(s, 1, 9, 5, 2), "start")
end)

test("no gates = nothing happens", function()
	local s = LapTimer.new({}, "free")
	eq(LapTimer.update(s, 1, 0, 0, 0), nil)
end)

test("go: a standing start runs the clock, the line just ahead doesn't restart it", function()
	local s = LapTimer.new({ gate(0, 0), gate(0, -50) }, "loop")
	LapTimer.go(s, 2)
	truthy(s.running)
	eq(LapTimer.update(s, 2.5, 0, 0, 0), nil)
	eq(LapTimer.update(s, 5, 0, 0, -50), "checkpoint")
	eq(LapTimer.update(s, 12, 0, 0, 0), "lap")
	near(s.last :: number, 10)
end)

local RaceStart = require("../src/shared/RaceStart")

test("race start: 3 red lamps then green, one at a time", function()
	local s = RaceStart.new()
	local got = {}
	for _ = 1, 400 do
		local step = RaceStart.update(s, 1 / 60)
		if step then
			table.insert(got, step)
		end
	end
	eq(table.concat(got, ","), "1,2,3,4")
	eq(RaceStart.update(s, 10), nil)
	-- green comes WAIT + 3 steps after landing
	local t = RaceStart.new()
	eq(RaceStart.update(t, RaceStart.WAIT - 0.01), nil)
	eq(RaceStart.update(t, 0.02), 1)
	eq(RaceStart.label(1), "3")
	eq(RaceStart.label(3), "1")
	eq(RaceStart.label(RaceStart.GO), "GO!")
end)
