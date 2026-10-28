--!strict
-- The first race's HOLD GAS! hint (GasHint): only when the car still sits on the line after GO.
local H = require("./harness")
local GasHint = require("../src/shared/GasHint")
local test, eq = H.test, H.eq

test(
	"HOLD GAS! shows 2 s after GO with the car still on the line, and goes once it moves",
	function()
		eq(GasHint.shows(nil, false, false), false) -- no GO yet (the lights)
		eq(GasHint.shows(1, false, false), false) -- give them a moment
		eq(GasHint.shows(GasHint.WAIT, false, false), true)
		eq(GasHint.shows(10, false, false), true)
		eq(GasHint.shows(10, true, false), false) -- moved: gone, and stays gone
		eq(GasHint.shows(10, false, true), false) -- the race is over
	end
)

test("the words fit the device", function()
	eq(GasHint.words(true), "HOLD GAS!")
	eq(GasHint.words(false), "HOLD W TO GO!")
end)
