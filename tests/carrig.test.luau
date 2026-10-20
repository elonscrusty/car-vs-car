--!strict
local H = require("./harness")
local CarRig = require("../src/shared/CarRig")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("CarRig")

test("every rig has four wheels, two of them steering, left and right mirrored", function()
	for id, rig in CarRig.Rigs do
		eq(#rig.wheels, 4, id)
		local steering = 0
		for _, w in rig.wheels do
			if w.front then
				steering += 1
				truthy(w.at[3] < 0, id .. " front wheels are toward the nose (-Z)")
			end
			truthy(w.at[2] >= rig.wheelRadius - 1e-6, id .. " wheel does not sink into the floor")
			truthy(
				rig.rideHeight >= 0 and rig.rideHeight < 2 * rig.wheelRadius,
				id .. " body floor is below the tire tops"
			)
		end
		eq(steering, 2, id)
		near(rig.wheels[1].at[1], -rig.wheels[2].at[1], 1e-9, id .. " FL/FR mirror")
		near(rig.wheels[3].at[1], -rig.wheels[4].at[1], 1e-9, id .. " RL/RR mirror")
	end
end)

test("the truck's turret spot is in the bed, behind the middle", function()
	local rig = CarRig.Rigs.RedTruck
	truthy(rig.snaps.roof[3] > 0, "roof spot is toward the tail")
	truthy(rig.snaps.front[3] < 0 and rig.snaps.back[3] > 0)
end)

test("wheels roll with speed and stay inside one turn", function()
	near(CarRig.spin(0, 10, 2, 0.1), 0.5)
	local a = 0
	for _ = 1, 1000 do
		a = CarRig.spin(a, 30, 2, 0.1)
	end
	truthy(a >= 0 and a < 2 * math.pi)
	eq(CarRig.spin(1, 5, 0, 1), 1)
end)

test("steering follows the turn, is capped, and flips when backing up", function()
	eq(CarRig.steer(0, 10), 0)
	truthy(CarRig.steer(1, 10) > 0)
	eq(CarRig.steer(99, 10), CarRig.MaxSteer)
	eq(CarRig.steer(1, -10), -CarRig.steer(1, 10))
end)
