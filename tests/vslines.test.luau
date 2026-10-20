--!strict
local H = require("./harness")
local VsLines = require("../src/shared/VsLines")
local BattleConfig = require("../src/shared/BattleConfig")
local eq, truthy = H.eq, H.truthy

print("VsLines")

H.test("every battle car has a line, and unknown cars get a generic one", function()
	for _, id in BattleConfig.Order do
		truthy(#VsLines.lineFor(id, 0) > 0, id)
	end
	truthy(#VsLines.lineFor("NoSuchCar", 3) > 0)
end)

H.test("a line sent by the server wins; an empty one does not", function()
	eq(VsLines.lineFor("RamTruck", 0, "Beep beep"), "Beep beep")
	truthy(VsLines.lineFor("RamTruck", 0, "") ~= "")
end)

H.test("the same name gives the same seed", function()
	eq(VsLines.seedOf("Crusher"), VsLines.seedOf("Crusher"))
	truthy(VsLines.seedOf("A") ~= VsLines.seedOf("B"))
end)
