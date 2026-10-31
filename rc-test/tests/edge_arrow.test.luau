--!strict
-- Edge arrows: where the chevron sits, which targets get one.
local H = require("./harness")
local EdgeArrow = require("../src/shared/EdgeArrow")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Edge arrows")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.01
end

test("edge arrows: a target on screen wants no arrow", function()
	local s = EdgeArrow.place(800, 400, 300, 200, 40, 40, 40, 40)
	eq(s.inside, true)
end)

test("edge arrows: off to the right sits on the right edge pointing right", function()
	local s = EdgeArrow.place(800, 400, 1600, 200, 40, 40, 40, 40)
	eq(s.inside, false)
	truthy(near(s.x, 760), "x " .. s.x)
	truthy(near(s.y, 200), "y " .. s.y)
	truthy(near(s.angle, 0), "angle " .. s.angle)
end)

test("edge arrows: up and left keeps the corner inset and points up-left", function()
	local s = EdgeArrow.place(800, 400, -400, -200, 40, 60, 40, 40)
	truthy(s.x >= 40 - 0.01 and s.y >= 60 - 0.01, `inside the inset ({s.x}, {s.y})`)
	truthy(s.angle < -90 and s.angle > -180, "angle " .. s.angle)
end)

test("edge arrows: the arrow never leaves the inset rect", function()
	for _, p in { { -900, 50 }, { 2000, 900 }, { 400, -700 }, { 400, 1200 }, { 1000, -300 } } do
		local s = EdgeArrow.place(800, 400, p[1], p[2], 40, 60, 40, 90)
		truthy(s.x >= 40 - 0.01 and s.x <= 760 + 0.01, `x {s.x}`)
		truthy(s.y >= 60 - 0.01 and s.y <= 310 + 0.01, `y {s.y}`)
	end
end)

test("edge arrows: behind the camera mirrors through the middle", function()
	local x, y = EdgeArrow.behind(800, 400, 100, 50)
	eq(x, 700)
	eq(y, 350)
end)

test("edge arrows: only the 3 nearest karts and 1 box, in range", function()
	local items = {
		{ dist = 100, enemy = true },
		{ dist = 20, enemy = true }, -- too near: seen anyway
		{ dist = 300, enemy = true },
		{ dist = 150, enemy = true },
		{ dist = 200, enemy = true },
		{ dist = 500, enemy = true }, -- too far
		{ dist = 90, enemy = false },
		{ dist = 60, enemy = false },
	}
	local out = EdgeArrow.pick(items)
	eq(#out, 4)
	eq(out[1], 1)
	eq(out[2], 4)
	eq(out[3], 5)
	eq(out[4], 8)
end)

test("edge arrows: nearer is stronger, always calm", function()
	truthy(EdgeArrow.strength(50) > EdgeArrow.strength(350))
	truthy(EdgeArrow.strength(0) <= 0.9 + 1e-6 and EdgeArrow.strength(1000) >= 0.45 - 1e-6)
end)

test("edge arrows: on a phone the right edge stays above DRIFT, inside the top inset", function()
	for _, size in { { 667, 375 }, { 844, 390 }, { 932, 430 } } do
		local ceiling = EdgeArrow.rightCeiling(size[2])
		local driftTop = 0.32 * size[2] -- (Controls: DRIFT bottom 0.54, side 0.22 of the height)
		truthy(ceiling + 15 < driftTop, `chevron reaches DRIFT at {size[1]}x{size[2]}`)
		truthy(ceiling >= 74, `no room under the top bar at {size[1]}x{size[2]}`) -- (phone top inset)
	end
end)

return nil
