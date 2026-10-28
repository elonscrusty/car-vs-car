--!strict
-- AUTO GAS is off at every race's start and after every put-back. Two races back to back: the
-- first race's grid, AUTO GAS on, walk back (Main's render step stops calling Controls.setRace
-- while you walk, so its "on changed" never fired for race 2: critic run 2), the second race's
-- grid. So the switch-off hangs on the "drive" message itself, sent once per race.
local fs = require("@lune/fs")
local H = require("./harness")
local test, truthy = H.test, H.truthy

print("Auto gas")

local MAIN = "src/client/Main.client.luau"
local CONTROLS = "src/client/Controls.luau"

-- the text of Main from `from` up to the next `till`
local function slice(src: string, from: string, till: string): string
	local a = string.find(src, from, 1, true)
	assert(a, "no " .. from)
	local b = string.find(src, till, a + #from, true) or #src
	return string.sub(src, a, b)
end

test('auto gas: every race\'s grid (each "drive" with a grid spot) turns AUTO GAS off', function()
	local src = fs.readFile(MAIN)
	local drive = slice(src, 'elseif kind == "drive"', "\n\telseif ")
	truthy(string.find(drive, "controls.autoOff()", 1, true), "drive: no controls.autoOff()")
	-- and not hung on setRace's change (it misses the second race)
	local ctl = fs.readFile(CONTROLS)
	local setRace = slice(ctl, "function controls.setRace", "\n\tend\n")
	truthy(not string.find(setRace, "setAuto", 1, true), "setRace still owns AUTO GAS")
	truthy(string.find(ctl, "function controls.autoOff", 1, true), "no controls.autoOff")
end)

test("auto gas: a put-back turns AUTO GAS off and waits for gas before the still clock", function()
	local src = fs.readFile(MAIN)
	local put = slice(src, 'hud.flash("BACK ON TRACK")', "return")
	truthy(string.find(put, "controls.autoOff()", 1, true), "put-back: no controls.autoOff()")
	truthy(string.find(put, "movedSincePut = false", 1, true), "put-back: still clock not held")
	truthy(
		string.find(src, "movedSinceGo and movedSincePut", 1, true),
		"lost ignores movedSincePut"
	)
end)
