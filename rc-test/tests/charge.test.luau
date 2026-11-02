--!strict
-- A kart's one special (shared/Charge): a gold box adds a third, it fills slowly alone, a full one
-- leaves the box for someone else, and the SPECIAL button spends only a full one.
local H = require("./harness")
local C = require("../src/shared/Charge")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Charge")

test("a new special is empty and three boxes fill it", function()
	local s = C.slot(100)
	near(C.level(s, 100), 0, 1e-9)
	near(C.add(s, 100) :: number, 1 / 3, 1e-9)
	near(C.add(s, 100) :: number, 2 / 3, 1e-9)
	eq(C.full(s, 100), false)
	near(C.add(s, 100) :: number, 1, 1e-9)
	eq(C.full(s, 100), true, "three boxes = full")
end)

test("a full special refuses a box (it stays for someone else)", function()
	local s = C.slot(0)
	for _ = 1, 3 do
		C.add(s, 0)
	end
	eq(C.add(s, 0), nil)
	near(C.level(s, 0), 1, 1e-9)
end)

test("it fills slowly on its own, 45 s from empty, and never past full", function()
	local s = C.slot(10)
	near(C.level(s, 10 + C.FILL_SECS / 2), 0.5, 1e-9)
	near(C.level(s, 10 + C.FILL_SECS), 1, 1e-9)
	near(C.level(s, 10 + C.FILL_SECS * 5), 1, 1e-9)
	near(C.level(s, 0), 0, 1e-9, "a clock that went back is just empty")
end)

test("a box adds to what the slow timer already filled", function()
	local s = C.slot(0)
	near(C.add(s, 15) :: number, 1 / 3 + 15 / C.FILL_SECS, 1e-9)
	-- the timer keeps going from the box: 15 s later it is a third + 30 s worth
	near(C.level(s, 30), 1 / 3 + 30 / C.FILL_SECS, 1e-9)
end)

test("the last box tops it off at exactly full", function()
	local s = C.slot(0)
	C.add(s, 0)
	C.add(s, 0)
	-- 10 s of timer makes it 2/3 + 2/9: the box must clamp at 1, not 1.22
	-- (30 s would fill it on the timer alone, and a full special refuses the box)
	near(C.add(s, 10) :: number, 1, 1e-9)
end)

test("use needs a full special and empties it", function()
	local s = C.slot(0)
	eq(C.use(s, 0), false, "empty: no")
	C.add(s, 0)
	eq(C.use(s, 0), false, "a third: no")
	C.add(s, 0)
	C.add(s, 0)
	eq(C.use(s, 0), true)
	near(C.level(s, 0), 0, 1e-9)
	eq(C.use(s, 0), false, "spent")
	-- and it fills again, slowly
	near(C.level(s, 9), 9 / C.FILL_SECS, 1e-9)
end)

test("dots: a third lights one, two thirds two, full three", function()
	eq(C.pips(0), 0)
	eq(C.pips(1 / 3), 1, "a third is one dot even with float rounding")
	eq(C.pips(0.5), 1)
	eq(C.pips(2 / 3), 2)
	eq(C.pips(1), 3)
	eq(C.pips(7), 3)
	eq(C.pips(-1), 0)
end)

test("nonsense amounts add nothing", function()
	local s = C.slot(0)
	eq(C.add(s, 0, 0), nil)
	eq(C.add(s, 0, -1), nil)
	eq(C.add(s, 0, 0 / 0), nil)
	near(C.level(s, 0), 0, 1e-9)
	truthy(C.PER_BOX == 1 / 3)
end)
