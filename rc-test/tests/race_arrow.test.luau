--!strict
-- The road arrow points from the car to the next gate, and never past it.
local H = require("./harness")
local RaceArrow = require("../src/shared/RaceArrow")

local test, eq, truthy = H.test, H.eq, H.truthy

print("RaceArrow")

local function G(x: number, z: number, dx: number, dz: number): RaceArrow.Gate
	return { x = x, y = 0, z = z, dx = dx, dz = dz }
end

test("next gate: the start line first, then the timer's next, wrapped", function()
	local gates = { G(0, 0, 1, 0), G(50, 0, 0, 1), G(50, 50, -1, 0) }
	eq(RaceArrow.nextGate(gates, 3, false), gates[1])
	eq(RaceArrow.nextGate(gates, 2, true), gates[2])
	eq(RaceArrow.nextGate(gates, 4, true), gates[1])
	eq(RaceArrow.nextGate({}, 1, true), nil)
end)

test("far away: in front of the car, pointing at the gate", function()
	local x, z, dx, dz = RaceArrow.place(0, 0, G(100, 0, 0, 1))
	eq(x, RaceArrow.AHEAD)
	eq(z, 0)
	eq(dx, 1)
	eq(dz, 0)
end)

test("near: points the way the gate faces, never past the gate", function()
	local x, z, dx, dz = RaceArrow.place(0, 0, G(10, 0, 0, 1))
	eq(x, 10)
	eq(z, 0)
	eq(dx, 0)
	eq(dz, 1)
	local none = RaceArrow.place(0, 0, G(1, 1, 1, 0))
	eq(none, nil)
	truthy(RaceArrow.MIN < RaceArrow.NEAR and RaceArrow.NEAR > RaceArrow.AHEAD, "order")
end)
