--!strict
-- Landing bounce (LandingBounce.luau): squashes on a hard landing, wobbles back to normal, and a
-- car that never landed is never touched.
local H = require("./harness")
local LB = require("../src/shared/LandingBounce")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("Landing bounce")

test("a car that never landed stays exactly the same size", function()
	local s = LB.new()
	for _ = 1, 30 do
		local sx, sy = LB.step(s, 1 / 60)
		eq(sx, 1)
		eq(sy, 1)
	end
end)

test("a hard landing squashes short and wide, then stretches tall", function()
	local s = LB.new()
	LB.land(s, 1)
	local sx, sy = LB.step(s, 1 / 60)
	truthy(sy < 1 and sx > 1, "squashed")
	local tallest = 0
	for _ = 1, 60 do
		local _, y = LB.step(s, 1 / 60)
		tallest = math.max(tallest, y)
	end
	truthy(tallest > 1, "stretched tall")
end)

test("a harder landing squashes more", function()
	local soft, hard = LB.new(), LB.new()
	LB.land(soft, 0.2)
	LB.land(hard, 1)
	local _, ys = LB.step(soft, 1 / 60)
	local _, yh = LB.step(hard, 1 / 60)
	truthy(yh < ys, "hard is flatter")
end)

test("it settles back to normal", function()
	local s = LB.new()
	LB.land(s, 1)
	local sx, sy = 0, 0
	for _ = 1, 150 do
		sx, sy = LB.step(s, 1 / 60)
	end
	near(sx, 1, 1e-9)
	near(sy, 1, 1e-9)
end)

test("no landing (0) changes nothing", function()
	local s = LB.new()
	LB.land(s, 0)
	local sx, sy = LB.step(s, 1 / 60)
	eq(sx, 1)
	eq(sy, 1)
end)
