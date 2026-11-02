--!strict
-- The Saw Rammer's blades spin (PR 1098 marks them with a SpinAxis attribute; the batch spins
-- them): your own car (CarSkin) and everyone else's (OtherCars) turn any part that has one.
local fs = require("@lune/fs")
local H = require("./harness")

local test, truthy = H.test, H.truthy

print("Saw spin")

test("the saw mover marks its blades, and both car views spin what is marked", function()
	local mover = fs.readFile("assets/saw_rammer/studio_saw_rammer.luau")
	truthy(string.find(mover, '"SpinAxis"', 1, true) ~= nil, "mover sets SpinAxis")
	for _, p in { "src/client/CarSkin.luau", "src/client/OtherCars.luau" } do
		local src = fs.readFile(p)
		truthy(string.find(src, 'GetAttribute("SpinAxis")', 1, true) ~= nil, p .. " reads SpinAxis")
		truthy(string.find(src, "CFrame.fromAxisAngle", 1, true) ~= nil, p .. " turns the part")
		truthy(string.find(src, "CarSkin.SPIN_RATE", 1, true) ~= nil, p .. " uses the shared rate")
	end
end)

return nil
