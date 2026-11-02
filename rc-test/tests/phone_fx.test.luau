--!strict
-- Phone buzz and auto quality: shared/Buzz and shared/FxLevel (pure rules).
local H = require("./harness")
local Buzz = require("../src/shared/Buzz")
local FxLevel = require("../src/shared/FxLevel")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Phone buzz and auto quality")

test("buzz: tiny, smash bigger than hit, one per gap, off switch works", function()
	truthy(Buzz.HIT.seconds <= 0.06, "hit is tiny")
	truthy(Buzz.SMASH.strength > Buzz.HIT.strength, "smash is bigger")
	eq(Buzz.ready(0, 0.01, false), false, "inside the gap")
	eq(Buzz.ready(0, 1, false), true, "after the gap")
	eq(Buzz.ready(0, 1, true), false, "off")
end)

local function run(s: FxLevel.State, fps: number, seconds: number)
	for _ = 1, math.floor(seconds * fps) do
		FxLevel.tick(s, 1 / fps)
	end
end

test("fx level: fast screen stays at full", function()
	local s = FxLevel.new()
	run(s, 60, 20)
	eq(FxLevel.level(s), 1, "full")
end)

test("fx level: slow screen drops, very slow drops more, never below the last step", function()
	local s = FxLevel.new()
	run(s, 22, 10)
	eq(FxLevel.level(s), 0.5, "half at 22 fps")
	run(s, 12, 20)
	eq(FxLevel.level(s), 0.25, "quarter at 12 fps")
	run(s, 5, 20)
	eq(FxLevel.level(s), 0.25, "stays at the floor")
end)

test("fx level: comes back slowly when fast again; a loading hitch is ignored", function()
	local s = FxLevel.new()
	run(s, 12, 20)
	eq(FxLevel.level(s), 0.25, "quarter")
	run(s, 60, 40)
	eq(FxLevel.level(s), 1, "back to full")
	local h = FxLevel.new()
	for _ = 1, 20 do
		FxLevel.tick(h, 2)
	end
	eq(FxLevel.level(h), 1, "hitches skipped")
end)

test("fx level: count scales and keeps at least one", function()
	eq(FxLevel.count(10, 0.5), 5, "half")
	eq(FxLevel.count(1, 0.25), 1, "still one")
	eq(FxLevel.count(0, 0.25), 0, "none stays none")
end)
