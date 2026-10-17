--!strict
local H = require("./harness")
local Duel = require("../src/shared/Duel")

-- Aim.direction(zAxis, a) = (-sin a, cos a) in (x, z)
local function dirOf(a: number): (number, number)
	return -math.sin(math.rad(a)), math.cos(math.rad(a))
end

H.test("angleOf matches Aim.direction for many angles", function()
	for _, a in { -170, -90, -45, 0, 30, 90, 135, 180 } do
		local x, z = dirOf(a)
		local back = Duel.angleOf(x, z)
		local diff = math.abs((back - a + 180) % 360 - 180)
		H.near(diff, 0, 1e-6, `angle {a}`)
	end
end)

H.test("drag down on screen sends car forward (camera looking along -z)", function()
	-- camera looks toward -Z, its right is +X
	local x, z = Duel.dragToWorld(0, 100, 1, 0, 0, -1)
	H.near(x, 0)
	H.near(z, -100)
end)

H.test("drag left sends car right", function()
	local x, z = Duel.dragToWorld(-50, 0, 1, 0, 0, -1)
	H.near(x, 50)
	H.near(z, 0)
end)

H.test("dragPower deadzone and clamp", function()
	H.eq(Duel.dragPower(5, 20, 220), 0)
	H.near(Duel.dragPower(120, 20, 220), 0.5)
	H.eq(Duel.dragPower(999, 20, 220), 1)
end)

H.test("timeout winner by HP, tie is 0", function()
	H.eq(Duel.timeoutWinner(10, 5), 1)
	H.eq(Duel.timeoutWinner(5, 10), 2)
	H.eq(Duel.timeoutWinner(7, 7), 0)
end)

H.test("botAim points at target and wraps", function()
	H.near(Duel.botAim(0, 0, 0, 10, 0), 0)
	H.near(Duel.botAim(0, 0, -10, 0, 0), 90)
	H.near(Duel.botAim(0, 0, 0, -10, 20), -160, 1e-6)
	H.near(Duel.botAim(0, 0, 0, -10, -20), 160, 1e-6)
end)
