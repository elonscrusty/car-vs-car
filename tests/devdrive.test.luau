--!strict
local H = require("./harness")
local DevDrive = require("../src/shared/DevDrive")

local test, eq, truthy = H.test, H.eq, H.truthy

print("DevDrive (Studio test steering)")

test("two numbers become steer and gas", function()
	local a = DevDrive.parse("0,1")
	truthy(a ~= nil)
	eq((a :: any).steer, 0)
	eq((a :: any).gas, 1)
	local b = DevDrive.parse("-0.4,1")
	eq((b :: any).steer, -0.4)
	eq((b :: any).gas, 1)
	local c = DevDrive.parse(" .5 , -1 ")
	eq((c :: any).steer, 0.5)
	eq((c :: any).gas, -1)
end)

test("both are held between -1 and 1", function()
	local a = DevDrive.parse("3,-7.5")
	eq((a :: any).steer, 1)
	eq((a :: any).gas, -1)
end)

test("anything else means the normal controls", function()
	for _, raw in { "", "x", "1", "1,", ",1", "1,2,3", "a,b", "1;1", "--1,1" } do
		eq(DevDrive.parse(raw), nil, "'" .. raw .. "'")
	end
	eq(DevDrive.parse(nil), nil)
	eq(DevDrive.parse(5), nil)
	eq(DevDrive.parse(true), nil)
end)
