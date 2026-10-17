--!strict
local H = require("./harness")
local ClawPath = require("../src/shared/ClawPath")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("ClawPath")

local target = { x = 1.2, z = -0.8 }
local chute = { x = 2, z = -1.9 }

local function at(name: string): number
	local t = 0
	for _, s in ClawPath.Steps do
		t += s.seconds
		if s.name == name then
			return t
		end
	end
	error("no step " .. name)
end

test("starts and ends at rest, open", function()
	local a = ClawPath.pose(0, target, chute, 1.5)
	near(a.dx, 0)
	near(a.dz, 0)
	near(a.dy, 0)
	eq(a.closed, false)
	local b = ClawPath.pose(ClawPath.total() + 5, target, chute, 1.5)
	near(b.dx, 0)
	near(b.dz, 0)
	near(b.dy, 0)
	eq(b.closed, false)
end)

test("goes over the target, down, and back up", function()
	local p = ClawPath.pose(at("move"), target, chute, 1.5)
	near(p.dx, target.x)
	near(p.dz, target.z)
	near(p.dy, 0)
	p = ClawPath.pose(at("drop"), target, chute, 1.5)
	near(p.dy, -1.5)
	p = ClawPath.pose(at("lift"), target, chute, 1.5)
	near(p.dy, 0)
end)

test("holds the prize while lifting and carrying, lets go over the chute", function()
	eq(ClawPath.pose(at("grab"), target, chute, 1.5).closed, true)
	eq(ClawPath.pose(at("lift") - 0.3, target, chute, 1.5).closed, true)
	eq(ClawPath.pose(at("carry") - 0.1, target, chute, 1.5).closed, true)
	local p = ClawPath.pose(at("carry"), target, chute, 1.5)
	near(p.dx, chute.x)
	near(p.dz, chute.z)
	eq(ClawPath.pose(at("release"), target, chute, 1.5).closed, false)
end)

test("never goes above rest height", function()
	local t = 0
	while t <= ClawPath.total() do
		truthy(ClawPath.pose(t, target, chute, 1.5).dy <= 0.0001)
		t += 0.05
	end
end)
